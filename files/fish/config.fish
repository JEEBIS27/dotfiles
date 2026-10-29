# Interactive configuration, sourced last by Home Manager.
set -g fish_greeting
# Recognized commands are green; this does not indicate exit status.
set -g fish_color_command green
fish_add_path --path --append "$HOME/.cargo/bin" "$HOME/.local/bin"
if test -x /home/linuxbrew/.linuxbrew/bin/brew
    /home/linuxbrew/.linuxbrew/bin/brew shellenv fish | source
end
fish_add_path --path --move "$HOME/.nix-profile/bin"
set -gx BAT_THEME ansi
if test -f '@themeDir@/preview.tmTheme'
    set -gx BAT_THEME Desktop
end
set -gx FZF_DEFAULT_COMMAND 'rg --files'
set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
# fzf callbacks use Bash syntax explicitly, regardless of the login shell.
set -gx FZF_DEFAULT_OPTS '--with-shell="bash -c" --style full --reverse --border --padding 1,2 --input-label " Input " --prompt "❯ " --bind ctrl-w:abort --bind pgup:preview-half-page-up,pgdn:preview-half-page-down --bind shift-up:preview-up,shift-down:preview-down --bind ctrl-up:page-up,ctrl-down:page-down'
set -gx FZF_CTRL_T_OPTS '--preview "bat --color=always {}"'
set -gx FZF_ALT_C_OPTS '--preview "eza --icons=always --color=always --tree --level=2 {}"'
# Fish owns its keyboard protocol. Do not port ZLE's CSI-u packet adapter.
source ~/.config/fish/jeebis-functions.fish
source ~/.config/fish/jeebis-prompt.fish
# Prefer adopted plugins over the legacy definitions above.
functions --erase ga gd gco
source @extractPlugin@/functions/extract.fish
source @extractPlugin@/functions/x.fish
# fifc previews are fish functions; other custom fzf searches use Bash.
set -gx fifc_custom_fzf_opts '--with-shell="fish -c"'
# Home Manager does not emit Fisher's install event.
if not set -q ABBR_TIPS_REGEXES
    __abbr_tips_install
else
    __abbr_tips_init
end
source ~/.config/fish/jeebis-keys.fish
