# eza-based listing aliases (omarchy lsa/ll equivalents)
if command -v eza >/dev/null 2>&1; then
  alias lsa='eza -lah --group-directories-first --icons=auto'
  alias ll='lsa'
  alias lt='eza --tree --level=2 --long --icons --git'
  alias lta='eza --tree --level=2 --long --icons --git -a'
fi

command -v lazygit >/dev/null 2>&1 && alias lg='lazygit'

# Debian/Devuan ship the binary as batcat; install.sh also links ~/.local/bin/bat -> batcat
# so fzf preview subshells (where aliases don't expand) can call plain `bat` everywhere.
if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
  alias bat='batcat'
fi

# default editor = nvim. nnn/git/etc. read these; nnn prefers $VISUAL then $EDITOR.
export VISUAL=nvim
export EDITOR=nvim
