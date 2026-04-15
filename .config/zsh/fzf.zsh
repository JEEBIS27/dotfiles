export FZF_DEFAULT_OPTS='
    --style full
    --reverse
    --border --padding 1,2
    --input-label " Input "
    --prompt "❯ "
    --bind '\''result:transform-list-label:
        if [[ -z $FZF_QUERY ]]; then
          echo " $FZF_MATCH_COUNT items "
        else
          echo " $FZF_MATCH_COUNT matches for [$FZF_QUERY] "
        fi
        '\''
    --bind '\''focus:transform-preview-label:[[ -n {} ]] && printf " Previewing [%s] " {}'\''
    --bind '\''ctrl-r:change-list-label( Reloading the list )+reload(sleep 2; git ls-files)'\''
    --bind '\''pgup:preview-half-page-up,pgdn:preview-half-page-down'\''
    --bind '\''shift-up:preview-up,shift-down:preview-down'\''
    --bind '\''ctrl-up:page-up,ctrl-down:page-down'\''
    --bind '\''alt-up:preview-half-page-up,alt-down:preview-half-page-down'\''
    --bind '\''alt-shift-up:preview-page-up,alt-shift-down:preview-page-down'\''
    --color "border:#aaaaaa,label:#cccccc"
    --color "preview-border:#9999cc,preview-label:#ccccff"
    --color "list-border:#669966,list-label:#99cc99"
    --color "input-border:#996666,input-label:#ffcccc"
    --color "header-border:#6699cc,header-label:#99ccff"
    '

export FZF_FILE_PREVIEW='--header-label " File Type " --border-label " File " --preview "bat --color=always {}" --bind '\''focus:+transform-header:file --brief {} || echo "No file selected"'\'''

export FZF_DIR_PREVIEW='--border-label " Directory " --preview "eza --icons=always --color=always --tree --level=2 {}" --preview-window=right:60%:nowrap'

export FZF_STRING_PREVIEW='--ansi --disabled --delimiter ":" --border-label " String " --bind '\''focus:+transform-header:echo {} | sed "s/\x1b\[[0-9;]*m//g" | cut -d: -f1 | xargs file --brief 2>/dev/null || echo "No file selected"'\'' --preview '\''f=$(echo {} | sed "s/\x1b\[[0-9;]*m//g" | cut -d: -f1); l=$(echo {} | sed "s/\x1b\[[0-9;]*m//g" | cut -d: -f2); [[ -n "$l" && "$l" =~ ^[0-9]+$ ]] && bat --style=numbers --color=always --highlight-line "$l" --line-range "$((l>5 ? l-5 : 1)):" "$f" 2>/dev/null || bat --style=numbers --color=always "$f" 2>/dev/null'\'' --preview-window=right:60%:nowrap'
