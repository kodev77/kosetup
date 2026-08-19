# MINGW64-style prompt: user@host ~/path (branch) on its own line, then the $ line.
# The WHOLE prompt is a single multi-line PS1 so line editors that redraw the prompt
# (ble.sh) own it correctly on Ctrl-L and resize. The hook below only UPDATES the
# dynamic pieces (path/git/leading-blank) into variables — it prints nothing.
#
# Works with plain bash (PROMPT_COMMAND + DEBUG trap) or under ble.sh (blehook);
# ble.sh itself is NOT a kosetup dependency — the ble branches only fire if the
# machine's bashrc loaded it.
#
# Disable per-machine (keep the distro prompt, e.g. omarchy's starship) with
#   export KOSETUP_PROMPT=0   before the kosetup source line in ~/.bashrc.
# Reaching this file at all therefore means the prompt IS wanted, so if the
# distro already started starship (omarchy does, from its own rc, which bash
# sources before the kosetup hook) starship is evicted below — see
# __ko_evict_starship. No need to edit the distro's init script.

# git-sh-prompt location varies: Debian-family, then Arch, then git contrib.
for _ko_gp in /usr/lib/git-core/git-sh-prompt \
              /usr/share/git/completion/git-prompt.sh \
              /usr/share/git-core/contrib/completion/git-prompt.sh; do
  [ -r "$_ko_gp" ] && . "$_ko_gp" && break
done
unset _ko_gp
GIT_PS1_SHOWDIRTYSTATE=1

# Add a blank line before the prompt only after a real command ran (not the first
# prompt or a bare Enter). Set in PREEXEC/DEBUG, consumed when building the next
# prompt. Under ble.sh it also flips the resize action to 'redraw-here' so a
# command's output is PRESERVED on resize; Ctrl-L / a fresh shell flip it back to
# 'clear' (clean prompt snaps to the top).
__cmd_just_ran=
__mark_cmd_executed() {
    __cmd_just_ran=1
    [[ ${BLE_VERSION-} ]] && bleopt canvas_winch_action=redraw-here
}

# Compute the dynamic PS1 pieces into __ps1_* vars (referenced by the PS1 template
# below). Prints nothing — so the full multi-line prompt redraws cleanly.
__update_ps1() {
    # Blank line between commands: print it as OUTPUT (not part of PS1) so Ctrl-L
    # and resize don't carry it into the prompt. Only after a real command ran.
    if [ -n "$__cmd_just_ran" ]; then echo; __cmd_just_ran=; fi
    __ps1_path="${PWD/#$HOME/\~}"
    __ps1_git=
    local repo_root
    if declare -F __git_ps1 >/dev/null && repo_root=$(git rev-parse --show-toplevel 2>/dev/null); then
        __ps1_git=" $(__git_ps1 "(%s)")"
        local sh="${HOSTNAME%%.*}"
        local total=$(( ${#USER} + 1 + ${#sh} + 1 + ${#__ps1_path} + ${#__ps1_git} ))
        local threshold=$(( ${COLUMNS:-80} * 70 / 100 ))
        # Collapse <repo>/a/b/c/leaf -> <repo>/.../leaf when the header exceeds 70% of cols
        if (( total > threshold )) && [[ "$PWD" == "$repo_root"/*/* ]]; then
            __ps1_path="${repo_root/#$HOME/\~}/.../${PWD##*/}"
        fi
    fi
}

# starship rewrites PS1 from its own precmd on EVERY prompt, so merely adding
# __update_ps1 alongside it loses the race and this prompt is never seen. Since
# KOSETUP_PROMPT=0 is the way to keep the distro prompt, getting here means this
# prompt was asked for — so take starship out cleanly instead of fighting it.
# Everything else in PROMPT_COMMAND (omarchy has a terminal-title hook and
# zoxide in there) is preserved.
__ko_evict_starship() {
    declare -F starship_precmd >/dev/null 2>&1 || return 0
    local e; local -a keep=()
    if [[ "$(declare -p PROMPT_COMMAND 2>/dev/null)" == "declare -a"* ]]; then
        for e in "${PROMPT_COMMAND[@]}"; do
            [[ "$e" == *starship_precmd* ]] || keep+=("$e")
        done
        PROMPT_COMMAND=("${keep[@]}")
    else
        PROMPT_COMMAND="${PROMPT_COMMAND//starship_precmd/}"
        PROMPT_COMMAND="${PROMPT_COMMAND//;;/;}"
    fi
    # starship stashes a pre-existing string PROMPT_COMMAND here — put it back
    [[ -n "${STARSHIP_PROMPT_COMMAND-}" ]] && PROMPT_COMMAND+=("$STARSHIP_PROMPT_COMMAND")
    # timing hooks: PS0 on bash >= 4.4, a DEBUG trap on older
    [[ "${PS0-}" == *STARSHIP_START_TIME* ]] && PS0=''
    case "$(trap -p DEBUG)" in *starship_preexec*) trap - DEBUG ;; esac
    unset -f starship_precmd starship_preexec starship_preexec_ps0 \
             starship_preexec_all _starship_set_return 2>/dev/null
    unset STARSHIP_PROMPT_COMMAND STARSHIP_START_TIME STARSHIP_PREEXEC_READY
    return 0
}

# PROMPT_COMMAND is an ARRAY on bash 5.1+ (omarchy's is: starship, title, zoxide).
# The old string-only form read element [0] and assigned straight back into it,
# which both hid the other entries and left starship running after __update_ps1.
__ko_prompt_register() {
    local e
    if [[ "$(declare -p PROMPT_COMMAND 2>/dev/null)" == "declare -a"* ]]; then
        for e in "${PROMPT_COMMAND[@]}"; do
            [[ "$e" == *__update_ps1* ]] && return 0
        done
        PROMPT_COMMAND=(__update_ps1 "${PROMPT_COMMAND[@]}")
    else
        case ";${PROMPT_COMMAND};" in
            *";__update_ps1;"*) ;;
            *) PROMPT_COMMAND="__update_ps1${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
        esac
    fi
    return 0
}

if [[ ${BLE_VERSION-} ]]; then
    # -+= appends with dedupe, so re-sourcing ~/.bashrc doesn't double-register
    blehook PREEXEC-+=__mark_cmd_executed
    blehook PRECMD-+=__update_ps1
    __ko_evict_starship
else
    trap '__mark_cmd_executed' DEBUG
    __ko_evict_starship
    __ko_prompt_register
fi

# Prompt symbol on line 2: U+F0A9 (nf-fa-arrow_circle_right), the circled arrow
# carried over from the komarchy starship prompt. It lives in the Nerd Font
# private use area, so a terminal WITHOUT a Nerd Font renders a tofu box —
# set KOSETUP_PROMPT_SYMBOL='$' in ~/.bashrc on such a machine.
: "${KOSETUP_PROMPT_SYMBOL:=}"

# Multi-line PS1 template. \[ \] wrap the non-printing colour escapes; the dynamic
# ${__ps1_*} vars expand to plain text. ANSI slot colours ride the terminal palette:
# user@host = green (slot 2), path = blue (slot 4), branch = yellow (slot 3),
# prompt symbol = cyan (slot 6, matching komarchy).
# `⟩` between host and path: same separator the komarchy starship prompt used
# (its directory format was "⟩ [$path]"). Plain Unicode U+27E9, no Nerd Font
# needed; cyan to match the line-2 prompt symbol.
PS1='\[\e[1;32m\]\u@\h \[\e[1;36m\]⟩ \[\e[1;34m\]${__ps1_path}\[\e[23;33m\]${__ps1_git}\[\e[0m\]\n\[\e[1;36m\]${KOSETUP_PROMPT_SYMBOL}\[\e[0m\]  '

# ble.sh redraw fixes (no-ops when ble.sh isn't loaded):
if [[ ${BLE_VERSION-} ]]; then
    bleopt prompt_eol_mark=
    # Resize behaviour is toggled by screen state (see __mark_cmd_executed):
    #   clean prompt (no output on screen) → 'clear': snap prompt to top on resize.
    #   after a command (output on screen)  → 'redraw-here': keep the output.
    bleopt canvas_winch_action=clear
    # Ctrl-L: clear all output (incl. the inter-command blank line), redraw the
    # prompt at the top, and flip the resize action back to 'clear'.
    function ble/widget/ko-clear-screen {
        bleopt canvas_winch_action=clear
        ble/widget/clear-screen
    }
    ble-bind -f 'C-l' ko-clear-screen
fi
