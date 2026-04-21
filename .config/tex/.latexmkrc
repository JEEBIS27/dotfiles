#!/usr/bin/env perl

# LaTeX
$lualatex = 'lualatex -synctex=1 --shell-escape -halt-on-error -file-line-error %O %S';
$max_repeat = 5;

# BibTeX
$bibtex = 'pbibtex %O %S';
$biber = 'biber --bblencoding=utf8 -u -U --output_safechars %O %S';

# index
$makeindex = 'mendex %O -o %D %S';

# Build artifacts
$aux_dir = '.build';
$out_dir = '.';
$emulate_aux = 1;
$pdf_mode = 4;

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

# Keep only .pdf and .tex in the source directory.
$success_cmd = 'if [ -f "%R.synctex.gz" ]; then mv -f "%R.synctex.gz" ".build/"; fi; if [ -f "%R.synctex" ]; then mv -f "%R.synctex" ".build/"; fi';

# clean up
$clean_full_ext = "%R.synctex.gz";
