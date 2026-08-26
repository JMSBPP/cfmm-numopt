# Implementation plan: `cfmm-gams` → `cfmm-numopt`

Spec: `docs/superpowers/specs/2026-08-26-numopt-migration-design.md`.

## Implementation steps (executing agent per step from the AI-agency catalog)

### Step 1 — Materialize locally, baseline — *Git Workflow Master*
```sh
git clone https://github.com/JMSBPP/cfmm-gams.git /home/jmsbpp/cfmm-numopt   # final name; never rmdir/mv the live cwd
cd /home/jmsbpp/cfmm-numopt && git submodule update --init lean4-spec
git checkout -b feat/numopt-migration main
make compile-gams && make test-gams      # baseline must be green BEFORE changes (first proof main is green anywhere)
```
All later commands use absolute `/home/jmsbpp/cfmm-numopt`. `/home/jmsbpp/cfmm-gams` (stale scratch) is deleted by the user after this session.

### Step 2 — Port the prover with authorship — *Git Workflow Master*
```sh
git fetch origin gsd/phase-0-honest-gates
git cherry-pick -x e81252d 1cb9dee                       # clean; touches only model/mev_tax_model_one/*
git checkout origin/gsd/phase-0-honest-gates -- docs/volume-path.md   # 17577ed would conflict (Makefile/mk/ rewrites)
git commit -m "docs: VolumePath usage contract (from gsd/phase-0-honest-gates)"
```
Verify: `diff` vs `/home/jmsbpp/cfmms-playground/cfmm-wt/gams/model/mev_tax_model_one/volume_path.gms` → empty.

### Step 3 — Build wiring for coexisting tracks — *DevOps Automator*
Makefile (base = `main`):
- `compile-gams`: add `-not -path '*/build/*'` to the `find`; otherwise unchanged (prover already found).
- Rename existing loop → `test-units`; add `test-volumepath` (adapted from PR #2 recipe): `cd model/mev_tax_model_one && mkdir -p build`; run 1 `action=ce o=build/run1.lst scrdir=build lo=0` gated on exit code; JSON parse check `jq -e . volume_path.json >/dev/null` behind `command -v jq` guard; copy; run 2; `cmp -s`. `test-gams: test-units test-volumepath`.
- In-model width guard in `volume_path.gms` next to `fj.pw = 4000` (line ~202): `abort$(nEv*25 > 4000) "JSON line would exceed fj.pw"` so well-formedness holds without jq.
- `clean-gams`: also `rm -rf model/mev_tax_model_one/{build,volume_path.json,volume_path.txt}`.
- `.gitignore`: `model/*/build/`, `model/mev_tax_model_one/volume_path.json`, `model/mev_tax_model_one/volume_path.txt` (anchored).
- `model/BUILD.md`: manifest = kernel/payoff units + prover; toolchain "GAMS 54.1 + CONOPT 4.39, **Demo licence** (models must stay within demo limits; licence date from `gamslice.txt`)".
- `docs/volume-path.md` line ~155: wording matches the kept checks.
Verify: `make clean-gams && make compile-gams && make test-gams` green; `git status` clean (no leaked `.lst`/`225*`).

### Step 4 — Rebrand & rename — *DevOps Automator*
- README: `# cfmm-numopt`; purpose paragraph (numerical layer emitting fixtures); "GAMS-only" policy sentence; table gains `mev_tax_model_one/` and `.agents/` rows; **Outputs** section; keep toolchain/build/architecture/Lean sections; replace all `cfmm-gams` self-refs. `gams.yml` untouched.
- Before renaming: `gh run cancel 31920282063 -R JMSBPP/cfmm-gams` (orphan pending deployment on PR #2).
- `gh repo rename cfmm-numopt -R JMSBPP/cfmm-gams --yes`; `gh repo edit JMSBPP/cfmm-numopt --description "Numerical-optimization layer for CFMM replication — GAMS programs (kernels, payoff theorems, VolumePath prover) emitting fixtures for fuzzers; formal spec in cfmm-lean4-spec"`; `git remote set-url origin https://github.com/JMSBPP/cfmm-numopt.git`.
- Survivors by id: env `gams-gate`, runner 21, PR #2, redirects. Runner `.runner` `gitHubUrl` and unit name stay stale (cosmetic).
- **Real** runner verification = a dispatched job in Step 5, not the runners list. Fallback if the job never leaves `queued` (user runs the sudo parts): `cd /home/jmsbpp/actions-runner && sudo ./svc.sh stop && ./config.sh remove --token T && ./config.sh --url https://github.com/JMSBPP/cfmm-numopt --token T --name cfmm-build-gams --labels cfmm-build && sudo ./svc.sh install && sudo ./svc.sh start`.

### Step 5 — Spec/plan docs, PR, CI, merge, supersede #2 — *Senior Project Manager → Git Workflow Master*
- Write `docs/superpowers/specs/2026-08-26-numopt-migration-design.md` + `docs/superpowers/plans/2026-08-26-numopt-migration-plan.md` (from this document; two-step review already done, findings recorded); commit.
- Push branch **once** (all commits ready — every push re-queues a run needing approval); open PR (body: what/why, supersedes #2 prover commits without the sweep).
- Approve the gate via CLI: `gh api -X POST repos/JMSBPP/cfmm-numopt/actions/runs/<ID>/pending_deployments -F 'environment_ids[]=18848522657' -f state=approved -f comment=reviewed`; job must execute on `cfmm-build-gams` and go green.
- Merge (manual gate — no branch protection exists; recorded as follow-up: add a ruleset requiring the `gams` check). Approve the post-merge `push: main` run too.
- Comment + close PR #2 ("superseded by #N; prover landed without the sweep; branch retained"). Do **not** delete `gsd/phase-0-honest-gates`.
- Tell the user to start the next session in `/home/jmsbpp/cfmm-numopt` and delete `/home/jmsbpp/cfmm-gams`.

---

## Verification (end-to-end)
1. GAMS-only invariant: `git ls-files | grep -vE '^(\.agents/|docs/|model/).*\.md$|\.(gms|gdx)$|^(README|LICENSE|Makefile|\.gitignore|\.gitmodules|lean4-spec)$|^\.github/workflows/gams\.yml$'` → empty.
2. `make compile-gams` → `N ok, 0 failed` incl. `mev_tax_model_one/volume_path.gms`.
3. `make test-gams` → 4 unit drivers PASS + prover gates PASS, JSON parses, byte-identical double run.
4. PR CI run **executed** on `cfmm-build-gams` and green; post-merge `main` run green.
5. `gh repo view JMSBPP/cfmm-numopt` ok; old URL redirects.
6. `git submodule status` shows `lean4-spec` at the same SHA as before.

## Out of scope (explicit)
Honest-gates machinery / `.planning/` from the gsd branch; Python/Solidity/.plk tooling; monorepo submodule wiring; branch protection ruleset (follow-up); a CONOPT commercial licence.

## Two-step review record (plan mode, read-only)
Reviewers: **Reality Checker** + **DevOps Automator** (task = repo migration, Make/CI gate, GitHub rename).
- BLOCKER ×2 (both): cwd not empty / don't mutate live cwd → **fixed** (clone straight to `cfmm-numopt`, no rmdir/mv).
- MAJOR: "strict superset" false → **reworded** (successor; 3 diverged files dropped). Demo licence → **documented** in BUILD.md/README. Runner verify-by-listing → **replaced** by dispatched job + re-register fallback. PR #2 pending run straddling rename → **cancel first**, approve via API, approve main run. Python3 policy contradiction → **policy defined** (tracked source vs dev helpers); JSON parse check kept via guarded `jq` + in-model `fj.pw` guard. `.agents/` untracked-by-regex → **kept & enforced** by tightened regex. No branch protection → **recorded** as follow-up.
- MINOR: cherry-pick simplified (`-x`, no `-n`); `docs/volume-path.md` differs from monorepo copy (gsd version is right); `mkdir -p build` before runs; "EVM-exact" → "EVM-scaled"; `find` build exclusion; anchored gitignore.
