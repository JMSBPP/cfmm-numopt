#!/bin/sh
# lean_sorry_check.sh <lean-file> <declaration-id>
#
# Exit-code contract (STABLE — plan 00-04 replaced the body, not this contract):
#   0  the declaration was found and its body contains no sorry/admit
#   1  the declaration was found and its body contains sorry or admit
#   2  the declaration was not found in the file
#   3  usage / file error
#
# Implementation: model/test/lean_sorry_check.py. It handles arbitrary
# indentation, nested namespaces, and `lemma` as well as `theorem` — the six
# vol_markets modules that declare ZERO `theorem`s (FeeSchedule, VolInstrument,
# RiskDesign, Flow, PosSpec, GeomProfile) were invisible to the previous
# `^theorem <id>` grep, and a later `sorry` could be attributed to an earlier
# declaration. Comments are stripped before the scan, so the backticked `sorry`
# in the eta.lean doc comment at line 602 does not falsely redden anything.
#
# The submodule contains no real sorry, so a scan of it can never demonstrate
# that this gate fires: model/test/_mutants/lean/SorryFixture.lean is what proves
# it, and it is registered in model/test/_mutants/registry.tsv.
set -e
exec python3 "$(dirname "$0")/lean_sorry_check.py" "$@"
