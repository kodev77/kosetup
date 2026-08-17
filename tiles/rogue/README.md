# rogue-tile

A tiny exploration roguelike for a terminal "tile" window, themed in **ko-matrix** phosphor green to sit
alongside `tty-clock`, `sys-tile`, and `snake-tile` on the Win95/XFCE desktop. Explore a dungeon of
scattered rooms joined by corridors — the map is dark until you walk it; entering a room lights it up.
Collect gold (`$`), gather every **star** (`✱`) to reveal the **key** (`⚷`) that unlocks the stairs
(`≡`), and descend to a fresh, deeper level. (Stairs display as a three-line `≡` "steps" glyph — down
an always-green inverted block that flashes red if you bump it while it's locked, up a plain green glyph; internally / in this doc they're still the `>` and `<` tile markers.)

**Location:** `rogue/rogue-tile` in this repo (single self-contained Bash script, no dependencies beyond
coreutils: `stty`, `sort`, `awk`). The `~/.local/bin/rogue-tile` command points at the repo-root **launcher
menu**, which runs it.

```
rogue-tile          # the game menu — pick Rogue (this game fills the terminal; resizing regenerates the level)
rogue-tile rogue    # skip the menu and launch the dungeon directly
rogue-tile -h       # usage
```

## Controls

| Key | Action |
|-----|--------|
| `h j k l` / arrows | move one tile (walls block) |
| `H J K L` / **Alt**+arrows | **run / travel** — go until a junction, a doorway (incl. pulling *level* with a door on a side wall), level with **either stair**, **any object/stair in your path**, or **level with any visible object's row/column** in your room (so you can turn straight to it), or a wall. Never auto-collects or descends — it stops so you step onto it yourself |
| **Ctrl**+arrows | **jump** — a fixed dash of up to 10 tiles, stopping early at a wall, **any object/stair in the path, or level with a visible object** (same: no auto-collect/descend) |
| `≡` | step onto the down-stairs (always a green block; flashes red if you bump it while locked) to descend a floor |
| `≡` | step onto the up-stairs (plain green `≡`) to climb back to the previous floor (never locked) |
| `$` | walk over gold to collect it (each piece a fixed random value, set when the floor is built) |
| `✱` | walk over a star to collect it — find them all to reveal the key |
| `⚷` | walk over the key to unlock this floor's down-stairs |
| `&` | the **hall monitor** — **paces** back and forth across a transition hall (one step each time you move — a fast-travel still nudges him just one tile — never within 3 tiles of a stair, holding still when you're adjacent so you can bump him). Bump him for a bump-by-bump conversation: **1st bump** shows his toll (85% of all gold since your last toll), **2nd bump** pays it, **3rd bump** steps you past (honouring run/jump — `Alt`/`Ctrl` carry you past *and* keep travelling). Can't afford it? He tells you the shortfall — backtrack up `<` for gold. Already paid → he waves you through (status → pass). His message **stays up** until you act |
| `r` | reroll the current floor (new layout, same depth) |
| `?` | help overlay (controls) |
| `m` | stats overlay (realm/floor/depth, score `@` multiplier, segment · rooms, seed · map — then stars / key / gold) |
| `c` | cycle the theme: custom ko-matrix green → ride the terminal's accent (palette slot 4) → ride its green (slot 2) → back (per-session) |
| `t` | toggle the tileset: **default** (the original look) ↔ **DOS/Epyx Rogue** (double-line orange walls, gray `▒` corridors, doorway glyphs) — per-session |
| `q` | quit |

Turn-based: the screen only redraws on a keypress or resize, so it sits idle at ~0% CPU (no animation
loop). Gold persists as you travel, and **floors are persistent** — climb back up with `<` and a floor is
exactly as you left it (same layout, your explored fog, the gold/stars you already took stay taken, the
key stays found, an unlocked stair stays unlocked).

**Stars ✱ & the locked stairs.** Each floor's `>` starts **locked** — bold red and still instead of bright
and blinking. Rooms hold a **star `✱`** (phosphor green `#33ff33`) on a random subset toward the segment
target (≤1 per room). The one room that's *never* seeded is the **game's very first room** (realm 0 / floor 0
/ room 0) — a star there would need no exploring. **Every other floor's arrival / up-stairs room (room 0) is
eligible** like any room, so descending no longer drops you into a guaranteed-empty room. The HUD
tracks them (`✱ 2/5`). Collect them **all** — which means actually visiting every room — and **a key `⚷`
appears** on a random room's floor (announced on the status bar), often somewhere you've already been, so
there's a final little trek. Grab the key and the `>` lights up bright and blinking — descend. Bumping a
locked `>` flashes it red and says `STAIRS LOCKED` (what's missing — stars left, or the key out on the map —
is shown in the HUD tracker). Run/jump **stop** at stars, the key, and gold (and at either stair) rather than
sweeping them up, so fast-travel is the natural way to *work* a floor, not a way to skip it — you consciously
step onto each pickup. The `<` up-stairs are never locked (backtracking is free), and the rare
1-room floor has no stars — its stairs start open.

**Speed travel.** Tapping tile-by-tile across a big floor is slow (and at full-desktop size the per-keypress
full redraw can't keep up with auto-repeat — see the render note). Two faster modes solve both: **run**
(`Alt`+dir / `H J K L`) sweeps along a corridor or across a room and stops at the next *decision point* — a
side passage, a doorway into/out of a room, **a column/row that lines up with a doorway on a perpendicular
wall** (so you stop level with a side door and can turn straight through it instead of overshooting to the
back wall), **a column/row level with either stair** when you're in its room (so you can beeline to a stair —
this now covers the **up**-stair `<` too, which earlier runs blew right past), **any object (`$ ✱ ⚷`) or stair
directly in the path** (it halts one tile short), **or a column/row level with any *visible* object elsewhere
in the room** (`aligned_object` — gold always counts, a star/key once the torch has revealed it; so you stop
the moment you line up with a pickup and can turn straight to it instead of passing it), or a wall — and
**jump** (`Ctrl`+dir) dashes a flat 10 tiles, stopping at the same things. Crucially, **neither auto-collects an item or auto-takes a stair** — they
stop *next to* it and you step on yourself, so you never sweep up gold/stars/keys or descend by accident. Each
is **one redraw per move** rather than one-per-tile, so they're fast *and* dodge the full-screen lag.

*(Run is on **Alt**, not Shift, because xfce4-terminal/VTE hard-binds `Shift+Up/Down` to scrollback — a VTE
built-in, not an xfce4-terminal accelerator, so it can't be unbound from config; `Alt+arrows` are free at both
the WM and terminal level. The parser accepts both Alt encodings: CSI `\e[1;3X` and meta `\e\e[X`.)*

## Display

- **1-char tiles** (`#` wall, `·` floor, `≡` stairs — down inverted block / up plain green, tile markers `>`/`<`, `$` gold, `✱` star, `⚷` key,
  `&` hall monitor (bold cyan), `@` you) — roguelike convention, fits more dungeon than snake-tile's 2-wide cells. (`✱`/`⚷` were
  font-tested in the tile terminal — Monospace 11, no Nerd Font — alongside rejected candidates `◆◊⬢❖✦✸●`
  (the glyph evolved red filled-star `✦` → green open-star `✧` → the green heavy-asterisk `✱` finally chosen).)
- **Fog of war:** `DISC[]` tracks discovered cells. Entering a room reveals the whole room + its walls;
  a 3×3 "flashlight" around `@` reveals nearby corridor tiles as you walk.
- **Flashlight** lights floor + *corridor* walls, but never a room's walls (via the `NEARROOM` mask), so
  a hallway glows without lighting up the walls of a room it passes — only the room *or* the hall lights.
- **Palette & stairs:** both stairs render as a three-line **`≡`** ("steps" — picked over `</>`, `^/v`,
  `↑/↓` and `▲/▼` in the tile-font test), with **up vs down carried by styling, not the glyph**. The **down**
  `≡` (tile marker `>`) is a **reverse-video block with a knockout black `≡`** (`BLK`) on an **always-green**
  background (`SBG`, `#33ff33`). Lock state isn't a *resting* colour at all — bumping a locked `>` triggers a
  brief **red flash** of just that cell (`flash_stair`: one ~0.3s red pulse via `SBGL`, then back to `SBG`
  green), like rattling a locked door, so the map stays calm and the feedback is active-only. (Earlier tries put the
  lock colour on the resting glyph/background — a red `≡` on green *washed out*, red-on-green being near-equal
  brightness + a colour-blind trap; the flash sidesteps that, and the HUD `✱`-counter / `⚷` already show lock
  state at rest.) The **up** `≡` (tile marker `<`) is a **plain bold green `≡`** (never locked). Reverse-video
  for the down stair makes it unmistakable *without* a new hue — every green *hue* read too close to a green
  up-stair (mint, teal, dim all trialled), so block-vs-glyph does the work (teal `#5fd7ff` / pure cyan kept as alts).
  dim/darker greens for lit/discovered floor and walls. **Money `$` is bold amber `#FFD24A`** (`GOLD`) and
  lights the floor in its 3×3 like any source, but that floor glows the **normal phosphor green** (`A`) — only
  the `$` glyph itself is amber (a gold floor-tint was trialled and dropped as too garish). The **key `⚷` is bold amber too** (`#FFD24A`) — the warm collectibles; the player `@` is
  bold mint `#5FFF8F` (`P`); stars `✱` are **phosphor green `#33FF33`**
  (the one collectible *not* bold) — the same bright matrix green as the lit walls, told apart by the `✱` glyph and by
  sitting on the dim floor (a brighter shade and bold weight were trialled for more separation but set aside; the `✱` heavy-asterisk was picked over
  the crystal `◆`/`◊`/`✧` and coin `●` candidates in the tile-font test). (A `CYAN` palette entry
  holds a Tron teal-blue / cyan we trialled for `<` but set aside in favour of the all-green dim/bright
  scheme — kept for easy revisiting.)
- **Theme — `c` cycles three palettes (per-session):** the default is the custom **ko-matrix** truecolor green
  above (`mode 0`: player `#5FFF8F`, lit `#33FF33`, seen `#43904F`, unexplored `#204828`, HUD bar `#102A10`).
  Pressing **`c`** cycles to two **palette-ride** modes that re-colour the dungeon from the *live terminal
  theme* instead: **`mode 1` rides the accent** (palette **slot 4**) and **`mode 2` rides green** (**slot 2**).
  A ride mode **queries the running terminal** over OSC — its background (`OSC 11`) and the chosen slot's hue
  (`OSC 4`) — and **synthesises the whole `@`/lit/seen/unexplored ramp in truecolor, anchored to that
  background** so it stays legible on *any* scheme, dark or light: `lit` = the hue at full, `seen`/`unexplored`
  fade 45%/72% toward the bg, the player `@` pushes 35% toward the opposite contrast extreme (white on a dark
  theme, black on a light one) so it always pops, and the HUD bar is the bg tinted 18% toward the hue (so it
  flips dark-bar/light-bar with the theme). Legibility uses a **WCAG-style contrast *ratio*** of hue-vs-bg luma
  (not a raw RGB distance): if the hue's ratio against the bg is under **2:1** it's **inverted**, and if it's
  *still* under 2 (a mid-gray-on-mid-gray theme) it's shoved 60% toward the extreme — so the theme's own colours
  are respected unless genuinely illegible. If the terminal doesn't answer the OSC query, ride falls back to
  flat ANSI bright/normal/faint tiers (blue for accent, green for green). The **semantic glyphs keep their
  meaning-colour in every mode** — the gold key/money, the cyan hall monitor, and the green/red stair blocks
  read the same whatever you're riding. Custom mode also **forces green-on-black** while it runs (`OSC 10/11`,
  restored on exit) so a reset always lands on black; switching *to* a ride mode lifts that first (`OSC
  110/111`) so the ramp reads the theme's real background. The choice is **per-session** (not saved).
  **Focus-in auto-refresh:** with focus reporting enabled (`\e[?1004h`), clicking back into the window in a ride
  mode **re-queries the theme** — so changing the terminal's colour scheme in its Preferences and returning
  updates the palette with no keypress.
- **Tileset — `t` toggles default ↔ DOS/Epyx Rogue (per-session):** the logical tiles in `TILE` never change —
  only how they're **drawn**. The default is the original look (green `#` walls, green-dot floors/corridors,
  the classic glyphs above). Pressing **`t`** switches to a faithful **IBM-PC DOS Rogue** skin, all standard
  Unicode (no special font needed):
  - **Walls** → connected **double-line** box-drawing (`═ ║ ╔ ╗ ╚ ╝ ╠ ╣ ╦ ╩ ╬`) in **orange**, drawn **only
    around rooms** — each `#` border cell links to its neighbouring *room* walls (`_roomwall`/`box_wall`,
    memoised per floor in `BOXMAP`), so rooms read as clean rectangles and the rock behind a wall never
    connects.
  - **Corridors** → gray `▒` blocks in **black void** (corridor-adjacent rock is left unfilled, so a hall is a
    bare `▒` passage, not a walled tube).
  - **Doors** → an orientation-aware doorway glyph where a corridor breaks a wall (`_door` → `DOORGLYPH`): `║`
    when a **vertical** corridor passes through a horizontal wall, `╬` when a **horizontal** corridor passes
    through a vertical wall (the `╬` joins the vertical wall *and* runs the passage on into the room). Doors
    **dim with their room** like the walls (`DOS_DOOR`/`DOS_DOOR_DIM`, gated on `lit`).
  - **Floors** stay green `·`; **entities** stay the classic glyphs (`@ & $ ✱ ⚷ ≡`). The hero `@` gets a gray
    cell-fill (`DOS_HALL_BG`) when it stands on a hallway tile so it doesn't punch a black hole in the corridor.
  - The DOS set uses its **own fixed colours** (orange walls, gray corridors — the `DOS_*` SGRs), overriding the
    `c` theme while it's active; the default tileset is untouched and still follows the theme.

  *The chunky **pixelated** DOS look itself is a property of the terminal **font**, not the game (the script only
  emits characters): point the tile terminal at a bitmap **CP437 font** — e.g. **More Perfect DOS VGA** (already
  in `~/.local/share/fonts/`), which covers every glyph this tileset uses — for the authentic blocky rendering.*
- **Status bar (HUD):** a single full-width **Infocom/Zork-style** bar on row 1 — a solid dark-green field
  (`#102A10` background, `BAR` escape), **condensed** to `LEVEL r/f · GOLD g` on the LEFT (realm/floor 1-based,
  world-level style, plus the gold count — the `GOLD` label stays phosphor green while the **number lights up
  amber** (`$GOLD`) once you hold any, dim green at zero) and an objective tracker **`⚷ [ ✱ ✱ … ]` pinned
  RIGHT** (with a 1-space inset from the edge) — the key `⚷` first, in three states: **dim green** (`$D`) before it's
  placed, **gold** (`$GOLD`) once it appears on the map (all stars collected → "come get me"), **phosphor
  green** (`$A`, matching the unlocked stairs) once taken; then the star bracket — one `✱` per star,
  **bright** (`$STAR`) once collected and **dim** (`$D`) until then. The whole thing fills in as you explore
  (no tracker on a 1-room floor). The transient **event message** (`STAIRS UNLOCKED`, `STAIRS LOCKED`)
  and the tracker are **mutually exclusive** — while a message is up it owns the right side and the tracker is
  hidden; it **auto-clears after ~750ms** (while a message is up the idle poll drops to 0.075s and counts down
  `MSG_DUR_TICKS`=10) *or* the instant you move (whichever first), then the tracker reappears (the message is
  `…`-clipped if too long, so
  it can never wrap onto the map). The rest — rooms total, seed —
  lives in the **`m` stats overlay**. **All bold** (`BOLD=\e[1m` once up front, reset by the trailing `R`); the
  left end has a 1-space inset, the right a 1-space inset; the `$BAR` bg persists through every span + the pad so it fills edge to
  edge. Two colour tiers: **bright phosphor (`#33FF33`, `$A`)** label + slashes, **dim (`#43904F`, `$D`)**
  numbers; messages are dim green (`$D`).
  The **seed hash is not on the bar** (valuable real estate) — it and the absolute `depth`
  live in the `m` stats overlay. The hash is base36 of `(mapseed<<20)|(W<<10)|H` — one shareable code packing the
  floor's RANDOM seed *and* the window size. Each floor reseeds `RANDOM` from `mapseed`, so the hash fully
  reproduces a layout: decode it back to `mapseed/W/H` and regenerate with `RT_SEED=<mapseed>` to debug it.
- **Borderless:** there is no box around the map — the status bar is the only chrome. The map sits below
  the bar with a **blank side gutter** of `GUTTER` columns each side (default **2**; no drawn border, just
  breathing room — `W = COLS-2·GUTTER`, rows indented `GUTTER` spaces), and no bottom border or controls
  line. The **status bar stays full-width** (its bg pads edge to edge), but its text is inset by the same
  `GUTTER` so the first label lines up with the map content.

## Window sizing

`read_size` maps the terminal to a map grid with **one layout** (no compact/roomy split — the borderless
status bar is the same on every window size):

- `W = COLS-2·GUTTER`, `H = ROWS-1` — row 1 is the full-width status bar; the map is indented `GUTTER`
  spaces (left gutter) and stops `GUTTER` columns short of the right edge (right gutter), and fills **all
  the way down to the last terminal row**. Reclaiming that bottom row is safe precisely *because* of the
  right gutter: with `GUTTER≥1` the map never writes the bottom-right cell, so there's nothing to trigger
  the classic last-cell autoscroll; the last map row also carries no trailing newline. (A small guard skips
  the bottom-right cell only in the degenerate `GUTTER=0` case.) On a small window this extra row gives the
  generator meaningfully more vertical budget for rooms and halls.
- Floors: `W` clamps to ≥12, `H` to ≥7.

Tall/long footprints are fine on small windows; the controls are always one `?` away.

## Dungeon generation (`generate`)

The level is built by **scattering rooms at random positions**, then connecting them — a non-grid layout
so rooms rarely line up on any axis (organic "cave" feel rather than a rigid grid). The headline trick is
**retry-until-clean**: rather than patching up an awkward layout, a layout that can't be wired cleanly is
thrown away and re-scattered.

1. **Scatter (rejection sampling).** Repeatedly try a random room rectangle (`rminw..rmaxw` wide ×
   `rminh..rmaxh` tall) at a random spot; reject it if it comes within the room spacing of any placed room.
   **Room dimensions** are `5–10 × 5–8` on a roomy window. On a **cramped** window the *minimum* drops per
   axis — `rminh=3` on a **short** (`H<13`) window, `rminw=3` on a **narrow** (`W<30`) one — while the max
   stays ≥5, so a cramped window mixes **3-, 4- and 5-long rooms**. That size *variety* is what lets rooms
   sit at different heights on a short window (a 5-tall room fills almost the whole vertical budget and is
   pinned to one row band; a 3-tall room can ride high or low), so the floor **scatters high/low** instead
   of lining up — even when it's too short to stack. (Sub-5 rooms dock doors **≥1 from a corner** rather than
   ≥2; the door rule relaxes adaptively for short walls — see step 7.)
   **Big chambers (peppered):** each room has a **20% chance** to roll a *big* size instead, choosing at random
   among the **four tiers that fit this window**: three **square** chambers — **subtle** `11–13 × 9`, **medium**
   `11–16 × 9–11`, **grand** `11–20 × 9–13` — plus a wide **hall** `14–24 × 3–5`. The square tiers must stay
   **≤ half the window on *both* axes** (`W≥2·bw && H≥2·bh`), so they only appear with vertical headroom (grand
   needs `H≥26`, subtle from `H≥18`) and never starve the floor. The **hall** is gated on **width only**
   (`W≥2·bw`, plus it must physically fit in height) — a wide-but-short room leaves space for others *beside* it
   rather than above/below, so it can be **grand even on a short window**: that's how a 76×8 tile still gets a
   striking `20×4` great-hall (its only fitting tier). Because the tier is picked among *fitting* ones, short
   windows reliably draw halls (~⅓ of floors) while tall windows mix all four. Result: ~1 big chamber per large
   floor and the occasional grand hall on small ones, as a landmark among the normal rooms.
   Placement uses the **full** window:
   a room's wall may sit on the map border row/col (`py ≤ H-rh-1`, not `H-rh-2`), reclaiming the row/col the
   old off-by-one wasted — worth one extra position of vertical play on short windows.
   Spacing is **directional**: `GAPH`/`GAPV` = **9 tiles** each axis on a normal window (9,
   not 5/7, so a Z-jog threading the gap between two side-by-side rooms can stay ≥4 tiles off both walls
   and never *hug* — see the `CHKHUG` rule in step 3), but on a **short** window (`H<13`) `GAPV` drops to **3** and on a **narrow** window
   (`W<30`) `GAPH` drops to **3**, so on a cramped window rooms can still sit close enough on the tight axis
   to **stack / go diagonal** (L-shaped and straight halls, real scatter) instead of a linear band.
   **Room count fluctuates per floor** — rather than always maxing out, the count is a *weighted random*: the
   window's **capacity** `cap` is `W*H/210` clamped **4–7** (roomy) or `max-dim/30` clamped **3–5** (cramped),
   and the actual target is a **triangular bell over `[2, cap]`** (`2 + (rand%(cap-1) + rand%(cap-1))/2`) with a
   **~4% chance of a lone-room floor**. So the *mid* count is most common and both ends — 1 and `cap` — are
   rare: a large window ranges the full 1–7 with a ~4–5 peak instead of cranking out 7 every time, while a
   small window (`cap=3`) stays a sane 2–3. A fallback force-places a room only if the scatter placed **none**
   (a floor needs at least the player's room; 1-room floors are an allowed rare roll, not forced up to 2).
2. **Build a clearance map (`OCC`).** Each room's interior plus a `CLR`-tile ring (3 tiles) is recorded.
   Corridors of *other* rooms must stay out of it, so a hall never runs within `CLR` tiles of a room it
   doesn't connect to.
3. **Connect with the STRICT pass only (`connect_pass 1 1 1 1 1`).** Candidate edges = every room pair, weighted
   by squared centre distance, sorted nearest-first. An edge is carved only if its corridor:
   - crosses **no** other room, and runs within neither the interior **nor the `CLR`-tile clearance** of any
     non-endpoint room (`OCC` is a **bitmask of every room** covering a cell — so overlapping clearance
     zones are all respected, not just the last writer);
   - stays **≥2 walls** from every already-carved corridor (`CHKCORR` checks distance-1/2 + diagonals →
     no double-wide, no jittery `corr·wall·parallel` tracks);
   - docks on a room **wall not already used** (`CHKSIDE` → at most **one hallway per room side**, so
     hallways never stack against the same wall);
   - has every 90° **turn-leg ≥3 tiles**, and a **Z-jog ≥4 tiles** (≥2 clear tiles between its two corners,
     so no cramped 1-tile jog) (`CHKLEG` + `JOGMIN`; `JOGMIN` relaxes to 3 on cramped windows where a longer
     jog won't fit);
   - **never runs parallel within `HUGCLR` tiles of any room wall** (`CHKHUG`): each carved leg is tested by
     `hseg`/`vseg` against every room — a horizontal leg within `HUGCLR` above/below a room it overlaps, or a
     vertical leg within `HUGCLR` beside one, is rejected. `HUGCLR=4` on roomy windows (corridors keep ≥3
     clear tiles off any wall — kills even the "2-tiles-off" Z-jog that still read as hugging), relaxed to
     **2** on cramped windows so they can still connect. This is what needs the wide `GAP=9`: a Z-jog
     between offset side-by-side rooms only clears `HUGCLR` from both walls if the gap is ≥9;
   - is **no longer than `CORR_MAXLEN`=60 tiles** (`CHKLEN`): the corridor's wall-gap (`dgx+dgy`) is capped,
     so wide windows can't grow a giant cross-the-screen hallway. To keep this *achievable*, the scatter
     (step 1) also **clusters** — a new room must sit within a `CORR_MAXLEN` corridor of an already-placed
     room (`near` check), so a short-corridor spanning tree always exists. The graded fallback (step 5) drops
     `CHKLEN`, so connectivity is never sacrificed to the cap.
4. **Retry-until-clean.** If the strict pass joined all rooms into **one** connected component, the layout
   is provably clean (only clean corridors were ever carved) and we keep it. Otherwise the entire layout
   is discarded and step 1 restarts — up to `MAXTRY` times (**40** normal, **28** on cramped windows where
   clean scatters are rarer). With all five rules enforced (incl. no-hug) the strict pass connects ~30–55%
   of scatters per try on roomy windows, so almost every map you see is a clean one; average generate stays
   ~90 ms (up to ~120 ms on a cramped window from the extra retries). *Geometric note:* at extreme short
   heights (`H≲10`) rooms can't **stack** (a vertical hall needs `5+gap+5` rows), so corridors stay mostly
   horizontal — that's physics. But rooms still **scatter high/low** there: with `rminh=3` the floor mixes
   3-, 4- and 5-tall rooms, and a short room riding high next to a tall one (or another short one riding low)
   makes them sit *diagonal* → clean L-corridors, not a flat band. All still fully clean.
5. **Graded fallback (only if every retry fails — vanishingly rare).** Loosen one rule at a time, ugliest
   last, so the map is always playable even when it can't be perfect: allow a short turn-leg → allow a 2nd
   hall per side + hugging → `OCC`-only (tolerate closeness, still never tunnel through a room) → raw
   force-connect. (Per your call: a fall-through here means the floor wasn't clean, so retry is preferred
   and this path almost never runs.)
6. **Loops (`Pass C`) — maximal circle-backs, strictly clean.** After the spanning tree, **every** remaining
   room pair (nearest-first) is tried as a **loop** edge under the *same strict test* as the tree (≥2 walls
   off other halls, ≤1 hall/side, turn-leg ≥3, no hug). Each edge that has a clean route is carved; one with
   none is rejected — so the pass adds **every loop the geometry cleanly allows and no more**. This is
   deliberately aggressive (the old pass only sampled `2·nr` candidates at 40%, so >half of large maps were
   pure trees); the strict rules **self-limit** the count, so it maximises alternate-path circle-backs
   without ever stacking, hugging, or jittering, and **cannot over-connect into a maze**. Already-carved tree
   edges re-probe as blocked (their own corridor + used sides) and are skipped, never double-carved. In
   practice this lifts large windows from ~25–48% to **~60–68% of maps with at least one circle-back** —
   ~68% being the clean-geometry ceiling, where the rest simply have no room-side pair that can connect
   without breaking a rule. Generation stays ~70 ms (≤21 candidate edges, since rooms cap at 7).
7. **Carve geometry (`connect`).** Rooms never overlap, so two rooms are joined by how they sit:
   - **diagonal** → an **L corridor** (turn out in the gap, both legs ≥3 tiles);
   - **stacked** (columns overlap) → a **straight vertical** hall if their door columns line up, else a
     clean **Z** (vertical stub · horizontal jog · vertical stub) whose doors are spread to the widest
     jog and whose stubs are clamped so all three legs are ≥3 tiles;
   - **side by side** (rows overlap) → a **straight horizontal** hall, or the same clean **Z** sideways.
   `connect` also reports `SIDEA/SIDEB` (which wall each end docks on) and `MINLEG` (its shortest turn-leg)
   so the probe can enforce the one-hall-per-side and ≥3-leg rules. Doors sit **≥2 tiles from corners on a
   ≥5-long wall, ≥1 on a short (3–4) wall** — the margin is adaptive (`hia/hib/via/vib` for the straight/L
   cases, `mwt/mwu/mht/mhu` for the Z cases all compute `dim>=5 ? 2 : 1`), so a cramped window's 3–4-long
   rooms still dock clean, corner-clear doors. (At ≥5 this is exactly the old ≥2 rule, so roomy windows are
   unchanged.)
8. **Place** the player in room 0, the **stairs in the farthest room** (a real trek), and **one money piece
   in each of `min(4 + RANDOM%5 + depth, rooms) × 7/10` randomly-chosen rooms** (never two in the same room;
   the `×7/10` is a deliberate **~30% money cut** applied *after* the per-room cap, so it bites even at deep
   floors where the raw count is already room-bound — ~2–3 pieces/floor on a roomy window).
   The stairs go on the allowed interior cell **nearest the farthest room's centre**, but **never on a row
   or column that lines up with one of that room's doors** — a door is a corridor cell (`CORR=1`) on the
   room's wall ring; a top/bottom door forbids its column, a left/right door its row. This keeps a held-arrow
   *fast-travel* from running straight through a door onto the stairs, which would skip still-unexplored rooms
   and their uncollected gold. (Falls back to the room centre only in the rare case every interior cell is on
   a door line.) **The stairs also prefer a *spaced* cell** (see the spacing rule below) among the off-door-line
   candidates. After the stairs, **stars `✱` are placed** — `STARS_HERE` of the floor's *eligible* rooms,
   ≤1 each (placed *before* gold so a star gets first pick of a spaced cell; via random tries → a spaced full
   scan → a relaxed full scan). The candidate pool is **every room including room 0** (the arrival / up-stairs
   room), **except on the game's very first floor** (realm 0 / floor 0), which reserves its room 0 so the
   opening room isn't a free star. `plan_this_floor` sets `avail` to match (`rooms` normally, `rooms-1` on that
   first floor or a lone-room floor). Then **gold** is dropped in the chosen rooms — but gold
   is **optional**: if a room has no spaced cell free it's skipped rather than crammed in. The **key `⚷` is
   *not* placed at generate time** — it spawns at *play* time (`spawn_key`) on a spaced random-room cell the
   moment the last star is collected, and lives in the per-floor overlay rather than the seed-reproducible layout.

   **Object spacing rule (`obj_ok`).** Every object — both stairs `>`/`<`, gold `$`, stars `✱`, and the key
   `⚷` — must sit with a **1-tile gap from walls AND from every other object**: a cell is legal only if it's
   plain floor and *all 8 of its neighbours are plain floor too* (no wall `#`, no map edge, no other object
   glyph, and not the start cell where `<` lands). This keeps objects from blobbing against a wall or each
   other, so each reads as its own glyph. The single `obj_ok` predicate encodes both halves and is used by
   every placement. It's **guaranteed on normal windows** (rooms there are always ≥5×5, with ample inner room),
   and **best-effort on cramped windows**: a tiny 3×3–3×4 room forced to hold two objects (e.g. the farthest
   room's stairs *and* its star) physically can't give both a full gap, so the required object (star/stairs/key)
   falls back to any free floor while gold simply skips. Measured: **100% of roomy maps fully obey it** (0
   relaxed over the six roomy sizes), ~88% across the whole matrix including the tiniest windows.

### Design invariants (verified by `rogue-tile-invariants.sh` across many sizes/seeds)

Run `./rogue-tile-invariants.sh` (in this repo) to re-check; it sources the generator's functions, builds a
matrix of maps (11 window sizes × 40 seeds = 440 by default, `-s N` to widen), asserts the rules below against
each final map, and exits non-zero on any violation. Measured over those 440+ maps spanning tiny to 150×40
windows, the kept (non-fallback) layouts show:

- **Full connectivity** — every floor cell reachable from the start; stairs always reachable (incl. tiny windows).
- **Rooms ≥3 tiles apart** (wall-to-wall) and never touching.
- **Halls stay ≥`CLR` tiles from rooms they don't connect to.**
- **No double-wide hallways** and **no jittery single-wall parallel tracks** (0).
- **At most one hallway per room side** (0 stacking; `maxDoorsPerSide == 1`).
- **No wall-hugging** — no corridor runs parallel within `HUGCLR` of any room wall (≥3 clear tiles off the
  wall on roomy windows). 0 hug-maps over 400+ maps at the windows users hit it on (large *and* cramped) —
  this was the hardest invariant to land; it took the seed-hash repro workflow to reproduce the rare
  offending Z-jogs and confirm the fix.
- **Every 90° turn-leg ≥3 tiles, and every Z-jog ≥4** (0 cramped 1-tile jogs on normal/compact windows;
  the only residual is the extreme wide-short aspect like 130×10, where there's no vertical room for a
  longer jog — geometric, still fully connected and hug-free).
- **Doors clear of corners** — ≥2 tiles on a ≥5-long room wall, ≥1 on a short (3–4) wall (adaptive margin;
  `doors-clear-of-corner`, 0 violations incl. the tiny 76×8 / 20×16 windows that exercise 3–4-long rooms).
- **At most one gold per room** (`maxGoldPerRoom == 1`).
- **≤ one star per room** — at most one `✱` per room (stars are seeded on a random subset toward the segment
  target). The harness generates the **game's first floor** (realm 0 / floor 0), whose room 0 is reserved, so
  it asserts room 0 has **none** there; on deeper floors room 0 is eligible like any room (`one-star-per-room`).
  Stars are walkable floor for connectivity, so every star is always reachable.
- **Objects spaced** — every object (`>` `<` `$` `✱` `⚷`) has a 1-tile gap from walls and from every other
  object (all 8 neighbours plain floor). Asserted on the **roomy** windows where it's guaranteed
  (`objects-spaced`, 240/240); best-effort on cramped windows where a tiny multi-object room can't fit the
  gaps (see the spacing rule in §8).
- **Stairs never on a door line** — the `>` never shares a row with a left/right door or a column with a
  top/bottom door of its room, so a held-arrow fast-travel through any door can't run onto it. 0 violations
  over 750 maps spanning roomy (60–120 wide) and cramped (26–40 wide, 11–16 tall) windows; the rare
  every-cell-blocked case falls back to the room centre (no failure, just no dodge).
- **Zero room-crossings.**

The harness checks every rule above that is re-derivable from the finished grid. The deeper **geometric
corridor** rules — no wall-hug (≥`HUGCLR`), turn-leg ≥3, Z-jog ≥4, ≥`CLR` from non-connected rooms, no
jittery single-wall parallel tracks — are enforced **constructively** by `connect_pass`'s `CHECKMODE` probe
at carve time (a corridor that would break them is never laid), so they hold by construction rather than
being re-asserted post-hoc; those were validated during development via the seed-hash repro workflow.

## Roadmap

### Done (2026-06-05) — hybrid dirty-rectangle redraw + input coalescing

**Problem.** `render` rebuilds and reprints the *entire* `W×H` coloured string on every keypress (~5.5 µs/cell).
Fine at tile size (~20 ms) but ~89 ms/frame on a full-desktop 240×67 window — slower than key auto-repeat
(~33 ms). Because the game is **turn-based** (no animation loop), the felt cost is the single keypress → screen
latency, *and* held-arrow keystrokes back up in the tty buffer faster than they're drawn, so `@` keeps moving
after you release.

**Shipped** (chosen over coalesce-only and colour-run-only — both partial). The three pieces:

1. **Hybrid dirty-rectangle.** A single step changes only a handful of cells, so repaint just those via cursor
   addressing (`\e[r;cH`) instead of the whole grid — sub-millisecond at any window size:
   - **single step (`try_move`, the hot path):** repaint the old `@` cell, the new `@` cell, and the newly-lit
     3×3 flashlight ring. Account for the **bar row (+1)** and the **left gutter (+`GUTTER`)** in the
     row/col math.
   - **big changes → keep the existing full `render` as a fallback:** entering a new room (the whole room
     lights up → `cur_room` changes), `run`/`jump` (multi-tile, already one redraw each), new map (`r`),
     descend, resize, help-exit. Worst case of a dirty-rect bug is a stale cell that a step or `r` repaints —
     never a wedged screen.
2. **Input coalescing.** Refactor the loop into `read_key` (assembles one full escape sequence) + `handle_key`
   (acts, no render). After the blocking read, **drain** any already-buffered keys (short-timeout reads — note
   `read -t 0` only *tests* availability, it doesn't consume, so use a tiny non-zero timeout like `0.001`),
   apply them all, then render **once**. Single taps still render per-move; only fast holds coalesce, bounding
   any overshoot.
3. **Reusable "force full redraw" hook.** Factor the resize/descend `CLR; render` into one entry point — the
   realm feature's floor-switch will call it verbatim to resync the screen and reset the dirty-rect's
   previous-frame assumption.

Colour-run (emit-escape-only-on-change) was skipped — once dirty-rect landed, per-frame cost stopped mattering
on the hot path.

**As implemented:** `cell_str` (single-cell colour string, kept byte-identical to `render`'s inner loop — see
the "KEEP IN SYNC" comment), `dirty_box`/`paint_dirty` (accumulate + repaint the changed box via `\e[r;cH`,
never the last column so it stays scroll-safe), `read_key`/`process_key`/`move_step` (input assembly split from
action; single steps take the dirty path, room-change/descend/`run`/`jump`/new-map/help-close go full), the
coalesce drain loop (tiny `0.005` timeout — a held key burst applies then paints once), and `redraw_all`
(clear+render; used on resize, the reusable hook for floor switches). **Verified:** `cell_str`≡`render` (0
parity mismatches); dirty-box covered every changed cell over 6219 in-room + 721 corridor steps + 100 room
transitions (0 coverage misses); invariants still 640/640. A corridor step repaints ~a 3×4 box (~300 bytes)
regardless of window size. (Committed: `fix render lag`.)

### Done (2026-06-05) — persistent world ▸ realms ▸ floors (up-stairs + back-and-forth)

An **up-stairs `<`** lets you climb back to the previous floor — to grab gold you missed — and floors now
**persist** instead of regenerating. The world is **realms** of `FLOORS_PER_REALM` (= 11) floors each.

- **Cache via regenerate-from-seed (not serialization).** Since a floor is fully determined by
  `(mapseed, W, H)`, we *don't* store its big `TILE`/`CORR` arrays. Per `realm,floor` we keep only a tiny
  overlay in assoc arrays — `WSEED` (the floor's seed), `WFOG` (discovered-cell set), `WGOLD` (collected-gold
  cells), `WSEEN` (rooms entered). Switching a floor reseeds + reruns `generate` to rebuild the *exact* layout,
  then re-applies the overlay. This is far lighter than serializing arrays, and it's **lazy** — a floor is
  built on first visit (no prebuild, no startup pause), then cached.
- **Paired stairs.** Each floor's `<` sits on its start cell (room 0 centre); `>` stays in the farthest room.
  Descending lands you on **a random tile in** the next floor's `<` room; ascending lands you on a random
  tile in the previous floor's `>` room — reversible. The landing obeys **the same spacing rule as objects**:
  `nudge_off_stair` prefers a cell with a **1-tile gap from walls AND from every object** (stair, gold, star,
  key — the `obj_ok` test) so the `@` is never dropped flush against a wall or right next to an item, and it's
  always ≥2 from the stair so it never covers the glyph. It picks one with **`SRANDOM`**, so the spot is
  **fresh on every arrival** (bouncing up/down drops you somewhere new), while the layout stays deterministic
  (`generate` reseeds `RANDOM`, which `SRANDOM` leaves untouched, so only the landing varies, never the map).
  Graceful degradation in a tight room with no fully-spaced cell: off-walls + 2-from-stair → any 2-from-stair
  floor → an adjacent `·` → staying put. Like the object-placement rule it's **fully spaced on roomy windows,
  best-effort on cramped** ones; the realm0/floor0 start has no stair under you, so it's left alone.
- **Realm boundaries.** Realm 0 / floor 0 has no `<` (top of the world). Descending past a realm's last floor
  rolls into the next realm's floor 0; ascending from a realm's floor 0 climbs into the previous realm's last
  floor — realms connect both ways and you can wander back through them.
- **Rendering ties in cleanly:** a floor switch changes `depth`, so `move_step` already routes it to a full
  `render` (no dirty-rect needed); the dirty-rect path never knows floors are cached. `r` rerolls the current
  floor (drops its cached overlay); **resize** wipes the cache and rebuilds the current floor at the new size.
- **HUD** now shows `REALM r · FLOOR f` (1-based) so realm changes are visible; the absolute `depth` moved to
  the `m` stats overlay next to the seed.

**As implemented:** `load_floor`/`save_floor_state`/`descend`/`ascend`/`reroll`/`nudge_off_stair` (world section), `<` added to
`render`/`cell_str`, stairs+gold wired into `try_move`/`run`/`jump`, `GOLDGONE` is an **indexed** array (a bug
where it was associative made arithmetic subscripts like `GOLDGONE[idx]` use the literal key `"idx"` — caught
by the headless test). **Verified:** stair pairing, deterministic revisits, fog + collected-gold persistence,
realm roll-over both directions, dirty-rect fast path intact, invariants 640/640. (Committed: `realms and
floors`.)

### Done (2026-06-11) — stars ✱ + key ⚷ + locked stairs (the explore-the-floor objective)

Fast-travel made blasting straight to the `>` trivial, so floors needed a reason to be *explored*. Mario-Maker
red-coin style: every room except the start room holds a **star `✱`** (phosphor green `#33ff33`); collect them all (= visit
every room) and a **key `⚷`** (amber) spawns on a random room's floor — grab it to unlock the floor's `>`,
which renders bold red & still while locked and bright-green/blinking once open. Bumping a locked stair explains itself on
the status bar (`LOCKED — ✱ 2/5` / `LOCKED — FIND THE ⚷`); key spawn + unlock announce there too (transient
mint messages, cleared on the next keypress). Run/jump sweep stars/key like gold; `<` is never locked; the
rare 1-room floor starts unlocked. All of it persists in the per-floor overlay (`WSTAR`/`WKEYST` join
`WGOLD`/`WFOG`/`WSEEN`), so revisits keep stars collected, the key found, the stair open. Glyphs were
font-tested in the tile terminal (Monospace 11) — `✱`(U+2731, heavy asterisk) and `⚷`(U+26B7) render; `◆◊⬢❖✦✧✸●` were the
candidates considered.

**As implemented:** star placement at the end of `generate` (8 tries + first-free scan per room ⇒ exactly
one per non-start room — new `one-star-per-room` invariant, 640/640); `collect` (shared gold/star/key pickup
for `try_move`/`run`/`jump`), `spawn_key` (play-time, random room, never under the player, full-map insurance
scan), locked check in `try_move`, `EVENT`/`BARMSG` plumbing through `move_step`/`process_key` (a bar message
forces one full render and clears on the next key), `>` lock-state colouring in `render`+`cell_str` (in sync),
HUD star counter/key indicator. **Verified:** 195/195 headless checks over 30 seeds — locked refusal+message,
key-on-last-star, unlock+descend, fresh-locked next floor, full revisit persistence, 1-room floor open at
start; HUD pads to exact width with the multibyte glyphs; invariants 640/640.

### Done (2026-06-14) — `m` stats overlay split from `?` help, both as framed table panels

Two overlays instead of one, and both redrawn as **phosphor-framed panels** (single-line box, bright title
centred in the top edge) with **aligned columns** — the old per-line `center_print` couldn't keep columns
straight. `?` is now **controls-only**, a tidy `key → short action` table; **`m`** opens a **stats panel** —
realm / floor / depth, rooms, star progress, key state (a short phrase: *held · unlocked* / *on the floor* /
*locked · N left* / *— open*), gold, then a `├──┤` divider and the floor **seed** + `WxH` map size (seed
moved here out of `?`). The full top HUD bar is unchanged — the panel is a fuller, on-demand companion.

**As implemented:** reusable bits replace `center_print` — `table2` (nameref; aligned `key/value` rows for
the stats panel, left column padded to the widest key by *visible* width via `strip_ansi`; `@RULE@` pairs
pass through as dividers), `build_2col` (lays key/desc pairs into a **two-column** grid, column-major, each
column sizing its own key/desc widths), `block_place` (prints a block at the **top-left** — left-aligned and
top-aligned, no centring — and emits **no trailing newline**, so a block exactly `ROWS` tall can't scroll the
terminal up by one), and `overlay` (frame + centred title + `@RULE@` dividers + the MORE bar, then
`block_place`). `show_help` builds a 2-col grid; `show_menu` a single-column label/value table; both call
`overlay`. The overlay is tracked by globals `OV` (`help`/`menu`/empty), `OVP` (page), `OVPAGES` (page count,
set by `overlay`); in `process_key` `q`/`Esc` closes, any other key advances `OVP` (closing past the last
page). The `?` table is **two columns** (movement & pickups | stairs & meta), halving its height so it stays
boxed on far more windows.

`overlay` fits any window without wrapping or scrolling. WIDTH: pad `2→1→0`, then clamp + `…`-truncate
over-long lines (`clip_visible`, ANSI-aware). HEIGHT: keep the **box only if it all fits one screen** (no
footer — a fitting menu has zero dead space below it); otherwise **drop the frame** and show a plain list. In
that **frameless** view `@RULE@` dividers are **dropped** (the `├──┤` separator is decoration that wastes a
precious row in a cramped list; it's kept only in the boxed view), so the whole menu often fits one screen —
when the (divider-stripped) list is `≤ ROWS` rows it's shown complete with **no MORE bar**. Only when it's
still too tall does it paginate, with a small **inverted (reverse-video) `MORE` chip docked at the very bottom
row** on every page but the last ("just show the MORE"). Paginated pages **fill**: each packs `ROWS-1` content
rows (the bottom row is the bar), so every page but the last is full and the content runs down to the chip —
no wasted rows. (Earlier this *rebalanced* to even page sizes to avoid an orphaned 1-row last page, but that
shrank every page and left blank space under the content; filling is preferred — see the 2026-06-16 note.)

The **stats panel is compact** — realm/floor/depth share one summary line and seed/map share another (7 rows
total) — so it stays boxed down to a 9-row window instead of splitting awkwardly. Verified: 2-col `?` boxed at
8 rows; stats boxed at 9; both paginate balanced on tinier windows (e.g. 3+3, 4+3).

**Caught & fixed:** two `set -u` *unbound variable* crashes from same-statement back-references
(`local fill=… lf=$((fill/2))`, `local cw=… outer=$((cw+2))`) — the script runs under `set -u`, so these
would crash on the first `?`/`m` press; split into separate `local`s. **Verified:** `bash -n` clean; both
panels rendered headlessly **under `set -u`** across a range of sizes — borders stay aligned even on glyph
rows, width clipping and multi-page splitting kick in as designed; invariants 640/640.

### Done (2026-06-15) — condensed HUD + right-aligned star/key tracker

The top bar dropped from a full stat line to a minimal **`LEVEL r/f · GOLD g`** on the LEFT (realm/floor,
world-level style; the `GOLD` label stays phosphor green while its **number lights up amber** once you hold
any) and a right-aligned **objective tracker** `⚷ [ ✱ ✱ … ]`. Everything else (rooms total, seed) lives in the
`m` overlay now.

- **Star bracket** `[ ✱ … ]` — one `✱` per star on the floor, **phosphor green** (`$STAR`) once collected,
  **dim** (`$D`) until then; phosphor-green brackets, a space between each star.
- **Key `⚷`** to the LEFT of the bracket, three colour states: **dim green** (`$D`) before it's placed,
  **gold** (`$GOLD`) once it's on the map (all stars collected), **phosphor green** (`$A`) once held.
- **Message vs tracker are mutually exclusive.** A transient bar message — `STAIRS LOCKED` / `STAIRS
  UNLOCKED`, **dim green** — takes the right side alone and hides the tracker; it **auto-clears after ~750ms**
  (while a message is up the idle poll drops to `0.075s` × `MSG_DUR_TICKS`=10) *or* the instant you move, then
  the tracker returns. The old `A KEY HAS APPEARED!` message was removed — the tracker's `⚷` turning gold says
  it; `LOCKED — ✱ n/m` / `FIND THE ⚷` collapsed to plain `STAIRS LOCKED` (the tracker shows the detail).
- **Immediate HUD refresh:** `move_step` forces a full render when `gold` or `starsgot` changes — the
  dirty-rect fast path repaints only map cells, never row 1, so without this the count lagged a turn.
- Left & right both have a 1-space inset; the right `]`/message can't wrap (`…`-clipped). **Verified:** the bar
  builds to exactly `COLS` across all states; `bash -n` clean; invariants 640/640. (Committed: `hud and
  message updates`.)

### Done (2026-06-15) — multi-floor segments, boss floors & empty floors

The objective went **realm-wide and multi-floor**. A realm is now a **chain of star-gated segments** separated
by **boss floors**, with the occasional barren **empty floor** between them; a realm's floor count is **driven
by the stars** (and window size), not a fixed `FLOORS_PER_REALM` (that constant is gone). Stars relaxed from
"one per *every* room" to "**≤1 per room on a random subset**", accumulating across a segment's floors.

**Realm structure** — `realm_plan` derives a realm's shape **purely from its index** via a tiny self-contained
LCG (touches none of `$RANDOM`, so it's identical across resize / revisit / session and caches in `RSEGS`/`RTGT`):

- **2–4 segments**, weighted to 3 (2:30% / 3:50% / 4:20%).
- Each segment a **star target 3–10**, a balanced bell centered on 6–7 (3:9% / 4:11% / 5:13% / 6:15% / 7:15% /
  8:13% / 9:12% / 10:12%) — so segment lengths vary from quick 3-star sprints to full 10-star hauls. *(Was
  6–10 weighted to 10; widened 2026-06-17 — see the note below.)*

**Per-floor planning** — `plan_this_floor` (run inside `generate`, once `NROOMS` is known) reads the floor
*above*'s plan (`WPLAN`, no `$RANDOM`) to get the current segment + running star total, then rolls a **subset
size** (≥ half the rooms, so big windows finish a segment in ~1-2 floors and small windows take more) from the
mapseed stream. It **always rolls the same way cache-or-not**, so the stream advances identically and a
revisited floor reproduces exactly. The floor whose stars complete the target is flagged the **boss**; it
places exactly the remainder. Placement is guaranteed (`STARS_HERE ≤ rooms-1`), so the segment total always
reaches its target.

**Boss floors & unlocking** — only **boss floors lock their `>`** (`try_move` keys off `IS_BOSS`); every other
floor (star-floors and empties) is freely descend/ascend-able. Collecting the **whole segment's** stars makes
the key `⚷` appear on a **random one of that segment's star floors** (not always the boss) — so completing a
segment often sends you **back up** to hunt the key, then back down to its boss. `spawn_key` only picks the
**floor** (`KEYFLOOR`, uniformly in the segment's tracked floor range `WSEGLO..WSEGHI`); `place_key_cell` drops
the actual glyph lazily the first time you're on that floor, caching the cell (per-segment `WSEGKEY` =
`spawned floor cell taken`). Grab the key → return to the boss → descend. The **last** segment's boss rolls into
a **fresh next realm**; `RLASTF` records a realm's last floor so an *upward* realm crossing lands on the right
floor. Depth is a monotonic counter cached per floor (`WDEPTH`), no longer `realm·N+floor`.

**Empty floors** — a NES-Metroid-style **transition hall** (`build_hallway`): one straight **1-tile-tall**
corridor-room of **random length at a random spot** in the window, the up-stair `<` at the left end (where you
arrive) and the down-stair `>` at the right end — no stars, no gold, unlocked `>`. You arrive at the entrance
and walk straight across to descend (arrival steps one tile *inward* from the stair, not the usual random
nudge; on the way back up you arrive just inside the right `>`) — unless a **hall monitor `&`** is posted (see
the toll section), in which case he blocks the corridor mid-way and you pay to pass. The length/position are rolled from `$RANDOM`
**seeded from the floor's mapseed**, so the hall is deterministic per floor and reproduces on revisit, while
varying floor-to-floor and game-to-game. Placement (which floors are empty) is decided in
`realm_plan` (deterministic, off `$RANDOM`): each of a realm's `segs-1` inter-segment boundaries independently
gets **0 or 1** empty floor, and **every realm is guaranteed ≥1** (forced to a single empty if all boundaries
roll 0). On top of that, **no two boundaries in a row may go without a hall** — if a boundary rolls 0 and the
previous one had none, it's forced to 1 (the streak carries across realms via `RLASTHALL`), so a hall appears
at least **every other segment**. A realm may **also** get **one back-to-back pair** (a boundary bumped to 2 empties in a row — the
cap): a random per-realm roll (`B2B_PCT`), but **only if the previous realm had none**, so doubles never land
in consecutive realms and a realm never has more than one. It's also **forced if the previous two realms both
had none**, so no 3-realm window is ever without a back-to-back (kills long droughts — you'll see one by realm
2 and at least every 3rd realm after). `RB2B[realm]` records it; `realm_plan` plans realms `R-1`/`R-2` first so
the flags are known. ~38% of realms get a back-to-back. Real segment floors always separate
boundaries, so 3+ empties in a row is impossible. The boss above queues its boundary's count via `erun` in
`WPLAN`; the floors after it read the run down.

**HUD** — the `⚷ [ ✱… ]` tracker and the `m` overlay now track the **current segment** (`SEG_GOT`/`SEG_TGT`),
resetting per segment so the bracket stays ~3-10 wide; the `m` panel gained a **`segment n/m · boss/empty`** row.
The tracker `⚷` only turns **gold once you're standing on the key's floor** (where the glyph is in view) — dim
on every other floor, so the key doesn't telegraph which floor it's on until you reach it; `m` reads
`on this floor` / `somewhere in this segment` accordingly.

**Caught & fixed during build:**

- **Associative-subscript gotcha (twice).** `arr[CUR_REALM]` / a default *indexed* array with a `"1,0"` key are
  arithmetic-evaluated (comma operator → `0`), silently colliding floors/realms. Fixed by always writing
  `${RSEGS[$CUR_REALM]}` and by declaring **all** persistent caches `declare -A` up near `generate()` (not only
  in the post-`main-loop` init the harness/sims never source).
- **Revisit determinism.** The plan's `$RANDOM` rolls must run on every regeneration (never short-circuited on a
  cache hit) or a revisited floor's gold/stars would shift; `realm_plan` stays off `$RANDOM` entirely.

**Verified:** `bash -n` clean; invariants **640/640** (the star check relaxed to "≤1 per room"); a headless
descent simulation across many RNG seeds and window sizes plays **300–400 floors / 14–33 realms with zero
place-shortfalls and zero softlocks**, collecting **every** key (the key-hunt navigates up to `KEYFLOOR` and
back) — **~70% of keys land off the boss floor** (random distribution holds), and a per-step assertion confirms
the `⚷` glyph is on the map **iff** `KEYSPAWNED && !KEYTAKEN && on-its-floor` (the exact HUD-gold rule, 0
mismatches). Ascend reversibility + revisit identity (seed/depth/tiles preserved) + upward realm crossing +
boss-lock gating + `r`-reroll re-derivation + the resize depth-walk all pass; the real game runs in a pty
without errors and the `m` overlay renders the segment/key rows.

### Done (2026-06-15) — dark mode (torch-lit room search), `d`

A `d`-toggle **dark mode** (`HARD`): rooms still reveal their **outline on entry** (walls light up as now, so you
can navigate), but the **floor interior stays dark** and only glows inside your **3×3 torch puddle** as you move
— so you physically **sweep each room** to search it. The **stars `✱` and key `⚷` are hidden** until your torch
has swept their tile, then they **stay shown** (like the corridors you've already lit). Gold and stairs stay
visible on entry. The `⚷`/`✱` HUD tracker is unchanged.

- **Light sources.** Stairs (`> <`) and money (`$`) **glow**, lighting the floor tiles in their 3×3 (`light_map`
  → a `LIGHTMAP` of lit cells) — little lanterns in the dark that also help you steer toward the exit. A star/key
  **starts hidden** but, once your torch uncovers it, **it becomes a light source too** (sits in its own pool of
  light until you collect it), so found-but-uncollected `✱`/`⚷` are beacons. `LIGHTMAP` rebuilds whenever a
  source appears/disappears: floor load, pickup, a newly-swept `✱`/`⚷` (`reveal` flags it → relight + full
  repaint, since the glow reaches past the player's own dirty box), and the toggle.
- **How it renders.** `render`/`cell_str` split floor brightness from wall brightness: a `·` is bright only
  when `intorch` **or** `LIGHTMAP[idx]` (dark mode), vs the old "whole current room is lit"; walls keep the
  room-entry lighting so the outline still pops. A `✱`/`⚷` whose cell isn't in `OBJSEEN` renders as a dim `·`.
  A freshly-spawned key **resets its own cell's `OBJSEEN`** in `place_key_cell`, so it starts hidden even when
  it lands on ground you've already swept — you re-sweep to find it, exactly like a star.
- **The torch trail** (`OBJSEEN`, set for the 3×3 in `reveal`) persists per floor exactly like fog — saved to
  `WOBJSEEN`, restored on revisit, wiped on resize, cleared on `r`-reroll. Mode is a pure render toggle: flip it
  anytime; already-swept cells stay revealed, and toggling rebuilds the light map.

**Verified:** `bash -n` clean; invariants **640/640**; per-cell `cell_str` assertions confirm — star hidden when
unswept / shown after the torch sweeps it / shown in normal mode; money-adjacent floor lit; far floor dark; room
floor **lit in normal but dark in dark mode** (only the torch lights it); room **walls still bright** on entry;
a **revealed star lights the floor around it**, and **collecting it drops the glow**. No gameplay regression
(key-aware sim: 33 realms / 400 floors, 0 softlocks, 0 HUD mismatches); a live dark-mode sweep uncovers up to 10
stars as the torch passes; the live `d`
toggle shows `DARK MODE`/`LIGHTS ON`, dims the floor, and runs in a pty without errors.

### Done (2026-06-16) — efficiency SCORE + dark mode is now the default

The HUD's stale `LEVEL r/f` became a **`SCORE`** — and dark mode stopped being a toggle. The torch *is* the game
now (`HARD=1` always, the `d` key is gone; a future shop will sell light with your gold, which is what makes gold
worth grabbing despite the step cost).

**Scoring rewards efficient searching, not hoarding.** Each star (and the key) scores the **moment you grab it**,
worth `base × your current efficiency multiplier` — so `SCORE` ticks up live as you collect, and a cleanly-found
star is worth more than one you backtracked to. The multiplier is **how much of your movement THIS phase was
*new ground* vs re-treading your own path** (`new_cells / steps`, mapped to `0.5×–3.0×`). Gold isn't in the score
at all — chasing it just *adds steps*, which quietly lowers your multiplier (the "gold is a tax" idea, no
confusing negative number).

A segment runs in two **phases** that only govern when the multiplier *resets*:

- **Phase 1 — find the stars.** Sweep the segment's floors collecting stars (each scores live).
- **Phase 2 — find the key.** The key spawns on a random segment floor; go get it (scores live).

The crucial bit (**Model A**): the step tracker **resets at the phase boundary**. So when the key appears two
floors up, climbing back to it counts as *new ground for phase 2* — you're not punished for where the key
randomly landed, only for wandering once you're hunting it. That's what lets the find-key phase "start high."

- **Implementation.** `track_step` (hooked into `try_move`/`run`/`jump`) tallies `PH_STEPS` and `PH_NEW` against
  a phase-scoped `PVIS` set keyed `realm,floor,cell` (spans floors, survives up/down trips). `score_pickup`
  pays `pts × phase_mult` into `SCORE` on every star/key; `reset_phase` clears the tracker at each boundary
  (star that completes the segment → phase 2; key → next segment's phase 1). Constants (`M_MIN/M_MAX/MULT_K`,
  `STAR_PTS`, `KEY_PTS`) are top-of-file and tunable.
- **HUD vs `m`.** The bar shows the running `SCORE` (ticks up per pickup); the **live** multiplier lives in the
  `m` stats panel (as `score N @ 3.0x`) so the bar stays calm. *(The explicit `find stars` / `find key` phase
  label was later dropped from the panel — the key-state row already implies the phase; see the 2026-06-16
  stats-reorg note.)*
- **Persistence.** Resize restarts the in-progress phase tracker (current-segment progress is lost anyway) but
  **keeps the accumulated SCORE**.

**Verified:** `bash -n` clean; invariants **640/640**; unit tests of `phase_mult` (clean 75%→3.0×, 30%→1.2×,
floor 0.5×) and the live machine — each star pays `+30` at 3.0×, a **backtracked key pays +132 (1.32×) vs a clean
+300**, the phase tracker resets so **phase 2 re-counts old floor cells as new** (Model A); no gameplay
regression (sim: ~32 realms / 400 floors, 0 softlocks); live pty confirms `SCORE` in the HUD, `LEVEL` gone, the
`d` key inert, and `m` showing `score … · find stars 2.3×`.

### Done (2026-06-16) — HUD/terrain polish + jump dash-scout

A round of readability/feel tweaks after playtesting the dark + scoring build:

- **Terrain.** Floor dots `·` are now **bold**, and the lit floor uses the same bright phosphor `A` (`#33ff33`)
  as the walls/stars — so a lit area reads as one uniform glow instead of muted floor + bright walls.
- **Key tracker — 4 shades.** The HUD `⚷` now distinguishes *not-placed-yet* (darkest `DK`) from *somewhere in
  the segment* (dim `D`), in addition to *on this floor* (gold) and *held* (phosphor) — it visibly "warms up" as
  you progress.
- **Star pips — 3 tiers (per-floor radar).** Bracket pips are collected = bright, uncollected **on this floor** =
  dim `D`, uncollected **on deeper floors** = darkest `DK`. The count of dim pips tells you exactly how many
  stars are still hidden on the current floor — fixes the "where are the last 1-2 stars" hunt.
- **Empty floors hide the tracker.** On an `IS_EMPTY` between-segments floor (nothing to find), the right side
  of the bar is blank — no stars/key tracker — so it's obvious you're just passing through.
- **Jump dash-scout.** `Ctrl+arrow` jump now also **uncovers stars/key up to `SCOUT` (=2) tiles off its
  path**, but only on floor you've already seen (no peeking through walls into new rooms); uncovered items show
  and start glowing. A scout dash that still costs its steps toward your efficiency multiplier, so it's not free.
  *(2026-06-16: extended to run too — see below; the constant was renamed `JUMP_SCOUT` → `SCOUT`.)*

**Verified:** `bash -n` clean; invariants **640/640**; per-cell/real-`render` checks of the 3-tier pips
(`[ B…B d x x ]`), the 4-shade key, the empty-floor blank tracker, and the jump scout radius/DISC-gating; live
pty runs clean.

### Done (2026-06-16) — arrival room (room 0) is star-eligible except on the game's first floor

Descending always drops you into **room 0** (the floor's up-stairs `<` / arrival room), and room 0 was
reserved star-free on *every* floor — so every floor you descended into opened on a guaranteed-empty room,
which read as "the up-stairs floor never has stars." Combined with dark mode (stars stay hidden until your
torch sweeps them), an arrival looked starless even though the *other* rooms held stars.

Now only the **game's very first room** (realm 0 / floor 0 / room 0 — the one floor with no up-stairs) stays
reserved; **every other floor's room 0 is a star candidate like any room**. A lone-room floor (`NROOMS==1`)
still seeds none (the deliberate breather).

**As implemented:** `plan_this_floor` sets `avail` to `rooms` (was `rooms-1`) unless it's realm 0 / floor 0
or a 1-room floor; the star placement loop in `generate` builds its candidate `rord` from room `1-star0`
upward (`star0=1` ⇒ include room 0) where `star0` is on for any floor past the very first. The plan's
per-floor `$RANDOM` draw count is unchanged (one roll regardless of `avail`), so the WPLAN chain and revisit
determinism are preserved. **Verified:** `bash -n` clean; invariants **640/640** (the harness only generates
the first floor, where room 0 stays reserved); a faithful `load_floor`/`descend` probe shows deeper floors'
room 0 now drawing stars (and floor 0 still empty); a segment-completion sim across 4 sizes × 4 realms confirms
each segment's placed stars still sum **exactly** to its target with a boss flagged (no softlock); the new path
runs clean under `set -u` with no stderr.

### Done (2026-06-16) — run (Alt) also dash-scouts; scout dropped from the help

The dash-scout (uncover stars/key off the path on already-seen floor) was jump-only; now **run/travel
(`Alt+arrow` / `H J K L`) scouts too** — since both are fast-sweep moves, both should reveal the last item or
two in a room you're crossing. The scout logic was factored out of `jump` into a shared **`scout()`** helper
(sweeps the `SCOUT`-radius box around the hero, uncovers a `✱`/`⚷` only if it's `DISC`-seen and not yet
`OBJSEEN`, returns 0 if it found something so the caller relights); `run` and `jump` each call `scout && nl=1`
per step and `light_map` once after. The constant `JUMP_SCOUT` was renamed **`SCOUT`** (no longer jump-only).
The `?` help dropped the `scout items` note on `Ctrl+arrows` (now just `jump 10`) — scouting is assumed for
both fast moves now, so it's no longer worth a HUD line.

**Verified:** `bash -n` clean; invariants **640/640**; an isolated `scout()` unit test confirms it uncovers
in-range stars/key, ignores out-of-range items, and **respects the DISC gate** (no peeking into unseen rooms);
a live pty run exercising `Alt`-run and `Ctrl`-jump in all four directions runs clean, with the `?` overlay
showing `jump 10` and no `scout` text.

### Done (2026-06-16) — paged-overlay MORE bar: no divider in list view, bottom-docked, filled pages, just "MORE"

On cramped windows where the `?`/`m` overlays paginate, the MORE bar floated **right below the content** with
dead space beneath it, it read `MORE  1/2  ▾ press any key` (more text than the small chip needs), and the
`├──┤` divider ate a precious row that often forced an extra page. Four fixes:

- **No divider in the frameless list.** `@RULE@` dividers are now **dropped in the frameless (list) view** —
  the separator is decoration, and skipping it usually lets the whole menu fit one screen (e.g. the `m` panel's
  9 entries become 8, fitting a 9-row window with the seed row and **no MORE** at all). The `├──┤` divider is
  kept in the **boxed** view, where it looks right and costs nothing.
- **Fits-one-screen frameless.** When the (divider-stripped) list is `≤ ROWS` rows, it's shown **complete with
  no MORE bar** (`cap=total`, `OVPAGES=1`), instead of always reserving a row for a bar it doesn't need.
- **Filled pages (no rebalance).** When it *does* still paginate, pages were *rebalanced* to even sizes
  (`cap=ceil(total/pages)`), which shrank **every** page and left blank rows under the content. Dropped the
  rebalance: each page packs the full `cap = ROWS-1` content rows, so every page but the last fills the screen.
- **Bottom-docked, trimmed bar.** The paged branch pads to `ROWS-1` so the bar lands on the very bottom row,
  and the chip says just **`MORE`** (page count + "press any key" dropped — any key pages, `q`/Esc closes).

Framed (boxed) overlays are otherwise unchanged.

**As implemented:** in `overlay`'s height block, the frameless branch strips `@RULE@` from `content`, then
takes a single-page path (`total<=ROWS`) or fills `cap=ROWS-1` pages; the render tail is `if framed … elif
more-pages …`, the paged branch padding to `ROWS-1` then appending `${REV} MORE ${R}`. **Verified:** `bash -n`
clean; headless `m`-panel renders — `ROWS=9` shows all 8 rows (incl. seed) with **no separator and no MORE**,
`ROWS=8` likewise fits all 8, `ROWS=13` stays **boxed with the `├──┤` divider**; a live pty `m` at 62×9 / 62×10
shows the full panel on one page, no separator, no MORE; paging/close still work where it does paginate.

### Done (2026-06-16) — `m` stats panel reorg (tighter meta block, items pinned bottom)

Reshuffled the `m` panel so the **meta** lines sit on top and the **collectible items** (stars / key / gold)
stay pinned at the bottom as a group:

- **`score N @ 3.0x`** — the score row absorbed the multiplier via a compact `@ Mx` shorthand, and the verbose
  `· find stars` / `· find key` phase label was dropped (the key-state row already implies which phase you're
  in, so the label was redundant).
- **`segment X/Y · rooms a/b`** — segment and rooms now share one line (they were two), saving a row.
- **`seed … · map W×H` moved up** above the divider, so the three item rows are the last thing in the panel.
- **Key row = lock state, two words.** The `key` row reports only **what the key unlocks** (the segment's boss
  `>`): `[locked]` until you grab the key, then `[unlocked]` — in **phosphor-green brackets with dim text**.
  *Where* the key is and whether it's been picked up is the job of the top-HUD `⚷` tracker, so this row stays a
  simple two-state lock indicator (replacing the old overloaded `[open]` / `[locked · N ✱ left]` /
  `[on this floor]` / … forms). Score spacing also tightened to a single space around the `@` (`score 0 @ 3.0x`).
- **Gold amount in amber.** The `gold` row's number lights up **amber** (`$GOLD`) once you hold any, dim at
  zero — matching the top-HUD gold readout.

Net: the meta block is 4 lines (realm/floor/depth · score · segment/rooms · seed/map), a divider, then the 3
item rows — one row shorter than before, so it boxes on smaller windows and (with the frameless divider drop)
fits even more cramped ones whole. **Verified:** `bash -n` clean; live pty `m` at 62×10 / 40×16 renders the
boxed panel with `score 0 @ 3.0x`, `segment 1/3 · rooms 1/3`, seed/map above the `├──┤`, `⚷ key [locked]` in
the items below; at 62×9 it's frameless with no divider/no MORE and the items still last.

### Done (2026-06-17) — segment star-targets widened to 3–10 (balanced bell)

Segment star-targets were **6–10 weighted hard toward 10** (10:40%, and **0%** below 6), so segments were
almost always long and you never got a short one. Widened the `realm_plan` weighting to the **full 3–10 range
as a balanced bell centered on 6–7** (3:9 / 4:11 / 5:13 / 6:15 / 7:15 / 8:13 / 9:12 / 10:12 %), so lengths now
vary from quick 3-star sprints to full 10-star hauls (lows 3–6 ≈ 48%, highs 7–10 ≈ 52%). It's still **one LCG
roll per segment** (the realm plan stays a pure function of the realm index, off `$RANDOM`), so resize/revisit
determinism is unchanged. **Verified:** `bash -n` clean; measured distribution matches the bell over 8.7k
segments; a segment-completion sim across 4 window sizes × 8 realms confirms **every** segment — down to the
new 3-star ones — still places exactly its target with a boss flagged (no place-shortfall, no softlock);
invariants **640/640**.

### Done (2026-06-17) — empty floors: guaranteed ≥1 per realm, random count, up to 2 back-to-back

Empty (between-segments) floors were rolled independently per boundary (~18% / ~5%), so a whole realm could —
and often did — have none; you could play two realms and never see one. Moved the decision into `realm_plan`
(deterministic, off `$RANDOM`) and reshaped it:

- **Guaranteed ≥1 per realm.** Each of the `segs-1` inter-segment boundaries rolls **0/1/2** empties
  (`EMPTY1_PCT=45` / `EMPTY2_PCT=15` / else none); if every boundary rolls 0, a random boundary is forced to a
  single empty. So there's always at least one breather.
- **Count is the random part.** Per-realm empties land **1 (57%) / 2 (27%) / 3 (12%) / 4–5 (rare)**.
- **Back-to-back, capped at 2.** A boundary can roll 2 empties in a row (random, ~28% of realms have a pair);
  never 3+, since real segment floors always separate boundaries. The boss queues its boundary's count as an
  `erun` countdown in `WPLAN`, and the following floors walk it down.

Empty placement no longer touches `$RANDOM` (only the per-floor star subset does), so resize/revisit
determinism is unchanged. The old `EMPTY_BOUNDARY_PCT` / `EMPTY_EDGE_PCT` constants (and the realm-opening
filler roll) are gone. **Verified:** `bash -n` clean; a descent sim over 120 realms (3 window sizes) confirms
**every realm has ≥1 empty, never >2 in a row, and every segment still completes** (no softlock); empties rose
from ~2.7% to ~12% of floors; invariants **640/640**; live pty descent runs clean.

### Done (2026-06-17) — empty floors are NES-Metroid transition halls

Empty floors used to generate a full scattered-room layout (just with no stars), which read like any other
floor. Now an empty floor is a **straight horizontal transition hall**, like the in-between corridors in NES
Metroid: a single **1-tile-tall** corridor-room of **random length at a random spot** in the window, with the
up-stair `<` at the **left** end and the down-stair `>` at the **right** end. You arrive at the entrance and
walk straight across to descend — a clear, calm breather.

- **`build_hallway`** lays it out: one `ROOM[0]`, 1 tile tall, a random length (~40–100% of the width but
  **capped at `HALL_MAXLEN`=60 tiles** so wide windows don't get an absurdly long full-width corridor; small
  windows are under the cap anyway) at a random row/column, with both stairs on its row. No stars, no gold. The
  length/position are rolled from `$RANDOM` **seeded from the floor's mapseed**, so revisits reproduce while
  halls vary floor-to-floor and game-to-game.
- **`generate` branches early.** A new `floor_is_empty` peek (reads the floor-above's `WPLAN` — no `$RANDOM`,
  no room count) lets `generate` choose the hall path *before* the scatter and `return` after
  `build_hallway` + `plan_this_floor` + `reveal`. The normal scatter path is untouched.
- **Entrance arrival.** Added `STARTR`/`STARTC` (the `<` / descend-arrival cell) so `load_floor` no longer
  hard-codes room-0 centre; a hall sets them to its left end. On a hall the arrival nudge steps one tile
  *inward toward the far stair* (right when descending, left when ascending) instead of the random spaced
  nudge, so you always start at the door you came in and traverse the corridor.

**Verified:** `bash -n` clean; a forced-empty descent dumps the expected hall (one `<` left, one `>` right,
same row, `@` one tile inward) and the corridor is fully connected `@`→`>`; ascending back lands just inside
the right `>`; a sim over 60 realms confirms every empty floor has exactly one `>` and 0 stars while the
guarantee/cap/segment-completion all still hold; invariants **640/640**; live pty descent runs clean.

### Done (2026-06-17) — back-to-back halls: ≤1 per realm, never in consecutive realms

Letting every boundary independently roll a 2 (back-to-back) made doubles too common — a realm could have
several, and they showed up realm after realm. Tightened to: a boundary's base roll is now only **0 or 1**
empty, and a realm gets **at most one** back-to-back pair, granted by a single random per-realm roll
(`B2B_PCT=35`) **only if the previous realm had none** — so back-to-backs never land in consecutive realms.

- `realm_plan` now records `RB2B[realm]` (did this realm get a double) and **plans realm `R-1` first**
  (a guarded recursion — instant on the cache hit you get in normal sequential play) so `R` can read the
  previous realm's flag. `RB2B` is a deterministic function of the realm index, survives resize/reroll like
  the rest of the realm plan, and never touches `$RANDOM`.
- The guarantee (≥1 empty/realm) and the 2-in-a-row cap are unchanged.
- **(Same-day follow-up)** Added an anti-drought floor: a back-to-back is also **forced when the previous two
  realms both lacked one** (`force` when `R≥2 && !RB2B[R-1] && !RB2B[R-2]`, reading `RB2B[R-2]` via the same
  recursion). So no 3-realm window is ever without one — first by realm 2, then at least every 3rd realm. Lifts
  the rate to ~38%. (Came from an hour of play with zero back-to-backs sighted.)

**Verified:** over 5000 realms — **max 1 back-to-back per realm, 0 consecutive-realm doubles, max gap of 2 dry
realms (every 3-window has one), first by realm 2, every realm ≥1 empty**; a descent sim (2 window sizes) shows
max 2 empties in a row and every segment still completing; invariants **640/640**; live pty clean.

### Done (2026-06-17) — fast-travel stops at every object & stair (no auto-collect, no passing the up-stair)

Run (`Alt`/`HJKL`) and jump (`Ctrl`) used to sweep *over* gold/stars/keys and `collect` them mid-travel — so
you'd pick things up without noticing — and the in-room "stop level with the stairs so you can turn to them"
logic only covered the **down**-stair, so runs blew straight past the **up**-stair `<`. Two fixes:

- **Stop at any non-floor tile.** Both run and jump now break when the next tile is anything but plain floor —
  a wall, a stair, **or** an object (`$ ✱ ⚷`) — and the `collect` calls were removed from both. So fast-travel
  **halts one tile short** of every item and stair; you step onto it yourself to grab/use it. No more
  accidental pickups (and the "gold is a tax" step-cost stays a conscious choice).
- **Up-stair is now a stop point.** Added the up-stair (`UPSTAIRR/UPSTAIRC`) to run's in-room level-with
  check, mirroring the down-stair, so you stop level with `<` and can turn to it (fixing the asymmetry where
  `>` stopped runs but `<` didn't). `UPSTAIRR=-1` (realm 0/floor 0, no up-stair) naturally never matches.
- **Stop in line with any visible object.** New `aligned_object` helper: while fast-travelling in a room, run
  *and* jump halt the moment the hero's column (moving horizontally) or row (moving vertically) lines up with a
  visible object elsewhere in the room — so you can turn and walk straight to it instead of passing its line.
  Gold `$` always counts; a star/key counts once the torch has revealed it (`OBJSEEN`), so it never stops for
  something you can't see. Because the check runs *after* the step, the next run moves off the aligned line —
  no getting stuck at an object's column.

Single-step movement (`hjkl`) still collects/descends normally — only fast-travel changed. **Verified:** unit
tests — run halts adjacent to gold with **gold uncollected** (tile intact), adjacent to `>` and `<`, **level
with the up-stair's column**, **level with an off-line gold's column and a star's row**, and continues past an
aligned object on the next run (not stuck); invariants **640/640**; live pty run/jump
in all directions clean.

### Done (2026-06-17) — the hall monitor `&`: gold finally matters (a toll to pass)

Gold was a pure tax (it cost steps → lowered your score multiplier, but bought nothing). Now a **nerdy
hall-monitor NPC `&`** posts up in transition halls and demands a **toll** to let you pass — so gold is
*mandatory* progress, and grabbing it (which dents your efficiency multiplier) is a real trade-off against
score.

- **Gold value is now fixed at placement.** Each `$` gets a random `1–20` value when the floor is built
  (`GOLDVAL[cell]`), not when picked up — so a floor's (and a segment's) total gold is *known*. `collect` pays
  the stored value; each floor's total is cached in `WFGOLD`.
- **The monitor & his fee.** `place_monitor` spawns the `&` (bold cyan) on the **first hall of a segment
  boundary** (so a back-to-back isn't double-charged) that's long enough and has gold to charge for (an
  "eligible" hall, flagged `WHALLELIG`). Normally a `TOLL_PCT=60` roll — but **forced if the previous two
  eligible halls both had no monitor** (a backward walk over `WHALLELIG`/`WHASMON`), so you **never pass 3
  eligible halls in a row without one** (~72% staffed in practice). Seated clear of both arrival cells. His fee
  (`compute_toll`) is **`TOLL_FRAC=85%` of *all* the gold dropped since the previous
  tolled hall** — not just the last segment. It walks up the floor chain summing each floor's cached `WFGOLD`
  and stops at the nearest floor that itself had a monitor (`WHASMON`, which already charged for the gold above
  it), crossing realms via `RLASTF`. Fully deterministic; if several segments pass with no monitor, the next
  one bills for the whole stretch. Halls too short to seat him, or a stretch with no gold, get no monitor.
- **Bump to pay, then hop over.** The `&` blocks the 1-wide corridor. Stepping into him pays if you can afford
  it (deducts, `PAID ng`) then **hops you to the far side — skipping his cell — and he stays put**; once paid
  you hop past him freely in either direction. If you can't afford it he refuses (`PAY ng TO PASS`) and you're
  stuck — backtrack up (free) to grab gold you skipped. He's a permanent fixture (`place_monitor` always seats
  him; the `WTOLLPAID` flag, not his presence, tracks payment). Fast-travel (run/jump) stops one tile short of
  him like any object, so you never auto-pay. `WTOLLPAID` persists per floor and survives resize.

This is the **first real gold sink** (the tabled shop can come later and spend the surplus). **Verified:**
blocked with too little gold (`PAY 23g`, monitor stays); paying deducts exactly, clears the `&`, passes
through, persists across a revisit; gold pickup pays the fixed placement value; fast-travel halts at the `&`;
invariants **640/640**; live pty clean.

### Done (2026-06-17) — corridor & hall length caps for wide windows

On medium/large windows the few (≈4) scattered rooms spread far apart, so connecting corridors grew huge — a
**240-wide window had corridors up to 136 tiles** (150→88, 120→73). Capped both kinds of long hall:

- **Transition halls** (`HALL_MAXLEN`=60): `build_hallway`'s random length is capped at 60 (small windows are
  under it anyway).
- **Room-to-room corridors** (`CORR_MAXLEN`=60): two cooperating changes. The scatter **clusters** — a new
  room must land within a `CORR_MAXLEN` corridor (wall-gap `dgx+dgy`) of an already-placed room, so a
  short-corridor spanning tree always exists; and the strict connect pass gains a 5th rule `CHKLEN` that
  **rejects any corridor longer than `CORR_MAXLEN`**. The graded fallback drops `CHKLEN`, so connectivity is
  never sacrificed.

**Verified:** longest straight corridor run by window — 240→**44**, 150→**48**, 120→**60**, 90→29, 40→14 (all
≤60, down from 136/88/73); **0/12 disconnected** on every size; generation stays ~115–300 ms/floor (the 240
costs more from extra re-scatters); invariants **640/640** — the `objects-spaced` assertion was tightened to
only require spacing for objects in rooms ≥5 in *both* dims (a 3-tall big "hall" chamber genuinely can't fit a
vertical gap — already documented best-effort, but the harness had over-asserted it); live pty clean at 150 &
240 wide.

### Done (2026-06-18) — anti-drought guarantees: a hall every other segment, a monitor every ≤2 halls

Two streak guarantees layered on the existing random rules:

- **A hall at least every other segment.** Inter-segment boundaries still roll 0/1 per the empty-floor rule,
  but now **never two in a row without a hall** — a 0 after a 0 is forced to 1, and the streak carries across
  realms (`RLASTHALL[realm]` = did the last boundary get a hall). So the longest hall-less stretch is one
  boundary. (Verified: longest hall-less run = 1 over 758 boundaries.)
- **A monitor at least every two halls.** `place_monitor` marks each eligible hall (`WHALLELIG`) and walks
  back over prior eligible halls; if the last two had no monitor it **forces** one, so you never pass 3
  eligible halls without a toll. Lifts staffing from ~60% to ~72% of eligible halls. (Verified: longest
  monitor-free run of eligible halls = 2.)

Both are deterministic (off `$RANDOM`, rebuilt on resize where layout-dependent) and don't disturb the gold
guarantee, the ≤1 back-to-back rule, or segment completion. **Verified:** invariants **640/640**; segment-
completion sim clean; live pty clean.

### Done (2026-06-26) — theme ride: `c` cycles custom / accent / green (contrast-anchored truecolor)

The fixed ko-matrix green became **three per-session palettes** cycled by **`c`**, so the dungeon can re-colour
itself from whatever terminal theme is running:

- **`mode 0` — custom (default).** The original Matrix Vivid truecolor green (player `#5FFF8F`, lit `#33FF33`,
  seen `#43904F`, unexplored `#204828`, HUD bar `#102A10`), unchanged.
- **`mode 1` — ride the accent** (palette **slot 4**) and **`mode 2` — ride green** (**slot 2**). A ride mode
  **queries the live terminal** over OSC for its background (`OSC 11`) and the chosen slot's hue (`OSC 4`), then
  **synthesises the `@`/lit/seen/unexplored ramp in truecolor anchored to that background** — `lit` = the hue at
  full, `seen`/`unexplored` blend 45%/72% toward the bg, `@` pushes 35% toward the opposite contrast extreme
  (white on dark, black on light) so it always pops, and the HUD bar is the bg tinted 18% toward the hue. So it
  stays legible on **any** scheme, dark or light.
- **Legibility = contrast *ratio*, not distance.** A WCAG-style ratio of hue-vs-bg luma (with a `+13` ≈ 0.05
  floor on the 0–255 scale): under **2:1** → invert the hue; still under 2 (mid-gray on mid-gray) → shove it
  60% toward the extreme. The threshold is 2 (not 3) on purpose — the theme's own colours are kept unless they
  read as genuinely illegible.
- **Semantic glyphs keep their hue in every mode** — gold key/money, the cyan hall monitor, the green/red stair
  blocks — so meaning-colour never rides.
- **Background handling.** Custom mode forces green-on-black via `OSC 10/11` (so every reset lands on black);
  switching to a ride mode lifts that first (`OSC 110/111`) so `set_palette`'s `OSC 11` query reads the theme's
  *real* bg before it builds the ramp. All restored on exit.
- **Focus-in auto-refresh.** Focus reporting (`\e[?1004h`) is enabled; a focus-in (`\e[I`) in a ride mode
  **re-queries the theme** (and redraws an open overlay), so changing the terminal scheme while away and
  clicking back updates the palette with no keypress. Disabled on exit so the shell doesn't keep receiving the
  reports.

**As implemented:** `osc_color` writes the query to `/dev/tty` and reads the reply with a 0.2s timeout, setting
`QR/QG/QB` as **globals in the caller's shell** — reading the reply inside a `$()`/`<()` subshell is unreliable
and silently fails (that bug had made ride mode fall back to flat ANSI tiers). `mix` blends two RGBs by a
percentage into an SGR string; `set_palette`'s `case $mode` builds either the custom constants or the ride ramp
(with the ANSI fallback when the OSC query goes unanswered). `c` is handled in `process_key`
(`mode=(mode+1)%3`, toggle the forced bg/fg, then rebuild), and `\e[I` focus-in is handled both in the main loop
and while an overlay is open. **Verified:** `bash -n` clean; the theme is a pure render/palette concern (it never
touches `generate`), so the design **invariants are unaffected** and still hold (192/192 over 16 window sizes);
rides confirmed legible across dark and light terminal schemes, with the OSC-timeout ANSI fallback covering
terminals that don't answer.

### Done (2026-06-27) — hall monitor is a 3-stage bump conversation (with a sticky message)

The monitor used to take your gold and hop you over in a **single** bump — silent, easy to trigger by accident,
and the confirmation flashed past in ~750ms. It's now a deliberate **bump-by-bump conversation** that tells you
what's happening and holds its message up:

- **1st bump — status.** He announces the toll (`TOLL 17g · BUMP TO PAY`); or, if you can't afford it, the
  shortfall (`TOLL 17g · NEED 7g MORE`); or — once paid — `PAID 17g · FREE TO PASS`. No charge, no move.
- **2nd bump — pay.** Deducts the toll (`PAID 17g · BUMP TO PASS`); if you still can't afford it he just
  re-tells the shortfall and stays put.
- **3rd bump — pass.** Steps you past him to the far side (he stays put). An **already-paid** monitor skips the
  pay stage, so it's a **2-bump** pass (status → pass).
- **Honours fast travel.** The pass bump respects the move you used: a plain arrow steps through, while
  `Alt`+arrow (run) / `Ctrl`+arrow (jump) carry you past him *and keep travelling* down the hall toward the
  `>`. Run/jump into an un-greeted monitor advance one conversation step and **stop adjacent** (talk/pay), so
  you never auto-pay or auto-pass by sweeping into him.
- **Sticky message.** Unlike the auto-clearing `STAIRS LOCKED`/`UNLOCKED` lines, the monitor's message **stays
  up in the HUD until your next action** — a new `STICKYMSG` flag exempts it from the ~750ms idle auto-clear and
  the fast-poll — so you can actually read it. Any keypress (bumping again, paying, walking away) dismisses it;
  resize drops it.

**As implemented:** a shared `bump_monitor` helper (the status/pay/pass state machine) replaces the old inline
block in `try_move` and is also called from `run`/`jump` — it returns 0 when the hero stepped past (so the
caller keeps travelling) and 1 when it only talked/charged (so the caller stops). `TOLLPHASE` tracks the stage
per floor visit (reset in `load_floor`, so each arrival re-greets); persistent payment still lives in
`WTOLLPAID`. `STICKYMSG` guards the message timer in the main loop. **Verified:** `bash -n` clean; invariants
hold (the monitor is gameplay, not generation); headless tests of the 3-stage flow (afford → status/pay/pass;
can't-afford → shortfall, then pay; already-paid → 2-bump pass) and the sticky-flag lifecycle. A
`monitor-test.sh` launcher — it pre-seeds realm 0 to a 1-star boss + an always-staffed hall, reusing the real
game unchanged — makes the `&` reachable in **one descent** for playtesting.

### Done (2026-06-27) — the hall monitor PACES (turn-based), keeping a 3-tile gap from the stairs

The monitor was a static `&` parked mid-hall. Now he **walks his beat** — turn-based, like a roguelike monster:

- **Moves when you move.** Each move you make advances him one tile along the hall; he reverses at the ends of
  his patrol. There's **no timer** — the game stays redraw-on-input (~0% idle CPU); he simply takes his step on
  your turn, inside `move_step`/`run`/`jump`.
- **One step per *command*, not per tile.** A single step nudges him one tile; a **fast-travel** (`Alt` run /
  `Ctrl` jump) of many tiles also nudges him just **one** — so sweeping down the hall doesn't make him sprint
  alongside you. (Gated on you actually moving — a blocked move, or a bump, doesn't advance him.)
- **3-tile gap from each stair.** His patrol is `[STARTC+4, STAIRC-4]`, so he never comes within **3 floor
  tiles** of either the up-stair `<` or the down-stair `>` — the landing zones stay clear. A hall must be
  **≥11 wide** to fit the gap plus a patrol cell; shorter halls get no monitor (the streak/force staffing logic
  already handles "no monitor here").
- **Holds when you're adjacent** (and never steps onto you), so you can always bump him to talk — the 3-stage
  status → pay → pass conversation is unchanged. Walk away and he resumes pacing.

**As implemented:** `pace_monitor` (one patrol step within `[TOLL_LO,TOLL_HI]`, bouncing at the ends, held when
the hero is adjacent) is called once per hero step from `move_step` (which dirties his two moved cells via the
`MON_*` globals for the single-step fast path) and once per command from `run`/`jump` (which full-render anyway,
gated on `pr0/pc0` movement). `place_monitor` seeds `TOLL_LO`/`TOLL_HI`/`TOLL_DIR`; the hall is one fully-
revealed room, so he stays visible (bold cyan) the whole way. **Verified:** `bash -n` clean; invariants hold
(the monitor is gameplay, not generation); headless tests of the patrol bounce, the adjacency / onto-hero hold,
the 3-tile stair gap on generated halls (0 violations over a full patrol), and one-step-per-command for single /
run / jump. The `monitor-test.sh` launcher reaches him in one descent.

### Done (2026-06-29) — `t` tileset toggle + a DOS/Epyx Rogue skin

A `t`-key tileset toggle (per-session, like the `c` theme) that re-skins the **map look** without touching the
logical `TILE` grid — so all game logic, collision, and the invariants are unaffected. `set_tiles` fills the
`T*` glyph vars + a `TDOS` flag that `render`/`cell_str` read; default is the original look, `t` switches to a
faithful **IBM-PC DOS Rogue** skin (all standard Unicode — *no special font required*):

- **Double-line orange walls, room-only.** Each `#` border cell renders as a connected double-line glyph
  (`╔═╗║╚╝╠╣╦╩╬`, from a 4-neighbour bitmask into `BOXCH`) — but a wall only draws if it borders a **room**
  interior (`_roomwall`), so corridors stay bare and rooms read as clean rectangles. Glyphs are memoised per
  floor in `BOXMAP`.
- **Gray `▒` corridors** in black void; **green `·`** room floors; **classic ASCII entities** (`@ & $ ✱ ⚷ ≡`).
- **Orientation-aware doors** (`_door` → `DOORGLYPH`): `║` for a vertical corridor through a horizontal wall;
  `╬` for a horizontal corridor through a vertical wall (joins the wall up/down **and** runs the passage into
  the room — fixing an earlier gap where a bare `═` floated, disconnected from the `║` walls). Doors **dim with
  their room** (`DOS_DOOR`/`DOS_DOOR_DIM`, gated on `lit`) like the walls.
- **Hero cell-fill in hallways** (`DOS_HALL_BG`): the `@` gets a gray background on corridor tiles so it doesn't
  leave a black hole in the gray hall (DOS-mode only).
- **Fixed DOS palette** (orange/gray `DOS_*` SGRs) overrides the `c` theme while DOS mode is on; the default
  tileset is byte-identical to before and still follows the theme.

The **pixelated** DOS rendering is a terminal-**font** matter, not the game's — pointing the tile terminal at a
CP437 bitmap font (e.g. **More Perfect DOS VGA**, already installed, which covers every glyph used) gives the
authentic blocky look. *(An earlier Nerd-Font icon tileset was prototyped and dropped in favour of this — the
DOS look needs no special font and matches the target screenshots.)*

**Verified:** `bash -n` clean; invariants **80/80** (render-only, generation untouched); headless unit/render
tests of the box-wall connection (clean room rectangles, bare corridors), orientation-aware doors with no gap,
doors dimming when their room isn't active, and the `@` gray-fill gated on `TDOS` + a corridor tile; default
tileset renders byte-identical to before.

### Tabled

- **DOS-mode CP437 entity glyphs** — under a DOS VGA font, the star `✱` (U+2731) and key `⚷` (U+26B7) are the
  only glyphs *not* in CP437, so they'd fall back to a smooth font. A DOS-mode swap (star → `*`, key → a CP437
  symbol) would make it 100% pixel-consistent; deferred pending a key-glyph choice.
- **Shop / light items** — spend gold on torches/lanterns that widen the light radius or temporarily reveal a
  floor. Gold now has a real use (the hall-monitor toll), so a shop would be a *second* sink spending the
  surplus you bank from under-tolled segments; still the reason dark mode is permanent.
- **Nerd Font tileset** — a `t`-cycle (ascii/unicode/nerd) with ASCII fallback; icons for
  player/monsters/coin/weapon/potion/scroll/key/star. User has `CaskaydiaCove Nerd Font Mono`, but the tile
  terminal is `Monospace 11` so icons render as tofu until the font is set. (Monsters still don't exist;
  items today are gold `$`, stars `✱`, and the key `⚷` — all picked to render in plain Monospace.)

## Related

Part of the ko-matrix TUI dashboard tile set (`sys-tile`, `snake-tile`, `vtop`, `btop-cpu`, `tty-clock`).
Theme palette is shared across xfce4-terminal, vim, bat, and the Claude Code TUI.
