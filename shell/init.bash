# kosetup — shell entry point, sourced from ~/.bashrc (line added by install.sh).
# Per-machine switches are env vars set BEFORE the source line, not repo edits:
#   export KOSETUP_PROMPT=0   keep the distro's own prompt (e.g. omarchy starship)
KOSETUP_DIR="${KOSETUP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# per-module opt-out, managed by install.sh's menu (shell items): a module name
# listed in ~/.local/state/kosetup/shell-disabled is skipped at startup
_ko_on() { ! grep -qxF "$1" "$HOME/.local/state/kosetup/shell-disabled" 2>/dev/null; }

_ko_on aliases && source "$KOSETUP_DIR/shell/aliases.bash"
_ko_on fzf-nav && source "$KOSETUP_DIR/shell/fzf-nav.bash"
_ko_on jcurl   && source "$KOSETUP_DIR/shell/jcurl.bash"
_ko_on nnn && command -v nnn >/dev/null 2>&1 && source "$KOSETUP_DIR/shell/nnn.bash"
_ko_on prompt && [ "${KOSETUP_PROMPT:-1}" != 0 ] && source "$KOSETUP_DIR/shell/prompt.bash"
# work module (dotnet env; dadbod/dvquery live in nvim + work/) — enabled by `install.sh --work`
[ -f "$HOME/.local/state/kosetup/work" ] && source "$KOSETUP_DIR/shell/work.bash"

true  # don't leak a failed guard's exit status to the sourcing shell
