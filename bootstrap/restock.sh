#!/usr/bin/env bash
# restock.sh — rebuild the bootstrap USB stick from a LIVE kosetup machine
# (lost/corrupted/new stick). Everything is regenerated from the repo clone,
# ~/.ssh, and the home directory. Run it from the REPO CLONE, not from the
# stick (the stick's own copy cannot restock — see the repo probe below):
#
#   bash ~/Work/kosetup/bootstrap/restock.sh /run/media/ko/<stick>/kosetup
#
# The one thing it cannot regenerate is the browser-password CSV — re-export
# that from the browser (vivaldi://settings/passwords -> Export) if wanted.
set -euo pipefail
DEST="${1:?usage: restock.sh /path/to/stick/kosetup-dir}"

say() { printf '\033[1m[restock]\033[0m %s\n' "$*"; }

# --- locate the repo clone ---------------------------------------------------
# This script is copied onto the stick too, but lands one level shallower there
# (<stick>/kosetup/restock.sh vs <repo>/bootstrap/restock.sh). Deriving the
# root as a blind "one level up from my own directory" therefore aims at the
# stick root when the stick copy is run, and dies on the first cp below. Probe
# both layouts and confirm the repo-tracked files are really there, so a wrong
# invocation fails here with an explanation instead of part-way through.
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO=""
for cand in "$SELF_DIR/.." "$SELF_DIR"; do
  if [ -f "$cand/bootstrap/bootstrap.sh" ]; then REPO="$(cd "$cand" && pwd)"; break; fi
done
if [ -z "$REPO" ]; then
  say "ERROR: no kosetup repo found from $SELF_DIR"
  say "       restock.sh rebuilds the stick FROM a clone — it cannot run from"
  say "       the stick's own copy. Use the clone instead, e.g.:"
  say "         bash ~/Work/kosetup/bootstrap/restock.sh $DEST"
  exit 1
fi
say "repo: $REPO"

mkdir -p "$DEST/ssh" "$DEST/secrets"

# 1. repo-tracked files
cp "$REPO/bootstrap/bootstrap.sh" "$REPO/bootstrap/ssh_config" "$REPO/bootstrap/repos.list" \
   "$REPO/bootstrap/restock.sh" "$REPO/bootstrap/README.md" "$DEST/"
say "bootstrap.sh + ssh_config + repos.list + restock.sh + README.md copied from repo"

# 2. forge keys — prefer this machine's ~/.ssh copies; generate fresh only as
#    a last resort (fresh keys mean re-uploading the pubkeys to all 3 forges!)
for k in kosetup_ed25519 kosetup_rsa; do
  priv="$HOME/.ssh/$k"
  if [ -f "$priv" ]; then
    cp "$priv" "$DEST/ssh/$k"
    # A missing .pub does NOT mean the key is lost — it derives from the
    # private half. Copying both in one cp made an absent .pub abort the whole
    # script (set -e) at step 2 of 4, leaving a stick with keys but no
    # known_hosts and no secrets; bootstrap.sh skips both of those silently,
    # so that half-restocked stick looks like a clean run. Derive instead.
    if [ -f "$priv.pub" ]; then
      cp "$priv.pub" "$DEST/ssh/$k.pub"
    elif pub="$(ssh-keygen -y -f "$priv" 2>/dev/null)"; then
      printf '%s kosetup-usb\n' "$pub" > "$DEST/ssh/$k.pub"
      say "NOTE: ~/.ssh/$k.pub was missing — regenerated from the private key"
    else
      say "WARN: ~/.ssh/$k.pub missing and cannot be derived from $priv"
      say "      (passphrase-protected or corrupt) — stick gets no $k.pub."
      say "      ssh can still authenticate from the private key alone."
    fi
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
restock_secret "$HOME/.config/ffdraft/sa-key.json"            ffdraft-sa-key.json
restock_secret "$HOME/.config/ffdraft/extra_sheets.txt"       ffdraft-extra_sheets.txt

sync
say "done — stick restocked at $DEST"
say "reminder: 'Browser Passwords.csv' must be re-exported from the browser if wanted"
