#!/bin/sh
# lean_sorry_check.sh <lean-file> <declaration-id>
#
# Exit-code contract (STABLE — plan 00-04 replaces the body, not this contract):
#   0  the declaration was found and its body contains no sorry/admit
#   1  the declaration was found and its body contains sorry or admit
#   2  the declaration was not found in the file
#   3  usage / file error
#
# KNOWN LIMITATIONS OF THIS IMPLEMENTATION (GATE-07, closed by plan 00-04):
#   * `^theorem <id>` is column-0 anchored and matches only `theorem`, so it
#     misses every `lemma` — which is how most vol_markets declarations are
#     written (PosSpec, Flow, GeomProfile, RiskDesign, FeeSchedule and
#     VolInstrument declare ZERO column-0 `theorem`s) — and anything indented.
#   * The awk body-extraction terminates on the next column-0 declaration, so a
#     later `sorry` can be attributed to the wrong declaration.
# Committed in this shape ONLY so the recipe gates on an exit code today.
set -e
LEAN="$1"
ID="$2"
[ -n "$LEAN" ] && [ -n "$ID" ] || { echo "usage: lean_sorry_check.sh <file> <id>" >&2; exit 3; }
[ -f "$LEAN" ] || { echo "lean_sorry_check: no such file: $LEAN" >&2; exit 3; }
START=$(grep -nE "^theorem $ID" "$LEAN" | head -1 | cut -d: -f1)
[ -n "$START" ] || { echo "lean_sorry_check: declaration not found: $ID" >&2; exit 2; }
END=$(awk -v s="$START" 'NR>s && /^(theorem |lemma |def |noncomputable def |namespace |end )/ {print NR; exit}' "$LEAN")
[ -n "$END" ] || END=$(wc -l < "$LEAN")
if sed -n "${START},${END}p" "$LEAN" | grep -vE '^[[:space:]]*(--|/-)' | grep -qE '\bsorry\b|\badmit\b'; then
    echo "lean_sorry_check: $ID body contains sorry/admit" >&2
    exit 1
fi
exit 0
