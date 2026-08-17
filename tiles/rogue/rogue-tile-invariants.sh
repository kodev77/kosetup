#!/usr/bin/env bash
# rogue-tile-invariants.sh — regression harness for the rogue-tile dungeon generator.
#
# Sources the generator's functions out of the installed script (everything up to the main loop),
# generates a matrix of maps across window sizes and seeds, and asserts the design invariants
# documented in rogue-tile.md against each FINAL map state (TILE/CORR/ROOM* arrays).
#
#   ./rogue-tile-invariants.sh                 # default matrix
#   ./rogue-tile-invariants.sh -s 80           # 80 seeds per size (default 40)
#   RT_BIN=~/.local/bin/rogue-tile ./rogue-tile-invariants.sh
#
# Exit status is non-zero if any invariant is violated. Per-invariant pass/fail counts are printed.
#
# Scope: this checks the invariants that are re-derivable from the final map — stairs-off-door-line,
# connectivity, gold/door/crossing/overlap rules. The deeper *geometric* corridor rules (no wall-hug,
# turn-leg >=3, Z-jog >=4, >=CLR from non-connected rooms, no jittery parallel tracks) are enforced
# CONSTRUCTIVELY by connect_pass's CHECKMODE probe at carve time and aren't cheaply reconstructed from
# the finished grid, so they're out of scope here (validated during development via the seed-hash repro
# workflow instead).

set -u
# Default to the script sitting next to this harness (the repo copy), so the harness is self-contained;
# override with RT_BIN=... to test a different build (e.g. the ~/.local/bin symlink).
RT_BIN=${RT_BIN:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/rogue-tile}
SEEDS=40

while (( $# )); do
  case $1 in
    -s) SEEDS=$2; shift 2;;
    -b) RT_BIN=$2; shift 2;;
    -h|--help) sed -n '2,18p' "$0"; exit 0;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

[[ -r $RT_BIN ]] || { echo "cannot read generator: $RT_BIN" >&2; exit 2; }

# Pull in the generator's functions WITHOUT running its main loop (the UI).
source <(sed '/^# --- main loop/,$d' "$RT_BIN")
set +u   # our own harness code below is defensive; don't inherit the game's strict-mode for it

# Window matrix: roomy (HUD + border + controls) and cramped (compact, smaller rooms / tighter spacing).
SIZES=(
  "60 24" "70 24" "90 30" "120 30" "150 40" "56 20"     # roomy
  "40 16" "28 14" "26 12" "40 11" "30 16"               # cramped / narrow / short
  "76 8" "60 10" "90 12" "24 20" "20 16"                # tiny/short + tiny/narrow: exercise 3-4 dim rooms
)

declare -A FAILS              # invariant -> failure count
declare -A SEEN               # invariant -> maps checked
TOTAL=0
EXAMPLE=""                    # first failing "size/seed: invariant" for the summary

note() {  # note <invariant> <ok:0|1> <size> <seed>
  local inv=$1 ok=$2 sz=$3 sd=$4
  SEEN[$inv]=$(( ${SEEN[$inv]:-0} + 1 ))
  if (( ! ok )); then
    FAILS[$inv]=$(( ${FAILS[$inv]:-0} + 1 ))
    [[ -z $EXAMPLE ]] && EXAMPLE="${sz// /x} seed=$sd: $inv"
  fi
}

floor_tile() { [[ $1 == '·' || $1 == '>' || $1 == '$' || $1 == '✱' ]]; }   # stars are walkable floor

check_map() {  # check_map <W> <H> <seed>
  local W=$1 H=$2 seed=$3 sz="$1 $2"
  local nr=${#ROOMx[@]} i r c

  # ---- exactly one staircase, and locate it -------------------------------------------------
  local stairs=0 si=-1
  for ((i=0; i<W*H; i++)); do [[ ${TILE[i]:-} == '>' ]] && { stairs=$((stairs+1)); si=$i; }; done
  note "one-staircase" $(( stairs==1 )) "$sz" "$seed"
  (( si<0 )) && return
  local sr=$(( si/W )) sc=$(( si%W ))

  # ---- which room holds the stairs ----------------------------------------------------------
  local far=-1
  for ((i=0; i<nr; i++)); do
    (( sr>=ROOMy[i] && sr<ROOMy[i]+ROOMh[i] && sc>=ROOMx[i] && sc<ROOMx[i]+ROOMw[i] )) && { far=$i; break; }
  done
  note "stairs-in-a-room" $(( far>=0 )) "$sz" "$seed"
  (( far<0 )) && return

  # ---- STAIRS NEVER ON A DOOR LINE (the rule this harness was added for) ---------------------
  # A door is a corridor cell (CORR=1) on the room's wall ring. A top/bottom door shares the
  # stairs' column risk; a left/right door shares the row risk. The '>' must avoid both.
  local fy0=${ROOMy[far]} fx0=${ROOMx[far]}
  local fy1=$(( fy0+ROOMh[far]-1 )) fx1=$(( fx0+ROOMw[far]-1 ))
  local online=0
  (( ${CORR[(fy0-1)*W+sc]:-0} || ${CORR[(fy1+1)*W+sc]:-0} )) && online=1   # top/bottom door in stairs column
  (( ${CORR[sr*W+fx0-1]:-0} || ${CORR[sr*W+fx1+1]:-0} )) && online=1       # left/right door in stairs row
  note "stairs-off-door-line" $(( ! online )) "$sz" "$seed"

  # ---- full connectivity: flood from the stairs reaches every floor cell ---------------------
  local -A vis=(); local q=("$si") head=0 reached=0
  vis[$si]=1
  while (( head < ${#q[@]} )); do
    local idx=${q[head]}; head=$((head+1)); reached=$((reached+1))
    local qr=$(( idx/W )) qc=$(( idx%W )) nb
    for nb in $(( idx-1 )) $(( idx+1 )) $(( idx-W )) $(( idx+W )); do
      local nr2=$(( nb/W )) nc2=$(( nb%W ))
      (( nb<0 || nb>=W*H )) && continue
      (( nb==idx-1 && qc==0 )) && continue          # don't wrap rows
      (( nb==idx+1 && qc==W-1 )) && continue
      [[ -n ${vis[$nb]:-} ]] && continue
      floor_tile "${TILE[$nb]:-#}" || continue
      vis[$nb]=1; q+=("$nb")
    done
  done
  local floors=0
  for ((i=0; i<W*H; i++)); do floor_tile "${TILE[i]:-#}" && floors=$((floors+1)); done
  note "full-connectivity" $(( reached==floors )) "$sz" "$seed"

  # ---- per-room sweeps: gold count, stars, doors, crossings --------------------------------
  local maxgold_ok=1 sidedoor_ok=1 doorcorner_ok=1 crossing_ok=1 star_ok=1
  for ((i=0; i<nr; i++)); do
    local ry0=${ROOMy[i]} rx0=${ROOMx[i]}
    local ry1=$(( ry0+ROOMh[i]-1 )) rx1=$(( rx0+ROOMw[i]-1 ))
    local gold=0 stars=0
    for ((r=ry0; r<=ry1; r++)); do for ((c=rx0; c<=rx1; c++)); do
      [[ ${TILE[r*W+c]:-} == '$' ]] && gold=$((gold+1))
      [[ ${TILE[r*W+c]:-} == '✱' ]] && stars=$((stars+1))
      (( ${CORR[r*W+c]:-0} )) && crossing_ok=0           # a corridor cell strictly inside a room = crossing
    done; done
    (( gold>1 )) && maxgold_ok=0
    # AT MOST one star per room. The harness generates the GAME'S FIRST FLOOR (CUR_REALM=0, CUR_FLOOR=0), whose
    # room 0 is reserved star-free (a star in the opening room would need no exploring) — so here room 0 must
    # have NONE. On DEEPER floors room 0 (the arrival / up-stairs room) is star-eligible like any room, but the
    # harness doesn't descend, so the i==0 check stays "==0". Stars are a random SUBSET toward a segment target.
    if (( i==0 )); then (( stars==0 )) || star_ok=0; else (( stars<=1 )) || star_ok=0; fi

    # doors on each wall-ring side; count per side (<=1) and check distance from the corner. The required
    # margin is adaptive: >=2 on a >=5-long wall, >=1 on a short (3-4) wall — small rooms on cramped windows
    # are allowed door-1-from-corner (the doors-clear-of-corners rule relaxes for sub-5 dims; see connect).
    local side dcount dc mw mh
    mw=$(( ROOMw[i]>=5 ? 2 : 1 ))   # top/bottom door margin keys off room WIDTH (door varies by column)
    mh=$(( ROOMh[i]>=5 ? 2 : 1 ))   # left/right door margin keys off room HEIGHT (door varies by row)
    # top / bottom (vary column)
    for side in $(( ry0-1 )) $(( ry1+1 )); do
      dcount=0
      for ((c=rx0; c<=rx1; c++)); do
        (( ${CORR[side*W+c]:-0} )) || continue
        dcount=$((dcount+1))
        dc=$c; (( dc-rx0 < mw || rx1-dc < mw )) && doorcorner_ok=0
      done
      (( dcount>1 )) && sidedoor_ok=0
    done
    # left / right (vary row)
    for side in $(( rx0-1 )) $(( rx1+1 )); do
      dcount=0
      for ((r=ry0; r<=ry1; r++)); do
        (( ${CORR[r*W+side]:-0} )) || continue
        dcount=$((dcount+1))
        dc=$r; (( dc-ry0 < mh || ry1-dc < mh )) && doorcorner_ok=0
      done
      (( dcount>1 )) && sidedoor_ok=0
    done
  done
  note "max-one-gold-per-room"   $maxgold_ok    "$sz" "$seed"
  note "one-star-per-room"       $star_ok       "$sz" "$seed"
  note "max-one-door-per-side"   $sidedoor_ok   "$sz" "$seed"
  note "doors-clear-of-corner"     $doorcorner_ok "$sz" "$seed"
  note "zero-room-crossings"     $crossing_ok   "$sz" "$seed"

  # ---- OBJECTS SPACED: every object has a 1-tile gap from walls AND from every other object ---
  # Objects = '>' '$' '✱' on the map, plus the future '<' at the player/start cell (pr,pc). Each must have
  # all 8 neighbours be plain floor (no wall/edge/other-object). Spacing is only achievable in a room that's
  # >=5 in BOTH dims (a thinner room — a cramped-window room, or the wide-but-3-5-tall big "hall" chamber —
  # physically can't give a vertical/horizontal gap), so we ASSERT it only for objects in such rooms; objects
  # in thin rooms are best-effort (see README). On a roomy window the normal rooms are >=5x5, hall chambers
  # are the exception.
  local spaced_ok=1 oi ot orr occ nrr ncc nt isobj rmk thin
  for ((oi=0; oi<W*H; oi++)); do
    ot=${TILE[oi]:-#}; isobj=0
    [[ $ot == '>' || $ot == '$' || $ot == '✱' ]] && isobj=1
    (( oi==pr*W+pc )) && isobj=1                       # the start cell -> the `<` up-stair lands here
    (( isobj )) || continue
    orr=$((oi/W)); occ=$((oi%W))
    thin=0                                             # is this object's room <5 in either dim? -> spacing unachievable, best-effort
    for ((rmk=0; rmk<nr; rmk++)); do
      (( orr>=ROOMy[rmk] && orr<ROOMy[rmk]+ROOMh[rmk] && occ>=ROOMx[rmk] && occ<ROOMx[rmk]+ROOMw[rmk] )) && {
        (( ROOMw[rmk]<5 || ROOMh[rmk]<5 )) && thin=1; break; }
    done
    (( thin )) && continue
    for ((nrr=orr-1; nrr<=orr+1; nrr++)); do for ((ncc=occ-1; ncc<=occ+1; ncc++)); do
      (( nrr==orr && ncc==occ )) && continue
      if (( nrr<0||nrr>=H||ncc<0||ncc>=W )); then spaced_ok=0; continue; fi
      nt=${TILE[nrr*W+ncc]:-#}
      [[ $nt == '#' || $nt == '>' || $nt == '$' || $nt == '✱' ]] && spaced_ok=0
      (( nrr==pr && ncc==pc )) && spaced_ok=0
    done; done
  done
  (( W>=56 && H>=20 )) && note "objects-spaced" $spaced_ok "$sz" "$seed"   # asserted on roomy windows only

  # ---- no double-wide hallway: no 2x2 block of corridor cells -------------------------------
  local dw_ok=1
  for ((r=0; r<H-1; r++)); do for ((c=0; c<W-1; c++)); do
    if (( ${CORR[r*W+c]:-0} && ${CORR[r*W+c+1]:-0} && ${CORR[(r+1)*W+c]:-0} && ${CORR[(r+1)*W+c+1]:-0} )); then
      dw_ok=0; break
    fi
  done; (( dw_ok )) || break; done
  note "no-double-wide-hall" $dw_ok "$sz" "$seed"

  # ---- rooms never overlap; stacked/side-by-side pairs stay >=3 tiles apart (wall-to-wall) ---
  local overlap_ok=1 apart_ok=1 a b
  for ((a=0; a<nr; a++)); do for ((b=a+1; b<nr; b++)); do
    local ay0=${ROOMy[a]} ax0=${ROOMx[a]} ay1=$(( ROOMy[a]+ROOMh[a]-1 )) ax1=$(( ROOMx[a]+ROOMw[a]-1 ))
    local by0=${ROOMy[b]} bx0=${ROOMx[b]} by1=$(( ROOMy[b]+ROOMh[b]-1 )) bx1=$(( ROOMx[b]+ROOMw[b]-1 ))
    local rowov=$(( ay0<=by1 && by0<=ay1 )) colov=$(( ax0<=bx1 && bx0<=ax1 ))
    if (( rowov && colov )); then overlap_ok=0
    elif (( colov )); then        # stacked: gap is vertical
      local vg=$(( (ay0>by0?ay0:by0) - (ay1<by1?ay1:by1) - 1 )); (( vg<3 )) && apart_ok=0
    elif (( rowov )); then        # side by side: gap is horizontal
      local hg=$(( (ax0>bx0?ax0:bx0) - (ax1<bx1?ax1:bx1) - 1 )); (( hg<3 )) && apart_ok=0
    fi                            # diagonal: separated on both axes by construction
  done; done
  note "rooms-never-overlap" $overlap_ok "$sz" "$seed"
  note "rooms-3-apart"       $apart_ok   "$sz" "$seed"
}

depth=1; gold=0; COMPACT=0; CUR_REALM=0; CUR_FLOOR=0   # generate now plans a floor role; give it realm0/floor0 context
for sz in "${SIZES[@]}"; do
  read -r W H <<<"$sz"
  for ((s=1; s<=SEEDS; s++)); do
    RT_SEED=$s generate >/dev/null 2>&1
    check_map "$W" "$H" "$s"
    TOTAL=$((TOTAL+1))
  done
done

echo "rogue-tile invariants — ${#SIZES[@]} sizes x $SEEDS seeds = $TOTAL maps"
echo "--------------------------------------------------------------"
fail_total=0
# stable order for readable output
ORDER=(one-staircase stairs-in-a-room stairs-off-door-line full-connectivity \
       max-one-gold-per-room one-star-per-room objects-spaced max-one-door-per-side doors-clear-of-corner \
       zero-room-crossings no-double-wide-hall rooms-never-overlap rooms-3-apart)
for inv in "${ORDER[@]}"; do
  seen=${SEEN[$inv]:-0}; f=${FAILS[$inv]:-0}; fail_total=$((fail_total+f))
  if (( f==0 )); then printf '  ok   %-22s %d/%d\n' "$inv" "$seen" "$seen"
  else               printf '  FAIL %-22s %d violations / %d\n' "$inv" "$f" "$seen"; fi
done
echo "--------------------------------------------------------------"
if (( fail_total==0 )); then
  echo "ALL INVARIANTS HOLD ($TOTAL maps)"; exit 0
else
  echo "$fail_total violations (first: $EXAMPLE)"; exit 1
fi
