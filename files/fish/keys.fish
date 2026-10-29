# Preserve zoxide ranking within each group; uppercase keywords prefer exact case.
function __jeebis_prefer_case
    set -l uppercase
    for keyword in $argv
        string match --quiet --regex '[[:upper:]]' -- "$keyword"; and set -a uppercase "$keyword"
    end
    set -l preferred
    set -l fallback
    while read --local directory
        test -n "$directory"; or continue
        set -l matches 1
        for keyword in $uppercase
            if not string match --quiet --regex -- (string escape --style=regex -- "$keyword") "$directory"
                set matches 0
                break
            end
        end
        if test $matches -eq 1
            set -a preferred "$directory"
        else
            set -a fallback "$directory"
        end
    end
    test (count $preferred) -eq 0; or printf '%s\n' $preferred
    test (count $fallback) -eq 0; or printf '%s\n' $fallback
end

function __jeebis_clear_list
    functions --query __jeebis_prompt_reset; and __jeebis_prompt_reset
    command clear; and command eza --icons=always
    commandline -f repaint
end

# Resolve symlinks before enforcing the direction of a directory jump.
function __jeebis_directory_below --argument-names dir base
    test -d "$dir"; or return 1
    test -n "$base"; or set base (path resolve -- "$PWD")
    set -l target (path resolve -- "$dir")
    set -l prefix "$base/"
    test "$base" = /; and set prefix /
    test "$target" != "$base"; and test "$(string sub --length (string length -- "$prefix") -- "$target")" = "$prefix"
end

# Explicit cd paths keep normal shell behavior; only zoxide searches are scoped.
function __zoxide_z
    if test "$argv[1]" = --
        set -e argv[1]
    end
    if test (count $argv) -eq 0
        __zoxide_cd
        return $status
    else if test (count $argv) -eq 1; and test "$argv[1]" = -
        __zoxide_cd -
        return $status
    else if test (count $argv) -eq 1; and test -d "$argv[1]"
        __zoxide_cd -- "$argv[1]"
        return $status
    end
    set -l destinations (command zoxide query --list --base-dir "$PWD" --exclude "$PWD" -- $argv | __jeebis_prefer_case $argv)
    set -l destination "$destinations[1]"
    test -n "$destination"; or return 1
    if __jeebis_directory_below "$destination"
        __zoxide_cd -- "$destination"
    else
        printf 'zoxide: 現在地の配下に一致するディレクトリがありません。\n' >&2
        return 1
    end
end

# Unrestricted zoxide entry point. Bare names prefer learned destinations.
function zd --description 'Jump with zoxide, without restricting the directory tree'
    if test (count $argv) -eq 0
        __zoxide_cd
        return $status
    else if test "$argv[1]" = --
        __zoxide_cd $argv
        return $status
    else if test (count $argv) -eq 1; and test "$argv[1]" = -
        __zoxide_cd -
        return $status
    else if test (count $argv) -eq 1; and string match --quiet '*/*' -- "$argv[1]"; and test -d "$argv[1]"
        __zoxide_cd -- "$argv[1]"
        return $status
    end
    set -l destinations (command zoxide query --list --exclude "$PWD" -- $argv 2>/dev/null | __jeebis_prefer_case $argv)
    set -l destination "$destinations[1]"
    if test -n "$destination"
        __zoxide_cd -- "$destination"
    else if test (count $argv) -eq 1; and test -d "$argv[1]"
        __zoxide_cd -- "$argv[1]"
    else
        printf 'zd: 一致する移動先がありません。\n' >&2
        return 1
    end
end
complete --command zd --no-files --arguments '(__zoxide_z_complete)'

# Sibling navigation uses names relative to the parent, never learned paths.
function __jeebis_sd_candidates
    test "$PWD" != /; or return
    set -l parent (path dirname -- "$PWD")
    for directory in (path filter --type dir -- "$parent"/* "$parent"/.*)
        test "$directory" = "$PWD"; and continue
        set -l name (path basename -- "$directory")
        string escape --no-quoted -- "$name/"
    end
end

function sd --description 'Move to a sibling directory'
    if test (count $argv) -ne 1
        printf 'sd: 同じ階層のディレクトリ名を1つ指定してください。\n' >&2
        return 2
    end
    set -l name (string replace --regex '/+$' '' -- "$argv[1]")
    if test "$PWD" = /; or test -z "$name"; or contains -- "$name" . ..; or string match --quiet '*/*' -- "$name"; or test "$name" = (path basename -- "$PWD")
        printf 'sd: 現在地以外の兄弟ディレクトリを指定してください。\n' >&2
        return 1
    end
    set -l destination (path dirname -- "$PWD")/"$name"
    if not test -d "$destination"
        printf 'sd: 兄弟ディレクトリがありません: %s\n' "$name" >&2
        return 1
    end
    __zoxide_cd -- "$destination"
end
complete --erase --command sd
complete --command sd --no-files --arguments '(__jeebis_sd_candidates)'

# Keep native completion side-effect-free; the merged source adds scoped zoxide results.
function __zoxide_z_complete
    complete --do-complete "'' "(commandline --cut-at-cursor --current-token) | string match --regex -- '.*/$'
end

function __zoxide_zi
    set -l destination (command zoxide query --list --base-dir "$PWD" --exclude "$PWD" -- $argv | __jeebis_prefer_case $argv | fzf --no-sort)
    or return
    __jeebis_directory_below "$destination"; and __zoxide_cd -- "$destination"
end

# fish-bd already finds ancestors. Use zoxide's underlying cd so that bd can
# move directly to the ancestor selected by the plugin.
if type -q bd
    functions bd | string replace --regex '^(\s*)cd(\s)' '$1__zoxide_cd$2' | source
end
complete --do-complete 'bd ' >/dev/null
function __fish_bd_complete_dirs
    set -l parent (path dirname -- "$PWD")
    while test "$parent" != /
        path basename -- "$parent"
        set parent (path dirname -- "$parent")
    end
end

# bd may use zoxide for ancestors, siblings, or other trees, but never descendants.
function __jeebis_directory_outside --argument-names dir base
    test -d "$dir"; or return 1
    test -n "$base"; or set base (path resolve -- "$PWD")
    set -l target (path resolve -- "$dir")
    set -l prefix "$base/"
    test "$base" = /; and set prefix /
    test "$target" != "$base"; and test "$(string sub --length (string length -- "$prefix") -- "$target")" != "$prefix"
end

if not functions --query __jeebis_bd_ancestors; and type -q bd
    functions --copy bd __jeebis_bd_ancestors
end
function bd --description 'Go to an ancestor or a zoxide destination outside the current subtree'
    # Retain the plugin's parent navigation, flags, and configured matching mode.
    if test (count $argv) -eq 0; or string match --quiet -- '-*' "$argv[1]"
        __jeebis_bd_ancestors $argv
        return $status
    end
    if test (count $argv) -eq 1
        for parent in (__fish_bd_complete_dirs)
            set -l matches 0
            switch "$BD_OPT"
                case sensitive
                    string match --quiet --regex -- '^(?:'(string escape --style=regex -- "$argv[1]")')' "$parent"; and set matches 1
                case insensitive
                    string match --quiet --ignore-case --regex -- '^(?:'(string escape --style=regex -- "$argv[1]")')' "$parent"; and set matches 1
                case '*'
                    test "$parent" = "$argv[1]"; and set matches 1
            end
            if test $matches -eq 1
                __jeebis_bd_ancestors $argv
                return $status
            end
        end
        if test -d "$argv[1]"
            if __jeebis_directory_outside "$argv[1]"
                __zoxide_cd -- "$argv[1]"
                return $status
            end
            printf 'bd: 現在地の配下には移動しません。\n' >&2
            return 1
        end
    end
    for destination in (command zoxide query --list --exclude "$PWD" -- $argv 2>/dev/null | __jeebis_prefer_case $argv)
        if __jeebis_directory_outside "$destination"
            __zoxide_cd -- "$destination"
            return $status
        end
    end
    printf 'bd: 祖先または現在地の配下以外に一致する移動先がありません。\n' >&2
    return 1
end

# Use relative directory paths unless the user explicitly started an absolute path.
# -s keeps symlink spellings instead of resolving them to unrelated locations.
function __jeebis_completion_directory --argument-names dir token
    if string match --quiet '/*' -- "$dir"; and not string match --quiet '/*' -- "$token"
        set -l target_parts (string split / -- (path normalize -- "$dir"))
        set -l base_parts (string split / -- "$PWD")
        while set -q target_parts[1]; and set -q base_parts[1]; and test "$target_parts[1]" = "$base_parts[1]"
            set -e target_parts[1]
            set -e base_parts[1]
        end
        set -l relative
        for part in $base_parts
            test -n "$part"; and set -a relative ..
        end
        set dir (string join / -- $relative $target_parts)
        test -n "$dir"; or set dir .
    end
    if test "$dir" != /
        set dir "$(string trim --right --chars / -- "$dir")/"
    end
    string escape --no-quoted -- "$dir"
end

# Merge native completions, zoxide destinations, and matching history arguments.
# History is tokenized only: command substitutions are never evaluated.
function __jeebis_completion_candidates --argument-names context token
    set -l previous
    set -l leading (string sub --length (math (string length -- "$context") - (string length -- "$token")) -- "$context")
    printf '%s\n' "$leading" | read --tokenize --array previous
    set -l directory_command 0
    contains -- "$previous[1]" cd z __zoxide_z; and set directory_command 1
    test "$previous[1]" = bd; and set directory_command 2
    test "$previous[1]" = zd; and set directory_command 3
    test "$previous[1]" = sd; and set directory_command 4
    # cd/bd keep contextual candidates first; zd puts learned candidates first.
    set -l seen
    set -l native
    for row in (complete --do-complete --escape -- "$context")
        set -l candidate (string split -m 1 \t -- "$row")[1]
        contains -- "$candidate" $native; or set -a native "$candidate"
    end
    if test $directory_command -ne 3
        set seen $native
        test (count $native) -gt 0; and printf '%s\n' $native
    end
    # bd and sd use only their contextual directory lists.
    if contains -- $directory_command 2 4
        return
    end
    set -l index (math (count $previous) + 1)
    set -l base
    test $directory_command -gt 0; and set base (path resolve -- "$PWD")
    if test $directory_command -gt 0
        set -l query
        printf '%s\n' "$token" | read --tokenize --array query
        # Completion also matches parent components (e.g. jeeb -> jeebis/mejiro31).
        # Keep zoxide's ranking, without its last-component query restriction.
        set -l scope
        test $directory_command -eq 1; and set scope --base-dir "$PWD"
        # --all avoids checking every registered directory before keyword filtering.
        # Verify existence/direction below, only for the matching entries.
        set -l matching_directories
        for dir in (command zoxide query --list --all $scope --exclude "$PWD" 2>/dev/null)
            set -l matches 1
            for keyword in $previous[2..-1] $query
                if not string match --quiet --ignore-case --regex -- (string escape --style=regex -- "$keyword") "$dir"
                    set matches 0
                    break
                end
            end
            if test $matches -eq 1
                if test $directory_command -eq 1
                    __jeebis_directory_below "$dir" "$base"; or continue
                else if test $directory_command -eq 2
                    __jeebis_directory_outside "$dir" "$base"; or continue
                else
                    test -d "$dir"; or continue
                end
                set -a matching_directories "$dir"
            end
        end
        for dir in (printf '%s\n' $matching_directories | __jeebis_prefer_case $previous[2..-1] $query)
                set -l candidate (__jeebis_completion_directory "$dir" "$token")
                test -n "$candidate"; or continue
                contains -- "$candidate" $seen; and continue
                set -a seen "$candidate"
                printf '%s\n' "$candidate"
        end
    end
    set -l history_contexts "$context"
    if test $directory_command -eq 3
        # Reuse directory arguments from the existing cd/bd history as well.
        set history_contexts 'zd ' 'cd ' 'bd '
    end
    set -l entries
    for history_context in $history_contexts
        set -a entries (builtin history search --prefix --case-sensitive --max=100 --null -- "$history_context" | string split0)
    end
    for entry in $entries
        set -l words
        printf '%s\n' "$entry" | read --tokenize --array words
        if set -q words[$index]; and test -n "$words[$index]"
            set -l word "$words[$index]"
            if test $directory_command -eq 1
                __jeebis_directory_below "$word" "$base"; or continue
            else if test $directory_command -eq 2
                __jeebis_directory_outside "$word" "$base"; or continue
            else if test $directory_command -eq 3
                test -d "$word"; or continue
                set -l keyword (string unescape -- "$token")
                string match --quiet --ignore-case --regex -- (string escape --style=regex -- "$keyword") "$word"; or continue
            end
            set -l candidate
            if test -d "$word"
                set candidate (__jeebis_completion_directory "$word" "$token")
            else
                set candidate (string escape --no-quoted -- "$word")
            end
            test -n "$candidate"; or continue
            contains -- "$candidate" $seen; and continue
            set -a seen "$candidate"
            printf '%s\n' "$candidate"
        end
    end
    if test $directory_command -eq 3
        for candidate in $native
            contains -- "$candidate" $seen; or printf '%s\n' "$candidate"
        end
    end
end

# Return to the reader between preparation and fifc so repaint runs first.
function __jeebis_prepare_completion
    set -e __jeebis_fifc_pending
    set -e __jeebis_fifc_candidates
    set -l buffer (commandline --current-buffer | string collect --allow-empty)
    set -l cursor (commandline --cursor)
    # Consecutive Tabs belong to one completion, until the user edits or moves.
    if not set -q __jeebis_completion_last_buffer; or test "$buffer" != "$__jeebis_completion_last_buffer"; or test "$cursor" != "$__jeebis_completion_last_cursor"
        set -g __jeebis_completion_original_buffer "$buffer"
        set -g __jeebis_completion_original_cursor "$cursor"
    end
    # Preserve autopair's treatment of a quoted variable before completion.
    set -l current_token (commandline --current-token | string collect)
    if string match --quiet --regex -- '\$[^\s]*"$' "$current_token"
        commandline --replace --current-token -- (string sub --end -2 -- "$current_token")
    end
    set -l context (commandline --cut-at-cursor | string collect)
    set -l token (commandline --current-token --cut-at-cursor | string collect)
    set -l candidates
    for candidate in (__jeebis_completion_candidates "$context" "$token")
        contains -- "$candidate" $candidates; or set -a candidates "$candidate"
    end
    if test (count $candidates) -eq 0
        set -e __jeebis_completion_last_buffer
        return
    else if test (count $candidates) -eq 1
        set -l candidate "$candidates[1]"
        if not string match --quiet '*/' -- "$candidate"
            set candidate "$candidate "
        end
        commandline --replace --current-token -- "$candidate"
        set -e __jeebis_completion_last_buffer
        return
    end
    if test "$argv[1]" != direct
        set -l common "$candidates[1]"
        for candidate in $candidates[2..-1]
            while test -n "$common"; and test "$(string sub --length (string length -- "$common") -- "$candidate")" != "$common"
                set common (string sub --length (math (string length -- "$common") - 1) -- "$common")
            end
        end
        if test (string length -- "$common") -gt (string length -- "$token"); and test "$(string sub --length (string length -- "$token") -- "$common")" = "$token"
            commandline --replace --current-token -- "$common"
            set -g __jeebis_completion_last_buffer (commandline --current-buffer | string collect --allow-empty)
            set -g __jeebis_completion_last_cursor (commandline --cursor)
            return
        end
    end
    # Keep the original context for fifc: inserting the first candidate must
    # not remove the other candidates from the completion list.
    set -g __jeebis_fifc_pending "$context"
    set -g __jeebis_fifc_input "$token"
    set -g __jeebis_fifc_candidates $candidates
    commandline --replace --current-token -- "$candidates[1]"
end

function __jeebis_open_completion
    set -q __jeebis_fifc_pending; or return
    set -l context "$__jeebis_fifc_pending"
    set -e __jeebis_fifc_pending
    set -lx __jeebis_fifc_active 1
    set -e __jeebis_fifc_accepted
    set -l query (string unescape -- "$__jeebis_fifc_input" | string collect --allow-empty)
    set -l escaped_query (string escape -- "$query")
    # Keep completion candidates below the current line, without a full-screen UI.
    set -lx fifc_custom_fzf_opts "$fifc_custom_fzf_opts --query=$escaped_query --no-sort --sync --height='~40%' --min-height=3 --layout=reverse --style=minimal --border=none --input-border=none --list-border=none --header-border=none --footer-border=none --padding=0 --margin=0 --info=hidden --no-preview"
    _fifc "$context"
    if not set -q __jeebis_fifc_accepted
        commandline --replace -- "$__jeebis_completion_original_buffer"
        commandline --cursor "$__jeebis_completion_original_cursor"
    end
    set -e __jeebis_completion_last_buffer
    set -e __jeebis_completion_original_buffer
    set -e __jeebis_completion_original_cursor
    set -e __jeebis_fifc_input
    set -e __jeebis_fifc_accepted
    set -e __jeebis_fifc_candidates
    commandline --function repaint
end

# fifc does not return the picker status. Observe its successful insertion so
# accepting the first candidate is distinguishable from cancelling the menu.
if type -q _fifc
    set -l definition (functions _fifc | string collect)
    if not string match --quiet '*__jeebis_fifc_accepted*' -- "$definition"
        printf '%s\n' "$definition" | string replace -- 'if test -n "$result"' 'if test -n "$result"; set -g __jeebis_fifc_accepted 1' | source
    end
end

# Use the same merged candidates for the common prefix and the fifc menu.
# Previews and selection remain fifc's responsibility.
function __jeebis_completion_source
    # fifc source rules return a command, not the candidates themselves.
    echo 'printf "%s\n" $__jeebis_fifc_candidates | string unescape'
end
fifc --order 1 --condition 'set -q __jeebis_fifc_active' --source __jeebis_completion_source

function fish_user_key_bindings
    for mode in default insert
        bind --mode $mode tab __jeebis_prepare_completion repaint __jeebis_open_completion
        bind --mode $mode shift-tab '__jeebis_prepare_completion direct' repaint __jeebis_open_completion
    end
    bind enter __abbr_tips_bind_newline
    bind ctrl-j __abbr_tips_bind_newline
    bind alt-h fzf-help-widget
    bind ctrl-f '__jeebis_find_file; commandline -f repaint'
    bind ctrl-g '__jeebis_find_text; commandline -f repaint'
    bind ctrl-d '__jeebis_find_directory; commandline -f repaint'
    bind ctrl-y '__jeebis_yazi; commandline -f repaint'
    bind ctrl-w cancel-commandline
    bind ctrl-shift-w exit
    bind ctrl-r _atuin_search
    bind ctrl-escape __jeebis_clear_list
    # Reserve Ctrl+L for the unified application bindings.
    bind ctrl-l ''
    bind escape,escape 'commandline -r ""'
    bind ctrl-left backward-word
    bind ctrl-right forward-word
    bind ctrl-backspace backward-kill-word
    bind ctrl-delete kill-word
    bind home beginning-of-line
    bind end end-of-line
    bind ctrl-t ''
    bind alt-c ''
end

# Install custom bindings after the shell integrations, including Atuin.
fish_user_key_bindings
