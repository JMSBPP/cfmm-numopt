# Compile-execute a GAMS module under src/.
# Layered layout: parameters/, variables/, equations/, models/.
# Run from project root (gams-deps.toml). idir=src keeps $include parameters/… working;
# transport pin dir is added so GdxComptimeHandshake can $include GdxWriter.gms.
# Usage:  just gams parameters/TickLattice.gms
#         just gams models/StripLengthFromGammaBudget.gms
# Listing: src/build/<slashes_to_underscores>.lst
gams file:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p src/build
    f="{{file}}"
    f="${f#file=}"
    f="${f#src/}"
    out="src/build/$(echo "$f" | tr / _ | sed 's/\.gms$//').lst"
    gams-deps
    transport_src="$(sed -n "s/^\$setGlobal GAMS_EVM_TRANSPORT_SRC '\\(.*\\)'/\\1/p" src/build/deps.inc | tr -d '\r')"
    if [[ -z "${transport_src}" ]]; then
      echo "just gams: GAMS_EVM_TRANSPORT_SRC missing from src/build/deps.inc" >&2
      exit 1
    fi
    gams "src/$f" action=ce o="$out" scrdir=src/build "idir=src:${transport_src}" lo=3
