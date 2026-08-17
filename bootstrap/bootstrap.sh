#!/usr/bin/env bash
# kosetup bootstrap — run from the USB stick on a FRESH machine:
#
#   bash /media/*/kosetup/bootstrap.sh
#
# Installs SSH keys + config from the stick, pins forge host keys, clones the
# repos.list manifest, places secret files, sets git identity, then offers to
# launch the kosetup installer. Idempotent — safe to re-run; never overwrites
# an existing key/secret on the machine.
#
# This script contains NO secrets (it is tracked in the kosetup repo and
# copied to the stick); the private material lives beside it on the stick:
#   ssh/kosetup_ed25519(.pub), ssh/kosetup_rsa(.pub)   forge keys
#   ssh/known_hosts                                    pinned host keys
#   ssh_config                                         Host blocks (no secrets)
#   secrets/gitconfig.work, secrets/connections.json, secrets/arcade1.cred
#   repos.list                                         what to clone where
set -euo pipefail
USB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

say() { printf '\033[1m[bootstrap]\033[0m %s\n' "$*"; }

GIT_NAME="kodev"
GIT_EMAIL="kjortego@gmail.com"

# --- 1. chicken-and-egg deps -------------------------------------------------
if ! command -v git >/dev/null 2>&1 || ! command -v ssh >/dev/null 2>&1; then
  say "installing git + openssh"
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update && sudo apt-get install -y git openssh-client
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sy --needed --noconfirm git openssh
  else
    say "ERROR: no apt/pacman — install git and ssh manually"; exit 1
  fi
fi

# --- 2. SSH keys (FAT32 can't hold perms — fix after copy) -------------------
mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
for k in "$USB"/ssh/kosetup_*; do
  [ -e "$k" ] || continue
  b="$(basename "$k")"
  if [ ! -f "$HOME/.ssh/$b" ]; then
    cp "$k" "$HOME/.ssh/$b"; say "key installed: $b"
  fi
done
chmod 600 "$HOME/.ssh"/kosetup_* 2>/dev/null || true
chmod 644 "$HOME/.ssh"/kosetup_*.pub 2>/dev/null || true

# --- 3. ssh config include + pinned host keys --------------------------------
install -m 600 "$USB/ssh_config" "$HOME/.ssh/kosetup_config"
touch "$HOME/.ssh/config"; chmod 600 "$HOME/.ssh/config"
if ! grep -q '^Include kosetup_config$' "$HOME/.ssh/config"; then
  # Include must precede any Host block, so prepend
  sed -i '1i Include kosetup_config' "$HOME/.ssh/config"
  say "ssh config: Include kosetup_config added"
fi
if [ -f "$USB/ssh/known_hosts" ]; then
  touch "$HOME/.ssh/known_hosts"; chmod 600 "$HOME/.ssh/known_hosts"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    grep -qxF "$line" "$HOME/.ssh/known_hosts" || echo "$line" >> "$HOME/.ssh/known_hosts"
  done < "$USB/ssh/known_hosts"
  say "known_hosts: forge host keys pinned"
fi

# --- 4. agent + auth sanity check --------------------------------------------
if ! ssh-add -l >/dev/null 2>&1; then
  eval "$(ssh-agent -s)" >/dev/null
fi
ssh-add "$HOME/.ssh/kosetup_ed25519" >/dev/null 2>&1 || true

if ssh -o BatchMode=yes -T git@github.com 2>&1 | grep -qi 'successfully authenticated'; then
  say "github.com: authenticated"
else
  say "WARN: github.com auth not confirmed — is the public key uploaded?"
fi
if ssh -o BatchMode=yes -T git@gitlab.com 2>&1 | grep -qi 'welcome'; then
  say "gitlab.com: authenticated"
else
  say "WARN: gitlab.com auth not confirmed — is the public key uploaded?"
fi

# --- 5. clone the manifest ---------------------------------------------------
# Repo root differs per setup: omarchy uses ~/Work, the old Devuan box ~/repo.
# Detect a sensible default, let the user override once.
if [ -d "$HOME/Work" ]; then def_root="$HOME/Work"
elif [ -d "$HOME/repo" ]; then def_root="$HOME/repo"
else def_root="$HOME/Work"; fi
read -r -p "[bootstrap] repo root [$def_root]: " ROOT
ROOT="${ROOT:-$def_root}"
ROOT="${ROOT/#\~/$HOME}"
mkdir -p "$ROOT"

while read -r url dest extra; do
  case "$url" in ''|\#*) continue ;; esac
  dest="${dest/#\~/$HOME}"
  dest="${dest//@ROOT/$ROOT}"
  if [ -e "$dest" ]; then
    say "exists, skipping: $dest"
    continue
  fi
  say "cloning $url -> $dest"
  # shellcheck disable=SC2086  # $extra is intentionally word-split (--depth 1)
  git clone $extra "$url" "$dest" || say "WARN: clone failed: $url"
done < "$USB/repos.list"

# --- 6. secrets --------------------------------------------------------------
place_secret() { # <usb-file> <dest> — never overwrites
  local src="$USB/secrets/$1" dst="$2"
  [ -f "$src" ] || return 0
  if [ -e "$dst" ]; then say "secret exists, skipping: $dst"; return 0; fi
  mkdir -p "$(dirname "$dst")"
  install -m 600 "$src" "$dst"
  say "secret placed: $dst"
}
place_secret gitconfig.work   "$HOME/.gitconfig.work"
place_secret connections.json "$HOME/.local/share/db_ui/connections.json"
place_secret arcade1.cred     "$HOME/.arcade1.cred"

# --- 7. git identity ---------------------------------------------------------
git config --global user.name  >/dev/null 2>&1 || git config --global user.name "$GIT_NAME"
git config --global user.email >/dev/null 2>&1 || git config --global user.email "$GIT_EMAIL"

# --- 8. hand off to the kosetup installer ------------------------------------
if [ -x "$ROOT/kosetup/install.sh" ]; then
  read -r -p "[bootstrap] launch the kosetup installer now? [Y/n] " reply
  case "$reply" in n|N) say "done — run $ROOT/kosetup/install.sh when ready" ;;
                   *) exec "$ROOT/kosetup/install.sh" ;; esac
else
  say "done — kosetup not cloned (check repos.list / auth warnings above)"
fi
