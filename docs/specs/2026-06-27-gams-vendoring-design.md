# Design: GAMS Vendoring into `model/`

**Date:** 2026-06-27
**Topic:** Vendor the external GAMS optimization sources into the repository under `model/`
**Roadmap link:** Phase 2 (GAMS Vendoring & Shared Kernel), requirement **GAMS-01**
**Status:** Revised after two-step review (Reality Checker + DevOps Automator) — awaiting user approval
**Review note:** This revision resolves both BLOCKERs (PriceKernel-as-listing; gameable grep) and all
MAJOR/MINOR findings from the 2026-06-27 review pass.

## Overview

The GAMS optimization track currently lives **outside** the repository at the sibling
path `../experiments/gams/` (the pre-vendor source location).
A clone of this repo cannot see or run the GAMS model, and any future CI workflow that
compiles GAMS has nothing in-tree to act on.

This change vendors the GAMS **source** files into `model/` so the project is
self-contained. It is scoped to vendoring only — **no CI / GitHub Actions work this
session**. It pulls the GAMS-01 slice of Phase 2 forward (without the kernel-elevation
parts of Phase 2) to unblock building the GAMS compilation workflow next.

## Scope

### In scope
- Copy GAMS **source** (`.gms`) files from `../experiments/gams/` into `model/`,
  preserving the `dynamic/` subdirectory.
- Add a tracked in-tree build manifest `model/BUILD.md` (entrypoints, fragments, pinned
  GAMS version, working-directory requirement) so the next session can build without
  reverse-engineering the layout.
- Add GAMS-generated artifacts to `.gitignore`, and un-ignore `docs/superpowers/` so this
  spec is committable.

### Out of scope (explicit)
- **No CI / workflow changes.** The existing `.github/workflows/test.yml` (Foundry:
  `forge fmt`/`build`/`test`) is **untouched** (byte-for-byte).
- **No Plank Makefile CI.** Deferred to the following workflow session.
- **No edits to GAMS model logic.** Vendored files are byte-for-byte copies.
- **No deletion of `../experiments/gams`.** External scratch dir left intact; `model/`
  receives a copy. (The external dir is an untracked sibling, so a `git mv` is impossible
  regardless.)
- **No kernel elevation** (KERN-01/02/03) — remains the rest of Phase 2.

## File manifest

Source `.gms` files copied `../experiments/gams/ → model/` (byte-for-byte):

| Source file | Destination | Lines | Role | Notes |
|---|---|---|---|---|
| `primitives.gms` | `model/primitives.gms` | 13 | fragment (include) | Shared scalars; include-guarded (`$if set PRIMITIVES_INCLUDED $exit`) |
| `PricingKernel.gms` | `model/PricingKernel.gms` | 23 | **entrypoint** | `$include primitives.gms`; self-contained, compilable |
| `LiquidityKernel.gms` | `model/LiquidityKernel.gms` | 53 | **entrypoint** | `$include primitives.gms`, `$include PricingKernel.gms`; self-contained |
| `TradingRegion.gms` | `model/TradingRegion.gms` | 55 | entrypoint (caveat) | `$include primitives.gms`; defines `inventory` as `/ assetX cashY /` (differs from PricingKernel's `/ X, Y /`) |
| `PayoffModule.gms` | `model/PayoffModule.gms` | 2 | **stub** | `$include primitives.gms` + blank; no payoff logic yet |
| `dynamic/InitState.gms` | `model/dynamic/InitState.gms` | 6 | **fragment** | Orphan in include graph; references the `inventory` symbol it never includes — **not independently compilable** |

**Excluded — `PriceKernel.gms` (BLOCKER B2, resolved):** NOT vendored. Evidence: it is a
GAMS **compilation listing** (`.lst` content) saved with a `.gms` extension — line 1 is
`GAMS 54.1.0 … Page 1`, followed by the `G e n e r a l   A l g e b r a i c …` banner,
line-number-gutter echo of source, and a `**** FILE SUMMARY` footer. It is the listing of
`PricingKernel.gms`, an orphan in the include graph (nothing includes it; it includes
nothing), and it is the sole carrier of the external absolute path. Excluding it removes
both the listing-as-source contradiction and the absolute-path debt.

**Excluded — generated `.lst` listings:** `LiquidityKernel.lst`, `PricingKernel.lst`,
`primitives.lst`, `TradingRegion.lst`.

## Include-graph integrity & resolution

All `$include` directives reference siblings by **bare filename**
(`$include primitives.gms`, `$include PricingKernel.gms`). Every include target
(`primitives.gms`, `PricingKernel.gms`) is vendored.

**Colocation is necessary but not sufficient for resolution.** GAMS resolves a relative
`$include` against the **working directory** of the `gams` invocation, not merely the
file's neighbors: running `gams model/PricingKernel.gms` from repo root makes
`$include primitives.gms` resolve to `repo-root/primitives.gms` and fail. Therefore any
build (the future CI job, or local checks) MUST invoke gams with `model/` as the working
directory (`cd model && gams …`) or pass an explicit include path (`IDIR`). This
requirement is recorded in `model/BUILD.md`.

## `model/BUILD.md` (build manifest, tracked in-tree)

Captured now (cheap) so the next session does not reconstruct it:

- **Pinned toolchain:** GAMS `54.1.0`, platform `linux x86_64` (observed from the local
  install `/usr/gams/gams54.1_linux_x64_64_sfx/gams` and the listing banner).
- **Working directory:** all `gams` invocations run from `model/` (`cd model && gams …`).
- **Compile entrypoints (syntax-checkable today):** `PricingKernel.gms`,
  `LiquidityKernel.gms`. Example: `cd model && gams PricingKernel.gms action=c`.
- **Fragments / stubs the CI job must NOT compile standalone:** `primitives.gms` (include),
  `dynamic/InitState.gms` (depends on `inventory`), `PayoffModule.gms` (empty stub).
- **Caveat:** `TradingRegion.gms` and `PricingKernel.gms` define the `inventory` set
  differently (`/ assetX cashY /` vs `/ X, Y /`); they are not co-compilable without
  reconciliation (a later kernel-unification task, not this one).
- **Solve status:** the vendored content contains **no `Model`/`Solve` statement** — it is
  **syntax-checkable only** (`action=c`) today. The forward "full install + license via
  GitHub secret" decision (below) is provisioned for a future solve target that does not
  yet exist; the CI session should gate any licensed-solve job behind a real model.

## `.gitignore` changes

Two edits:

1. Un-ignore the spec subtree (the repo currently ignores `docs/`):
   ```gitignore
   docs/*
   !docs/superpowers/
   ```
2. Append a GAMS artifacts block — **all rules anchored under `model/`** so they cannot
   leak across the monorepo (`src/`, `test/`, `spec/`, submodules):
   ```gitignore
   # GAMS generated artifacts under model/ (listings, save/work files, scratch)
   model/**/*.lst
   model/**/*.g00
   model/**/*.lxi
   model/**/*.gdx
   model/225*/
   ```
   Anchoring to `model/` (vs the earlier repo-wide `*.lst`/`*.gdx`) removes the foot-gun
   where a future intended `.gdx`/`.lst` anywhere else in the tree is silently untracked.
   `model/225*/` is a best-effort catch for the GAMS default scratch-dir prefix; the
   future CI job should additionally direct scratch via `scrdir`/`curDir` to a controlled
   path rather than rely on the glob.

## Decisions (from brainstorming + review resolution)

1. **Vendor directory = `model/`** (per roadmap GAMS-01), not `gams/`.
2. **Copy, leave external intact.** `../experiments/gams` untouched; `model/` holds a copy.
3. **`PriceKernel.gms` excluded entirely** (review B2). It is a generated listing, an
   orphan, and the absolute-path carrier. No "vendor as-is / clean later" debt.
4. **Spec subtree un-ignored** so this artifact is committable (review M-docs).

## Forward decision recorded (next session, not built here)

When the GAMS CI workflow is built: **full GAMS install + license via GitHub secret**.
Recorded honestly: the vendored content has no solve target yet (syntax-check only), so the
licensed-solve job should be gated behind the existence of a real `Model`/`Solve` file.
Nothing in this spec implements CI.

## Success criteria (what must be TRUE after this change)

1. `model/` contains exactly **6 files**: 5 top-level `.gms` (`primitives`,
   `PricingKernel`, `LiquidityKernel`, `TradingRegion`, `PayoffModule`) **plus**
   `model/dynamic/InitState.gms`. `PriceKernel.gms` is **absent**.
2. No `.lst` file and no listing-content-as-`.gms` is tracked; `.gitignore` ignores GAMS
   artifacts.
3. `grep -rIn 'experiments/gams' model/ --include='*.gms'` returns **nothing** — no GAMS
   **source/pipeline** file references the external dir in **any** form (relative
   `../experiments/gams` or absolute `/home/.../experiments/gams`). This is GAMS-01's "no
   pipeline file references `../experiments/gams`" guarantee. (Scoped to `*.gms`: the
   `model/BUILD.md` manifest intentionally records provenance — "Vendored from
   `../experiments/gams/`" — which is documentation, not a build-time dependency, and is an
   accepted reference. The earlier `../experiments/gams`-only grep was hardened to catch the
   absolute form too, per BLOCKER B1.)
4. Include graph intact: every `$include` target exists as a sibling in `model/`
   (existence check only — resolution additionally requires `model/` as working dir, per
   above; not a resolution guarantee).
5. `.github/workflows/test.yml` is left untouched/unstaged. (Note: `.github/` is
   currently **untracked** in this repo, so this is verified as "no *tracked* change and
   nothing staged under `.github/`", not as a git-diff of a tracked file.)
6. `model/BUILD.md` exists and is `git ls-files`-tracked, naming entrypoints, fragments,
   the pinned GAMS version, and the working-directory requirement.
7. This spec is committable (`git check-ignore` does not match it after the `.gitignore`
   negation).

## Verification

- `ls -R model/` shows the 6-file manifest + `BUILD.md`; `PriceKernel.gms` absent.
- `git status` shows new `model/**` files, modified `.gitignore`, the now-tracked spec, and
  **no** change under `.github/`.
- `grep -rIn 'experiments/gams' model/ --include='*.gms'` → empty (criterion #3). (An
  all-files grep matches only the intentional `model/BUILD.md` provenance note.)
- `git check-ignore docs/superpowers/2026-06-27-gams-vendoring-design.md` → no match
  (criterion #7).
- Optional (local, licensed GAMS 54.1): `cd model && gams PricingKernel.gms action=c` and
  `gams LiquidityKernel.gms action=c` syntax-check clean, proving includes resolve from the
  vendored location.
