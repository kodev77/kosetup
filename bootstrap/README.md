# kosetup USB stick — new machine runbook

This stick bootstraps a fresh machine into the full ko environment.
**It holds real secrets** (forge SSH keys with no passphrase, work
credentials) — treat losing it as a credential compromise.

If a Claude Code session is helping with the setup: read this file, then
`~/Work/kosetup/install.sh` — its comments are the documentation, and
`git lg2` in that repo is the history of every fix and why. Claude's own
settings + memory arrive via the `[claude]` group; only `claude` login
is needed to restore its full context of these machines.

## Assumptions
- User is `ko`, home `/home/ko`, repos root `~/Work` (omarchy) or `~/repo` (legacy Devuan).
- OS is omarchy (Arch/Hyprland). Non-omarchy machines: bootstrap works; several install groups self-skip with a printed reason.

## Order of operations

1. **Install omarchy**, log in, open a terminal.
2. **Bootstrap** (stick is FAT32 `showexec` — must invoke via bash):
   ```sh
   bash /run/media/*/*/kosetup/bootstrap.sh
   ```
   Installs SSH keys + pinned host keys, clones repos.list into the
   chosen root, places secrets, sets git identity. Idempotent; never
   overwrites existing keys/secrets. Answer the repo-root prompt
   (default is right), and note the final prompt DEFAULTS TO YES about
   launching the installer.
3. **Install everything**:
   ```sh
   cd ~/Work/kosetup && ./install.sh all-work   # or `all` for a non-work machine
   ```
   Re-run `./install.sh --list` anytime — [x]/[~]/[ ] is live drift
   detection. Groups/items are individually installable and removable.

## Per-machine ceremonies (by design not automated — mostly logins)
- `claude` → sign in (settings/memory already arrive via the repo).
- Chrome: sign into Google (password store syncs down), Chrome restart
  after the dotnet item so the dev-cert padlock applies.
- `az login` (Azure CLI) — browser flow.
- Work repos: clone manually into `~/Work/rpc/` (deliberately not in
  repos.list — no work URLs in a personal repo). Identity switches to
  the work account automatically under that path.
- First JobTracker restore: `dotnet restore --interactive` (device-code
  sign-in; plain restore works forever after).
- teams-for-linux + Outlook web app: sign in once.
- Bluetooth headset: pair via the bar menu (pairing is per-machine
  cryptography, not config).
- ASUS laptops only: `[hardware]` group installs the platform-profile
  tools; everywhere else it prints a skip reason.

## Known gotchas (all discovered the hard way — details in git log)
- First idle after a reboot MAY fire the screensaver at 2.5 min once
  (upstream omarchy shell race). Fix: `omarchy restart shell`.
- `display/libre-icons` refuses while LibreOffice runs — close it first
  (LO rewrites its config on exit and would discard the patch).
- nnn preview (`;p`) needs plugins: run `;g` inside nnn once.
- Steam's Rogue files are needed for `rogue-dos`; the ARCADE1 cab must
  be on the LAN for `arcade1-mount`.
- Aspire edge stack: if https://localhost:8443 hangs with 504s, that is
  the ufw container→host block — `work-cli/edge-fw` applies the rule.

## Before decommissioning / wiping any machine
1. Push every repo (`git status` in each ~/Work clone).
2. Refresh this stick: `bash ~/Work/kosetup/bootstrap/restock.sh /run/media/ko/<stick>/kosetup`
3. Verify Chrome password sync is ON (passwords live nowhere else).
4. Sweep `~/Pictures` / `~/Wallpapers` if wanted — they live in no repo.
