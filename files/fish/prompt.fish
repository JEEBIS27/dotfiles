set -g fish_transient_prompt 1
set -g __jeebis_slow_command_ms 3000
set -g __jeebis_face '( ´･ω･`)つ_/'
set -g __jeebis_color 87af87
set -g __jeebis_had_command 0
set -g __jeebis_prompt_ready 0

function __jeebis_prompt_reset
    set -g __jeebis_prompt_ready 0
    set -e __jeebis_previous_prompt_pwd
    set -e __jeebis_previous_prompt_git
    set -e __jeebis_path_anchor
    set -e __jeebis_git_anchor
end

function __jeebis_prompt_resize --on-signal WINCH
    __jeebis_prompt_reset
end

function clear --wraps clear
    __jeebis_prompt_reset
    command clear $argv
end

function reset --wraps reset
    __jeebis_prompt_reset
    command reset $argv
end

function __jeebis_prompt_pill --argument-names icon text
    set_color 303030
    printf ''
    set_color -b 303030 dadada
    printf '%s %s' "$icon" "$text"
    set_color normal
    set_color 303030
    printf ''
    set_color normal
end

function __jeebis_prompt_path --argument-names current previous
    if test -n "$previous"
        if test "$current" = "$previous"
            printf '.'
            return
        else if test (path dirname -- "$current") = "$previous"; or test (path dirname -- "$current") = (path dirname -- "$previous")
            printf '.../%s' (path basename -- "$current")
            return
        end
    end
    string replace --regex '^'(string escape --style=regex -- "$HOME")'($|/)' '~$1' -- "$current"
end

function __jeebis_prompt_refresh --on-event fish_prompt
    # TUIOS can tell us whether the full context is still on the visible screen.
    # Failure to inspect it is handled conservatively by printing full context.
    if set -q TUIOS_WINDOW_ID; and begin; set -q __jeebis_path_anchor; or set -q __jeebis_git_anchor; end
        set -l screen (command tuios capture-pane --window "$TUIOS_WINDOW_ID" --trim 2>/dev/null | string collect --allow-empty)
        if test -z "$screen"
            __jeebis_prompt_reset
        else
            if set -q __jeebis_path_anchor; and not string match --quiet --regex -- (string escape --style=regex -- "$__jeebis_path_anchor") "$screen"
                set -e __jeebis_previous_prompt_pwd
                set -e __jeebis_path_anchor
            end
            if set -q __jeebis_git_anchor; and not string match --quiet --regex -- (string escape --style=regex -- "$__jeebis_git_anchor") "$screen"
                set -e __jeebis_previous_prompt_git
                set -e __jeebis_git_anchor
            end
        end
    end
    set -g __jeebis_prompt_time (date +%H:%M:%S)
    set -g __jeebis_prompt_pwd "$PWD"
    set -g __jeebis_prompt_path_label (__jeebis_prompt_path "$PWD" "$__jeebis_previous_prompt_pwd")
    set -g __jeebis_prompt_branch (command git symbolic-ref --quiet --short HEAD 2>/dev/null)
    if test -z "$__jeebis_prompt_branch"
        set -g __jeebis_prompt_branch (command git rev-parse --short HEAD 2>/dev/null)
    end
    set -g __jeebis_prompt_dirty 0
    set -g __jeebis_prompt_git ''
    if test -n "$__jeebis_prompt_branch"
        set -l root (command git rev-parse --show-toplevel 2>/dev/null)
        test -n "$(command git status --porcelain 2>/dev/null)"; and set -g __jeebis_prompt_dirty 1
        set -g __jeebis_prompt_git "$root::$__jeebis_prompt_branch::$__jeebis_prompt_dirty"
    end
    set -g __jeebis_prompt_ready 1
end

function __jeebis_preexec --on-event fish_preexec
    set -g __jeebis_had_command 1
    set -g __jeebis_last_command $argv[1]
    if set -q TUIOS_WINDOW_ID
        printf '\e]133;C\a'
    end
end

function __jeebis_command_result --argument-names result duration
    set -l left ''
    set -l right ''
    if test "$result" -ne 0
        set left (set_color d75f5f)'✗ '"$result"(set_color normal)
    end
    if test "$duration" -ge $__jeebis_slow_command_ms
        set -l elapsed (printf '%.1fs' (math "$duration / 1000"))
        set right (__jeebis_prompt_pill '⏳' "$elapsed" | string collect)
    end
    if test -z "$left"; and test -z "$right"
        return
    end
    if test -n "$right"
        set -l columns 80
        set -q COLUMNS; and set columns $COLUMNS
        set -l padding (math "max(1, $columns - 1 - $(string length --visible -- "$left") - $(string length --visible -- "$right"))")
        printf '%s%*s%s\n' "$left" "$padding" '' "$right"
    else
        printf '%s\n' "$left"
    end
end

function __jeebis_postexec --on-event fish_postexec
    set -l result $status
    set -l duration 0
    set -q CMD_DURATION; and set duration $CMD_DURATION
    set -l command_name (string split -m 1 ' ' -- (string trim -- $argv[1]))[1]
    set -g __jeebis_face '( ´･ω･`)つ_/'
    set -g __jeebis_color 87af87
    if test $result -ne 0
        set -g __jeebis_face '( *｀ω´)/ﾑｷｰ'
        set -g __jeebis_color d75f5f
    else if test "$duration" -ge $__jeebis_slow_command_ms
        set -g __jeebis_face '(´っω-)….｡oO'
        set -g __jeebis_color af87af
    else if test "$command_name" = sudo
        set -g __jeebis_face '(-■д■-)ゞｸｲｯ'
        set -g __jeebis_color d7d75f
    else if string match -rq '^(l|eza)' -- "$command_name"
        set -g __jeebis_face ']ก`-ωｰ́ )ｼﾞｰｯ'
        set -g __jeebis_color 87afd7
    else if contains -- "$command_name" cd bd zd sd z zi cdi md / '~' - .. ... ....
        set -g __jeebis_face '≡( ⊂ ˆωˆ )⊃ '
        set -g __jeebis_color 87afaf
    end
    if set -q TUIOS_WINDOW_ID
        # Keep status decoration outside the captured command-output region.
        printf '\e]133;D;%s\a' $result
    end
    __jeebis_command_result "$result" "$duration"
    if string match --quiet --regex '(^|[;&|]\s*)(command\s+)?(clear|reset)(\s|$)' -- "$argv[1]"
        __jeebis_prompt_reset
    end
    set -g __jeebis_prompt_ready 0
end

function fish_prompt
    if test "$__jeebis_prompt_ready" != 1; or test "$__jeebis_prompt_pwd" != "$PWD"
        __jeebis_prompt_refresh
    end
    if set -q TUIOS_WINDOW_ID
        printf '\e]133;A\a'
    end
    __jeebis_prompt_pill '' "$__jeebis_prompt_time"
    set_color blue
    if contains -- --final-rendering $argv
        printf ' %s' "$__jeebis_prompt_path_label"
    else
        # Keep the active location explicit; only completed prompts use deltas.
        printf ' %s' (__jeebis_prompt_path "$__jeebis_prompt_pwd" '')
    end
    if test -n "$__jeebis_prompt_branch"
        set_color 87af87
        if test "$__jeebis_prompt_git" = "$__jeebis_previous_prompt_git"
            printf ' '
        else
            __jeebis_git_label "$__jeebis_prompt_branch" "$__jeebis_prompt_dirty"
        end
    end
    set_color normal
    if contains -- --final-rendering $argv
        printf ' '
        # Commit context only when this prompt is actually retained in scrollback.
        set -l git_changed 0
        test "$__jeebis_prompt_git" != "$__jeebis_previous_prompt_git"; and set git_changed 1
        set -g __jeebis_previous_prompt_pwd "$__jeebis_prompt_pwd"
        set -g __jeebis_previous_prompt_git "$__jeebis_prompt_git"
        if not string match --quiet --regex '^(\.|\.\.\./.*)$' -- "$__jeebis_prompt_path_label"
            set -g __jeebis_path_anchor "$__jeebis_prompt_path_label"
        end
        if test -z "$__jeebis_prompt_branch"
            set -e __jeebis_git_anchor
        else if test $git_changed -eq 1
            set -g __jeebis_git_anchor " $__jeebis_prompt_branch"
            test $__jeebis_prompt_dirty -eq 1; and set -g __jeebis_git_anchor "$__jeebis_git_anchor*"
        end
    else
        printf '\n'
        set_color $__jeebis_color
        printf '%s ' "$__jeebis_face"
    end
    set_color $__jeebis_color
    printf '❯ '
    set_color normal
    if set -q TUIOS_WINDOW_ID
        printf '\e]133;B\a'
    end
end

function fish_right_prompt
end

function __jeebis_list_on_cd --on-variable PWD
    status is-interactive; and command eza --icons=always
end
