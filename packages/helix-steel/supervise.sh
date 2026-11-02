# Keep the shell's foreground job alive while the Yazi helper pauses Helix.
# Do not exec: fish would otherwise observe Helix's temporary SIGSTOP and
# reclaim the terminal while Yazi is still using it.
"$@"
status=$?
# Restore the shell cursor color even when Helix exits from insert mode.
if [ -t 1 ]; then printf '\033]112\007'; fi
exit "$status"
