# Phase 0 — deferred items

Out-of-scope discoveries logged rather than fixed, per the execution scope boundary.

## From plan 00-01

### D1. `nc-runner-selftest-registry` passes if the selftest file is DELETED

- **Found:** plan 00-01, task 3.
- **What:** the row's command is
  `make negative-controls REGISTRY=model/test/_mutants/registry.selftest.tsv` with
  `expect = nonzero`. If `registry.selftest.tsv` is deleted, the runner exits **2**
  ("registry … does not exist") — still non-zero — so the row reports PASS. Deleting the
  runner's falsifiability proof leaves `make negative-controls` green.
- **Why not fixed here:** the fix is a 5th registry row, and plan 00-01's acceptance criterion
  pins the main registry at exactly `4 entries, 0 failed`. Strengthening it inside 00-01 would
  have failed 00-01's own check.
- **Proposed fix, for a plan that appends rows (00-02):** append
  `nc-selftest-file-present<TAB>positive<TAB>0<TAB>test -f model/test/_mutants/registry.selftest.tsv<TAB>the runner's mutation proof exists; deleting it must not leave the suite green`
  and, ideally, a second row pinning the selftest entry count so the file cannot be gutted to
  a single always-failing row either.
- **Note:** `expect = nonzero` on the existing row is still correct and must not be changed to an
  exact code — `make` collapses every recipe failure to its own exit status 2, so the runner's
  exit 1 is not observable through it.

### D2. `model/PricingKernelMoments.gms` is a known silent no-op inside the 12/12 baseline

- **Found:** pre-existing; restated here because plan 00-01 re-pinned the baseline.
- **What:** `compile-gams: 12 ok` includes a unit that compiles and does nothing. The count is a
  regression pin, not a goal. Phase 4 replaces the unit and the count is expected to change.
- **Action:** none in Phase 0. Do not treat `12` as a target to preserve after Phase 4.
