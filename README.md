# cfmm-numopt

The **numerical-optimization layer** of the CFMM replication work: a GAMS-only
package that runs CFMM programs — pricing/liquidity kernels, per-theorem payoff
units, and the VolumePath prover — and emits machine-readable outputs (GDX
fixtures, EVM-scaled JSON) for fuzzers and differential tests downstream.

It pairs with the **formalization layer**,
[`JMSBPP/cfmm-vol-markets-spec`](https://github.com/JMSBPP/cfmm-vol-markets-spec) (Lean 4;
formerly `cfmm-lean4-spec`), which is mounted here as the `lean4-spec/` submodule. History was split out of
[`cfmm-vol-markets`](https://github.com/d2p-finance/cfmm-vol-markets) (formerly `cfmm-replicationPlank`)
with the `model/` commits preserved. (Formerly `cfmm-gams`; the old URL redirects.)

**GAMS-only policy.** Tracked source is `.gms`, `.gdx`, Markdown, the Makefile and
the CI workflow — nothing else, and the Makefile invokes only `gams` plus POSIX
shell. No Python/Solidity/TypeScript source or tooling lives here; that stays in
the monorepo.

## What is here

| Path | Contents |
|------|----------|
| `model/` | GAMS sources — pricing kernel, liquidity kernel, trading region, price-impact fixture |
| `model/payoff/` | One file per formalized theorem, each an independent execution unit |
| `model/test/` | One assertion driver per theorem unit, plus kernel tests |
| `model/mev_tax_model_one/` | The **VolumePath prover** (`volume_path.gms`) and its spec (`notes.md`) |
| `model/spec/` | Mathematical spec notes (mirror — canonical copy lives in `cfmm-vol-markets-spec`) |
| `model/BUILD.md` | Toolchain pin, licence note, and build manifest |
| `docs/volume-path.md` | Usage contract of the prover for its downstream consumers |
| `docs/specs/`, `docs/plans/`, `docs/superpowers/` | Design specs and implementation plans |
| `.agents/gams/research/` | GAMS tooling research notes |
| `lean4-spec/` | Submodule → `JMSBPP/cfmm-vol-markets-spec` (Lean sources under `lean/`) |

## Outputs for fuzzers

| Output | How | Status |
|--------|-----|--------|
| `model/price_impact_kernel.gdx` | `make payoff-fixtures` / kernel fixture driver | committed reference fixture |
| `model/payoff_zero_slippage.gdx` | `make payoff-fixtures` | committed reference fixture |
| `model/payoff_band_monotone_large.gdx` | `make payoff-fixtures` | committed reference fixture |
| `model/mev_tax_model_one/volume_path.json` | `make test-volumepath` (or `gams volume_path.gms --sqrtPriceX96=… --volTgtWad=…`) | generated, git-ignored, byte-deterministic |

The VolumePath JSON carries swap quantities at EVM scale (wei magnitudes);
values above 2^53 pass through GAMS doubles, so treat them as **EVM-scaled**,
not bit-exact, unless a consumer proves otherwise.

## Toolchain

GAMS **54.1.0**, linux x86_64, with the **CONOPT** solver (the payoff units and the
prover carry real NLP `Model`/`Solve` statements; kernel files compile without a
solver). The install in use is a **GAMS Demo licence** — models must stay within
demo size limits. See `model/BUILD.md`.

## Build

```sh
make compile-gams      # action=c syntax check over every .gms
make test-gams         # test-units + test-volumepath
make test-units        # action=ce — runs the abort$() assertion drivers under model/test/
make test-volumepath   # prover self-test: in-model gates + determinism double run
make payoff-fixtures   # regenerate the committed payoff GDX fixtures
make clean-gams
```

GAMS resolves relative `$include` against the **working directory of the
invocation** and writes listings there, so every target `cd`s into the model's
own directory and pins `scrdir=build`. Running `gams` from the repo root will
scatter `.lst` files — the `.gitignore` patterns are deliberately unanchored to
catch that.

## Architecture: one execution unit per theorem

GAMS has a single global symbol namespace. Each file under `model/payoff/`
declares its own fixture (`iCfg`, `LbarQ128`, `DICfgQ128`, probes, provenance
sets) plus its own `Model`, `Equation`, and `Variable`s — and those names are
deliberately reused across theorems, because each theorem is a *different*
numerical fixture. The per-theorem files are therefore **never** `$include`d
into one compilation unit: each gets its own driver under `model/test/`, and
`make test-units` executes them separately. `model/PayoffModule.gms` is a
registry documenting the pairs, not an aggregator.

The VolumePath prover is standalone by design (no `$include`); its inputs are
shock parameters overridable on the command line — see `docs/volume-path.md`.

## Relationship to the Lean formalization

The `lean4-spec` submodule pins the Lean 4 proofs this model implements
(`git submodule update --init lean4-spec`). Each payoff unit's header cites the
theorem it realizes; checking those theorems are `sorry`/`admit`-free is the
formalization repo's CI job, not this Makefile's — the former `spec-preflight*`
targets (Python-based spec extraction) were removed to keep this package
GAMS-only.

## CI

`.github/workflows/gams.yml` runs `make compile-gams` and `make test-gams` on a
self-hosted runner behind the `gams-gate` environment (required-reviewer
approval before any untrusted code reaches the runner — do not remove it).

## Contributing / Workflow

**Fork → PR workflow (d2p-finance canonical).** The `d2p-finance` GitHub org owns
the CANONICAL/upstream repos; the `JMSBPP/*` repos are the develop FORKS. ALL
changes are made on the `JMSBPP/*` forks and reach the `d2p-finance/*` canonical
repos ONLY through pull requests (fork → upstream). Never commit or push directly
to a `d2p-finance` canonical repo — open a PR from the JMSBPP fork.

For this repo: canonical is `d2p-finance/cfmm-numopt`, the develop fork is
`JMSBPP/cfmm-numopt`. Work on a branch of the fork, open a PR against
`d2p-finance/cfmm-numopt:main`; CI runs there behind the `gams-gate` approval.

```sh
git remote add upstream https://github.com/d2p-finance/cfmm-numopt.git
```

## License

MIT — see [LICENSE](LICENSE).
