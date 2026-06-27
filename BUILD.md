# GAMS Model — Build Manifest

Vendored from `../experiments/gams/` on 2026-06-27 (GAMS-01). This file is the
authoritative build reference; the future GAMS CI workflow reads it.

## Pinned toolchain
- GAMS **54.1.0**, platform **linux x86_64**.
  (Local install: `/usr/gams/gams54.1_linux_x64_64_sfx/gams`.)

## Working directory (required)
GAMS resolves relative `$include` against the **working directory** of the `gams`
invocation, not the file's neighbors. All invocations MUST run from `model/`:

    cd model && gams <file>.gms action=c

## Compile entrypoints (syntax-checkable today, `action=c`)
- `PricingKernel.gms`   — `$include primitives.gms`; self-contained.
- `LiquidityKernel.gms` — `$include primitives.gms`, `$include PricingKernel.gms`; self-contained.

## Fragments / stubs — DO NOT compile standalone
- `primitives.gms`        — include-only (shared scalars; include-guarded).
- `dynamic/InitState.gms` — orphan; references the `inventory` symbol it never
  includes, so it is not independently compilable.
- `PayoffModule.gms`      — empty stub (`$include primitives.gms` only); no payoff logic yet.

## Known caveats
- `TradingRegion.gms` and `PricingKernel.gms` define the `inventory` set
  differently (`/ assetX cashY /` vs `/ X, Y /`); not co-compilable without a
  later kernel-unification task.
- **No `Model`/`Solve` statement exists yet** — vendored content is
  **syntax-checkable only**. The forward decision ("full GAMS install + license
  via GitHub secret") is provisioned for a future solve target; gate any
  licensed-solve CI job behind the existence of a real model.
- `PriceKernel.gms` from the source dir is intentionally **not** vendored: it is a
  GAMS compilation listing (`.lst` content) saved with a `.gms` extension.

## Generated scratch
GAMS scratch/listing output under `model/` is git-ignored (`model/**/*.lst`,
`model/**/*.g00`, `model/**/*.lxi`, `model/**/*.gdx`, `model/225*/`). The CI job
should additionally pin scratch to a controlled dir via `scrdir`/`curDir`.
