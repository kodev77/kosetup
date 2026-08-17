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
# NOTE: if starship is active it rewrites PS1 from its own PROMPT_COMMAND every
# prompt, so to use THIS prompt on omarchy also remove the starship init line.

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

if [[ ${BLE_VERSION-} ]]; then
    # -+= appends with dedupe, so re-sourcing ~/.bashrc doesn't double-register
    blehook PREEXEC-+=__mark_cmd_executed
    blehook PRECMD-+=__update_ps1
else
    trap '__mark_cmd_executed' DEBUG
    case ";${PROMPT_COMMAND};" in
        *";__update_ps1;"*) ;;
        *) PROMPT_COMMAND="__update_ps1${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
    esac
fi

# Multi-line PS1 template. \[ \] wrap the non-printing colour escapes; the dynamic
# ${__ps1_*} vars expand to plain text. ANSI slot colours ride the terminal palette:
# user@host = green (slot 2), path = blue (slot 4), branch = yellow (slot 3).
PS1='\[\e[1;32m\]\u@\h \[\e[1;34m\]${__ps1_path}\[\e[23;33m\]${__ps1_git}\[\e[0m\]\n\[\e[1;39m\]\$ \[\e[0m\]'

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
