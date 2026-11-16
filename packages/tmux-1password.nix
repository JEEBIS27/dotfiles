{ pkgs }:
pkgs.tmuxPlugins.mkTmuxPlugin {
  pluginName = "1password";
  version = "2025-05-23-fee3649";
  rtpFilePath = "plugin.tmux";
  src = pkgs.fetchFromGitHub {
    owner = "yardnsm";
    repo = "tmux-1password";
    rev = "fee36493fe352e34f46f2e293a218a6667607b00";
    sha256 = "1zak9lz8j7d71zcjr5rzxhsb4dr1wlqnvqcknbz5424d6knw7v6i";
  };
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postPatch = ''
    cp ${../files/tmux/1password-op.sh} scripts/utils/op.sh
    cp ${../files/tmux/1password-clipboard.sh} scripts/utils/clipboard.sh
    substituteInPlace plugin.tmux \
      --replace-fail 'tmux bind-key "$(options::keybinding)"' \
                     'tmux bind-key -n "$(options::keybinding)"'
    substituteInPlace scripts/options.sh \
      --replace-fail '@1password-key" "u"' '@1password-key" "M-u"'
    substituteInPlace scripts/main.sh \
      --replace-fail 'tmux send-keys -t "$ACTIVE_PANE" "$selected_item_password"' \
                     'tmux send-keys -l -t "$ACTIVE_PANE" -- "$selected_item_password"'
  '';
  postInstall = ''
    for script in "$target/plugin.tmux" "$target/scripts/main.sh"; do
      wrapProgram "$script" --prefix PATH : ${pkgs.lib.makeBinPath [
        pkgs.bash pkgs.tmux pkgs._1password-cli pkgs.fzf pkgs.jq
        pkgs.coreutils pkgs.gnugrep pkgs.gawk pkgs.ncurses pkgs.wl-clipboard
      ]}
    done
  '';
}
