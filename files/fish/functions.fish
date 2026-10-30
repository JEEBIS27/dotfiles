# Retained listing and Git shortcuts. No d/f/g/y or miscellaneous abbreviations.
alias ls 'eza --icons=always'
alias ll 'ls -l'
alias la 'ls -a'
alias lA 'll -a'
alias lt 'ls --tree --level=2'
alias lta 'la --tree --level=2'
alias lT 'ls --tree'
alias lTa 'la --tree'
alias ld 'ls -D'
alias lda 'la -D'
alias lf 'ls -F'
alias lfa 'la -F'
function l.; eza --icons=always .*; end
# Fish changes directory when a directory path is entered by itself.
abbr --add --position command -- - 'cd -'
for n in (seq 1 9)
    abbr --add --position command -- -$n "prevd $n"
end
alias .. 'cd ..'
alias ... 'cd ../..'
alias .... 'cd ../../..'
function md
    test (count $argv) -gt 0; or return 1
    command mkdir -p -- $argv; and cd -- $argv[-1]
end
alias rd rmdir
for entry in 'gcl:clone' 'gs:status' 'gd:diff' 'ga:add' 'gA:add -A' 'gc:commit' 'gm:commit -m' 'gp:push' 'gpl:pull --rebase' 'gl:log --oneline -20' 'gb:branch' 'gco:checkout' 'gst:stash' 'gr:restore' 'gns:restore --staged' 'gn:reset --soft HEAD~1'
    set -l parts (string split -m 1 : -- $entry)
    alias $parts[1] "git $parts[2]"
end
# Shared full Git label for the prompt and repository listing.
function __jeebis_git_label --argument-names branch dirty color
    set -l normal
    set -l muted
    set -l green
    set -l orange
    if test "$color" != never
        set normal (set_color normal)
        set muted (set_color dadada)
        set green (set_color 87af87)
        set orange (set_color ff8700)
    end
    printf '%s on %s %s' "$muted" "$green" "$branch"
    test "$dirty" = 1; and printf '%s*' "$orange"
    printf '%s' "$normal"
end

function lg --description 'Show Git status, or list nearby repositories'
    if command git rev-parse --git-dir >/dev/null 2>&1
        command git status $argv
        return $status
    end
    if test (count $argv) -gt 0
        printf 'lg: リポジトリの外では引数なしで実行してください。\n' >&2
        return 2
    end
    set -l color never
    isatty stdout; and set color always
    for directory in (path filter --type dir -- * .*)
        # A .git file also identifies linked worktrees and submodules.
        if not test -e "$directory/.git"
            test "$(command git -C "$directory" rev-parse --is-bare-repository 2>/dev/null)" = true; or continue
        end
        set -l branch (command git -C "$directory" symbolic-ref --quiet --short HEAD 2>/dev/null)
        if test -z "$branch"
            set branch (command git -C "$directory" rev-parse --short HEAD 2>/dev/null)
            test -n "$branch"; or continue
        end
        set -l label (command eza --oneline --treat-dirs-as-files --icons=always --color=$color -- "$directory")
        set -l dirty 0
        test -n "$(command git -C "$directory" status --porcelain 2>/dev/null)"; and set dirty 1
        printf '%s' "$label"
        __jeebis_git_label "$branch" "$dirty" "$color"
        printf '\n'
    end
end

function __jeebis_find_directory
    set -l dir (zoxide query --list --base-dir "$PWD" --exclude "$PWD" | fzf --border-label ' Directory ' --preview 'eza --icons=always --color=always --tree --level=2 {}' --preview-window 'right:60%:nowrap')
    test -n "$dir"; and cd -- "$dir"
end
function __jeebis_find_file
    set -l file (fd --type f --hidden --exclude .git | fzf --border-label ' File ' --preview 'bat --color=always {}')
    test -n "$file"; and $EDITOR "$file"
end
function __jeebis_find_text
    # Tab separates filename/line/text; colons in file names are preserved.
    set -l search 'rg --line-number --no-heading --hidden --glob "!.git/*" --json -- {q} . | jq -r "select(.type == \"match\") | [.data.path.text, .data.line_number, (.data.lines.text | rtrimstr(\"\\n\"))] | @tsv"'
    set -l result (fzf --disabled --delimiter '\t' --border-label ' String ' --bind "start:reload:$search" --bind "change:reload:sleep 0.1; $search" --preview 'bat --color=always --highlight-line {2} {1}')
    if test -n "$result"
        set -l fields (string split \t -- $result)
        switch (path basename "$EDITOR")
            case hx helix
                $EDITOR "$fields[1]:$fields[2]"
            case '*'
                $EDITOR +$fields[2] "$fields[1]"
        end
    end
end
function __jeebis_yazi
    set -l tmp (mktemp -t yazi-cwd.XXXXXX); or return
    command yazi $argv --cwd-file="$tmp"
    set -l cwd (command cat -- "$tmp")
    command rm -f -- "$tmp"
    test -n "$cwd"; and test "$cwd" != "$PWD"; and cd -- "$cwd"
end

# TUIOS owns the already-rendered output. No command is rerun or wrapped in tee.
function __jeebis_last_output
    if not set -q TUIOS_WINDOW_ID
        printf 'この機能はTUIOSのペイン内で使ってください。\n' >&2
        return 1
    end
    command tuios capture-pane --window "$TUIOS_WINDOW_ID" --last-command --unwrap
end
function copy-last-output --description 'Copy the last finished command output'
    set -l tmp (mktemp -t last-output.XXXXXX); or return
    __jeebis_last_output > "$tmp"
    set -l result $status
    if test $result -eq 0
        if command -q wl-copy
            command wl-copy < "$tmp"
        else if command -q pbcopy
            command pbcopy < "$tmp"
        else if command -q xclip
            command xclip -selection clipboard < "$tmp"
        else
            printf 'クリップボード用のコマンドが見つかりません。\n' >&2
            command rm -- "$tmp"
            return 1
        end
        set result $status
    end
    command rm -- "$tmp"
    return $result
end
function save-last-output --description 'Save the last finished command output to a new file'
    if test (count $argv) -ne 1
        printf '使い方: save-last-output ファイル名\n' >&2
        return 2
    end
    # Stage first: a failed capture must not create a misleading empty file.
    set -l tmp (mktemp -t last-output.XXXXXX); or return
    __jeebis_last_output > "$tmp"
    set -l result $status
    if test $result -eq 0
        command cat -- "$tmp" >? "$argv[1]"
        set result $status
    end
    command rm -- "$tmp"
    return $result
end

function extract --description 'Extract archives'
    test (count $argv) -gt 0; or return 2
    for archive in $argv
        switch "$archive"
            case '*.tar.gz' '*.tgz' '*.tar.bz2' '*.tbz2' '*.tar.xz' '*.txz' '*.tar.zst' '*.tar'
                command tar -xf "$archive"; or return
            case '*.zip'
                command unzip "$archive"; or return
            case '*.7z' '*.rar'
                command 7zz x "$archive"; or return
            case '*.gz'
                command gzip -dk "$archive"; or return
            case '*.bz2'
                command bzip2 -dk "$archive"; or return
            case '*.xz'
                command xz -dk "$archive"; or return
            case '*'
                printf '未対応の形式: %s\n' "$archive" >&2
                return 1
        end
    end
end
alias x extract

function __jeebis_complete
    set -l choices (complete --do-complete=(commandline -cp))
    # Let fish insert a single candidate with its native quoting and spacing.
    if test (count $choices) -le 1
        commandline -f complete
        return
    end
    set -l choice (printf '%s\n' $choices | fzf --height=40% --delimiter '\t' --border-label ' Completion ')
    if test -n "$choice"
        set -l candidate (string split -m 1 \t -- "$choice")[1]
        commandline --current-token --replace (string escape -- "$candidate")
    end
end
