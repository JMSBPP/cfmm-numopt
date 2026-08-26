# GAMS Model — Build Manifest

Authoritative build reference for `cfmm-numopt`; the CI workflow
(`.github/workflows/gams.yml`) runs exactly the targets listed here.

## Pinned toolchain
- GAMS **54.1.0**, linux x86_64 (`/usr/gams/gams54.1_linux_x64_64_sfx/gams`).
- Solver **CONOPT** (payoff units and the VolumePath prover carry real NLP
  `Model`/`Solve` statements; kernel files are compile-checkable without it).
- Licence: **GAMS Demo** (`gamslice.txt`: `G260530`, dev machine = CI runner).
  Every model MUST stay within demo size limits; a solve that exceeds them
  fails with a licence error, not a modelling error — check this first.
- The VolumePath determinism guarantee (byte-identical JSON) is per-toolchain:
  GAMS 54.1 + CONOPT 4.39.

## Working directory (required)
GAMS resolves relative `$include` against the **working directory** of the
invocation and writes listings/scratch there. Every Make target therefore
`cd`s into the model's own directory and pins `scrdir=build`:

- kernel / payoff / test units run from `model/` → `model/build/`
- the VolumePath prover runs from `model/mev_tax_model_one/` → `model/mev_tax_model_one/build/`

Both `build/` trees are git-ignored.

## Tracks

### Kernels (compile-checked, `action=c`)
- `primitives.gms` — include-only shared scalars (include-guarded).
- `PricingKernel.gms`, `PricingKernelMoments.gms`, `LiquidityKernel.gms`,
  `TradingRegion.gms`, `_PriceImpactKernelInputs.gms`, `PriceImpactKernelFixture.gms`.
- `dynamic/InitState.gms` — references `inventory` without including it; compiles
  in isolation only because nothing dereferences it.
- `PayoffModule.gms` — registry of (theorem unit, test driver) pairs, not an aggregator.

### Payoff theorem units (executed, `action=ce`, need CONOPT)
One file per formalized theorem under `payoff/`, one driver per unit under
`test/`; units are never `$include`d together (shared symbol names by design).
Committed reference fixtures: `price_impact_kernel.gdx`, `payoff_zero_slippage.gdx`,
`payoff_band_monotone_large.gdx` (regenerate with `make payoff-fixtures`).

### VolumePath prover (executed, needs CONOPT)
`mev_tax_model_one/volume_path.gms` — standalone, no `$include`. Spec:
`mev_tax_model_one/notes.md`. Usage contract: `docs/volume-path.md`. Emits
`volume_path.json` (git-ignored, byte-deterministic).

## Targets
- `make compile-gams`     — `action=c` over every `.gms` under `model/` except `test/` and `build/`
- `make test-gams`        — `test-units` + `test-volumepath`
- `make test-units`       — every `model/test/*.gms` with `action=ce`, exit-code gated
- `make test-volumepath`  — prover self-test: in-model gates + double-run `cmp`
- `make payoff-fixtures`  — regenerate the committed payoff GDX fixtures
- `make clean-gams`

Exit codes on GAMS 54.1: `2` compile error, `3` execution abort. Targets gate on
the exit code; never scrape listings (`lo=0` removes the status line).
