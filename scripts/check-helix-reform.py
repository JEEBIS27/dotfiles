#!/usr/bin/env python3
"""Test rendered Graphite keymaps and composable editing operations."""

import argparse
import fcntl
import json
import os
import pty
import re
import select
import shutil
import struct
import subprocess
import tempfile
import termios
import time
from pathlib import Path

import pyte

parser = argparse.ArgumentParser(
    description="Test rendered Helix keys, syntax targets and wrappers in private PTYs (requires pyte)."
)
parser.add_argument(
    "--config",
    type=Path,
    required=True,
    help="Home Manager generated helix/config.toml",
)
parser.add_argument("--helix", default=shutil.which("hx"))
parser.add_argument("--direction-keys", default="haoe")
parser.add_argument(
    "--live",
    action="store_true",
    help="Use the installed config and plugins; skip clipboard tests",
)
parser.add_argument(
    "--match", help="Only run named cases matching this regular expression"
)
parser.add_argument(
    "--boolswitcher",
    type=Path,
    default=Path.home() / ".local/share/jeebis-helix-steel/cogs/boolswitcher.hx",
)
args = parser.parse_args()
repo = Path(__file__).resolve().parent.parent
assert args.helix
assert len(args.direction_keys) == 4 and len(set(args.direction_keys)) == 4
logical = "hjkl"
mapping = dict(zip(logical, args.direction_keys))
inverse = {v: k for k, v in mapping.items()}
for key in set(args.direction_keys) - set(logical):
    previous = inverse[key]
    while previous in inverse:
        previous = inverse[previous]
    mapping[key] = previous
mapping.update({k.upper(): v.upper() for k, v in list(mapping.items())})


class Screen(pyte.Screen):
    def report_device_status(self, mode, private=False):
        if not private:
            return super().report_device_status(mode)


class Editor:
    def __init__(self, name, text, live=args.live):
        self.temp = tempfile.TemporaryDirectory(prefix="hx-reform-")
        self.root = Path(self.temp.name)
        self.path = self.root / name
        self.path.write_text(text)
        env = {
            k: v
            for k, v in os.environ.items()
            if not k.startswith(
                ("TUIOS", "HERDR", "TMUX", "HELIX_STEEL_CONFIG", "STEEL_HOME")
            )
        }
        env["TERM"] = "xterm-256color"
        if not live:
            conf = self.root / "config/helix"
            (conf / "themes").mkdir(parents=True)
            (conf / "config.toml").write_text(args.config.read_text())
            source = (repo / "files/helix/steel/init.scm").read_text()
            block = source[
                source.index(";; BEGIN cursor motions") : source.index(
                    ";; END cursor motions"
                )
            ]
            smooth = source[
                source.index(";; BEGIN smooth scrolling") : source.index(
                    ";; END smooth scrolling"
                )
            ]
            (conf / "init.scm").write_text(block + "\n" + smooth)
            cogs = self.root / "data/jeebis-helix-steel/cogs"
            cogs.mkdir(parents=True)
            (cogs / "boolswitcher.hx").symlink_to(args.boolswitcher.resolve())
            self.clipboard = self.root / "clipboard"
            with (conf / "config.toml").open("a") as out:
                out.write(
                    "\n[editor.clipboard-provider.custom]\n"
                    + "yank = "
                    + "{command = "
                    + json.dumps(shutil.which("cat"))
                    + ", args = ["
                    + json.dumps(str(self.clipboard))
                    + "]}"
                    + "\n"
                    + "paste = "
                    + "{command = "
                    + json.dumps(shutil.which("tee"))
                    + ", args = ["
                    + json.dumps(str(self.clipboard))
                    + "]}"
                    + "\n"
                )
            (conf / "themes/Desktop.toml").write_text('inherits = "default"\n')
            env.update(
                HOME=str(self.root),
                XDG_CONFIG_HOME=str(self.root / "config"),
                XDG_DATA_HOME=str(self.root / "data"),
                XDG_CACHE_HOME=str(self.root / "cache"),
                XDG_STATE_HOME=str(self.root / "state"),
            )
        self.fd, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 140, 0, 0))
        self.screen = Screen(140, 40)
        self.stream = pyte.ByteStream(self.screen)
        self.output = bytearray()
        self.p = subprocess.Popen(
            [args.helix, str(self.path)],
            stdin=slave,
            stdout=slave,
            stderr=slave,
            env=env,
        )
        os.close(slave)
        self.pump(3 if args.live else 1)

    def view(self):
        return "\n".join(self.screen.display)

    def pump(self, duration=0.25):
        until = time.monotonic() + duration
        while time.monotonic() < until:
            if not select.select([self.fd], [], [], 0.02)[0]:
                continue
            try:
                data = os.read(self.fd, 65536)
            except OSError:
                break
            self.output.extend(data)
            self.stream.feed(data)
            if b"\x1b[?6n" in data:
                os.write(self.fd, b"\x1b[?1;1R")
            if b"\x1b[6n" in data:
                os.write(self.fd, b"\x1b[1;1R")
            if b"\x1b[c" in data:
                os.write(self.fd, b"\x1b[?1;2c")

    def send(self, data, delay=0.3):
        os.write(self.fd, data)
        self.pump(delay)

    def key(self, s):
        # Separate key events allow Steel/compositor callbacks to settle, as
        # with physical input; a whole byte burst can precede deferred callbacks.
        for char in s.translate(str.maketrans(mapping)):
            os.write(self.fd, char.encode())
            self.pump(0.03)
        self.pump(0.25)

    def save(self):
        self.send(b"\x13")
        return self.path.read_text()

    def close(self):
        if self.p.poll() is None:
            self.send(b"\x1b")
            self.send(b":quit-all!\r")
        if self.p.poll() is None:
            self.p.terminate()
        self.p.wait(timeout=5)
        os.close(self.fd)
        self.temp.cleanup()


def case(name, text, actions, expected):
    if args.match and not re.search(args.match, name):
        return
    e = Editor(name, text)
    try:
        assert "error[E" not in e.view(), e.view()
        for kind, packet in actions:
            (e.key if kind == "k" else e.send)(packet)
        actual = e.save()
        assert actual == expected, (name, actual, expected, e.view())
        assert "no such command" not in e.view(), e.view()
        print("PASS", name, flush=True)
    finally:
        e.close()


case("next.txt", "alpha beta gamma\n", [("k", "w"), ("k", "d")], "alpha  gamma\n")
case(
    "prev.txt",
    "alpha beta gamma\n",
    [("k", "w"), ("k", "e"), ("k", "d")],
    " beta gamma\n",
)
case(
    "start.txt",
    "alpha beta gamma\n",
    [("k", "w"), ("k", "b"), ("k", "i"), ("t", b"X"), ("t", b"\x1b")],
    "alpha Xbeta gamma\n",
)
case(
    "append.txt",
    "alpha beta gamma\n",
    [("k", "w"), ("k", "I"), ("t", b"X"), ("t", b"\x1b")],
    "alpha betaX gamma\n",
)
case("current.txt", "SUPER xyz\n", [("k", "ll"), ("k", "t"), ("k", "d")], " xyz\n")
case("WORD.txt", "alpha beta.foo gamma\n", [("k", "W"), ("k", "d")], "alpha  gamma\n")
case(
    "WORD-prev.txt",
    "alpha beta.foo gamma\n",
    [("k", "W"), ("k", "E"), ("k", "d")],
    " beta.foo gamma\n",
)
case(
    "WORD-start.txt",
    "alpha beta.foo gamma\n",
    [("k", "W"), ("k", "B"), ("k", "i"), ("t", b"X"), ("t", b"\x1b")],
    "alpha Xbeta.foo gamma\n",
)
case(
    "line-mode.txt",
    "one\ntwo\nthree\nfour\n",
    [("k", "V"), ("k", "j"), ("k", "d")],
    "three\nfour\n",
)
case("all.txt", "one\ntwo\n", [("t", b"\x01"), ("k", "d")], "")
case(
    "open.txt",
    "one\n",
    [
        ("k", "o"),
        ("t", b"two"),
        ("t", b"\x1b"),
        ("k", "O"),
        ("t", b"above"),
        ("t", b"\x1b"),
    ],
    "one\nabove\ntwo\n",
)
case("cut.txt", "abcd\n", [("k", "y"), ("k", "l"), ("k", "D"), ("k", "p")], "acbd\n")
case(
    "replace-yank.txt",
    "abcd\n",
    [("k", "y"), ("k", "l"), ("k", "R"), ("t", b"X"), ("k", "p")],
    "aXbcd\n",
)
case("call.py", "outer(inner(1), 2)\n", [("k", "ll"), ("k", "tf"), ("k", "d")], "\n")
case(
    "nested.py",
    "outer(inner(1), 2)\n",
    [("k", "7l"), ("k", "tf"), ("k", "d")],
    "outer(, 2)\n",
)
case("next-call.py", "first(1); second(2)\n", [("k", "nf"), ("k", "d")], "first(1); \n")
case(
    "prev-call.py",
    "first(1); second(2)\n",
    [("k", "nf"), ("k", "Nf"), ("k", "d")],
    "; second(2)\n",
)
case(
    "function.py",
    "def sample(x):\n    return x\n\nsample(1)\n",
    [("k", "j"), ("k", "tF"), ("k", "d")],
    "\n\nsample(1)\n",
)
case("pair.txt", "(alpha)\n", [("k", "t("), ("k", "s"), ("k", "d")], "alpha\n")
case("unwrap.py", "foo(alpha)\n", [("k", "tf"), ("k", "s"), ("k", "d")], "alpha\n")
case(
    "rewrap.py",
    "foo(alpha)\n",
    [("k", "tf"), ("k", "s"), ("k", "r"), ("t", b"[")],
    "[alpha]\n",
)
case("inner.py", "foo(alpha)\n", [("k", "tf"), ("k", "S"), ("k", "d")], "foo()\n")
case(
    "wrap.txt",
    "alpha\n",
    [("k", "t"), ("t", b"\x1b[71;6u"), ("k", "sa"), ("t", b"[")],
    "[alpha]\n",
)
case(
    "function-wrap.txt",
    "alpha\n",
    [("k", "t"), ("t", b"\x1b[71;6u"), ("k", "sa"), ("t", b"f"), ("t", b"foo\r")],
    "foo(alpha)\n",
)
case(
    "function-rewrap.py",
    "foo(alpha)\n",
    [("k", "tf"), ("k", "s"), ("k", "r"), ("t", b"f"), ("t", b"bar\r")],
    "bar(alpha)\n",
)
case(
    "find.txt",
    "abacad\n",
    [("k", "f"), ("t", b"a"), ("k", ";i"), ("t", b"X"), ("t", b"\x1b")],
    "abXacad\n",
)

case(
    "insert-literal.txt",
    "abc\n",
    [("k", "i"), ("t", b"aeojkl "), ("t", b"\x1b")],
    "aeojkl abc\n",
)
case("replace-literal.txt", "abc\n", [("k", "r"), ("t", b"a")], "abc\n")
case(
    "wrap-undo.txt",
    "alpha\n",
    [("k", "t"), ("t", b"\x1b[71;6u"), ("k", "sa"), ("t", b"["), ("k", "u")],
    "alpha\n",
)
case(
    "rewrap-undo.py",
    "foo(alpha)\n",
    [("k", "tf"), ("k", "s"), ("k", "r"), ("t", b"["), ("k", "u")],
    "foo(alpha)\n",
)
case(
    "multi-wrap.txt",
    "one two\n",
    [
        ("t", b"\x01"),
        ("k", "G/"),
        ("t", b"one|two\r"),
        ("t", b"\x1b[71;6u"),
        ("k", "sa"),
        ("t", b"["),
    ],
    "[one] [two]\n",
)
case(
    "multi-unwrap.py",
    "foo(1); bar(2)\n",
    [
        ("t", b"\x01"),
        ("k", "G/"),
        ("t", b"foo\\(1\\)|bar\\(2\\)\r"),
        ("k", "s"),
        ("k", "d"),
    ],
    "1; 2\n",
)
case(
    "call-unicode.py",
    "変数 = foo(日本語)\n",
    [("k", "nf"), ("k", "s"), ("k", "r"), ("t", b"[")],
    "変数 = [日本語]\n",
)
case(
    "function.js",
    "function sample(x) { return x; }\n",
    [("k", "tF"), ("k", "s"), ("k", "d")],
    " return x; \n",
)
case(
    "function.rs",
    "fn sample(x: i32) -> i32 { x }\n",
    [("k", "tF"), ("k", "s"), ("k", "d")],
    " x \n",
)
case(
    "call.js",
    "const x = foo(bar(1));\n",
    [("k", "nf"), ("k", "s"), ("k", "r"), ("t", b"[")],
    "const x = [bar(1)];\n",
)
case(
    "line-shrink.txt",
    "one\ntwo\nthree\n",
    [("k", "V"), ("k", "j"), ("k", "k"), ("k", "d")],
    "two\nthree\n",
)
case(
    "line-exit.txt",
    "one\ntwo\n",
    [("k", "V"), ("t", b"\x1b"), ("k", "l"), ("k", "d")],
    "one\nwo\n",
)
case(
    "change.txt",
    "abcd\n",
    [("k", "y"), ("k", "l"), ("k", "C"), ("t", b"X"), ("t", b"\x1b"), ("k", "p")],
    "aXcbd\n",
)
case(
    "multi-wrap-compose.txt",
    "one two\n",
    [
        ("t", b"\x01"),
        ("k", "G/"),
        ("t", b"one|two\r"),
        ("t", b"\x1b[71;6u"),
        ("k", "sa"),
        ("t", b"["),
        ("k", "d"),
    ],
    " \n",
)
case(
    "rewrap-compose.py",
    "foo(alpha)\n",
    [
        ("k", "tf"),
        ("k", "s"),
        ("k", "r"),
        ("t", b"["),
        ("k", "r"),
        ("t", b"("),
        ("k", "d"),
    ],
    "alpha\n",
)
case(
    "call-count.py",
    "first(1); second(2); third(3)\n",
    [("k", "2nf"), ("k", "d")],
    "first(1); second(2); \n",
)
case(
    "call-select.py",
    "first(1); second(2)\n",
    [("k", "v"), ("k", "nf"), ("k", "d")],
    "\n",
)
case("replace-cancel.txt", "abc\n", [("k", "r"), ("t", b"\x1b")], "abc\n")
case(
    "surround-cancel.txt",
    "abc\n",
    [("k", "t"), ("t", b"\x1b[71;6u"), ("k", "sa"), ("t", b"\x1b")],
    "abc\n",
)
case(
    "function-cancel.txt",
    "abc\n",
    [("k", "t"), ("t", b"\x1b[71;6u"), ("k", "sa"), ("t", b"f"), ("t", b"foo\x1b")],
    "abc\n",
)
case(
    "modifier-split.txt",
    "abcd\n",
    [
        ("t", b"\x1b[13;5u"),
        ("k", "l"),
        ("t", b"\x08"),
        ("k", "i"),
        ("t", b"XY"),
        ("t", b"\x1b[3;6~"),
        ("t", b"\x1b"),
    ],
    "XY\n",
)
case(
    "modifier-code.txt",
    "1\n",
    [("t", b"\x1b[71;6u"), ("k", "nw"), ("t", b"\x1b[71;6u"), ("k", "ne")],
    "1\n",
)

case(
    "select-word.txt", "SUPER next\n", [("k", "2l"), ("k", "t"), ("k", "d")], " next\n"
)
case(
    "select-grow.txt",
    "foo(bar) tail\n",
    [("k", "5l"), ("k", "t"), ("k", "t"), ("k", "d")],
    "foo tail\n",
)
case(
    "select-shrink.txt",
    "foo(bar) tail\n",
    [("k", "5l"), ("k", "t"), ("k", "t"), ("k", "T"), ("k", "d")],
    "foo() tail\n",
)
case(
    "select-character.txt",
    "SUPER next\n",
    [("k", "2l"), ("k", "t"), ("k", "T"), ("k", "d")],
    "SUER next\n",
)
case(
    "select-boundary.txt", "(hello)\n", [("k", "2l"), ("k", "s"), ("k", "d")], "hello\n"
)
case("select-inner.txt", "(hello)\n", [("k", "2l"), ("k", "S"), ("k", "d")], "()\n")
case(
    "select-toggle.txt",
    "(hello)\n",
    [("k", "2l"), ("k", "s"), ("k", "S"), ("k", "s"), ("k", "d")],
    "hello\n",
)
case(
    "select-repeat-boundary.txt",
    "((hello))\n",
    [("k", "3l"), ("k", "ss"), ("k", "d")],
    "(hello)\n",
)
case(
    "select-nested.txt",
    "((hello))\n",
    [("k", "3l"), ("k", "s"), ("k", "t"), ("k", "d")],
    "(hello)\n",
)
case(
    "select-nested-return.txt",
    "((hello))\n",
    [("k", "3l"), ("k", "s"), ("k", "t"), ("k", "T"), ("k", "d")],
    "(hello)\n",
)
case(
    "select-delimiter.txt",
    "[(hello)]\n",
    [("k", "3l"), ("k", "t"), ("k", "["), ("k", "d")],
    "\n",
)
case(
    "select-delimiter-boundary.txt",
    "[(hello)]\n",
    [("k", "3l"), ("k", "s"), ("k", "["), ("k", "d")],
    "(hello)\n",
)
case(
    "select-delimiter-repeat.txt",
    "((hello))\n",
    [("k", "3l"), ("k", "t"), ("k", "("), ("k", "("), ("k", "d")],
    "\n",
)
case(
    "select-quote.txt",
    '"hello" tail\n',
    [("k", "3l"), ("k", "s"), ("k", "d")],
    "hello tail\n",
)
case("select-no-pair.txt", "word next\n", [("k", "s")], "word next\n")
case(
    "select-multiline.txt",
    "(one\n two)\nlast\n",
    [("k", "2l"), ("k", "t("), ("k", "d")],
    "\nlast\n",
)
case(
    "select-insert-literal.txt",
    "(hello)\n",
    [("k", "2l"), ("k", "t"), ("k", "i"), ("t", b"sStT("), ("t", b"\x1b")],
    "(sStT(hello)\n",
)
case("step-next.txt", "value = 20\n", [("k", "3l"), ("k", "Z")], "value = 19\n")
case("step-increment.txt", "value = 20\n", [("k", "z")], "value = 21\n")
case("step-count.txt", "value = 20\n", [("k", "3Z")], "value = 17\n")
case("step-negative.txt", "value = -20\n", [("k", "z")], "value = -19\n")
case("step-hex.txt", "value = 0x0f\n", [("k", "z")], "value = 0x10\n")
case("step-separator.txt", "value = 1_999\n", [("k", "z")], "value = 2_000\n")
case("step-boolean.txt", "flag = false\n", [("k", "z")], "flag = true\n")
case("step-boolean-back.txt", "flag = true\n", [("k", "Z")], "flag = false\n")
case("step-boolean-case.txt", "flag = FALSE\n", [("k", "z")], "flag = TRUE\n")
case("step-boolean-even.txt", "flag = false\n", [("k", "2z")], "flag = false\n")
case("step-repeated.txt", "flag = false\n", [("k", "z"), ("k", "z")], "flag = false\n")
case("step-identifier.txt", "item20 = 30\n", [("k", "z")], "item20 = 31\n")
case(
    "step-no-next-line.txt",
    "nothing here\nvalue = 20\n",
    [("k", "z")],
    "nothing here\nvalue = 20\n",
)
case("step-left.txt", "20 end\n", [("k", "5l"), ("k", "z")], "20 end\n")
case("step-undo.txt", "flag = false\n", [("k", "z"), ("k", "u")], "flag = false\n")
case(
    "step-multiple.txt",
    "a = 9\nb = false\n",
    [("t", b"\x01"), ("k", "G/"), ("t", b"9|false\r"), ("k", "z")],
    "a = 10\nb = true\n",
)
case(
    "step-multiple-undo.txt",
    "a = 9\nb = false\n",
    [("t", b"\x01"), ("k", "G/"), ("t", b"9|false\r"), ("k", "z"), ("k", "u")],
    "a = 9\nb = false\n",
)
case("step-float.txt", "value = 1.25\n", [("k", "z")], "value = 1.25\n")
case("step-zero-one.txt", "value = 0\n", [("k", "z"), ("k", "z")], "value = 2\n")
case(
    "select-multiline-larger.txt",
    "(one\n two)\nlast\n",
    [("k", "2l"), ("k", "t("), ("k", "t"), ("k", "d")],
    "",
)
case(
    "select-multicursor.txt",
    "(one) [two]\n",
    [("t", b"\x01"), ("k", "G/"), ("t", b"one|two\r"), ("k", "s"), ("k", "d")],
    "one two\n",
)
case("select-empty.txt", "()\n", [("k", "s"), ("k", "r"), ("t", b"[")], "[]\n")
case(
    "select-grapheme.txt",
    "café next\n",
    [("k", "3l"), ("k", "t"), ("k", "T"), ("k", "d")],
    "caf next\n",
)
case(
    "select-normal-paste.txt",
    "abc def\n",
    [("k", "y"), ("k", "t"), ("k", "p")],
    "abca def\n",
)
case(
    "select-normal-word.txt",
    "abc def\n",
    [("k", "t"), ("k", "w"), ("k", "d")],
    "abc \n",
)
case("step-date.txt", "date = 2026-11-04\n", [("k", "z")], "date = 2026-11-05\n")
case("step-time.txt", "time = 12:30\n", [("k", "Z")], "time = 12:29\n")
case(
    "step-deduplicate.txt",
    "n = 12\n",
    [("t", b"\x01"), ("k", "G/"), ("t", b"1|2\r"), ("k", "z")],
    "n = 13\n",
)
case(
    "step-register.txt",
    "value = 20\n",
    [("k", "y"), ("k", "z"), ("k", "p")],
    "value = 21v\n",
)
case(
    "select-deduplicate.txt",
    "(one two)\n",
    [
        ("t", b"\x01"),
        ("k", "G/"),
        ("t", b"one|two\r"),
        ("k", "s"),
        ("k", "r"),
        ("t", b"f"),
        ("t", b"bar\r"),
    ],
    "bar(one two)\n",
)
# Space starts the command prompt in both normal and select mode.
for selecting in (False, True):
    e = Editor("command-space.txt", "alpha\n")
    try:
        if selecting:
            e.key("v")
        e.send(b" ")
        assert e.screen.display[-1].lstrip().startswith(":"), e.view()
    finally:
        e.close()
# q saves and closes; Q closes without writing. Only private fixture buffers.
for key, saved in [("q", "Xalpha\n"), ("Q", "alpha\n")]:
    e = Editor("quit.txt", "alpha\n")
    try:
        e.key("i")
        e.send(b"X")
        e.send(b"\x1b")
        e.key(key)
        e.pump(0.2)
        assert e.p.poll() is not None, (key, e.view())
        assert e.path.read_text() == saved, (key, e.path.read_text())
    finally:
        e.close()
if not args.live:
    e = Editor("clipboard.txt", "abcd\n")
    try:
        e.key("Y")
        assert e.clipboard.read_text() == "a", e.view()
        e.key("l")
        e.key("d")
        e.key("p")
        assert e.save() == "acad\n", e.view()
        assert e.clipboard.read_text() == "a"
    finally:
        e.close()
print(
    "PASS: rendered keymap; word/WORD, insertion, cuts, line mode, syntax targets, wrappers, literal input, Space, q/Q"
)
