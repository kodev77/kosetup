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
PLATFORM_PROFILE=/sys/firmware/acpi/platform_profile
GPU_TMPFILES=/etc/tmpfiles.d/kosetup-gpu-profile.conf

say() { printf '\033[1m[kosetup]\033[0m %s\n' "$*"; }

KGROUPS=(display packages shell inputrc git lazygit claude nvim nvim-work work-cli tiles retro hardware)
declare -A GDESC=(
  [display]="omarchy display: Berkeley Mono font + one-knob text scaling"
  [packages]="core CLI packages + fd/bat shims"
  [shell]="bashrc hook + shell modules"
  [inputrc]="~/.inputrc: case-insensitive completion, colored stats"
  [git]="git include.path: lg/lg2/lgf log aliases, work includeIf"
  [lazygit]="lazygit: flat file list, lg2 log format, theme-safe selection"
  [claude]="Claude Code: settings + persistent memory (skills come from omarchy; login stays per-machine)"
  [nvim]="nvim overlay (core)"
  [nvim-work]="nvim overlay (work)"
  [work-cli]="dvquery/sqlcmd venvs + stubs + work marker"
  [tiles]="TUI tiles -> ~/.local/bin"
  [retro]="retro launchers + emulators (dosbox, linapple, stella) + dasm 6502 assembler"
  [hardware]="ASUS ROG platform-profile switcher (ASUS hardware only)"
)
declare -A IDESC=(
  [display/font]="Berkeley Mono (from repository1-c) -> system monospace"
  [display/text-size]="bar 15px (~32 tall); terminal pinned 13pt; GTK apps 1.0x"
  [display/monitors]="known-monitor rules (ViewSonic/LG/laptop) — inert when not connected"
  [display/idle]="screensaver after 20min, never asks a password; auto-lock only if idle 24h"
  [display/clock]="bar clock 12-hour: Tuesday 9:36 PM"
  [display/libre-icons]="LibreOffice toolbar/sidebar icons -> small (HiDPI auto-pick fix)"
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
  [work-cli/az]="Azure CLI (az login / az functionapp ...)"
  [work-cli/func]="Azure Functions Core Tools (func start)"
  [work-cli/dotnet]="dotnet SDK, ASP.NET packs, Artifacts credprovider, dev-cert trust (JobTracker)"
  [work-cli/edge-fw]="ufw: allow docker containers -> host edge dev ports (5000/5002/5100/6000)"
  [work-cli/teams]="teams-for-linux: Teams with REAL desktop notifications + tray"
  [work-cli/outlook]="Outlook as an omarchy web app (app-mode window + launcher entry)"
  [retro/simcity]="simcity-1989/1994/2000"
  [retro/apple2]="apple2-run + zork launcher + linapple configs"
  [retro/rogue-dos]="DOS Rogue via dosbox"
  [retro/arcade1]="ARCADE1 cab CIFS mount/umount"
  [hardware/gpu-profile]="gpu-profile -> ~/.local/bin (quiet/balanced/performance)"
  [hardware/gpu-profile-perms]="boot hook: platform_profile writable by group video"
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

# AUR packages (packages/aur.list) — pacman machines with yay only. They join
# the [packages] group as ordinary items: pkg_present sees them once installed,
# and removal goes through the same recorded-set pacman path.
aur_names() {
  [ "$PM" = pacman ] || return 0
  grep -vE '^\s*(#|$)' "$REPO/packages/aur.list" 2>/dev/null || true
}

is_aur_pkg() { aur_names | grep -qxF "$1"; }

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

# --- hardware detection ------------------------------------------------------
# The hardware/ items drive /sys/firmware/acpi/platform_profile, which the
# asus-wmi driver exposes on ASUS ROG machines. Installing them anywhere else
# just puts a gpu-profile in ~/.local/bin that can only ever print an error, so
# both the group and the individual items refuse up front. Note that REMOVAL is
# deliberately NOT gated — a machine that has them must be able to shed them
# even if the hardware or the driver changed underneath.

hw_vendor() { cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo unknown; }

hw_skip_reason() { # echoes why hardware/ can't install here; empty = it can
  case "$(hw_vendor)" in
    ASUS*|ASUSTeK*) ;;
    *) echo "not ASUS hardware (DMI vendor: $(hw_vendor))"; return ;;
  esac
  [ -e "$PLATFORM_PROFILE" ] || echo "no $PLATFORM_PROFILE (asus-wmi not exposing it)"
}

asus_hardware() { [ -z "$(hw_skip_reason)" ]; }

# --- omarchy display: font + text scaling ------------------------------------
# Ported from komarchy group 005 (Berkeley Mono into waybar/fontconfig/ghostty)
# onto the CURRENT omarchy generation, where the old per-app patching is two
# stock commands: `omarchy font set` (fontconfig monospace alias + terminals +
# Quickshell bar) and `omarchy display text size` (shell [font] base-size in
# ~/.config/omarchy/shell.toml + GTK text-scaling-factor + terminal pt, all in
# lockstep; the bar's height scales with base-size by itself). 15px reproduces
# the old waybar numbers: bar ~32px, ~11pt font.
#
# The terminal is deliberately DECOUPLED from that knob: 15px maps to an 11pt
# terminal, but the old setup ran the terminal at 13 and that stays the
# preference — so pin_terminal_size re-pins every terminal config to
# DISPLAY_TERMINAL_PT after any omarchy command that rewrites sizes.
#
# ORDER MATTERS: `omarchy font set` rewrites foot.ini with a hardcoded
# `:size=9`, and `omarchy display text size` rewrites terminals to the coupled
# pt. items_of lists font BEFORE text-size for the group install, the font
# item re-applies the recorded size afterwards, and both paths finish with
# pin_terminal_size so the 13pt override always lands last.
DISPLAY_TEXT_SIZE=15
DISPLAY_TERMINAL_PT=13
# GTK text-scaling-factor, also DECOUPLED from the knob: 15px maps it to 1.27,
# which blows up Chrome/nautilus/LibreOffice UI text while the bar+terminal
# look right. Apps stay at 1.0; only the shell rides the 15px base.
DISPLAY_GTK_TEXT_SCALE=1.0
# Idle auto-lock, seconds. The shell has NO off switch here — 0 means "lock the
# moment the idle cycle starts" (secondsFromConfig treats 0 as valid, and the
# service locks immediately when lockDelaySeconds == 0), and the stay-awake
# toggle (SUPER+CTRL+I) disables the whole cycle INCLUDING the screensaver.
# So "manual lock only" = keep idle.screensaver at its default and push
# idle.lock out to a day. Qt timers cap around 24.8 days (ms in a 32-bit int);
# stay well under that.
DISPLAY_IDLE_LOCK_S=86400
DISPLAY_IDLE_SCREENSAVER_S=1200   # 20 min (shell default: 150)
# Bar clock, Qt.formatDateTime tokens: h = 12-hour no leading zero, AP = AM/PM
# (shell default: "dddd HH:mm"). NOTE right-clicking the clock cycles formats
# and PERSISTS the cycled one into shell.json — status flags that as drift.
DISPLAY_CLOCK_FMT="dddd h:mm AP"
BERKELEY_FAMILY="Berkeley Mono"
# repository1-c is a sibling clone (repos.list puts both under @ROOT)
berkeley_src() { echo "$(dirname "$REPO")/repository1-c/L3/fonts/Berkeley Mono TX-02/TX-02-ZN3QQVKK"; }

display_skip_reason() { # empty = the display items can run here
  command -v omarchy >/dev/null 2>&1 || echo "no omarchy CLI (not an omarchy machine)"
}

current_text_size() { # base-size from the machine-level shell.toml, if any
  sed -n 's/^[[:space:]]*base-size[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p' \
    "$HOME/.config/omarchy/shell.toml" 2>/dev/null | head -1
}

reapply_text_size() { # after font set stomps foot's :size=9
  local cur; cur="$(current_text_size)"
  [ -n "$cur" ] && omarchy display text size "$cur" >/dev/null
  pin_terminal_size
  pin_gtk_text_scale
}

pin_gtk_text_scale() { # override the knob's coupled GTK factor
  command -v gsettings >/dev/null 2>&1 || return 0
  gsettings set org.gnome.desktop.interface text-scaling-factor "$DISPLAY_GTK_TEXT_SCALE" 2>/dev/null || true
}

gtk_text_scale() { gsettings get org.gnome.desktop.interface text-scaling-factor 2>/dev/null; }

pin_terminal_size() { # override the coupled pt in every terminal config present
  local pt="$DISPLAY_TERMINAL_PT"
  # same files + sed shapes as omarchy-display-text-size, so the two agree
  [ -f "$HOME/.config/alacritty/alacritty.toml" ] && \
    sed -i -E "s/^size[[:space:]]*=.*/size = $pt/" "$HOME/.config/alacritty/alacritty.toml"
  if [ -f "$HOME/.config/kitty/kitty.conf" ]; then
    sed -i -E "s/^font_size[[:space:]]+.*/font_size $pt.0/" "$HOME/.config/kitty/kitty.conf"
    pkill -USR1 kitty 2>/dev/null || true
  fi
  if [ -f "$HOME/.config/ghostty/config" ]; then
    sed -i -E "s/^font-size = .*/font-size = $pt/" "$HOME/.config/ghostty/config"
    pkill -SIGUSR2 ghostty 2>/dev/null || true
  fi
  # foot has no reload signal — new windows pick it up
  [ -f "$HOME/.config/foot/foot.ini" ] && \
    sed -i -E "s/(:size=)[0-9.]+/\\1$pt/" "$HOME/.config/foot/foot.ini"
  say "display: terminal font pinned at ${pt}pt (new terminal windows)"
}

foot_size() { sed -n 's/.*:size=\([0-9.]*\).*/\1/p' "$HOME/.config/foot/foot.ini" 2>/dev/null | head -1; }

install_display_font() {
  if ! ls "$HOME/.local/share/fonts"/BerkeleyMono*.ttf >/dev/null 2>&1; then
    local src; src="$(berkeley_src)"
    if [ ! -d "$src" ]; then
      say "TODO: Berkeley Mono TTFs not found — clone repository1-c next to kosetup ($src)"
      return 0
    fi
    mkdir -p "$HOME/.local/share/fonts"
    cp "$src"/*.ttf "$HOME/.local/share/fonts/"
    fc-cache -f >/dev/null 2>&1
    say "display: Berkeley Mono TTFs installed to ~/.local/share/fonts"
  fi
  if [ "$(omarchy font current 2>/dev/null)" = "$BERKELEY_FAMILY" ]; then
    say "display: font already $BERKELEY_FAMILY"
  else
    omarchy font set "$BERKELEY_FAMILY" >/dev/null 2>&1
    say "display: monospace font -> $BERKELEY_FAMILY"
  fi
  # Unconditional, even on the already-branch: a bare `omarchy font set` run
  # outside kosetup stomps foot to :size=9, and re-running this item is the
  # natural way to repair that — the early return used to leave the stomp.
  reapply_text_size
}

remove_display_font() {
  # Back to the omarchy default family; TTFs stay in ~/.local/share/fonts
  # (delete manually to purge) — mirrors the venv-keep behaviour of work-cli.
  if [ "$(omarchy font current 2>/dev/null)" = "$BERKELEY_FAMILY" ]; then
    omarchy font set "JetBrainsMono Nerd Font" >/dev/null 2>&1
    reapply_text_size
    say "display: font restored to JetBrainsMono Nerd Font (TTFs kept on disk)"
  fi
}

MONITORS_LUA="$HOME/.config/hypr/monitors.lua"
SHELL_JSON="$HOME/.config/omarchy/shell.json"

shell_json_idle() { jq -r ".idle.$1 // empty" "$SHELL_JSON" 2>/dev/null; }

shell_json_clock_fmt() {
  jq -r '[.bar.layout[][] | select(.id == "omarchy.clock") | .format] | first // empty' \
    "$SHELL_JSON" 2>/dev/null
}

set_clock_fmt() { # <qt-format> — rewrites only the omarchy.clock entry's format
  [ -f "$SHELL_JSON" ] || { mkdir -p "$(dirname "$SHELL_JSON")"; cp "${OMARCHY_PATH:-/usr/share/omarchy}/config/omarchy/shell.json" "$SHELL_JSON"; }
  local tmp; tmp="$(mktemp)"
  jq --arg f "$1" '.bar.layout |= map_values(map(if .id == "omarchy.clock" then .format = $f else . end))' \
    "$SHELL_JSON" > "$tmp" && mv "$tmp" "$SHELL_JSON"
}

# LibreOffice pins its toolbar/sidebar/notebookbar icon size from HiDPI
# auto-detection unless SymbolSet & friends are set (value 0 = small). Ported
# from komarchy 006-00029. The file is REWRITTEN BY LIBREOFFICE ON EXIT, so
# both paths refuse while soffice runs — an edit made now would be lost.
LIBRE_XCU="$HOME/.config/libreoffice/4/user/registrymodifications.xcu"

libre_running() { pgrep -x soffice.bin >/dev/null 2>&1; }

install_libre_icons() {
  [ -f "$LIBRE_XCU" ] || { say "TODO: open LibreOffice once to create its config, then re-run display/libre-icons"; return 0; }
  libre_running && { say "WARN: LibreOffice is running — close it, then re-run display/libre-icons (it rewrites its config on exit)"; return 0; }
  if grep -q 'oor:name="SymbolSet"' "$LIBRE_XCU"; then say "display: LibreOffice icon size already pinned"; return 0; fi
  sed -i '/<\/oor:items>/i \
<!-- BEGIN ko kosetup libre-icons -->\
<item oor:path="/org.openoffice.Office.Common/Misc"><prop oor:name="SymbolSet" oor:op="fuse"><value>0</value></prop></item>\
<item oor:path="/org.openoffice.Office.Common/Misc"><prop oor:name="SidebarIconSize" oor:op="fuse"><value>0</value></prop></item>\
<item oor:path="/org.openoffice.Office.Common/Misc"><prop oor:name="NotebookbarIconSize" oor:op="fuse"><value>0</value></prop></item>\
<!-- END ko kosetup libre-icons -->' "$LIBRE_XCU"
  say "display: LibreOffice icons pinned to small"
}

remove_libre_icons() {
  [ -f "$LIBRE_XCU" ] || return 0
  libre_running && { say "WARN: LibreOffice is running — close it, then re-run remove display/libre-icons"; return 0; }
  # strip our marker block if still intact, then any reserialized single-line
  # forms of the three properties (LO rewrites items in its own formatting)
  sed -i '/<!-- BEGIN ko kosetup libre-icons -->/,/<!-- END ko kosetup libre-icons -->/d' "$LIBRE_XCU"
  sed -i '/oor:name="SymbolSet"/d; /oor:name="SidebarIconSize"/d; /oor:name="NotebookbarIconSize"/d' "$LIBRE_XCU"
  say "display: LibreOffice icon size back to automatic"
}

set_idle() { # <screensaver-s> <lock-s> — surgical on .idle only; hot-reloads on save
  [ -f "$SHELL_JSON" ] || { mkdir -p "$(dirname "$SHELL_JSON")"; cp "${OMARCHY_PATH:-/usr/share/omarchy}/config/omarchy/shell.json" "$SHELL_JSON"; }
  local tmp; tmp="$(mktemp)"
  jq --argjson ss "$1" --argjson lk "$2" '.idle.screensaver = $ss | .idle.lock = $lk' \
    "$SHELL_JSON" > "$tmp" && mv "$tmp" "$SHELL_JSON"
}

hypr_validate() { # per omarchy guidance: reload, then configerrors must be clean
  command -v hyprctl >/dev/null 2>&1 || { say "NOTE: no hyprctl — rules apply on next Hyprland start"; return 0; }
  hyprctl reload >/dev/null 2>&1 || true
  local errs; errs="$(hyprctl configerrors 2>/dev/null)"
  case "$errs" in
    ''|*"no errors"*) say "display: hyprland reloaded, config clean" ;;
    *) say "WARN: hyprctl configerrors reports:"; printf '%s\n' "$errs" | sed 's/^/  /' ;;
  esac
}

install_display_monitors() {
  mkdir -p "$HOME/.config/hypr"
  link "$REPO/config/hypr/monitors-kosetup.lua" "$HOME/.config/hypr/monitors-kosetup.lua"
  touch "$MONITORS_LUA"
  if ! grep -q '^-- --- BEGIN kosetup monitors ---$' "$MONITORS_LUA"; then
    cat >> "$MONITORS_LUA" <<'LUA'

-- --- BEGIN kosetup monitors ---
-- pcall: if the kosetup symlink is ever removed out-of-band, the require
-- fails soft instead of taking the whole Hyprland config down with it.
pcall(require, "hypr.monitors-kosetup")
-- --- END kosetup monitors ---
LUA
    say "display: monitors.lua — kosetup require block added"
  fi
  hypr_validate
}

remove_display_monitors() {
  if grep -q '^-- --- BEGIN kosetup monitors ---$' "$MONITORS_LUA" 2>/dev/null; then
    sed -i '/^-- --- BEGIN kosetup monitors ---$/,/^-- --- END kosetup monitors ---$/d' "$MONITORS_LUA"
    say "display: monitors.lua — kosetup require block removed"
  fi
  unlink_repo "$HOME/.config/hypr/monitors-kosetup.lua"
  hypr_validate
}


install_gpu_perms() { # make platform_profile group-writable at every boot
  if [ ! -d /etc/tmpfiles.d ]; then
    say "TODO: no /etc/tmpfiles.d here — run $REPO/hardware/50-gpu-profile-perms"
    say "      at boot instead (that script is the /etc/rc.local route)"
    return 0
  fi
  printf 'z %s 0664 root video -\n' "$PLATFORM_PROFILE" | sudo tee "$GPU_TMPFILES" >/dev/null
  sudo systemd-tmpfiles --create "$GPU_TMPFILES" >/dev/null 2>&1 || true
  say "hardware: boot perms installed ($GPU_TMPFILES)"
  id -nG | tr ' ' '\n' | grep -qx video \
    || say "TODO: add yourself to the video group: sudo usermod -aG video $USER (re-login)"
}

remove_gpu_perms() {
  if [ -f "$GPU_TMPFILES" ]; then
    sudo rm -f "$GPU_TMPFILES"; say "removed: $GPU_TMPFILES"
  fi
}

# --- item registry -----------------------------------------------------------

items_of() {
  case "$1" in
    display)   printf '%s\n' font text-size monitors idle clock libre-icons ;;   # font FIRST — see ORDER MATTERS above
    packages)  pkg_names; aur_names ;;
    shell)     printf '%s\n' aliases fzf-nav jcurl nnn prompt ;;
    nvim)      printf '%s\n' lsp-extra db2 dasm ;;
    nvim-work) printf '%s\n' dadbod dap lsp-work ;;
    work-cli)  printf '%s\n' dvquery sqlcmd az func dotnet edge-fw teams outlook ;;
    tiles)     printf '%s\n' sys-tile snake-tile clock-tile rogue-tile ;;
    retro)     printf '%s\n' simcity apple2 rogue-dos arcade1 ;;
    hardware)  printf '%s\n' gpu-profile gpu-profile-perms ;;
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
      printf '%s\t%s\n' "$REPO/bin/zork" "$HOME/.local/bin/zork"
      printf '%s\t%s\n' "$REPO/config/linapple" "$HOME/.config/linapple" ;;
    retro/rogue-dos)
      printf '%s\t%s\n' "$REPO/bin/rogue-dos" "$HOME/.local/bin/rogue-dos" ;;
    retro/arcade1)
      printf '%s\t%s\n' "$REPO/bin/arcade1-mount" "$HOME/.local/bin/arcade1-mount"
      printf '%s\t%s\n' "$REPO/bin/arcade1-umount" "$HOME/.local/bin/arcade1-umount" ;;
    hardware/gpu-profile)
      printf '%s\t%s\n' "$REPO/hardware/gpu-profile" "$HOME/.local/bin/gpu-profile" ;;
  esac
}

# --- shell module enable/disable ---------------------------------------------

# Detect via the BEGIN marker, not the source line: the old check grepped for
# the literal 'kosetup/shell/init.bash', so it only matched when the clone was
# named exactly 'kosetup' and reported "not installed" for any other directory
# name — re-adding the hook and re-seeding the module list on every run. The
# marker is what remove_group already keys on, so the two now agree.
shell_hook_present() { grep -q '^# --- BEGIN kosetup ---$' "$HOME/.bashrc" 2>/dev/null; }

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
    display)
      case "$i" in
        font)      [ "$(omarchy font current 2>/dev/null)" = "$BERKELEY_FAMILY" ] ;;
        text-size) [ "$(current_text_size)" = "$DISPLAY_TEXT_SIZE" ] && \
                   { [ ! -f "$HOME/.config/foot/foot.ini" ] || [ "$(foot_size)" = "$DISPLAY_TERMINAL_PT" ]; } && \
                   { ! command -v gsettings >/dev/null 2>&1 || [ "$(gtk_text_scale)" = "$DISPLAY_GTK_TEXT_SCALE" ]; } ;;
        monitors)  points_into_repo "$HOME/.config/hypr/monitors-kosetup.lua" && \
                   grep -q '^-- --- BEGIN kosetup monitors ---$' "$MONITORS_LUA" 2>/dev/null ;;
        idle)      [ "$(shell_json_idle lock)" = "$DISPLAY_IDLE_LOCK_S" ] && \
                   [ "$(shell_json_idle screensaver)" = "$DISPLAY_IDLE_SCREENSAVER_S" ] ;;
        clock)     [ "$(shell_json_clock_fmt)" = "$DISPLAY_CLOCK_FMT" ] ;;
        libre-icons) # match the property, not our marker: LO reserializes the
                     # file on every exit and only the settings are guaranteed
                     # to survive, in its own formatting.
                     grep -q 'oor:name="SymbolSet"' "$LIBRE_XCU" 2>/dev/null ;;
      esac ;;
    packages) pkg_present "$i" ;;
    shell)    shell_hook_present && shell_mod_enabled "$i" ;;
    work-cli)
      case "$i" in
        az)   command -v az >/dev/null 2>&1 ;;
        func) command -v func >/dev/null 2>&1 ;;
        dotnet) dotnet --list-sdks 2>/dev/null | grep -q . && \
                [ -f "$HOME/.nuget/plugins/netcore/CredentialProvider.Microsoft/CredentialProvider.Microsoft.dll" ] ;;
        edge-fw) [ -f "$STATE_DIR/edge-fw" ] ;;
        teams)   command -v teams-for-linux >/dev/null 2>&1 ;;
        outlook) [ -f "$HOME/.local/share/applications/Outlook.desktop" ] ;;
        *) [ -f "$HOME/.local/bin/$i" ] && grep -q 'kosetup exec stub' "$HOME/.local/bin/$i" 2>/dev/null ;;
      esac ;;
    nvim|nvim-work|tiles|retro)
      first="$(pairs_of "$g" "$i" | head -1 | cut -f2)"
      [ -n "$first" ] && points_into_repo "$first" ;;
    hardware)
      case "$i" in
        gpu-profile)       points_into_repo "$HOME/.local/bin/gpu-profile" ;;
        gpu-profile-perms) [ -f "$GPU_TMPFILES" ] ;;
      esac ;;
    *) return 1 ;;
  esac
}

group_status() { # echoes 'x', '~' or ' '
  local g="$1" i inst=0 tot=0
  case "$g" in
    inputrc) points_into_repo "$HOME/.inputrc" && echo x || echo ' '; return ;;
    lazygit) points_into_repo "$HOME/.config/lazygit/config.yml" && echo x || echo ' '; return ;;
    claude)
      points_into_repo "$HOME/.claude/settings.json" && \
      points_into_repo "$HOME/.claude/projects/-home-ko/memory" && echo x || echo ' '; return ;;
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
    display)
      local why; why="$(display_skip_reason)"
      if [ -n "$why" ]; then say "skip display/$i — $why"; return 0; fi
      case "$i" in
        font)      install_display_font ;;
        text-size) omarchy display text size "$DISPLAY_TEXT_SIZE" >/dev/null
                   say "display: text size -> ${DISPLAY_TEXT_SIZE}px (bar ~32)"
                   pin_terminal_size
                   pin_gtk_text_scale
                   say "display: GTK apps pinned at 1.0x text scale" ;;
        monitors)  install_display_monitors ;;
        idle)      set_idle "$DISPLAY_IDLE_SCREENSAVER_S" "$DISPLAY_IDLE_LOCK_S"
                   # restart, don't hot-reload: the shell's IdleMonitor goes DEAD
                   # when its timeout changes at runtime (observed: armed 150s at
                   # boot, config applied later, then six idle hours produced zero
                   # idle events). A fresh shell arms correctly from the file.
                   omarchy restart shell >/dev/null 2>&1 || true
                   say "display: screensaver after $((DISPLAY_IDLE_SCREENSAVER_S/60))min, auto-lock after $((DISPLAY_IDLE_LOCK_S/3600))h idle (SUPER+CTRL+L to lock now; shell restarted)" ;;
        clock)     set_clock_fmt "$DISPLAY_CLOCK_FMT"
                   say "display: bar clock format -> $DISPLAY_CLOCK_FMT" ;;
        libre-icons) install_libre_icons ;;
      esac ;;
    packages)
      if pkg_present "$i"; then say "package present: $i"
      elif is_aur_pkg "$i"; then
        if command -v yay >/dev/null 2>&1; then
          yay -S --needed --noconfirm "$i" && pkg_record "$i" || say "WARN: $i (AUR) not installed"
        else
          say "TODO: $i is AUR-only — install yay, then: yay -S $i"
        fi
      else pkg_install_one "$i" && pkg_record "$i" || say "WARN: $i not installed"; fi
      pkg_shims ;;
    shell)
      # Modules are opt-OUT: init.bash treats an ABSENT shell-disabled list as
      # "every module on". So on the first shell item installed to a machine,
      # adding the hook alone would silently enable all five — picking one item
      # in the menu installed the whole group. Seed the list with everything
      # first, so enabling one really does mean one. Keyed on the hook being
      # absent, which is what distinguishes a first install from a later
      # single-item add on top of a group install (group install rm's the list
      # to mean "all on", and must stay that way).
      if ! shell_hook_present; then
        mkdir -p "$STATE_DIR"; items_of shell > "$SHELL_DISABLED"
      fi
      shell_hook_add; shell_mod_enable "$i"
      [ "$i" = nnn ] && { mkdir -p "$HOME/.config/nnn"; link "$REPO/config/nnn.tmux.conf" "$HOME/.config/nnn/nnn.tmux.conf"; } || true ;;
    work-cli) install_workcli_tool "$i" ;;
    nvim|nvim-work)
      nvim_base_ok || return 0
      pairs_of "$g" "$i" | link_pairs ;;
    tiles|retro)
      mkdir -p "$HOME/.local/bin"
      pairs_of "$g" "$i" | link_pairs ;;
    hardware)
      local why; why="$(hw_skip_reason)"
      if [ -n "$why" ]; then say "skip hardware/$i — $why"; return 0; fi
      case "$i" in
        gpu-profile)
          mkdir -p "$HOME/.local/bin"
          pairs_of "$g" "$i" | link_pairs ;;
        gpu-profile-perms) install_gpu_perms ;;
      esac ;;
  esac
}

remove_item() { # <group> <item>
  local g="$1" i="$2"
  case "$g" in
    display)  # needs the omarchy CLI; without it nothing was installed anyway
      command -v omarchy >/dev/null 2>&1 || { say "display/$i: no omarchy CLI — nothing to remove"; return 0; }
      case "$i" in
        font)      remove_display_font ;;
        text-size) omarchy display text size reset >/dev/null
                   say "display: text size reset (12px / 1.0 / 9pt)" ;;
        monitors)  remove_display_monitors ;;
        idle)      set_idle 150 300   # shell defaults (Service.qml defaultScreensaver/LockSeconds)
                   omarchy restart shell >/dev/null 2>&1 || true   # same stale-monitor workaround
                   say "display: idle restored to defaults (screensaver 150s, lock 300s)" ;;
        clock)     set_clock_fmt "dddd HH:mm"   # canonical shell.json default
                   say "display: bar clock restored to 24-hour" ;;
        libre-icons) remove_libre_icons ;;
      esac ;;
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
    hardware)  # never gated on the hardware check — see hw_skip_reason
      case "$i" in
        gpu-profile)       pairs_of "$g" "$i" | unlink_pairs ;;
        gpu-profile-perms) remove_gpu_perms ;;
      esac ;;
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

install_workcli_tool() { # dvquery | sqlcmd | az | func
  local tool="$1" stub
  mkdir -p "$STATE_DIR"; touch "$STATE_DIR/work"
  # az/func are real packages, not venv-backed repo scripts — no stub, no venv.
  case "$tool" in
    az)
      if command -v az >/dev/null 2>&1; then say "work: az present"
      elif [ "$PM" = pacman ]; then
        pkg_install_one azure-cli && pkg_record azure-cli || say "WARN: azure-cli not installed"
      else
        say "TODO: az on non-Arch — needs Microsoft's apt repo or https://aka.ms/InstallAzureCLIDeb"
      fi
      command -v az >/dev/null 2>&1 && say "work: az ready (az login for RPC tenant)"
      return 0 ;;
    dotnet)
      # JobTracker (prerequisites.md) needs the .NET 10 SDK; a bare runtime/host
      # (omarchy dep) makes `dotnet clean` report "No .NET SDKs were found".
      # ASP.NET runtime + targeting pack cover the web projects.
      if dotnet --list-sdks 2>/dev/null | grep -q .; then say "work: dotnet SDK present"
      elif [ "$PM" = pacman ]; then
        for _p in dotnet-sdk aspnet-runtime aspnet-targeting-pack; do
          pkg_install_one "$_p" && pkg_record "$_p" || say "WARN: $_p not installed"
        done
      else
        say "TODO: dotnet SDK on non-Arch — dotnet-install.sh --channel 10.0 --install-dir ~/.dotnet (work.bash picks up DOTNET_ROOT)"
      fi
      dotnet --list-sdks 2>/dev/null | grep -q . && say "work: dotnet ready ($(dotnet --list-sdks | head -1 | cut -d' ' -f1))"
      # Azure Artifacts credential provider (user-level, ~/.nuget/plugins):
      # without it, restore against the private OilData.Artifacts feed 401s.
      # Plain `dotnet restore` runs NON-INTERACTIVE by design, so the provider
      # may only use cached tokens — hence the TODO: one interactive restore
      # per machine to do the Entra device-code sign-in and warm the cache.
      if [ ! -f "$HOME/.nuget/plugins/netcore/CredentialProvider.Microsoft/CredentialProvider.Microsoft.dll" ]; then
        curl -fsSL https://aka.ms/install-artifacts-credprovider.sh | bash >/dev/null 2>&1 \
          && say "work: Azure Artifacts credential provider installed" \
          || say "WARN: credprovider install failed — retry: curl -fsSL https://aka.ms/install-artifacts-credprovider.sh | bash"
      fi
      [ -f "$HOME/.local/share/MicrosoftCredentialProvider/SessionTokenCache.dat" ] \
        || say "TODO: first restore must be interactive: cd <work-repo> && dotnet restore --interactive (device-code sign-in, then plain restore works)"
      # HTTPS dev-cert trust. Two client families, two stores:
      #   * Chrome/NSS reads ~/.pki/nssdb — on a fresh machine that db does not
      #     even exist, so `dev-certs --trust` silently fails into it ("trusted
      #     by some clients but not others") and Chrome shows Not secure AND
      #     withholds password-save prompts on the dev sites. Initialize it
      #     first, then trust.
      #   * OpenSSL clients (curl, service-to-service HttpClient) need
      #     SSL_CERT_DIR to include ~/.aspnet/dev-certs/trust — exported by
      #     shell/work.bash, so that half needs no action here.
      if command -v certutil >/dev/null 2>&1; then
        certutil -d sql:"$HOME/.pki/nssdb" -L >/dev/null 2>&1 \
          || { mkdir -p "$HOME/.pki/nssdb"; certutil -d sql:"$HOME/.pki/nssdb" -N --empty-password; say "work: initialized Chrome NSS store (~/.pki/nssdb)"; }
        if ! certutil -d sql:"$HOME/.pki/nssdb" -L 2>/dev/null | grep -q aspnetcore-localhost; then
          dotnet dev-certs https --trust >/dev/null 2>&1 || true
          certutil -d sql:"$HOME/.pki/nssdb" -L 2>/dev/null | grep -q aspnetcore-localhost \
            && say "work: ASP.NET dev cert trusted for Chrome (restart Chrome to see the padlock)" \
            || say "WARN: dev cert did not land in NSS — run: dotnet dev-certs https --trust"
        else
          say "work: ASP.NET dev cert already trusted in NSS"
        fi
      else
        say "TODO: certutil missing (pacman: nss) — needed to trust the dev cert for Chrome"
      fi
      return 0 ;;
    outlook)
      # Outlook stays a WEB app, unlike Teams: prospect-mail (the community
      # wrapper) is near-abandoned, native clients fight Entra auth for a
      # worse Outlook, and meeting/chat urgency is already covered by
      # teams-for-linux. omarchy-webapp-install is the scriptable equivalent
      # of Chrome's "install app": app-mode window + desktop launcher entry.
      if ! command -v omarchy-webapp-install >/dev/null 2>&1; then
        say "TODO: outlook web app — omarchy only (elsewhere: browser PWA of outlook.cloud.microsoft)"
      elif [ -f "$HOME/.local/share/applications/Outlook.desktop" ]; then
        say "work: Outlook web app already installed"
      else
        omarchy-webapp-install "Outlook" "https://outlook.cloud.microsoft/mail/" \
          "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/microsoft-outlook.png" >/dev/null \
          && say "work: Outlook web app installed (launcher: Outlook)" \
          || say "WARN: omarchy-webapp-install failed for Outlook"
      fi
      return 0 ;;
    teams)
      # teams-for-linux over the Chrome PWA on purpose: Chrome renders its own
      # notification popups (invisible to the omarchy shell's notification
      # daemon — no history, no DND) and goes silent when the window closes.
      # The Electron app notifies via libnotify and persists in the tray.
      if command -v teams-for-linux >/dev/null 2>&1; then say "work: teams-for-linux present"
      elif [ "$PM" = pacman ] && command -v yay >/dev/null 2>&1; then
        yay -S --needed --noconfirm teams-for-linux \
          || say "WARN: teams-for-linux install failed — retry: yay -S teams-for-linux"
      else
        say "TODO: teams-for-linux — arch: yay -S teams-for-linux; elsewhere see github.com/IsmaelMartinez/teams-for-linux"
      fi
      return 0 ;;
    edge-fw)
      # omarchy runs ufw; published container ports work, but container->HOST
      # traffic (the edge nginx proxying to identity/sse/ui services) hits the
      # INPUT chain and hangs as upstream timeouts. Allow docker's address
      # space to the JobTracker edge dev ports only. State marker instead of
      # `ufw status` for the [x] check — reading ufw needs root.
      if ! command -v ufw >/dev/null 2>&1 || ! systemctl is-active -q ufw 2>/dev/null; then
        say "work: ufw not active — no container->host firewall rule needed"
        mkdir -p "$STATE_DIR"; touch "$STATE_DIR/edge-fw"
      elif [ -f "$STATE_DIR/edge-fw" ]; then
        say "work: edge firewall rule already applied"
      else
        sudo ufw allow proto tcp from 172.16.0.0/12 to any port 5000,5002,5100,6000 \
          comment 'JobTracker edge dev: containers -> host services' \
          && { mkdir -p "$STATE_DIR"; touch "$STATE_DIR/edge-fw"; say "work: ufw rule added (docker subnets -> 5000,5002,5100,6000)"; } \
          || say "WARN: ufw rule failed — run manually with sudo"
      fi
      return 0 ;;
    func)
      if command -v func >/dev/null 2>&1; then say "work: func present"
      elif [ "$PM" = pacman ] && command -v yay >/dev/null 2>&1; then
        # -bin: prebuilt; the source PKGBUILD pulls the whole dotnet build chain
        yay -S --needed --noconfirm azure-functions-core-tools-bin \
          || say "WARN: func install failed — retry: yay -S azure-functions-core-tools-bin"
      else
        say "TODO: func — arch: yay -S azure-functions-core-tools-bin; elsewhere npm i -g azure-functions-core-tools@4"
      fi
      command -v func >/dev/null 2>&1 && say "work: func ready (func start)"
      return 0 ;;
  esac
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
  case "$tool" in
    az)
      if grep -qxF azure-cli "$PKG_RECORD" 2>/dev/null; then
        sudo pacman -Rns --noconfirm azure-cli || true
        grep -vxF azure-cli "$PKG_RECORD" > "$PKG_RECORD.tmp" || true; mv "$PKG_RECORD.tmp" "$PKG_RECORD"
        say "work: azure-cli removed (~/.azure login state kept — delete manually to purge)"
      else
        say "work: azure-cli was not installed by kosetup — leaving it alone"
      fi
      return 0 ;;
    outlook)
      # || true: as the final command of an && chain a nonzero exit here
      # would trip set -e and kill the whole removal run
      command -v omarchy-webapp-remove >/dev/null 2>&1 && omarchy-webapp-remove "Outlook" 2>/dev/null || true
      rm -f "$HOME/.local/share/applications/Outlook.desktop"
      say "work: Outlook web app removed"
      return 0 ;;
    teams)
      if pacman -Q teams-for-linux >/dev/null 2>&1; then
        sudo pacman -Rns --noconfirm teams-for-linux || true
        say "work: teams-for-linux removed (~/.config/teams-for-linux kept)"
      fi
      return 0 ;;
    edge-fw)
      if [ -f "$STATE_DIR/edge-fw" ] && command -v ufw >/dev/null 2>&1; then
        sudo ufw delete allow proto tcp from 172.16.0.0/12 to any port 5000,5002,5100,6000 2>/dev/null || true
        say "work: edge firewall rule removed"
      fi
      rm -f "$STATE_DIR/edge-fw"
      return 0 ;;
    dotnet)
      local _p
      for _p in dotnet-sdk aspnet-targeting-pack aspnet-runtime; do
        if grep -qxF "$_p" "$PKG_RECORD" 2>/dev/null; then
          sudo pacman -Rns --noconfirm "$_p" || true
          grep -vxF "$_p" "$PKG_RECORD" > "$PKG_RECORD.tmp" || true; mv "$PKG_RECORD.tmp" "$PKG_RECORD"
          say "work: $_p removed"
        else
          say "work: $_p was not installed by kosetup — leaving it alone"
        fi
      done
      return 0 ;;
    func)
      if pacman -Q azure-functions-core-tools-bin >/dev/null 2>&1; then
        sudo pacman -Rns --noconfirm azure-functions-core-tools-bin || true
        say "work: azure-functions-core-tools-bin removed"
      fi
      return 0 ;;
  esac
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
  local g="$1" i why
  say "--- install: $g ---"
  case "$g" in
    inputrc) link "$REPO/config/inputrc" "$HOME/.inputrc"; return ;;
    lazygit)
      mkdir -p "$HOME/.config/lazygit"
      link "$REPO/config/lazygit.yml" "$HOME/.config/lazygit/config.yml"; return ;;
    claude)
      # Settings, user skills, and MEMORY live in the repo; ~/.claude points at
      # them. Memory is written by Claude during sessions, so new memories show
      # up as repo diffs to review/commit — same flow as any other change.
      # .credentials.json (OAuth) stays machine-local on purpose: run `claude`
      # and sign in once per machine.
      # NOTE: ~/.claude/skills is deliberately NOT ours — omarchy installs
      # those as symlinks into /usr/share/omarchy; owning them would fight it.
      mkdir -p "$HOME/.claude" "$HOME/.claude/projects/-home-ko"
      link "$REPO/claude/settings.json" "$HOME/.claude/settings.json"
      link "$REPO/claude/memory"        "$HOME/.claude/projects/-home-ko/memory"
      return ;;
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
    hardware)
      why="$(hw_skip_reason)"
      if [ -n "$why" ]; then say "hardware: skipped — $why"; return 0; fi ;;
    display)
      why="$(display_skip_reason)"
      if [ -n "$why" ]; then say "display: skipped — $why"; return 0; fi ;;
  esac
  while read -r i; do [ -n "$i" ] && install_item "$g" "$i"; done < <(items_of "$g")
  # `if` rather than `[ ... ] && retro_emulators`: as the LAST statement of this
  # function the && form returns 1 for every non-retro group, and under set -e
  # that killed the caller — `install.sh all` stopped dead after `packages`.
  if [ "$g" = retro ]; then retro_emulators; fi
}

retro_emulators() { # the launchers need dosbox-staging (simcity/rogue-dos) + linapple (apple2-run)
  if ! command -v dosbox-staging >/dev/null 2>&1 && ! command -v dosbox >/dev/null 2>&1; then
    case "$PM" in
      # dosbox-staging left the official Arch repos (extra/dosbox is the 2010
      # SVN DOSBox — too old for these confs, and rogue-dos needs staging
      # outright); it lives in the AUR now, so take the yay route like linapple.
      pacman) if command -v yay >/dev/null 2>&1; then
                # source build first; the 0.83 RC has a racy build graph that
                # can fail randomly under parallel ninja — fall back to the
                # prebuilt stable dosbox-staging-bin rather than TODO-ing out.
                yay -S --needed --noconfirm dosbox-staging \
                  || yay -S --needed --noconfirm dosbox-staging-bin \
                  || say "TODO: dosbox-staging AND -bin both failed — retry: yay -S dosbox-staging-bin"
              else
                say "TODO: dosbox-staging is AUR-only on Arch — install yay, then: yay -S dosbox-staging-bin"
              fi ;;
      apt)    sudo apt-get install -y dosbox-staging \
                || say "TODO: dosbox-staging not in apt — tarball to ~/.local/opt + symlink ~/.local/bin/dosbox-staging" ;;
      *)      say "TODO: install dosbox-staging for the simcity/rogue-dos launchers" ;;
    esac
  fi
  # Atari 2600 dev loop (repository1-c "atari noob" projects + nvim/dasm item):
  # stella = the emulator (official repo); dasm = the 6502 assembler (AUR).
  if ! command -v stella >/dev/null 2>&1 && [ "$PM" = pacman ]; then
    pkg_install_one stella && pkg_record stella || say "TODO: install stella (Atari 2600 emulator)"
  fi
  if ! command -v dasm >/dev/null 2>&1; then
    if [ "$PM" = pacman ] && command -v yay >/dev/null 2>&1; then
      yay -S --needed --noconfirm dasm || say "TODO: dasm AUR install failed — yay -S dasm"
    else
      say "TODO: dasm assembler — arch: yay -S dasm; elsewhere build from dasm-assembler.github.io"
    fi
  fi
  if ! command -v linapple >/dev/null 2>&1; then
    if command -v yay >/dev/null 2>&1; then
      yay -S --needed --noconfirm linapple-git \
        || say "TODO: linapple install failed — build the linapple repo clone (make && sudo make install)"
    else
      say "TODO: linapple for apple2-run — arch: yay -S linapple-git; elsewhere build the linapple repo clone (make && sudo make install)"
    fi
  fi
  # linapple-git's PKGBUILD has a doubled prefix bug: the binary lands at
  # /usr/usr/local/bin/linapple, which is on nobody's PATH — the package
  # installs "successfully" and linapple still can't be found. Bridge it.
  if ! command -v linapple >/dev/null 2>&1 && [ -x /usr/usr/local/bin/linapple ]; then
    mkdir -p "$HOME/.local/bin"
    ln -sfn /usr/usr/local/bin/linapple "$HOME/.local/bin/linapple"
    say "retro: linapple bridged to ~/.local/bin (AUR package installs to /usr/usr/local/bin)"
  fi
}

remove_group() {
  local g="$1" i
  say "--- remove: $g ---"
  case "$g" in
    inputrc) unlink_repo "$HOME/.inputrc"; return ;;
    lazygit) unlink_repo "$HOME/.config/lazygit/config.yml"; return ;;
    claude)
      unlink_repo "$HOME/.claude/settings.json"
      unlink_repo "$HOME/.claude/projects/-home-ko/memory"
      return ;;
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

# hardware is safe to list here: it self-skips on non-ASUS machines.
DEFAULT_SET=(display packages shell inputrc git lazygit claude nvim tiles retro hardware)
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
