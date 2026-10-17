# Compile-execute a GAMS model. Pass a path under model/, e.g.
#   just gams model/infra/TickLattice.draft1.gms
# Listing and scratch files land in model/build/.
gams file:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p model/build
    f="{{file}}"
    f="${f#model/}"
    out="build/$(echo "$f" | tr / _ | sed 's/\.gms$//').lst"
    cd model && gams "$f" action=ce o="$out" scrdir=build lo=3
