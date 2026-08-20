---
name: kosetup-fleet
description: "kosetup repo at ~/Work/kosetup manages Ko's multi-machine Omarchy setup; deploys via symlinks, so git pull alone updates live configs"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1547037f-06a4-4fac-9f28-64910416b203
  modified: 2026-08-20T14:00:02.776Z
---

Ko's machine setup repo lives at `/home/ko/Work/kosetup` (github.com/kodev77/kosetup). `bootstrap.sh`/`install.sh` are run once per machine; install symlinks files into place (e.g. `~/.local/bin/sys-tile` → `tiles/sys-tile`, `~/.config/hypr/monitors-kosetup.lua` → `config/hypr/`), so after the first install a plain `git pull` deploys updates — no re-run needed unless install.sh itself gains new links/packages. Machine-specific logic in the repo is gated on DMI product name or hardware probes so shared files stay inert on other machines.

Known fleet (as of Aug 2026): Beelink SER9 mini PC (AMD HawkPoint APU, no fan sensor exposed — sys-tile fan column reads N/A there by hardware limitation), MacBook Pro "ko-mac-omarchy" (applesmc fan, Intel i915), and an ASUS ROG laptop (nvidia Optimus + asus hwmon). After pulling changes that touch Hyprland config, run `hyprctl reload` and check `hyprctl configerrors`.
