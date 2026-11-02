//! Use eza's filename style, without duplicating its file-type/theme database.
//! I/O runs only in fish's background highlighter. No shell or user command is run.
use crate::env::Environment;
use crate::text_face::{ResettableStyle, TextFace, UnderlineStyle};
use fish_color::Color;
use fish_widestring::{L, wcs2osstring, wstr};
use std::collections::HashMap;
use std::ffi::OsString;
use std::io::Read;
use std::os::unix::fs::MetadataExt;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, Instant};

// Keep HighlightSpec Copy/Eq/Hash for fish's existing render cache.
// 0 = terminal default, 1..256 = palette, 0x1000000 | RGB = truecolor.
#[derive(Clone, Copy, Debug, Default, Eq, Hash, PartialEq)]
pub struct EzaStyle {
    fg: u32,
    bg: u32,
    flags: u8,
}

impl EzaStyle {
    pub(crate) fn apply(self, face: &mut TextFace) {
        let color = |n: u32| match n {
            0 => Color::Normal,
            1..=256 => Color::Named { idx: (n - 1) as u8 },
            _ => Color::from_rgb((n >> 16) as u8, (n >> 8) as u8, n as u8),
        };
        face.fg = color(self.fg);
        face.bg = color(self.bg);
        face.style.bold = self.flags & 1 != 0;
        face.style.dim = self.flags & 2 != 0;
        face.style.italics = if self.flags & 4 != 0 {
            ResettableStyle::On(())
        } else {
            ResettableStyle::Off
        };
        if self.flags & 8 != 0 {
            face.style
                .inject_underline(ResettableStyle::On(UnderlineStyle::Single));
        }
        face.style.reverse = if self.flags & 16 != 0 {
            ResettableStyle::On(())
        } else {
            ResettableStyle::Off
        };
        face.style.strikethrough = if self.flags & 32 != 0 {
            ResettableStyle::On(())
        } else {
            ResettableStyle::Off
        };
    }

    fn sgr(&mut self, codes: &[u16]) -> Option<()> {
        let mut i = 0;
        while i < codes.len() {
            match codes[i] {
                0 => *self = Self::default(),
                1 => self.flags |= 1,
                2 => self.flags |= 2,
                3 => self.flags |= 4,
                4 => self.flags |= 8,
                7 => self.flags |= 16,
                9 => self.flags |= 32,
                22 => self.flags &= !3,
                23 => self.flags &= !4,
                24 => self.flags &= !8,
                27 => self.flags &= !16,
                29 => self.flags &= !32,
                n @ 30..=37 => self.fg = u32::from(n - 30 + 1),
                n @ 40..=47 => self.bg = u32::from(n - 40 + 1),
                n @ 90..=97 => self.fg = u32::from(n - 90 + 9),
                n @ 100..=107 => self.bg = u32::from(n - 100 + 9),
                39 => self.fg = 0,
                49 => self.bg = 0,
                n @ (38 | 48) => {
                    let c = match *codes.get(i + 1)? {
                        5 => {
                            i += 2;
                            u32::from(*codes.get(i)?.min(&255)) + 1
                        }
                        2 => {
                            let r = *codes.get(i + 2)?;
                            let g = *codes.get(i + 3)?;
                            let b = *codes.get(i + 4)?;
                            if r > 255 || g > 255 || b > 255 {
                                return None;
                            }
                            i += 4;
                            0x1000000 | u32::from(r) << 16 | u32::from(g) << 8 | u32::from(b)
                        }
                        _ => return None,
                    };
                    if n == 38 {
                        self.fg = c;
                    } else {
                        self.bg = c;
                    }
                }
                _ => (),
            }
            i += 1;
        }
        Some(())
    }
}

// Only decode leading SGR; never relay terminal controls or filename bytes.
fn parse_style(bytes: &[u8], name: &[u8]) -> Option<EzaStyle> {
    let mut style = EzaStyle::default();
    let mut i = 0;
    while bytes.get(i..i + 2) == Some(b"\x1b[") {
        let end = i + 2 + bytes.get(i + 2..)?.iter().position(|b| *b == b'm')?;
        let codes = std::str::from_utf8(bytes.get(i + 2..end)?).ok()?;
        let codes: Option<Vec<u16>> = codes
            .split(';')
            .map(|n| {
                if n.is_empty() {
                    Some(0)
                } else {
                    n.parse().ok()
                }
            })
            .collect();
        style.sgr(&codes?)?;
        i = end + 1;
    }
    bytes.get(i..)?.starts_with(name).then_some(style)
}

#[derive(Hash, Eq, PartialEq)]
struct CacheKey {
    path: PathBuf,
    // Includes chmod, edits, parent changes (eza can classify build outputs by siblings).
    metadata: (u64, u32, i64, i64, i64, i64),
    environment: Vec<(&'static str, Option<OsString>)>,
}
struct CacheEntry {
    at: Instant,
    style: Option<EzaStyle>,
}
static CACHE: OnceLock<Mutex<HashMap<CacheKey, CacheEntry>>> = OnceLock::new();

pub(crate) fn style_for(path: &wstr, vars: &dyn Environment) -> Option<EzaStyle> {
    if vars.get(L!("fish_color_path_by_type"))?.as_string() != L!("1") {
        return None;
    }
    let path = PathBuf::from(wcs2osstring(path));
    let parent = path
        .parent()
        .filter(|p| !p.as_os_str().is_empty())
        .unwrap_or(Path::new("/"));
    let name = path.file_name().unwrap_or(std::ffi::OsStr::new("."));
    use std::os::unix::ffi::OsStrExt;
    // eza escapes control characters; leave those rare names to standard highlighting.
    if name.as_bytes().iter().any(|b| *b < 32 || *b == 127) {
        return None;
    }
    let meta = std::fs::symlink_metadata(&path).ok()?;
    let parent_meta = std::fs::metadata(parent).ok()?;
    let environment = [
        ("EZA_COLORS", L!("EZA_COLORS")),
        ("LS_COLORS", L!("LS_COLORS")),
        ("EXA_COLORS", L!("EXA_COLORS")),
        ("EZA_CONFIG_DIR", L!("EZA_CONFIG_DIR")),
        ("XDG_CONFIG_HOME", L!("XDG_CONFIG_HOME")),
        ("HOME", L!("HOME")),
    ]
    .into_iter()
    .map(|(name, key)| (name, vars.get(key).map(|v| wcs2osstring(&v.as_string()))))
    .collect::<Vec<_>>();
    let key = CacheKey {
        path: path.clone(),
        metadata: (
            meta.ino(),
            meta.mode(),
            meta.ctime(),
            meta.ctime_nsec(),
            parent_meta.mtime(),
            parent_meta.mtime_nsec(),
        ),
        environment,
    };
    let cache = CACHE.get_or_init(|| Mutex::new(HashMap::new()));
    if let Some(entry) = cache.lock().ok()?.get(&key) {
        if entry.at.elapsed() < Duration::from_secs(2) {
            return entry.style;
        }
    }
    let mut command = Command::new("@eza@");
    command
        .current_dir(parent)
        .args([
            "--oneline",
            "--treat-dirs-as-files",
            "--color=always",
            "--icons=never",
            "--hyperlink=never",
            "--classify=never",
            "--no-quotes",
            "--",
        ])
        .arg(name)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null());
    for (name, value) in &key.environment {
        if let Some(value) = value {
            command.env(name, value);
        } else {
            command.env_remove(name);
        }
    }
    let mut child = command.spawn().ok()?;
    let started = Instant::now();
    let style = loop {
        match child.try_wait() {
            Ok(Some(status)) => {
                let mut output = Vec::new();
                if status.success() {
                    if let Some(stdout) = child.stdout.take() {
                        let _ = stdout.take(16384).read_to_end(&mut output);
                    }
                }
                break parse_style(&output, name.as_bytes());
            }
            Ok(None) if started.elapsed() < Duration::from_millis(80) => {
                std::thread::sleep(Duration::from_millis(1))
            }
            _ => {
                let _ = child.kill();
                let _ = child.wait();
                break None;
            }
        }
    };
    let mut cache = cache.lock().ok()?;
    if cache.len() >= 256 {
        cache.clear();
    }
    cache.insert(
        key,
        CacheEntry {
            at: Instant::now(),
            style,
        },
    );
    style
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn eza_style_sgr() {
        let style = parse_style(b"\x1b[1;34mGit\x1b[0m\n", b"Git").unwrap();
        assert_eq!(style.fg, 5);
        assert_eq!(style.flags, 1);
        let style = parse_style(
            b"\x1b[38;2;100;150;200;48;5;17mphoto.png\x1b[0m\n",
            b"photo.png",
        )
        .unwrap();
        assert_eq!(style.fg, 0x16496c8);
        assert_eq!(style.bg, 18);
        assert!(parse_style(b"\x1b]52;c;bad\x07file", b"file").is_none());
        assert!(parse_style(b"\x1b[38;2;1mfile", b"file").is_none());
        assert!(parse_style(b"wrong", b"file").is_none());
    }
}
