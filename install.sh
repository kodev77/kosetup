#!/usr/bin/env bash
# kosetup installer — component-based, item-granular, idempotent, reversible.
#
#   ./install.sh                     fzf menu, nested groups + items:
#                                      [x] [packages]
#                                        [x] [fzf]
#                                        [ ] [neovim]
#                                    Enter toggles selection ([ ] installs,
#                                    [x] removes); TAB = multi-select.
#   ./install.sh <group>...          install whole group(s)
#   ./install.sh <group>/<item>...   install single item(s), e.g. shell/jcurl
#   ./install.sh remove <group|group/item>...|--all
#   ./install.sh all | all-work      everything (all-work includes work groups)
#   ./install.sh --list              print the nested status tree
#
# Flags: --no-prompt (write KOSETUP_PROMPT=0 into the bashrc hook)
#        --nvim-appimage (fetch latest Neovim AppImage to ~/.local/bin/nvim)
#
# Removal is surgical: only symlinks pointing INTO this repo are removed,
# *.bak-kosetup backups are restored, and package removal only touches the
# recorded set this script actually installed (never pre-existing packages).
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$HOME/.local/state/kosetup"
PKG_RECORD="$STATE_DIR/installed-packages"
SHELL_DISABLED="$STATE_DIR/shell-disabled"
NVCONF="$HOME/.config/nvim"

say() { printf '\033[1m[kosetup]\033[0m %s\n' "$*"; }

KGROUPS=(packages shell inputrc git nvim nvim-work work-cli tiles retro)
declare -A GDESC=(
  [packages]="core CLI packages + fd/bat shims"
  [shell]="bashrc hook + shell modules"
  [inputrc]="~/.inputrc: case-insensitive completion, colored stats"
  [git]="git include.path: aliases, diffview mergetool, work includeIf"
  [nvim]="nvim overlay (core)"
  [nvim-work]="nvim overlay (work)"
  [work-cli]="dvquery/sqlcmd venvs + stubs + work marker"
  [tiles]="TUI tiles -> ~/.local/bin"
  [retro]="retro game launchers + linapple configs"
)
declare -A IDESC=(
  [shell/aliases]="eza ll/lsa/lt, lg, bat, EDITOR=nvim"
  [shell/fzf-nav]="cdf cdff cdg cds"
  [shell/jcurl]="curl+jq JSON helper"
  [shell/nnn]="nnn wrapper + tmux preview"
  [shell/prompt]="2-line git prompt"
  [nvim/lsp-extra]="bashls pyright jsonls yamlls"
  [nvim/db2]="password-manager tool"
  [nvim/dasm]="6502 completion + syntax"
  [nvim-work/dadbod]="DB suite + formatter + dataverse adapter"
  [nvim-work/dap]="C#/netcoredbg debugging"
  [nvim-work/lsp-work]="omnisharp ts_ls angularls"
  [work-cli/dvquery]="Dataverse SQL CLI (venv)"
  [work-cli/sqlcmd]="pymssql wrapper (venv)"
  [retro/simcity]="simcity-1989/1994/2000"
  [retro/apple2]="apple2-run + linapple configs"
  [retro/rogue-dos]="DOS Rogue via dosbox"
  [retro/arcade1]="ARCADE1 cab CIFS mount/umount"
)

NO_PROMPT=0 NVIM_APPIMAGE=0

# --- platform helpers --------------------------------------------------------

PM=""
command -v apt-get >/dev/null 2>&1 && PM=apt
[ -z "$PM" ] && command -v pacman >/dev/null 2>&1 && PM=pacman

pkg_list_file() {
  case "$PM" in
    apt) echo "$REPO/packages/apt.list" ;;
    pacman) echo "$REPO/packages/pacman.list" ;;
  esac
}

pkg_names() {
  [ -n "$PM" ] || return 0
  grep -vE '^\s*(#|$)' "$(pkg_list_file)"
}

pkg_present() {
  case "$PM" in
    apt) dpkg -s "$1" >/dev/null 2>&1 ;;
    pacman) pacman -Qi "$1" >/dev/null 2>&1 || pacman -Qg "$1" >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}

pkg_install_one() {
  case "$PM" in
    apt)    sudo apt-get install -y "$1" ;;
    pacman) sudo pacman -S --needed --noconfirm "$1" ;;
  esac
}

pkg_record() {
  mkdir -p "$STATE_DIR"
  grep -qxF "$1" "$PKG_RECORD" 2>/dev/null || echo "$1" >> "$PKG_RECORD"
}

link() { # link <target> <dest> — backs up a pre-existing real file/dir
  local t="$1" d="$2"
  [ -L "$d" ] && [ "$(readlink "$d")" = "$t" ] && return 0
  if [ -e "$d" ] && [ ! -L "$d" ]; then
    mv "$d" "$d.bak-kosetup"; say "backed up: $d -> $d.bak-kosetup"
  fi
  ln -sfn "$t" "$d"; say "link: $d -> $t"
}

unlink_repo() { # remove only if it points into the repo; restore backup
  local d="$1"
  if [ -L "$d" ] && [[ "$(readlink "$d")" == "$REPO"/* ]]; then
    rm "$d"; say "unlink: $d"
  fi
  if [ -e "$d.bak-kosetup" ]; then
    mv "$d.bak-kosetup" "$d"; say "restored: $d (from .bak-kosetup)"
  fi
}

points_into_repo() { [ -L "$1" ] && [[ "$(readlink "$1")" == "$REPO"/* ]]; }

link_pairs()   { local t d; while IFS=$'\t' read -r t d; do mkdir -p "$(dirname "$d")"; link "$t" "$d"; done; }
unlink_pairs() { local t d; while IFS=$'\t' read -r t d; do unlink_repo "$d"; done; }

nvim_base_ok() {
  if [ ! -d "$NVCONF" ]; then
    say "WARN: no ~/.config/nvim — kosetup's nvim files overlay an existing (LazyVim/omarchy) config. Install the base config first."
    return 1
  fi
}

# --- item registry -----------------------------------------------------------

items_of() {
  case "$1" in
    packages)  pkg_names ;;
    shell)     printf '%s\n' aliases fzf-nav jcurl nnn prompt ;;
    nvim)      printf '%s\n' lsp-extra db2 dasm ;;
    nvim-work) printf '%s\n' dadbod dap lsp-work ;;
    work-cli)  printf '%s\n' dvquery sqlcmd ;;
    tiles)     printf '%s\n' sys-tile snake-tile clock-tile rogue-tile ;;
    retro)     printf '%s\n' simcity apple2 rogue-dos arcade1 ;;
    *) : ;;  # inputrc, git — no sub-items
  esac
}

pairs_of() { # pairs_of <group> <item> → "repo-file<TAB>abs-dest" lines
  local g="$1" i="$2" f
  case "$g/$i" in
    nvim/lsp-extra)
      printf '%s\t%s\n' "$REPO/nvim/lua/plugins/lsp-extra.lua" "$NVCONF/lua/plugins/lsp-extra.lua" ;;
    nvim/db2)
      printf '%s\t%s\n' "$REPO/nvim/lua/plugins/db2.lua" "$NVCONF/lua/plugins/db2.lua"
      printf '%s\t%s\n' "$REPO/nvim/lua/util/db2.lua" "$NVCONF/lua/util/db2.lua" ;;
    nvim/dasm)
      printf '%s\t%s\n' "$REPO/nvim/lua/plugins/blink-dasm.lua" "$NVCONF/lua/plugins/blink-dasm.lua"
      printf '%s\t%s\n' "$REPO/nvim/lua/dasm_complete.lua" "$NVCONF/lua/dasm_complete.lua"
      printf '%s\t%s\n' "$REPO/nvim/after/ftplugin/asm.lua" "$NVCONF/after/ftplugin/asm.lua"
      printf '%s\t%s\n' "$REPO/nvim/after/syntax/asm.vim" "$NVCONF/after/syntax/asm.vim" ;;
    nvim-work/dadbod)
      for f in "$REPO"/nvim/lua/plugins_work/dadbod*.lua; do
        printf '%s\t%s\n' "$f" "$NVCONF/lua/plugins/$(basename "$f")"
      done
      printf '%s\t%s\n' "$REPO/nvim/lua/util/dadbod-format.lua" "$NVCONF/lua/util/dadbod-format.lua"
      printf '%s\t%s\n' "$REPO/nvim/lua/util/dadbod-helpers.lua" "$NVCONF/lua/util/dadbod-helpers.lua"
      for f in "$REPO"/nvim/lua/util/dadbod-tables/*.lua; do
        printf '%s\t%s\n' "$f" "$NVCONF/lua/util/dadbod-tables/$(basename "$f")"
      done
      printf '%s\t%s\n' "$REPO/nvim/autoload/db/adapter/dataverse.vim" "$NVCONF/autoload/db/adapter/dataverse.vim" ;;
    nvim-work/dap)
      printf '%s\t%s\n' "$REPO/nvim/lua/plugins_work/dap.lua" "$NVCONF/lua/plugins/dap.lua" ;;
    nvim-work/lsp-work)
      printf '%s\t%s\n' "$REPO/nvim/lua/plugins_work/lsp-work.lua" "$NVCONF/lua/plugins/lsp-work.lua" ;;
    tiles/sys-tile|tiles/snake-tile|tiles/clock-tile)
      printf '%s\t%s\n' "$REPO/tiles/$i" "$HOME/.local/bin/$i" ;;
    tiles/rogue-tile)
      printf '%s\t%s\n' "$REPO/tiles/rogue/rogue-tile" "$HOME/.local/bin/rogue-tile" ;;
    retro/simcity)
      for f in simcity-1989 simcity-1994 simcity-2000; do
        printf '%s\t%s\n' "$REPO/bin/$f" "$HOME/.local/bin/$f"
      done ;;
    retro/apple2)
      printf '%s\t%s\n' "$REPO/bin/apple2-run" "$HOME/.local/bin/apple2-run"
      printf '%s\t%s\n' "$REPO/config/linapple" "$HOME/.config/linapple" ;;
    retro/rogue-dos)
      printf '%s\t%s\n' "$REPO/bin/rogue-dos" "$HOME/.local/bin/rogue-dos" ;;
    retro/arcade1)
      printf '%s\t%s\n' "$REPO/bin/arcade1-mount" "$HOME/.local/bin/arcade1-mount"
      printf '%s\t%s\n' "$REPO/bin/arcade1-umount" "$HOME/.local/bin/arcade1-umount" ;;
  esac
}

# --- shell module enable/disable ---------------------------------------------

shell_hook_present() { grep -q 'kosetup/shell/init.bash' "$HOME/.bashrc" 2>/dev/null; }

shell_hook_add() {
  if ! shell_hook_present; then
    {
      echo ''
      echo '# --- BEGIN kosetup ---'
      [ "$NO_PROMPT" = 1 ] && echo 'export KOSETUP_PROMPT=0'
      echo "source \"$REPO/shell/init.bash\""
      echo '# --- END kosetup ---'
    } >> "$HOME/.bashrc"
    say "bashrc: kosetup source line added"
  fi
}

shell_mod_enabled() { ! grep -qxF "$1" "$SHELL_DISABLED" 2>/dev/null; }
shell_mod_enable()  {
  [ -f "$SHELL_DISABLED" ] && { grep -vxF "$1" "$SHELL_DISABLED" > "$SHELL_DISABLED.tmp" || true; mv "$SHELL_DISABLED.tmp" "$SHELL_DISABLED"; }
  say "shell module enabled: $1"
}
shell_mod_disable() {
  mkdir -p "$STATE_DIR"
  grep -qxF "$1" "$SHELL_DISABLED" 2>/dev/null || echo "$1" >> "$SHELL_DISABLED"
  say "shell module disabled: $1 (new shells only)"
}

# --- status ------------------------------------------------------------------

item_installed() { # <group> <item>
  local g="$1" i="$2" first
  case "$g" in
    packages) pkg_present "$i" ;;
    shell)    shell_hook_present && shell_mod_enabled "$i" ;;
    work-cli) [ -f "$HOME/.local/bin/$i" ] && grep -q 'kosetup exec stub' "$HOME/.local/bin/$i" 2>/dev/null ;;
    nvim|nvim-work|tiles|retro)
      first="$(pairs_of "$g" "$i" | head -1 | cut -f2)"
      [ -n "$first" ] && points_into_repo "$first" ;;
    *) return 1 ;;
  esac
}

group_status() { # echoes 'x', '~' or ' '
  local g="$1" i inst=0 tot=0
  case "$g" in
    inputrc) points_into_repo "$HOME/.inputrc" && echo x || echo ' '; return ;;
    git) git config --global --get-all include.path 2>/dev/null | grep -qF "kosetup/git/ko.gitconfig" \
           && echo x || echo ' '; return ;;
  esac
  while read -r i; do
    [ -n "$i" ] || continue
    tot=$((tot + 1))
    item_installed "$g" "$i" && inst=$((inst + 1)) || true
  done < <(items_of "$g")
  if [ "$tot" -eq 0 ] || [ "$inst" -eq 0 ]; then echo ' '
  elif [ "$inst" -eq "$tot" ]; then echo x
  else echo '~'
  fi
}

# --- install / remove --------------------------------------------------------

install_item() { # <group> <item>
  local g="$1" i="$2"
  case "$g" in
    packages)
      if pkg_present "$i"; then say "package present: $i"
      else pkg_install_one "$i" && pkg_record "$i" || say "WARN: $i not installed"; fi
      pkg_shims ;;
    shell) shell_hook_add; shell_mod_enable "$i"
           [ "$i" = nnn ] && { mkdir -p "$HOME/.config/nnn"; link "$REPO/config/nnn.tmux.conf" "$HOME/.config/nnn/nnn.tmux.conf"; } || true ;;
    work-cli) install_workcli_tool "$i" ;;
    nvim|nvim-work)
      nvim_base_ok || return 0
      pairs_of "$g" "$i" | link_pairs ;;
    tiles|retro)
      mkdir -p "$HOME/.local/bin"
      pairs_of "$g" "$i" | link_pairs ;;
  esac
}

remove_item() { # <group> <item>
  local g="$1" i="$2"
  case "$g" in
    packages)
      if grep -qxF "$i" "$PKG_RECORD" 2>/dev/null; then
        case "$PM" in
          apt)    sudo apt-get remove -y "$i" || true ;;
          pacman) sudo pacman -Rns --noconfirm "$i" || true ;;
        esac
        grep -vxF "$i" "$PKG_RECORD" > "$PKG_RECORD.tmp" || true; mv "$PKG_RECORD.tmp" "$PKG_RECORD"
        say "package removed: $i"
      else
        say "package '$i' was not installed by kosetup — leaving it alone"
      fi ;;
    shell) shell_mod_disable "$i"
           [ "$i" = nnn ] && unlink_repo "$HOME/.config/nnn/nnn.tmux.conf" || true ;;
    work-cli) remove_workcli_tool "$i" ;;
    nvim|nvim-work|tiles|retro)
      pairs_of "$g" "$i" | unlink_pairs
      [ "$g" = nvim ] || [ "$g" = nvim-work ] && nvim_rmdirs || true ;;
  esac
}

pkg_shims() {
  mkdir -p "$HOME/.local/bin"
  if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"; say "shim: fd -> fdfind"
  fi
  if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"; say "shim: bat -> batcat"
  fi
}

nvim_rmdirs() {
  rmdir "$NVCONF/lua/util/dadbod-tables" "$NVCONF/lua/util" \
        "$NVCONF/after/ftplugin" "$NVCONF/after/syntax" \
        "$NVCONF/autoload/db/adapter" "$NVCONF/autoload/db" 2>/dev/null || true
}

install_workcli_tool() { # dvquery | sqlcmd
  local tool="$1" stub
  mkdir -p "$STATE_DIR"; touch "$STATE_DIR/work"
  if [ "$PM" = apt ] && ! python3 -m venv --help >/dev/null 2>&1; then
    sudo apt-get install -y python3-venv
  fi
  case "$tool" in
    dvquery)
      if [ ! -x "$HOME/.local/share/dvquery-venv/bin/python3" ]; then
        say "work: creating dvquery venv (requests, tabulate)"
        python3 -m venv "$HOME/.local/share/dvquery-venv"
        "$HOME/.local/share/dvquery-venv/bin/pip" install -q requests tabulate
      fi ;;
    sqlcmd)
      if [ ! -x "$HOME/.local/share/sqlcmd-venv/bin/python3" ]; then
        say "work: creating sqlcmd venv (pymssql)"
        python3 -m venv "$HOME/.local/share/sqlcmd-venv"
        "$HOME/.local/share/sqlcmd-venv/bin/pip" install -q pymssql
      fi ;;
  esac
  # venv shebangs can't be portable — generate a tiny exec stub; script stays in the repo
  stub="$HOME/.local/bin/$tool"
  if [ -e "$stub" ] && [ ! -L "$stub" ] && ! grep -q 'kosetup exec stub' "$stub" 2>/dev/null; then
    mv "$stub" "$stub.bak-kosetup"; say "backed up: $stub -> $stub.bak-kosetup"
  fi
  cat > "$stub" <<STUB
#!/bin/sh
# kosetup exec stub — the real script lives in the kosetup repo
exec "\$HOME/.local/share/${tool}-venv/bin/python3" "$REPO/work/$tool" "\$@"
STUB
  chmod +x "$stub"
  say "work: $tool stub installed"
  case "$tool" in
    dvquery)
      [ -f "$HOME/.local/share/db_ui/connections.json" ] \
        || say "TODO: create ~/.local/share/db_ui/connections.json (template: work/connections.json.example)" ;;
    sqlcmd)
      command -v go-sqlcmd >/dev/null 2>&1 \
        || say "TODO: Entra/AAD SQL auth needs go-sqlcmd -> ~/.local/bin (github.com/microsoft/go-sqlcmd releases)" ;;
  esac
  command -v dotnet >/dev/null 2>&1 \
    || say "TODO: .NET SDK: dotnet-install.sh --channel 10.0 --install-dir ~/.dotnet (work.bash already sets DOTNET_ROOT)"
}

remove_workcli_tool() {
  local tool="$1" stub="$HOME/.local/bin/$1"
  if [ -f "$stub" ] && grep -q 'kosetup exec stub' "$stub" 2>/dev/null; then
    rm "$stub"; say "removed stub: $stub"
  fi
  [ -e "$stub.bak-kosetup" ] && { mv "$stub.bak-kosetup" "$stub"; say "restored: $stub"; }
  say "note: venv kept at ~/.local/share/${tool}-venv — delete manually to purge"
  if ! item_installed work-cli dvquery && ! item_installed work-cli sqlcmd; then
    rm -f "$STATE_DIR/work"
    say "work: marker removed (shell dotnet env off in new shells)"
  fi
}

install_group() {
  local g="$1" i
  say "--- install: $g ---"
  case "$g" in
    inputrc) link "$REPO/config/inputrc" "$HOME/.inputrc"; return ;;
    git)
      if ! git config --global --get-all include.path 2>/dev/null | grep -qF "kosetup/git/ko.gitconfig"; then
        git config --global --add include.path "$REPO/git/ko.gitconfig"
        say "git: include.path -> git/ko.gitconfig"
      else
        say "git: include already wired"
      fi
      git config --global user.name >/dev/null 2>&1 \
        || say "REMINDER: set identity: git config --global user.name/user.email"
      return ;;
    shell) shell_hook_add; rm -f "$SHELL_DISABLED" ;;
  esac
  while read -r i; do [ -n "$i" ] && install_item "$g" "$i"; done < <(items_of "$g")
  [ "$g" = retro ] && retro_emulators
  # NOTE: hardware/ (gpu-profile + boot-time perms) is deliberately NOT installed —
  # it needs ASUS hardware plus a distro-specific boot hook; wire it up per-machine.
}

retro_emulators() { # the launchers need dosbox-staging (simcity/rogue-dos) + linapple (apple2-run)
  if ! command -v dosbox-staging >/dev/null 2>&1 && ! command -v dosbox >/dev/null 2>&1; then
    case "$PM" in
      pacman) sudo pacman -S --needed --noconfirm dosbox-staging \
                || say "TODO: install dosbox-staging" ;;
      apt)    sudo apt-get install -y dosbox-staging \
                || say "TODO: dosbox-staging not in apt — tarball to ~/.local/opt + symlink ~/.local/bin/dosbox-staging" ;;
      *)      say "TODO: install dosbox-staging for the simcity/rogue-dos launchers" ;;
    esac
  fi
  if ! command -v linapple >/dev/null 2>&1; then
    if command -v yay >/dev/null 2>&1; then
      yay -S --needed --noconfirm linapple-git \
        || say "TODO: linapple install failed — build the linapple repo clone (make && sudo make install)"
    else
      say "TODO: linapple for apple2-run — arch: yay -S linapple-git; elsewhere build the linapple repo clone (make && sudo make install)"
    fi
  fi
}

remove_group() {
  local g="$1" i
  say "--- remove: $g ---"
  case "$g" in
    inputrc) unlink_repo "$HOME/.inputrc"; return ;;
    git)
      if git config --global --get-all include.path 2>/dev/null | grep -qF "kosetup/git/ko.gitconfig"; then
        git config --global --unset include.path "kosetup/git/ko\.gitconfig" || true
        say "git: include.path removed"
      fi
      return ;;
    shell)
      if grep -q '^# --- BEGIN kosetup ---$' "$HOME/.bashrc" 2>/dev/null; then
        sed -i '/^# --- BEGIN kosetup ---$/,/^# --- END kosetup ---$/d' "$HOME/.bashrc"
        say "bashrc: kosetup block removed (open shells keep it until restarted)"
      fi
      rm -f "$SHELL_DISABLED"
      unlink_repo "$HOME/.config/nnn/nnn.tmux.conf"
      return ;;
    packages)
      local reply
      read -r -p "[kosetup] remove kosetup-installed packages ($( [ -s "$PKG_RECORD" ] && tr '\n' ' ' < "$PKG_RECORD" || echo none ))? [y/N] " reply
      case "$reply" in y|Y) ;; *) say "packages: skipped"; return ;; esac ;;
  esac
  while read -r i; do [ -n "$i" ] && remove_item "$g" "$i"; done < <(items_of "$g")
}

# --- rendering ---------------------------------------------------------------

render() { # "key<TAB>display" lines for menu/list
  local g i m d
  for g in "${KGROUPS[@]}"; do
    m="$(group_status "$g")"
    printf '%s\t[%s] [%s] — %s\n' "$g" "$m" "$g" "${GDESC[$g]}"
    while read -r i; do
      [ -n "$i" ] || continue
      if item_installed "$g" "$i"; then m=x; else m=' '; fi
      d="${IDESC[$g/$i]:-}"
      printf '%s/%s\t  [%s] [%s]%s\n' "$g" "$i" "$m" "$i" "${d:+ — $d}"
    done < <(items_of "$g")
  done
}

print_list() { render | cut -f2-; }

DEFAULT_SET=(packages shell inputrc git nvim tiles retro)
WORK_SET=(nvim-work work-cli)

toggle_key() { # <group> or <group/item>
  local key="$1" g i
  if [[ "$key" == */* ]]; then
    g="${key%%/*}" i="${key#*/}"
    if item_installed "$g" "$i"; then say "--- remove: $key ---"; remove_item "$g" "$i"
    else say "--- install: $key ---"; install_item "$g" "$i"; fi
  else
    if [ "$(group_status "$key")" = x ]; then remove_group "$key"
    else install_group "$key"; fi
  fi
}

nvim_appimage() {
  say "downloading latest Neovim AppImage"
  curl -fL -o "$HOME/.local/bin/.nvim.appimage.part" \
    https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage
  chmod +x "$HOME/.local/bin/.nvim.appimage.part"
  mv "$HOME/.local/bin/.nvim.appimage.part" "$HOME/.local/bin/nvim-linux-x86_64.appimage"
  ln -sfn "$HOME/.local/bin/nvim-linux-x86_64.appimage" "$HOME/.local/bin/nvim"
  say "nvim: AppImage installed as ~/.local/bin/nvim"
}

menu() {
  if ! command -v fzf >/dev/null 2>&1; then
    say "fzf not found — run '$0 packages' first (or use CLI args; see --help)"
    exit 1
  fi
  local sel line key c reply
  while true; do
    sel=$( { render
            printf '@all\t=== Install All (no work) ===\n'
            printf '@all-work\t=== Install All +Work ===\n'
            printf '@remove-all\t=== Remove All ===\n'
            printf '@quit\t=== Quit ===\n'
          } | fzf --multi --delimiter='\t' --with-nth=2 --prompt="kosetup > " --layout=reverse \
              --header="Enter toggles: [ ] installs, [x]/[~] removes/completes. TAB = multi-select. Esc = quit." ) || break
    [ -z "$sel" ] && break
    local acted=0
    while IFS= read -r line; do
      key="${line%%$'\t'*}"
      case "$key" in
        @quit) return 0 ;;
        @all)      for c in "${DEFAULT_SET[@]}"; do install_group "$c"; done; acted=1 ;;
        @all-work) for c in "${DEFAULT_SET[@]}" "${WORK_SET[@]}"; do install_group "$c"; done; acted=1 ;;
        @remove-all)
          read -r -p "[kosetup] remove ALL kosetup components? [y/N] " reply
          case "$reply" in
            y|Y) for c in "${KGROUPS[@]}"; do remove_group "$c"; done; acted=1 ;;
            *) say "remove all: cancelled" ;;
          esac ;;
        *) toggle_key "$key"; acted=1 ;;
      esac
    done <<< "$sel"
    if [ "$acted" = 1 ]; then
      echo
      read -r -p "[kosetup] done — Enter for menu, q to quit: " reply
      [ "$reply" = q ] && break
    fi
  done
}

# --- main --------------------------------------------------------------------

ARGS=()
for a in "$@"; do
  case "$a" in
    --no-prompt) NO_PROMPT=1 ;;
    --nvim-appimage) NVIM_APPIMAGE=1 ;;
    --list) print_list; exit 0 ;;
    --help|-h) sed -n '2,20p' "$0"; exit 0 ;;
    *) ARGS+=("$a") ;;
  esac
done

[ "$NVIM_APPIMAGE" = 1 ] && nvim_appimage

if [ ${#ARGS[@]} -eq 0 ]; then
  [ "$NVIM_APPIMAGE" = 1 ] && exit 0   # flag-only invocation
  menu
elif [ "${ARGS[0]}" = remove ]; then
  if [ "${ARGS[1]:-}" = "--all" ]; then
    for c in "${KGROUPS[@]}"; do remove_group "$c"; done
  else
    [ ${#ARGS[@]} -ge 2 ] || { say "remove what? groups: ${KGROUPS[*]} (or group/item)"; exit 1; }
    for key in "${ARGS[@]:1}"; do
      if [[ "$key" == */* ]]; then say "--- remove: $key ---"; remove_item "${key%%/*}" "${key#*/}"
      else remove_group "$key"; fi
    done
  fi
elif [ "${ARGS[0]}" = all ]; then
  for c in "${DEFAULT_SET[@]}"; do install_group "$c"; done
elif [ "${ARGS[0]}" = all-work ]; then
  for c in "${DEFAULT_SET[@]}" "${WORK_SET[@]}"; do install_group "$c"; done
else
  for key in "${ARGS[@]}"; do
    if [[ "$key" == */* ]]; then say "--- install: $key ---"; install_item "${key%%/*}" "${key#*/}"
    else install_group "$key"; fi
  done
fi

say "done."
