# Price-Impact Kernel (η=½) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the `priceImpactKernel_Add0` GAMS `$macro`, an assertion test (three properties), and a committed `price_impact_kernel.gdx` fixture in the gams worktree on branch `feat/gams`, so the gamsdiff peer can extend their differential-testing pipeline against `PriceImpactKernelHarness.plk`.

**Architecture:** Three artifacts in `/home/jmsbpp/cfmms-playground/cfmm-wt/gams` on `feat/gams`: a one-line `$macro` in `model/PricingKernel.gms`; a fixture driver `model/PriceImpactKernelFixture.gms` at model root (not `test/`) that builds a 1×241×3 grid and `execute_unload`s a Q64.96 `priceImpact` parameter plus provenance scalars to `model/price_impact_kernel.gdx`; and a test `model/test/PriceImpactKernelTest.gms` asserting zero-input no-op, dx-monotone, and an EVM-formula cross-validation against an independent `mulDiv`-form replica.

**Tech Stack:** GAMS 54.1 (`/usr/gams/gams54.1_linux_x64_64_sfx/gams`, on `PATH` as `gams`); GNU Make; bash. No Solidity, no Python, no Plank in this plan — those are out-of-scope per the spec.

## Global Constraints

- **Worktree only.** All edits in `/home/jmsbpp/cfmms-playground/cfmm-wt/gams` on branch `feat/gams`. Never edit the main checkout `/home/jmsbpp/cfmms-playground/cfmm-replicationPlank/`.
- **Shell cwd resets between Bash calls.** Every `Bash` command must use absolute paths or `cd <abs> && …` chains. Do not rely on cwd persistence.
- **Submodules.** Do NOT run `git submodule update --init`; the gams worktree is intentionally uninitialised. The GAMS toolchain requires no `lib/` content.
- **Spec is source of truth.** `docs/superpowers/specs/2026-06-28-price-impact-kernel-gams-design.md` (commit `e7c2797`). Implementation must match §5 (macro), §6 (fixture driver), §7 (test), §D9 (tolerance `1e-12`).
- **Macro form (exact, copied verbatim from spec §5):**
  ```
  $macro priceImpactKernel_Add0(sqrtP, L, dx) ( (L) * (sqrtP) / ( (L) + (dx) * (sqrtP) / power(2, 96) ) )
  ```
  Do not re-derive — the form was empirically verified against an independent EVM `mulDiv` replica during brainstorm (rel err `1.22e-16`, machine precision).
- **Provenance scalars in the GDX:** `gamsVersion = 54.1`, `etaWeight = 0.5`, `lambdaVal = lambda / unity` (= 1.0001). All three must appear in `execute_unload`.
- **Tolerance:** `1e-12` for the EVM-formula cross-validation (spec §D9). Do not invent values.
- **`Lbar` = `unity` (= 1e18, WAD).** A fresh design choice — *not* sourced from `dynamic/InitState.gms` (which only defines inventory amounts `X=1e20, Y=1e22`, no `L` symbol).
- **Fixture file location.** `model/PriceImpactKernelFixture.gms` lives at the **model root**, NOT under `model/test/`. It's a *generator*, not an assertion test. `compile-gams` will pick it up — final green count = **7 ok / 0 failed** (currently 6).
- **Out of scope for this plan** (owned by other peers): `tools/gamsdiff/` (gamsdiff CLI is hardcoded for `priceKernel`; peer `0hpyy1t4` extends it), `cfmm-wt/plank/*` (Plank harness), the Foundry diff test, the JSON fixture, the Makefile (no change required).
- **Pre-state (verified at planning time, 2026-06-28):**
  - Branch `feat/gams` HEAD = `e7c2797 docs(gams): revise priceImpactKernel spec…`.
  - `make compile-gams` → `6 ok / 0 failed`.
  - `make test-gams` → `1 passed / 0 failed` (the existing `PricingKernelTest.gms`).
  - `model/PricingKernel.gms` already defines `priceKernel`, `tunablePricingKernel`, `lambda`, `unity`, `tickSpacingDomain`, `tick`.
- **Post-merge action (NOT a plan step):** send a `claude-peers send_message` to `0hpyy1t4` after PR-ing, with the GDX path and the proposed JSON schema (spec §8). Tracked outside the plan because it's a side-effect, not a verifiable artifact in the PR.

---

## Task 1: Add `priceImpactKernel_Add0` macro + zero-input no-op test

**Files:**
- Modify: `/home/jmsbpp/cfmms-playground/cfmm-wt/gams/model/PricingKernel.gms` (append macro definition + comment block after line 39, the last line)
- Create: `/home/jmsbpp/cfmms-playground/cfmm-wt/gams/model/test/PriceImpactKernelTest.gms`

**Interfaces:**
- Consumes (from existing `model/PricingKernel.gms`): `priceKernel(tickSpacingDomain, tick)` parameter, `lambda` scalar, `unity` scalar, `tickSpacingDomain` set, `tick` set.
- Produces (for Tasks 2 and 3): `$macro priceImpactKernel_Add0(sqrtP, L, dx)` returning `(L * sqrtP) / (L + dx * sqrtP / 2^96)`. Three positional macro arguments, all numeric. Result is Q64.96 when `sqrtP` is Q64.96 and `L`, `dx` are raw.

- [ ] **Step 1: Create the failing test file**

  Create `/home/jmsbpp/cfmms-playground/cfmm-wt/gams/model/test/PriceImpactKernelTest.gms`:

  ```gams
  $title Price-impact kernel: assertion-only properties for priceImpactKernel_Add0
  * Runs under `make test-gams` (action=ce). No EVM diff here — the diff lives in
  * the Solidity test on the gamsdiff peer's track. Spec: §7.

  $include PricingKernel.gms

  Scalar Lbar; Lbar = unity;                  * = 1e18 = WAD; matches the fixture (spec §D4)

  * --- Property 1 (spec §7-1): zero-input no-op ---------------------------------
  * For every (s, t), priceImpactKernel_Add0(priceKernel(s,t), Lbar, 0) == priceKernel(s,t)
  * exactly. Reason: denominator collapses to L (the dx*sqrtP/2^96 term vanishes),
  * so the ratio reduces to sqrtP.
  Parameter noOpDelta(tickSpacingDomain, tick);
  noOpDelta(tickSpacingDomain, tick) =
      abs( priceImpactKernel_Add0(priceKernel(tickSpacingDomain, tick), Lbar, 0)
           - priceKernel(tickSpacingDomain, tick) );
  Scalar maxNoOp; maxNoOp = smax((tickSpacingDomain, tick), noOpDelta(tickSpacingDomain, tick));
  abort$(maxNoOp > 0) "FAIL: priceImpactKernel_Add0(P,L,0) must exactly equal P", maxNoOp;
  display "PASS: zero-input no-op (max abs delta)", maxNoOp;
  ```

- [ ] **Step 2: Run the test, verify it FAILS with macro-not-defined**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && make test-gams 2>&1 | tail -10
  ```

  Expected: `FAIL test/PriceImpactKernelTest.gms (gams rc=2) -> model/build/test_PriceImpactKernelTest.lst` (GAMS compile error: `priceImpactKernel_Add0` is an unknown identifier). `test-gams` exits non-zero. The existing `PricingKernelTest.gms` still passes.

  Verify the failure mode is what we expect (macro undefined, not something else):

  ```bash
  grep -n '\*\*\*\*\|priceImpactKernel_Add0' /home/jmsbpp/cfmms-playground/cfmm-wt/gams/model/build/test_PriceImpactKernelTest.lst | head -10
  ```

  Expected: one of the `****` error lines mentions `priceImpactKernel_Add0` (the unknown identifier), confirming red is for the right reason — not a typo elsewhere.

- [ ] **Step 3: Add the macro to `model/PricingKernel.gms`**

  Append after the existing trailing line (line 39, the `tunablePricingKernel` macro). The exact text to append:

  ```gams


  * priceImpactKernel_Add0(sqrtP, L, dx): post-trade sqrt price (Q64.96) for the
  * η = 1/2 kernel, selling token0 for token1 (Uniswap V3 add=true direction).
  * Mirrors v3::math::sqrt_price_math::getNextSqrtPriceFromAmount0RoundingUp(P, L, dx, true)
  * exposed by PriceImpactKernelHarness.plk.
  *
  * Scale convention:
  *   sqrtP enters in Q64.96 (the on-chain scale produced by `priceKernel`);
  *   L and dx enter raw (matching `liquidity` uint128 and `amount` uint256);
  *   the macro returns Q64.96 (directly comparable to the EVM output).
  * The EVM's `numerator1 = L << 96` introduces an asymmetric scaling: in the
  * denominator, L is raw but dx*sqrtP is Q96, so the dx*sqrtP product must be
  * divided by 2^96 before being added to L. The "scales cancel" intuition is
  * WRONG; the asymmetry is load-bearing. Empirically verified against an
  * independent EVM mulDiv replica (rel err = 1.22e-16 at machine precision).
  *
  * Rounding: Uniswap rounds the division UP (mulDivRoundingUp); GAMS uses IEEE
  * doubles. The differential diff uses assertApproxEqRel at 1e-12 (spec §D8/§D9).
  *
  * Naming: the `_Add0` suffix marks the token0-input direction; future siblings
  * `_Add1` (token1-input) and a potential `_Sub0/_Sub1` (add=false branch) will
  * share the `priceImpactKernel_` prefix.
  *
  * TODO(eta-CES): a tunable-η post-trade form is reachable via the lean4-spec
  * kernel-split identity (CFMM.Eta.eta_split_kernel_identity, see
  * lean4-spec/lean/exp/eta.lean), but blocked on an η-CES post-trade EVM
  * function existing to diff against.
  $macro priceImpactKernel_Add0(sqrtP, L, dx) ( (L) * (sqrtP) / ( (L) + (dx) * (sqrtP) / power(2, 96) ) )
  ```

- [ ] **Step 4: Run the test, verify PASS**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && make test-gams 2>&1 | tail -6
  ```

  Expected: `PASS test/PriceImpactKernelTest.gms`, summary line `test-gams: 2 passed, 0 failed`, exit 0.

- [ ] **Step 5: Verify `compile-gams` still 6 ok**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && make compile-gams 2>&1 | tail -4
  ```

  Expected: `compile-gams: 6 ok, 0 failed, 0 skipped`, exit 0. (No new file at model root yet — the test file lives under `model/test/` which `compile-gams` excludes via `-not -path './test/*'`.)

- [ ] **Step 6: Commit**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && \
    git add model/PricingKernel.gms model/test/PriceImpactKernelTest.gms && \
    git commit -m "$(cat <<'EOF'
  feat(gams): add priceImpactKernel_Add0 macro + zero-input no-op test

  Mirrors v3 getNextSqrtPriceFromAmount0RoundingUp(P, L, dx, add=true) for the
  η=1/2 kernel. Macro takes sqrtP in Q64.96 and returns Q64.96, with the dx*sqrtP
  product divided by 2^96 to reconcile against the EVM's raw-L / Q96-sqrtP
  asymmetry (numerator1 = L<<96). Empirical verification done during spec
  brainstorm; this test asserts the zero-input boundary across the full grid.

  Spec: docs/superpowers/specs/2026-06-28-price-impact-kernel-gams-design.md §5, §7-1.

  Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Task 2: Add monotone-in-dx + EVM-formula cross-validation properties

**Files:**
- Modify: `/home/jmsbpp/cfmms-playground/cfmm-wt/gams/model/test/PriceImpactKernelTest.gms` (append two more property blocks)

**Interfaces:**
- Consumes: `priceImpactKernel_Add0` (Task 1), `priceKernel`, `lambda`, `unity`.
- Produces: nothing new (still just an assertion test).

- [ ] **Step 1: Append the monotonicity (Property 2) block**

  Append to `/home/jmsbpp/cfmms-playground/cfmm-wt/gams/model/test/PriceImpactKernelTest.gms`:

  ```gams


  * --- Property 2 (spec §7-2): monotone in dx ----------------------------------
  * For every (s, t): priceImpact at small > medium > large. Economically: selling
  * more token0 strictly depresses the post-trade sqrtPX96. Counts every (s,t)
  * where the strict ordering is violated; abort if any violation exists.
  Set       dxD       / small, medium, large /;
  Parameter dxVal(dxD);
  dxVal('small')  = Lbar / 1000;                * 1e15
  dxVal('medium') = Lbar /   10;                * 1e17
  dxVal('large')  = Lbar;                       * 1e18

  Parameter pi(tickSpacingDomain, tick, dxD);
  pi(tickSpacingDomain, tick, dxD) =
      priceImpactKernel_Add0(priceKernel(tickSpacingDomain, tick), Lbar, dxVal(dxD));

  Parameter monoBreaks(tickSpacingDomain, tick);
  monoBreaks(tickSpacingDomain, tick) =
      1$( pi(tickSpacingDomain, tick, 'small')  <= pi(tickSpacingDomain, tick, 'medium') )
    + 1$( pi(tickSpacingDomain, tick, 'medium') <= pi(tickSpacingDomain, tick, 'large')  );
  Scalar totalBreaks; totalBreaks = sum((tickSpacingDomain, tick), monoBreaks(tickSpacingDomain, tick));
  abort$(totalBreaks > 0)
      "FAIL: dx-monotone (small > medium > large) violated somewhere on the grid",
      totalBreaks;
  display "PASS: dx-monotone over full grid (violation count)", totalBreaks;
  ```

- [ ] **Step 2: Append the EVM-formula cross-validation (Property 3) block**

  Append to the same file:

  ```gams


  * --- Property 3 (spec §7-3): EVM-formula cross-validation --------------------
  * Reproduce the EVM's mulDiv-form algebra independently (different parenthesisation)
  * at one spot (tick=k121, dx=medium) and assert agreement with the macro at the
  * committed 1e-12 tolerance (spec §D9). Independence is structural — a typo in
  * the macro's surface form cannot also appear in this alternative expression.
  Scalar Q96; Q96 = power(2, 96);
  Scalar evmRef;
  evmRef = (Lbar * Q96) * priceKernel('s1','k121')
         / ((Lbar * Q96) + dxVal('medium') * priceKernel('s1','k121'));
  Scalar macroVal; macroVal = pi('s1','k121','medium');
  Scalar evmRelErr; evmRelErr = abs(macroVal - evmRef) / evmRef;
  abort$(evmRelErr > 1e-12)
      "FAIL: priceImpactKernel_Add0 disagrees with independent EVM-formula reproduction",
      macroVal, evmRef, evmRelErr;
  display "PASS: EVM-formula cross-validation at (k121, medium) — relErr:", evmRelErr;
  ```

- [ ] **Step 3: Run the test, verify all three properties PASS**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && make test-gams 2>&1 | tail -6
  ```

  Expected: `PASS test/PriceImpactKernelTest.gms`, summary line `test-gams: 2 passed, 0 failed`, exit 0.

  Also confirm the three asserts actually ran (look at the `.lst` listing — each `display` line should have printed):

  ```bash
  grep -E 'PASS:|maxNoOp|totalBreaks|evmRelErr' /home/jmsbpp/cfmms-playground/cfmm-wt/gams/model/build/test_PriceImpactKernelTest.lst | head -20
  ```

  Expected: three `PASS:` lines (no-op, monotone, EVM cross-val) and the three diagnostic values; `evmRelErr` should be at machine precision (`<= ~2e-16`).

- [ ] **Step 4: Commit**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && \
    git add model/test/PriceImpactKernelTest.gms && \
    git commit -m "$(cat <<'EOF'
  test(gams): add dx-monotone + EVM-formula cross-validation properties

  Property 2 sweeps the full (tickSpacing, tick) grid asserting strict
  monotonicity in dx (small > medium > large), the swap-direction sign.
  Property 3 reproduces the EVM mulDiv algebra independently at one spot
  (k121, medium) and diffs against the macro at the committed 1e-12 tolerance.
  Together with §7-1 these are the three properties spec'd for the
  assertion-only test file.

  Spec: docs/superpowers/specs/2026-06-28-price-impact-kernel-gams-design.md §7-2, §7-3, §D9.

  Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Task 3: Fixture driver + committed GDX (+ final success-criteria check)

**Files:**
- Create: `/home/jmsbpp/cfmms-playground/cfmm-wt/gams/model/PriceImpactKernelFixture.gms`
- Create (generated, committed): `/home/jmsbpp/cfmms-playground/cfmm-wt/gams/model/price_impact_kernel.gdx`

**Interfaces:**
- Consumes: `priceImpactKernel_Add0` (Task 1), `priceKernel`, `lambda`, `unity`, `tick`, `tickSpacingDomain`.
- Produces (GDX symbols, for the gamsdiff peer to consume per spec §8):
  - `priceImpact(s, t, dxD)` — 1 × 241 × 3 = 723 records, Q64.96 post-trade sqrt prices.
  - `Lbar` (scalar, `1e18`).
  - `dxVal(dxD)` — three labels `{small, medium, large}` mapped to `{1e15, 1e17, 1e18}`.
  - `gamsVersion` (scalar, `54.1`).
  - `etaWeight` (scalar, `0.5`).
  - `lambdaVal` (scalar, `1.0001`).

- [ ] **Step 1: Create the fixture driver**

  Create `/home/jmsbpp/cfmms-playground/cfmm-wt/gams/model/PriceImpactKernelFixture.gms`:

  ```gams
  $title Price-impact kernel GDX fixture (priceImpact(s,t,dxD) in Q64.96 + provenance)
  * Generator (not an assertion test) — writes model/price_impact_kernel.gdx for the
  * gamsdiff peer to consume per spec §6/§8. Lives at model/ root (NOT model/test/)
  * because compile-gams must syntax-check it; test-gams must NOT execute it.

  $include PricingKernel.gms

  Scalar Lbar; Lbar = unity;                       * = 1e18 = WAD (spec §D4; fresh design choice)

  Set       dxD       / small, medium, large /;
  Parameter dxVal(dxD);
  dxVal('small')  = Lbar / 1000;                   * 1e15
  dxVal('medium') = Lbar /   10;                   * 1e17
  dxVal('large')  = Lbar;                          * 1e18

  * Literal singleton declared locally so the GDX domain on `priceImpact` is
  * reported as `s`, not the parent `tickSpacingDomain`. We index priceKernel
  * with the string literal 's1' (which IS a label in tickSpacingDomain), so
  * GAMS resolves it without a domain-mismatch error.
  Set s / s1 /;

  Parameter priceImpact(s, tick, dxD);
  priceImpact('s1', tick, dxD) =
      priceImpactKernel_Add0(priceKernel('s1', tick), Lbar, dxVal(dxD));

  * Provenance scalars (spec §D6) so the GDX is self-describing for version/parameters.
  Scalar gamsVersion / 54.1 /;                     * matches model/BUILD.md pinned toolchain
  Scalar etaWeight   / 0.5  /;                     * η = 1/2 (the kernel this fixture is specialised to)
  Scalar lambdaVal;  lambdaVal = lambda / unity;   * = 1.0001 (the pricing-kernel base)

  execute_unload 'price_impact_kernel.gdx',
      priceImpact, Lbar, dxVal,
      gamsVersion, etaWeight, lambdaVal;
  ```

- [ ] **Step 2: Run `make compile-gams` to confirm the fixture syntax-checks (now 7 ok)**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && make compile-gams 2>&1 | tail -10
  ```

  Expected: line `OK   PriceImpactKernelFixture.gms`, summary `compile-gams: 7 ok, 0 failed, 0 skipped`, exit 0. (`compile-gams` runs with `action=c`, so `execute_unload` is *not* executed during this check — that happens in the next step.)

- [ ] **Step 3: Generate the GDX (action=ce, runs from model/ so the relative output path lands correctly)**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams/model && \
    mkdir -p build && \
    gams PriceImpactKernelFixture.gms action=ce \
         o=build/PriceImpactKernelFixture.lst scrdir=build lo=0 ; \
    echo "exit=$?"
  ```

  Expected: `exit=0`. The GDX lands at `/home/jmsbpp/cfmms-playground/cfmm-wt/gams/model/price_impact_kernel.gdx` (relative to the cwd of `gams`, which we set to `model/`).

- [ ] **Step 4: Verify the GDX has the 6 documented symbols + 723 rows under `priceImpact`**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && \
    gdxdump model/price_impact_kernel.gdx Symbols | head -20
  ```

  Expected output lists exactly these symbols (order may vary): `priceImpact`, `Lbar`, `dxVal`, `gamsVersion`, `etaWeight`, `lambdaVal`, plus the auto-promoted domain sets `s`, `tick`, `dxD`. The `priceImpact` line should show domain `(s, tick, dxD)` and `Records = 723`.

  Then sanity-check one value (tick=k121 at dx=medium should match the §D8 derivation, ≈ `7.20e28`):

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && \
    gdxdump model/price_impact_kernel.gdx Symb=priceImpact Filter=s1,k121,medium 2>/dev/null | grep -E 'k121|7\.20' | head
  ```

  Expected: a single value line with `~7.20e28` (more precisely, the same number the test's `evmRef` computed in Task 2 step 3 — they share the formula and inputs).

- [ ] **Step 5: Run `make test-gams` once more to confirm the new fixture file doesn't accidentally break the test layer**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && make test-gams 2>&1 | tail -4
  ```

  Expected: `test-gams: 2 passed, 0 failed`, exit 0.

- [ ] **Step 6: Verify `.gitignore` does not exclude `*.gdx`**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && \
    git check-ignore -v model/price_impact_kernel.gdx ; \
    echo "exit=$?"
  ```

  Expected: `exit=1` (nothing prints) — the file is *not* gitignored. If it IS gitignored (exit 0), the gitignore must be patched to allow `model/*.gdx` since the sister `model/pricing_kernel.gdx` is committed.

- [ ] **Step 7: Commit (fixture driver + GDX together)**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && \
    git add model/PriceImpactKernelFixture.gms model/price_impact_kernel.gdx && \
    git commit -m "$(cat <<'EOF'
  feat(gams): price-impact-kernel fixture driver + committed GDX

  Adds model/PriceImpactKernelFixture.gms (the generator) and the generated
  model/price_impact_kernel.gdx (723 rows of priceImpact(s,t,dxD) in Q64.96
  plus Lbar, dxVal, and the provenance scalars gamsVersion/etaWeight/lambdaVal).
  Fixture lives at model/ root (not test/) because it's a generator, not an
  assertion test — bumps make compile-gams from 6 ok to 7 ok.

  The GDX is the artifact the gamsdiff peer (0hpyy1t4) will consume to emit
  test/gamsDiff/fixtures/price_impact_kernel.json and write a Foundry diff
  against PriceImpactKernelHarness.plk at the committed 1e-12 tolerance.

  Spec: docs/superpowers/specs/2026-06-28-price-impact-kernel-gams-design.md §6, §8.

  Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
  EOF
  )"
  ```

- [ ] **Step 8: Final success-criteria check (spec §10) — run all three checks back-to-back**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && \
    echo '=== compile-gams ===' && make compile-gams 2>&1 | tail -3 && \
    echo '=== test-gams ===' && make test-gams 2>&1 | tail -3 && \
    echo '=== gdxdump schema ===' && gdxdump model/price_impact_kernel.gdx Symbols 2>&1 | head -12
  ```

  Expected, in order:
  - `compile-gams: 7 ok, 0 failed, 0 skipped`
  - `test-gams: 2 passed, 0 failed`
  - `gdxdump` lists `priceImpact`, `Lbar`, `dxVal`, `gamsVersion`, `etaWeight`, `lambdaVal` (plus auto-promoted sets `s`, `tick`, `dxD`).

  If any line fails or counts differ, do not push — diagnose the gap against the spec's §10 success criteria before continuing.

- [ ] **Step 9: Push to `origin`**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && git push 2>&1 | tail -3
  ```

  Expected: push succeeds (upstream `origin/feat/gams` was already set on the prior PR). The PR `JMSBPP/cfmm-replicationPlank#1` picks up these three commits automatically.

---

## Self-Review (checked by plan author at write time)

**Spec coverage:**
- §5 macro → Task 1 step 3 (verbatim).
- §6 fixture driver → Task 3 step 1 (verbatim algebra + provenance scalars).
- §7 properties 1-3 → Task 1 step 1 (P1), Task 2 step 1 (P2), Task 2 step 2 (P3).
- §D9 `1e-12` tolerance → Task 2 step 2 (`evmRelErr > 1e-12`).
- §D6 provenance scalars → Task 3 step 1 (all three present in `execute_unload`).
- §10 success criteria → Task 3 step 8 (compile-gams 7 ok, test-gams 2 passed, gdxdump shows 6 symbols).
- §8 handoff → out of plan scope; the post-merge `claude-peers send_message` is called out in Global Constraints, not as a step.

**Placeholder scan:** No `TBD`, no `TODO` in the executable steps (the `TODO(eta-CES)` is *inside* the committed macro comment, which is the spec's documented signpost, not a plan gap). No "similar to" cross-references; each task contains its own code.

**Type/name consistency:** `priceImpactKernel_Add0(sqrtP, L, dx)` defined Task 1 step 3, used identically in Task 1 step 1, Task 2 step 1, Task 2 step 2, Task 3 step 1. `Lbar`, `dxD`, `dxVal`, `pi` referenced consistently across Task 2 and (with different scope) Task 3. GDX symbol names (`priceImpact`, `Lbar`, `dxVal`, `gamsVersion`, `etaWeight`, `lambdaVal`) match between the `execute_unload` call (Task 3 step 1) and the `gdxdump` verification (Task 3 steps 4 and 8).

**Hidden assumption check:** Task 3's `execute_unload 'price_impact_kernel.gdx'` writes relative to `gams`'s cwd. The plan pins that cwd to `model/` in Task 3 step 3 (`cd .../gams/model && gams ...`), so the GDX lands at `model/price_impact_kernel.gdx` as the spec requires. The same path is then `git add`-ed in step 7 and `gdxdump`-ed in step 4 from the worktree root — both use the same `model/price_impact_kernel.gdx` relative path. Consistent.
