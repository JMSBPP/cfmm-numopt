# Compile-execute a GAMS module under src/.
# Layered layout: parameters/, variables/, equations/, models/.
# Run from project root (gams-deps.toml). idir=src keeps $include parameters/… working;
# transport utils pin is added so GdxComptimeHandshake can $include GdxWriter.gms.
# Usage:  just gams parameters/TickLattice.gms
#         just gams models/StripLengthFromGammaBudget.gms
# Listing: src/build/<slashes_to_underscores>.lst

# Build CommandDispatcher.so inside the RPC pin (gams-evm-transport owns the API artifact).
dispatcher:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p src/build
    gams-deps
    rpc="$(sed -n "s/^\$setGlobal GAMS_EVM_TRANSPORT_RPC '\\(.*\\)'/\\1/p" src/build/deps.inc | tr -d '\r' | sed 's|/$||; s|/\.$||')"
    if [[ -z "${rpc}" || ! -f "${rpc}/justfile" ]]; then
      echo "just dispatcher: GAMS_EVM_TRANSPORT_RPC justfile missing" >&2
      exit 1
    fi
    just --justfile "${rpc}/justfile" --working-directory "${rpc}" dispatcher
    test -f "${rpc}/lib/exec/CommandDispatcher.so"

# EF does system("just broadcast_tick_path") from the GAMS working directory.
broadcast_tick_path:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p src/build build
    # environment.d is in systemd --user; already-open shells (and this recipe)
    # do not re-import it. Fill only unset apply addrs.
    if [[ -z "${TICK_ADDRESS:-}" || -z "${MULTICALLER_ADDRESS:-}" || -z "${ANVIL_RPC_URL:-}" ]]; then
      while IFS= read -r line; do
        case "$line" in
          ANVIL_RPC_URL=*|TICK_ADDRESS=*|MULTICALLER_ADDRESS=*)
            key="${line%%=*}"
            if [[ -z "${!key:-}" ]]; then
              export "$line"
            fi
            ;;
        esac
      done < <(systemctl --user show-environment)
    fi
    if [[ -z "${TICK_ADDRESS:-}" || -z "${MULTICALLER_ADDRESS:-}" ]]; then
      echo "just broadcast_tick_path: TICK_ADDRESS / MULTICALLER_ADDRESS unset (not in env or systemd --user)" >&2
      exit 1
    fi
    gams-deps
    rpc="$(sed -n "s/^\$setGlobal GAMS_EVM_TRANSPORT_RPC '\\(.*\\)'/\\1/p" src/build/deps.inc | tr -d '\r' | sed 's|/$||; s|/\.$||')"
    if [[ -z "${rpc}" || ! -f "${rpc}/src/Broadcast_tick_path.idr" ]]; then
      echo "just broadcast_tick_path: pinned Broadcast_tick_path.idr missing" >&2
      exit 1
    fi
    idris2 --source-dir "${rpc}/src" --output-dir build -o broadcast_tick_path "${rpc}/src/Broadcast_tick_path.idr"
    build/broadcast_tick_path

gams file: dispatcher
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p src/build build
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
