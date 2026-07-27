# cfmm-gams

The off-chain **GAMS algebraic model** for CFMM payoff replication — split out of
[`JMSBPP/cfmm-replicationPlank`](https://github.com/JMSBPP/cfmm-replicationPlank)
with its `model/` history preserved.

This repository is the source of truth for the GAMS track. The monorepo consumes
it as a submodule mounted at `gams/`.

## What is here

| Path | Contents |
|------|----------|
| `model/` | GAMS sources — pricing kernel, liquidity kernel, trading region, payoff units |
| `model/payoff/` | One file per formalized theorem, each an independent execution unit |
| `model/test/` | One assertion driver per theorem unit, plus kernel tests |
| `model/spec/` | Mathematical spec notes (mirrored reference — canonical copy lives in `cfmm-lean4-spec`) |
| `model/BUILD.md` | Toolchain pin and build manifest |
| `docs/specs/`, `docs/plans/` | Design specs and implementation plans |
| `lean4-spec/` | Submodule → `JMSBPP/cfmm-lean4-spec` (the Lean formalization this model implements) |

## Toolchain

GAMS **54.1.0**, linux x86_64. The payoff units carry real NLP `Model`/`Solve`
statements and therefore need the **CONOPT** solver; the kernel files are
compile-checkable without a solver.

## Build

```sh
make compile-gams   # action=c syntax check over every .gms
make test-gams      # action=ce — runs abort$() assertions and the NLP solves
make clean-gams     # remove listings, scratch, and build output
```

GAMS resolves relative `$include` against the **working directory of the
invocation**, not the including file's directory. Every target therefore `cd`s
into `model/` first. Running `gams` from the repo root will not resolve includes
and will scatter `.lst` files — the `.gitignore` patterns are deliberately
unanchored to catch that.

## Architecture: one execution unit per theorem

GAMS has a single global symbol namespace. Each file under `model/payoff/`
declares its own fixture (`iCfg`, `LbarQ128`, `DICfgQ128`, probes, provenance
sets) plus its own `Model`, `Equation`, and `Variable`s — and those names are
deliberately reused across theorems, because each theorem is a *different*
numerical fixture.

Consequently the per-theorem files are **never** `$include`d into one
compilation unit. Each gets its own driver under `model/test/`, and
`make test-gams` executes them separately. `model/PayoffModule.gms` is a
registry documenting the pairs, not an aggregator. See its header for the full
rationale.

## Relationship to the Lean formalization

The `lean4-spec` submodule holds the Lean 4 proofs this model implements. The
`spec-preflight-band` target re-greps the cited theorems for `sorry`/`admit`
before extracting any GAMS code from a spec document, so a GAMS unit can never
claim to implement an unproven theorem.

```sh
git submodule update --init lean4-spec
make spec-preflight-band
```

## License

MIT — see [LICENSE](LICENSE).
