#!/usr/bin/env bash
# kosetup bootstrap — run from the USB stick on a FRESH machine:
#
#   bash /run/media/*/*/kosetup/bootstrap.sh    # udisks2 (omarchy/Arch)
#   bash /media/*/kosetup/bootstrap.sh          # older automounters
#
# The stick is FAT32 and mounted `showexec`, so bootstrap.sh is never
# executable in place — it must be invoked via `bash <path>`.
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
#   secrets/ffdraft-sa-key.json, secrets/ffdraft-extra_sheets.txt   ffdraft pipeline
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

# --- 2. ~/.ssh scaffold ------------------------------------------------------
# A genuinely fresh machine has no ~/.ssh at all. Create the directory AND the
# two files the later steps append to, with the permissions ssh insists on, so
# every ssh/git command below has somewhere to read from and write to. Doing
# this in one explicit step (rather than letting each section mkdir/touch as it
# goes) is what makes the rest of the script safe to reorder or re-run.
mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
touch "$HOME/.ssh/config" "$HOME/.ssh/known_hosts"
chmod 600 "$HOME/.ssh/config" "$HOME/.ssh/known_hosts"
say "~/.ssh ready (dir 700, config + known_hosts 600)"

# --- 3. SSH keys (FAT32 can't hold perms — fix after copy) -------------------
for k in "$USB"/ssh/kosetup_*; do
  [ -e "$k" ] || continue
  b="$(basename "$k")"
  if [ ! -f "$HOME/.ssh/$b" ]; then
    cp "$k" "$HOME/.ssh/$b"; say "key installed: $b"
  fi
done
chmod 600 "$HOME/.ssh"/kosetup_* 2>/dev/null || true
chmod 644 "$HOME/.ssh"/kosetup_*.pub 2>/dev/null || true

# --- 4. ssh config include + pinned host keys --------------------------------
install -m 600 "$USB/ssh_config" "$HOME/.ssh/kosetup_config"
if ! grep -q '^Include kosetup_config$' "$HOME/.ssh/config"; then
  # Include must precede any Host block, so prepend. Do NOT use
  # `sed -i '1i ...'` here: on the zero-byte config of a fresh machine there is
  # no line to insert before, so sed silently writes nothing and the Include
  # never lands — clones then quietly fall back to the default identity and the
  # Azure DevOps rsa block never applies at all.
  { echo 'Include kosetup_config'; cat "$HOME/.ssh/config"; } > "$HOME/.ssh/config.kosetup-new"
  mv "$HOME/.ssh/config.kosetup-new" "$HOME/.ssh/config"
  chmod 600 "$HOME/.ssh/config"
  say "ssh config: Include kosetup_config added"
fi
if [ -f "$USB/ssh/known_hosts" ]; then
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    grep -qxF "$line" "$HOME/.ssh/known_hosts" || echo "$line" >> "$HOME/.ssh/known_hosts"
  done < "$USB/ssh/known_hosts"
  say "known_hosts: forge host keys pinned"
fi

# --- 5. agent + auth sanity check --------------------------------------------
if ! ssh-add -l >/dev/null 2>&1; then
  eval "$(ssh-agent -s)" >/dev/null
fi
ssh-add "$HOME/.ssh/kosetup_ed25519" >/dev/null 2>&1 || true

# `ssh -T` exits 1 at github even when auth SUCCEEDS, and `set -o pipefail`
# propagates that exit status through `| grep`, so the obvious
# `if ssh ... | grep -q ...` form reports a false WARN on a working stick.
# Capture the banner first and match it out of band. `-n` is load-bearing too:
# ssh reads stdin by default and would eat the answers to the `read` prompts
# below (and can swallow terminal keystrokes), aborting the script under set -e.
forge_banner() { ssh -n -o BatchMode=yes -T "$1" 2>&1 || true; }
case "$(forge_banner git@github.com)" in
  *"successfully authenticated"*) say "github.com: authenticated" ;;
  *) say "WARN: github.com auth not confirmed — is the public key uploaded?" ;;
esac
case "$(forge_banner git@gitlab.com)" in
  *"Welcome to GitLab"*) say "gitlab.com: authenticated" ;;
  *) say "WARN: gitlab.com auth not confirmed — is the public key uploaded?" ;;
esac

# --- 6. clone the manifest ---------------------------------------------------
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
  # </dev/null: the loop's stdin is repos.list itself — keep git off it.
  git clone $extra "$url" "$dest" </dev/null || say "WARN: clone failed: $url"
done < "$USB/repos.list"

# --- 7. secrets --------------------------------------------------------------
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
place_secret db2.json         "$HOME/Documents/db2.json"
place_secret ffdraft-sa-key.json      "$HOME/.config/ffdraft/sa-key.json"
place_secret ffdraft-extra_sheets.txt "$HOME/.config/ffdraft/extra_sheets.txt"
# secrets/"Browser Passwords.csv" (if present on the stick) is NOT auto-placed —
# it's a browser-import artifact: import it via chrome://settings/passwords on
# the new machine, then delete it from the stick (plaintext passwords).

# --- ffdraft deps ------------------------------------------------------------
# The fantasy-football pipeline (@ROOT/ffdraft) needs user-level gspread+pandas
# (its scripts run bare python3 — no venv; see ffdraft/README.md). Only bother
# when its service-account key was placed above.
if [ -f "$HOME/.config/ffdraft/sa-key.json" ]; then
  if python3 -c 'import gspread, pandas' >/dev/null 2>&1; then
    say "ffdraft: python deps already present"
  else
    if ! command -v pip3 >/dev/null 2>&1; then
      if command -v apt-get >/dev/null 2>&1; then sudo apt-get install -y python3-pip
      elif command -v pacman >/dev/null 2>&1; then sudo pacman -S --needed --noconfirm python-pip
      fi
    fi
    if pip3 install --user --break-system-packages gspread pandas >/dev/null 2>&1; then
      say "ffdraft: gspread + pandas installed"
    else
      say "WARN: ffdraft deps failed — run: pip3 install --user --break-system-packages gspread pandas"
    fi
  fi
fi

# --- 8. git identity ---------------------------------------------------------
git config --global user.name  >/dev/null 2>&1 || git config --global user.name "$GIT_NAME"
git config --global user.email >/dev/null 2>&1 || git config --global user.email "$GIT_EMAIL"

# --- 9. hand off to the kosetup installer ------------------------------------
if [ -x "$ROOT/kosetup/install.sh" ]; then
  read -r -p "[bootstrap] launch the kosetup installer now? [Y/n] " reply
  case "$reply" in n|N) say "done — run $ROOT/kosetup/install.sh when ready" ;;
                   *) exec "$ROOT/kosetup/install.sh" ;; esac
else
  say "done — kosetup not cloned (check repos.list / auth warnings above)"
fi
