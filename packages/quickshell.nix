{ pkgs }:
# Preserve 0.3.2 and backport only its upstream unlock notification fix.
# Without it, QML can keep reporting locked after successful authentication,
# which prevents the next lock request from taking effect.
pkgs.quickshell.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [ ./desktop/quickshell-session-lock-state.patch ];
})
