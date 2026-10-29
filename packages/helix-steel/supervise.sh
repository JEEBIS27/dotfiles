# Keep the shell's foreground job alive while the Yazi helper pauses Helix.
# Do not exec: fish would otherwise observe Helix's temporary SIGSTOP and
# reclaim the terminal while Yazi is still using it.
"$@"
status=$?
exit "$status"
