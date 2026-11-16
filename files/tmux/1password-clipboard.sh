# Keep secrets out of the recorded terminal and consume the clipboard on paste.
clipboard::copy() { printf '%s' "$1" | wl-copy --type text/plain --sensitive --paste-once; }
clipboard::clear() { :; } # wl-copy releases ownership after the first paste.
