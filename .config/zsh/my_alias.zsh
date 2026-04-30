# ディレクトリ検索
function d() {
  local dir
  dir=$(zoxide query -l | eval fzf $FZF_DIR_PREVIEW)
  [ -n "$dir" ] && cls "$dir"
}

# ファイル検索
function f() {
  local file
  file=$(eval fzf $FZF_FILE_PREVIEW)
  [ -n "$file" ] && ${EDITOR:-vim} "$file"
}

# 文字列一致検索
function g() {
  local initial_query="${1:-}"
  local result

  result=$(rg --line-number --color=always "${initial_query}" 2>/dev/null | \
           eval fzf $FZF_STRING_PREVIEW \
           --query \"\$initial_query\" \
           --bind \'change:reload:sleep 0.1\; rg --line-number --color=always {q} \|\| true\' \
           --bind \'start:reload:rg --line-number --color=always {q} \|\| true\')

  if [ -n "$result" ]; then
    local clean_result=$(echo "$result" | sed 's/\x1b\[[0-9;]*m//g')
    local file=$(echo "$clean_result" | cut -d: -f1)
    local line=$(echo "$clean_result" | cut -d: -f2)
    nvim "+${line}" "$file"
  fi
}

# ls
alias ls="eza --icons=always"
alias ll="ls -l"
alias la="ls -a"
alias lA="ll -a"
alias lT="ls --tree"
alias lt="lT --level=2"
alias lTa="la --tree"
alias lta="lTa --level=2"
alias l.="la | grep '^\.'"
alias lg="ll --git"

__ls_variant() {
  local variant="$1"
  local list_target="$2"
  case "$variant" in
    ll) ll ${list_target:+"$list_target"} ;;
    la) la ${list_target:+"$list_target"} ;;
    lA) lA ${list_target:+"$list_target"} ;;
    lT) lT ${list_target:+"$list_target"} ;;
    lt) lt ${list_target:+"$list_target"} ;;
    lT) lT ${list_target:+"$list_target"} ;;
    lt) lt ${list_target:+"$list_target"} ;;
    l.) l. ${list_target:+"$list_target"} | grep '^\.' ;;
    lg) lg ${list_target:+"$list_target"} ;;
    *)  ls ${list_target:+"$list_target"} ;;
  esac
}

__resolve_target_dir() {
  local cmd="$1"
  local target="$2"

  if [ "$cmd" = "rm" ]; then
    dirname "$target"
  elif [ -d "$target" ]; then
    printf '%s\n' "$target"
  else
    dirname "$target"
  fi
}

__run_cmd_interactive() {
  local cmd="$1"
  shift
  "$cmd" -i "$@"
}

__cmd_cd_only() {
  local cmd="$1"
  shift

  [ $# -gt 0 ] || return 1
  __run_cmd_interactive "$cmd" "$@" || return 1

  local target="${@: -1}"
  local next_dir
  next_dir="$(__resolve_target_dir "$cmd" "$target")"
  \cd "$next_dir"
}

__cmd_cd_ls() {
  local cmd="$1"
  local variant="$2"
  shift 2

  [ $# -gt 0 ] || return 1
  __run_cmd_interactive "$cmd" "$@" || return 1

  local target="${@: -1}"
  local next_dir
  next_dir="$(__resolve_target_dir "$cmd" "$target")"
  \cd "$next_dir" || return 1
  __ls_variant "$variant"
}

__cmd_ls_only() {
  local cmd="$1"
  local variant="$2"
  shift 2

  [ $# -gt 0 ] || return 1
  __run_cmd_interactive "$cmd" "$@" || return 1

  local target="${@: -1}"
  local list_target
  list_target="$(__resolve_target_dir "$cmd" "$target")"
  __ls_variant "$variant" "$list_target"
}

__cl_dispatch() {
  local variant="$1"
  local target_path="${2:-$HOME}"
  \cd "$target_path" || return 1
  __ls_variant "$variant"
}

typeset -a __LS_SUFFIXES=(s ll la lA lT lt lT lt l. lg)

for __suffix in "${__LS_SUFFIXES[@]}"; do
  if [ "$__suffix" = "s" ]; then
    __variant='base'
    __cl_name='cls'
  elif [ "$__suffix" = "l" ]; then
    __variant='l'
    __cl_name='cl'
  else
    __variant="$__suffix"
    __cl_name="c$__suffix"
  fi

  eval "$__cl_name() { __cl_dispatch $__variant \"\$1\"; }"
done

typeset -A __PMR_CMDS=( [p]='cp' [m]='mv' [r]='rm' )

for __prefix __cmd in "${(@kv)__PMR_CMDS}"; do
  eval "${__prefix}c() { __cmd_cd_only $__cmd \"\$@\"; }"

  for __suffix in "${__LS_SUFFIXES[@]}"; do
    if [ "$__suffix" = "s" ]; then
      __variant='base'
      __cdls_name="$__prefix"'cls'
      __ls_name="$__prefix"'ls'
    elif [ "$__suffix" = "l" ]; then
      __variant='l'
      __cdls_name="$__prefix"'cl'
      __ls_name="$__prefix"'l'
    else
      __variant="$__suffix"
      __cdls_name="$__prefix""c$__suffix"
      __ls_name="$__prefix""$__suffix"
    fi

    eval "$__cdls_name() { __cmd_cd_ls $__cmd $__variant \"\$@\"; }"
    eval "$__ls_name() { __cmd_ls_only $__cmd $__variant \"\$@\"; }"
  done
done

# cd
alias 'cd'='z'
alias '/'='cd /'
alias '~'='cd ~'
alias -- '-'='cd -'
alias '-1'='cd -1'
alias '-2'='cd -2'
alias '-3'='cd -3'
alias '-4'='cd -4'
alias '-5'='cd -5'
alias '-6'='cd -6'
alias '-7'='cd -7'
alias '-8'='cd -8'
alias '-9'='cd -9'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# dir
unalias md 2>/dev/null
md() {
  [ $# -gt 0 ] || return 1
  local target="${@: -1}"
  mkdir -p -- "$@" && \cd -- "$target"
}
alias rd='rmdir'

# git
alias gcl='git clone'
alias gs='git status'
alias gd='git diff'
alias ga='git add'
alias gA='git add -A'
alias gc='git commit'
alias gm='git commit -m'
alias gp='git push'
alias gpl='git pull'
alias gl='git log --oneline -15'
alias gb='git branch'
alias gco='git checkout'
alias gst='git stash'

# other
alias _=sudo
alias h='history'
alias x='clear'
alias q='exit'
alias cat='bat'
alias chat='copilot'
alias nv='nvim'
alias memo='nb'
alias latexmk='latexmk -r ~/.config/tex/.latexmkrc -pvc'

# Leading "|" command: run normally and copy stdout to clipboard
if [[ -o interactive ]]; then
  if command -v wl-copy >/dev/null 2>&1; then
    typeset -g __CLIP_CMD='wl-copy'
  elif command -v pbcopy >/dev/null 2>&1; then
    typeset -g __CLIP_CMD='pbcopy'
  elif command -v xclip >/dev/null 2>&1; then
    typeset -g __CLIP_CMD='xclip -selection clipboard'
  elif command -v xsel >/dev/null 2>&1; then
    typeset -g __CLIP_CMD='xsel --clipboard --input'
  fi

  __accept_line_with_clip_prefix() {
    emulate -L zsh

    if [[ $BUFFER == \|* ]]; then
      local cmd="${BUFFER#\|}"
      cmd="${cmd#"${cmd%%[![:space:]]*}"}"

      if [[ -z $cmd ]]; then
        zle -M "コマンドを入力してください"
        return 0
      fi

      if [[ -z $__CLIP_CMD ]]; then
        zle -M "wl-copy / pbcopy / xclip / xsel が見つかりません"
        BUFFER="$cmd"
      else
        BUFFER="$cmd | tee >( ${=__CLIP_CMD} )"
      fi
    fi

    zle .accept-line
  }

  zle -N accept-line __accept_line_with_clip_prefix
fi

# --------------------------------------
# Google search from terminal
# --------------------------------------
google() {
    local search_query="$@"
    local encoded_query=$(echo "$search_query" | sed 's/ /+/g')
    xdg-open "https://www.google.com/search?q=$encoded_query"
}

# Sheldon plugin manager aliases
unalias zsh-plugin-add 2>/dev/null; function zsh-plugin-add { sheldon add --github "$1" "${1##*/}" }  # 使い方: zsh-plugin-add zsh-users/zsh-autosuggestions
alias zsh-plugin-remove='sheldon remove'             # 使い方: zsh-plugin-remove zsh-autosuggestions
alias zsh-plugin-list='cat ~/.config/sheldon/plugins.toml'
alias zsh-plugin-update='sheldon lock --update && source ~/.zshrc'
alias zsh-plugin-reload='source ~/.zshrc'
