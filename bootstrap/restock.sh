#!/usr/bin/env bash
# restock.sh — rebuild the bootstrap USB stick from a LIVE kosetup machine
# (lost/corrupted/new stick). Everything is regenerated from the repo clone,
# ~/.ssh, and the home directory:
#
#   bash bootstrap/restock.sh /media/ko/<stick>/kosetup
#
# The one thing it cannot regenerate is the browser-password CSV — re-export
# that from the browser (vivaldi://settings/passwords -> Export) if wanted.
set -euo pipefail
DEST="${1:?usage: restock.sh /path/to/stick/kosetup-dir}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

say() { printf '\033[1m[restock]\033[0m %s\n' "$*"; }

mkdir -p "$DEST/ssh" "$DEST/secrets"

# 1. repo-tracked files
cp "$REPO/bootstrap/bootstrap.sh" "$REPO/bootstrap/ssh_config" "$REPO/bootstrap/repos.list" "$DEST/"
say "bootstrap.sh + ssh_config + repos.list copied from repo"

# 2. forge keys — prefer this machine's ~/.ssh copies; generate fresh only as
#    a last resort (fresh keys mean re-uploading the pubkeys to all 3 forges!)
for k in kosetup_ed25519 kosetup_rsa; do
  if [ -f "$HOME/.ssh/$k" ]; then
    cp "$HOME/.ssh/$k" "$HOME/.ssh/$k.pub" "$DEST/ssh/"
    say "key restored from ~/.ssh: $k"
  else
    case "$k" in
      kosetup_ed25519) ssh-keygen -q -t ed25519 -N "" -C "kosetup-usb" -f "$DEST/ssh/$k" ;;
      kosetup_rsa)     ssh-keygen -q -t rsa -b 4096 -N "" -C "kosetup-usb" -f "$DEST/ssh/$k" ;;
    esac
    say "WARN: $k not in ~/.ssh — GENERATED NEW KEY. Upload $DEST/ssh/$k.pub"
    say "      to the forges (GitHub/GitLab use ed25519, Azure DevOps uses rsa)"
    say "      and revoke the old one."
  fi
done

# 3. pinned host keys, captured live
ssh-keyscan -t ed25519,rsa github.com gitlab.com ssh.dev.azure.com 2>/dev/null > "$DEST/ssh/known_hosts"
say "known_hosts re-pinned"

# 4. secrets from this machine's home dir
restock_secret() { # <home-file> <stick-name>
  if [ -f "$1" ]; then
    cp "$1" "$DEST/secrets/$2"; say "secret restocked: $2"
  else
    say "WARN: $1 not on this machine — $2 skipped"
  fi
}
restock_secret "$HOME/.gitconfig.work"                        gitconfig.work
restock_secret "$HOME/.local/share/db_ui/connections.json"    connections.json
restock_secret "$HOME/.arcade1.cred"                          arcade1.cred
restock_secret "$HOME/Documents/db2.json"                     db2.json

sync
say "done — stick restocked at $DEST"
say "reminder: 'Browser Passwords.csv' must be re-exported from the browser if wanted"
