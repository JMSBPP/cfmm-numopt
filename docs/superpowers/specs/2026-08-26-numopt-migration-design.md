# Design: `cfmm-gams` → `cfmm-numopt` — the GAMS-only numerical-optimization layer

## Context

The CFMM work splits into a **formalization layer** (`JMSBPP/cfmm-lean4-spec`, Lean 4) and a
**numerical-optimization layer** that runs CFMM programs (kernels, payoff theorems, the VolumePath
prover) and emits machine-readable outputs (GDX fixtures, EVM-scaled JSON) for fuzzers and
differential tests. The numerical layer must be a **GAMS-only package** in its own repository,
named to pair with the formalization repo.

### What exists today (verified 2026-08-26, incl. two-step review)

| Thing | State |
|---|---|
| `JMSBPP/cfmm-gams` `main` @ `ad8f0bd` (30 commits) | GAMS split of monorepo `feat/gams` **with history**. Kernels, per-theorem payoff units, `model/test/` (4 drivers, all green locally), 3 committed GDX fixtures, `lean4-spec` submodule, Makefile, self-hosted CI (`gams.yml`, env `gams-gate` id 18848522657, runner `cfmm-build-gams` id 21 online). Also tracks `.agents/gams/research/*.md` and `docs/{specs,plans}/*.md`. **`main` has never had a green CI run** (only run was cancelled). No branch protection/rulesets. |
| `cfmm-gams` PR **#2** (`gsd/phase-0-honest-gates`, OPEN) | Ships the **VolumePath prover** and a **sweep** deleting kernels/payoff/submodule/honest-gates. Its run `31920282063` has been `waiting` on `gams-gate` approval since 2026-08-16 (not broken — never approved; GitHub auto-fails ~09-15). |
| Monorepo `origin/feat/gams` vs `main` | `main` is the **successor, not a superset**: 3 files diverged in `ad8f0bd` (`PayoffModule.gms` → registry stub, `PricingKernel.gms` macro arg renames + `MIN_TICK/MAX_TICK`, `exp/eta.md` rewrite). Monorepo versions are intentionally dropped. Nothing else to reconcile. |
| VolumePath prover | `origin/gsd/phase-0-honest-gates:model/mev_tax_model_one/{volume_path.gms,notes.md}` is **byte-identical** to monorepo `cfmm-wt/gams` copy. Cherry-pick `e81252d 1cb9dee` onto `main` dry-runs clean and touches only those two files. `compile-gams` on `main` picks it up (`13 ok`); two `action=ce` runs are byte-identical. In-model `abort$` gates cover solver status, targets, closure, swap-sign (line 199) and count (line 77). |
| Local `/home/jmsbpp/cfmm-gams` | Session cwd, nested in the home `spec-lab` repo. **Not empty**: contains GAMS scratch `225a/`. **Do not touch during this session.** |
| Toolchain | GAMS 54.1.0 + CONOPT at `/usr/gams/gams54.1_linux_x64_64_sfx/`, **GAMS Demo licence** (same host as the CI runner, at `/home/jmsbpp/actions-runner`, unit `actions.runner.JMSBPP-cfmm-gams.cfmm-build-gams.service`). Models are within demo limits today. |
| Consumers | No `.gitmodules` or code reference to `cfmm-gams` anywhere in `JMSBPP` (`gh search code` empty). |

### Decisions taken with the user (this session)
1. **Content = union**: everything on `main` **plus** the VolumePath prover. Non-GAMS artifacts excluded.
2. **Name = `cfmm-numopt`**.
3. **History**: build on existing `main`.

### Policy definitions (resolve reviewer contradictions)
- **"GAMS-only"** = *tracked source* is `.gms`/`.gdx`/Markdown/Make/CI only. Dev-machine Make
  helpers may shell out to `jq`/`python3` (existing `spec-preflight*` targets already do). This is
  written into README so the claim is reviewable.
- **PR #2**: only its prover feature content is ported; the sweep, honest-gates machinery and
  `.planning/` trees are **not** resurrected. PR #2 is closed as superseded; branch kept.
- `.agents/gams/research/*.md` are GAMS research notes → kept, listed in the layout.

---

## Target layout (`cfmm-numopt`)

```
cfmm-numopt/
├── .agents/gams/research/*.md    # kept
├── .github/workflows/gams.yml    # unchanged gate
├── .gitignore                    # + model/*/build/, model/mev_tax_model_one/volume_path.{json,txt}
├── .gitmodules, lean4-spec/      # submodule kept
├── LICENSE, Makefile, README.md
├── docs/specs/, docs/plans/      # existing (kept as-is)
├── docs/volume-path.md           # prover usage contract (from PR #2)
├── docs/superpowers/{specs,plans}/2026-08-26-numopt-migration-*.md   # this migration
└── model/
    ├── BUILD.md                  # both tracks + prover; demo-licence note
    ├── (kernels, payoff/, test/, spec/, dynamic/, exp/, *.gdx)  # unchanged
    └── mev_tax_model_one/{volume_path.gms, notes.md}
```

Outputs (README "Outputs for fuzzers"): committed GDX fixtures `model/{price_impact_kernel,payoff_zero_slippage,payoff_band_monotone_large}.gdx`; generated, gitignored, byte-deterministic `model/mev_tax_model_one/volume_path.json` (**EVM-scaled** — values > 2^53 are double-rounded; do not claim "exact").

---

