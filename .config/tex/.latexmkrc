#!/usr/bin/env perl

use File::Spec;
use File::Basename qw(dirname);

# LaTeX
$lualatex = 'lualatex -synctex=1 --shell-escape -halt-on-error -file-line-error %O %S';
$max_repeat = 5;

# BibTeX
$bibtex = 'pbibtex %O %S';
$biber = 'biber --bblencoding=utf8 -u -U --output_safechars %O %S';

# index
$makeindex = 'mendex %O -o %D %S';

my $main_tex = '';
for my $arg (@ARGV) {
    next if $arg =~ /^-/;
    if ($arg !~ m{/} && $arg !~ /\./ && !-f $arg && !-f "$arg.tex" && -f "$arg/$arg.tex") {
        $arg = "$arg/$arg.tex";
    }
    if ($arg =~ /\.tex$/ && -f $arg) {
        $main_tex = $arg;
        last;
    }
    if (-f "$arg.tex") {
        $main_tex = "$arg.tex";
        last;
    }
}

my $source_dir = '.';
if ($main_tex ne '') {
    $source_dir = dirname($main_tex);
    $source_dir = '.' if !defined($source_dir) || $source_dir eq '';
}
my $build_dir = ($source_dir eq '.') ? '.build' : "$source_dir/.build";

# Build artifacts
$aux_dir = $build_dir;
$out_dir = $build_dir;
$emulate_aux = 0;

my $use_platex = 0;
if ($main_tex ne '') {
    my $main_path = File::Spec->rel2abs($main_tex);
    if (open(my $fh, '<', $main_path)) {
        local $/;
        my $content = <$fh>;
        close($fh);

        # Ignore comments so multiline \documentclass can be parsed safely.
        $content =~ s/^\s*%.*$//mg;
        $content =~ s/(?<!\\)%.*$//mg;

        if ($content =~ /\\documentclass\s*(?:\[(.*?)\])?\s*\{([^}]+)\}/s) {
            my $raw_opts = defined($1) ? $1 : '';
            my $docclass = $2;
            $docclass =~ s/\s+//g;

            my %opt = map { my $k = lc($_); $k =~ s/\s+//g; $k => 1 }
                      grep { $_ ne '' }
                      split(/\s*,\s*/, $raw_opts);

            if ($docclass eq 'jreport') {
                $use_platex = 1;
            } elsif ($docclass eq 'jlreq') {
                # jlreq supports multiple engines; prefer LuaLaTeX when requested.
                $use_platex = $opt{'luatex'} ? 0 : 1;
            }
        }
    }
}

if ($use_platex) {
    $latex = 'platex -synctex=1 -halt-on-error -file-line-error %O %S';
    $dvipdf = 'dvipdfmx %O -o %D %S';
    $pdf_mode = 3;
} else {
    $pdf_mode = 4;
}

# sed
$pdf_update_method = 4;
if ($^O eq 'darwin') {
    $pdf_update_command = "find . -type f -name '*.tex' -print0 | xargs -0 sed -i '' -e 's/、/，/g' -e 's/。/．/g'";
} elsif ($^O eq 'linux') {
    $pdf_update_command = "find . -type f -name '*.tex' -print0 | xargs -0 sed -i -e 's/、/，/g' -e 's/。/．/g'";
}

# preview
$pvc_view_file_via_temporary = 0;
if ($^O eq 'linux') {
	if ($ENV{WSL_DISTRO_NAME}) {
		$dvi_previewer = q{powershell.exe -NoProfile -Command "Start-Process -FilePath 'C:\Users\umada\AppData\Local\SumatraPDF\SumatraPDF.exe' -ArgumentList '-reuse-instance','$(wslpath -w %S)'"};
		$pdf_previewer = q{powershell.exe -NoProfile -Command "Start-Process -FilePath 'C:\Users\umada\AppData\Local\SumatraPDF\SumatraPDF.exe' -ArgumentList '-reuse-instance','$(wslpath -w %S)'"};
    } else {
    	$dvi_previewer = "xdg-open %S";
    	$pdf_previewer = "evince %S";
	}
} elsif ($^O eq 'darwin') {
    if (-f '/Applications/Skim.app/Contents/MacOS/Skim'){
    $dvi_previewer = "/Applications/Skim.app/Contents/MacOS/Skim %S";
    $pdf_previewer = "/Applications/Skim.app/Contents/MacOS/Skim %S";
    } else {
    $dvi_previewer = "open %S";
    $pdf_previewer = "open %S";
    }
} else {
    $dvi_previewer = "start %S";
    $pdf_previewer = '"C:\Program Files\SumatraPDF\SumatraPDF.exe" -reuse-instance %O %S';
}

# Keep only .tex and .pdf in the source directory.
$success_cmd = "mkdir -p \"$build_dir\"; [ -f \"$build_dir/%R.pdf\" ] && cp -f \"$build_dir/%R.pdf\" \"$source_dir/%R.pdf\"; (cd \"$source_dir\" && for f in %R.*; do [ -e \"\$f\" ] || continue; case \"\$f\" in %R.tex|%R.pdf) ;; *) mv -f \"\$f\" .build/;; esac; done)";

# clean up
$clean_full_ext = "%R.synctex.gz";
