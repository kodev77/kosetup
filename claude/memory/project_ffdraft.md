---
name: project-ffdraft
description: "ffdraft fantasy-football draft kit: Sleeper projections + VBD boards pushed to Kenneth's & Shannen's Google Sheets; in-sheet draft marker; league-exact SaintsNation scoring; full ops runbook + Sheets-API gotchas"
metadata: 
  node_type: memory
  type: project
  modified: 2026-08-21T00:00:00.000Z
---

Draft kit for Yahoo league **SaintsNation** (id 796961): 10-team, full PPR, **offline draft**
(no Yahoo clock on draft night), roster QB/2WR/2RB/TE/W-R-T/K + IDP (3 D-flex, 2 DB, 2 DL)
+ 12 BN + 2 IR = 27 rounds. Repo `~/repo/ffdraft` (Devuan box) or `@ROOT/ffdraft` via kosetup
(gitlab kennethortego/ffdraft, master). README is current and accurate — trust it first.

**Sheets (both named "Fantasy Draft - 2026"):** Kenneth/primary
`1RrSf8-P3boR246zaRKb12f-sfd-02gbjXHq6HSIRuC8` (his Drive); Shannen (wife)
`1YkaeTNdK-WG_dk6o3HH12oKBrP7MYRThtgamiWaA5q4` (her Drive, listed in
`~/.config/ffdraft/extra_sheets.txt`). Fully independent: own Picks/My Team/marks; only the
push pipeline is shared. Both carry the bound Apps Script `draft_marker.gs` **v6** (copies
inherit it — share NEW sheets by File→Make-a-copy of the primary, never blank; the SA cannot
install scripts). The original 2026 sheet (`1m0-HK...`) was trashed 2026-08-21.

**Auth/deps:** service account `node-one-faf15@appspot.gserviceaccount.com` (GCP `node-one`,
Sheets API only — Drive API DISABLED: SA cannot create/copy/delete spreadsheets; sheet
creation/copying goes through ko's Drive MCP connector or manual). Key `~/.config/ffdraft/sa-key.json`;
user-level pip gspread+pandas. kosetup bootstrap places key+extra_sheets from the USB stick and
installs deps; data files self-download on first `refresh.py`.

**Ops runbook:** `refresh.py` = download all sources → rebuild → push BOTH sheets + change
report (run each draft-week morning; cron-able). `reset_picks.py [sheet-id]` = full tracker
reset (Picks + Gone boxes + re-asserts ALL validations; no arg = primary). `test_push_one.py
<id>` = push a single sheet. `capture_style.py` = re-snapshot styling → sheet_style.json
(replayed onto extra sheets; primary keeps its live styling + semantic enforcement).

**Board design:** every player tab pins `Depth | Bye | FPts Proj | PPG Proj | ADP | (Proj Val
on boards) | FPts League | PPG | ECR` after Player-ish cols; Player col A + frozen everywhere.
Depth = slot+string (`RB` starter, `WR1-2` backup) — slot numbers are alignment, NOT rank.
Sorts: Draft Board by **Proj Val** (VBD = FPts Proj − replacement at PROJ_BASELINE
QB12/RB24/WR24/TE12/K10/DL24/LB30/DB24), pool boards by own-pool ADP asc, position tabs by
FPts Proj; orange header = sort key; per-tab `Sort by`/`Dir` dropdowns re-sort live (basic
filters removed — they cannot sort formula tabs). Projections: Sleeper free API
(`api.sleeper.app/projections/nfl/<yr>?season_type=regular&position[]=...`) scored through
league rules in make_proj.py; est. from 2025 rates: 40+ bonuses, IDP PD/TFL, kicker under-40
FGs (Sleeper only projects 40+ FGs; fgm_yds = 40+-only yardage); adp_idp==999 = undrafted →
blank. Defense ADP = Sleeper IDP pool ≠ offense FFC ADP.

**Tracker:** owner codes uniform **M / Q / X** (green/navy/red). Mark dropdown (M/Q/X/CLEAR)
+ one-click Gone checkbox on all 11 ranked tabs & My Team → bound script writes Picks
instantly (finds Player col by header; lock-serialized; sweeps whole Mark column; re-asserts
Mark/Gone validations + resyncs Gone boxes from Picks on every event & onOpen).
`draft_marker.py` = API-polling fallback daemon (script-less sheets; Mark only). My Team
shows M picks + Q queue preview (navy), Owner + Mark cols at end. All column letters DERIVE
from name lists via sheet_model() — reorder = edit a list.

**Sheets-API gotchas (hard-won):** (1) values:batchClear/clear REMOVES data validation
despite docs — never values-clear a validated range without re-asserting
(validation_requests() is the single source of every rule). (2) gspread add_cols INSERTS
dimensions → shifts existing formula references; push grows ALL grids before writing
formulas/styling. (3) A QUERY matching 0 rows returns #N/A and kills its array stack — every
tail QUERY is IFERROR-wrapped with a width-matched blank row. (4) UI paste replaces target
validation (safe bulk-X: copy a TICKED Gone checkbox cell, paste over Gone cells). (5)
Formula-view tabs can't be filter-sorted (cells are virtual); typed-over Taken cells
self-heal each push. (6) Legend styling is text-keyed; banding auto-widens to full grid;
Bye accent (blue bold centered) painted semantically by column name each push; all other
data cells get fg/bold/align reset. (7) Sheets mobile dark theme inverts custom colors —
per-file ⋮→"View in light theme" (app stays dark). (8) Write quota 60/min:
BackOffHTTPClient everywhere + 60s sleep between sheets.

**Draft strategy settled with ko:** elite RB early (their VBD towers), Bowers-class TE at
the turn, QB streamable (Allen the exception), K last; IDP = elite-or-wait (1 elite DL
and/or top LB, LB volume mid, DBs last), NO IDP bench — stream byes via waivers (keep ≥2
startable DL and ≥2 DB at all times; elites park on BN their bye week via an offense-bench
drop). Bye rules: never same-position starter collisions; QB2 bye ≠ QB1; week 11 = 6 teams
out (heavy). Mock drafts: Yahoo Instant Mock = league-exact vs bots (fast, quit anytime,
timer autopicks from Yahoo's in-draft queue — load it as insurance); live lobby mocks =
generic settings, early-rounds-feel only.
