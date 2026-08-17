# nnn file manager. Plugin shortcuts (invoke with `;` + key inside nnn):
#   p=preview-tui  o=fzopen  c=fzcd  d=diffs  z=autojump  g=getplugs
export NNN_PLUG='p:preview-tui;o:fzopen;c:fzcd;d:diffs;z:autojump;g:getplugs'
# ANSI palette riding (works on ANY distro/terminal, incl. omarchy themes): nnn's
# built-in defaults use 256-cube indices (dir=39, orphan=247) that ignore the
# terminal's 16-colour palette. Forcing every file-type colour into ANSI slots
# 0-15 makes nnn recolour automatically with whatever theme the terminal runs.
# Field order: blk char dir exe reg hardlink symlink orphan fifo sock unknown misc.
export NNN_FCOLORS='030304020000060103050106'   # dir=blue(4) exe=green(2) reg=default link=cyan(6) orphan=red(1)
export NNN_COLORS='2136'                          # the 4 context-tab colours (all 0-7 → ride)
# NOTE: no static NNN_FIFO. The -a flag below auto-creates a PER-INSTANCE temp
# FIFO instead. A shared /tmp/nnn.fifo lets orphaned preview readers from old
# sessions steal hover events → preview stops updating on j/k.
export NNN_SPLIT='v'   # force side-by-side preview (preview pane always on right)
# mouse-scrollable preview: --mouse lets less take the wheel so tmux forwards it
export NNN_PAGER='less -P?n -R -C -S --mouse --wheel-lines=3'  # -S: chop long lines

# cd-on-quit + auto-tmux: typing `nnn` (this function shadows the binary) quits into
# its last dir. preview-tui (;p) needs a multiplexer to draw an INLINE split, so when
# not already in tmux, wrap nnn in a throwaway tmux server (-L nnn, isolated from
# real tmux sessions). The real binary is always called via `command nnn`.
nnn() {
  # block nesting an nnn inside an nnn subshell
  [ "${NNNLVL:-0}" -eq 0 ] || { echo "nnn is already running"; return; }
  export NNN_TMPFILE="${XDG_CONFIG_HOME:-$HOME/.config}/nnn/.lastd"
  local nconf="${XDG_CONFIG_HOME:-$HOME/.config}/nnn/nnn.tmux.conf"
  if [ -z "$TMUX" ] && [ -f "$nconf" ] && command -v tmux >/dev/null 2>&1; then
    # Pass NNN_* env per-session (-e): the long-lived -L nnn server captures its
    # global env once at start; -e overrides that regardless of server age.
    local nenv=()
    [ -n "${NNN_FCOLORS:-}" ] && nenv+=(-e "NNN_FCOLORS=$NNN_FCOLORS")
    [ -n "${NNN_COLORS:-}" ]  && nenv+=(-e "NNN_COLORS=$NNN_COLORS")
    # on quit the tmux client prints a hardcoded "[exited]" line (no option to
    # silence it in 3.5a) — erase it, but only on clean exit so real errors stay
    tmux -L nnn -f "$nconf" new-session -d "${nenv[@]}" "command nnn -ae $(printf '%q ' "$@")" \; attach \
      && printf '\033[A\033[2K'
  else
    command nnn -ae "$@"  # -a: per-instance preview FIFO; -e: text files in $EDITOR
  fi
  [ ! -f "$NNN_TMPFILE" ] || { . "$NNN_TMPFILE"; rm -f -- "$NNN_TMPFILE"; }
}
alias n=nnn   # short form; same wrapper
# raw nnn without the wrapper (no cd-on-quit / inline preview): use `command nnn`
