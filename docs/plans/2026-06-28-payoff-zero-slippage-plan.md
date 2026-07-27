# Payoff Zero-Slippage (cycle 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the `PayoffModule` scaffolding + the first per-theorem program (`eta_pi_trader_zero_slippage`) on branch `feat/gams-payoff` in the gams worktree, with a committed control-target GDX fixture, so the gamsdiff peer can later consume it and a future EVM controller can read its `diStarInt = 35` operational target.

**Architecture:** Five GAMS source files (scaffolding, per-theorem, orchestrator, test rollup, fixture-generator-via-driver), two new Makefile targets that codify the rev-4 pre-flight discipline, one `.gitignore` re-include for the committed binary. The pre-flighted spec MD is the source of truth: every per-theorem source file is **extracted from the spec MD verbatim via the spec-preflight Python regex**, never hand-transcribed (rev 3 shipped because of hand-transcription drift; rev 4's discipline is what this plan bakes in).

**Tech Stack:** GAMS 54.1 (`/usr/gams/gams54.1_linux_x64_64_sfx/gams` on PATH); GNU Make; Python 3 (for MD-block extraction); bash. No Solidity, no Plank, no Lean in this plan — those are out-of-scope per the spec.

## Global Constraints

- **Worktree only.** All edits in `/home/jmsbpp/cfmms-playground/cfmm-wt/gams` on branch `feat/gams-payoff`. Never edit the main checkout `/home/jmsbpp/cfmms-playground/cfmm-replicationPlank/`.
- **Shell cwd resets between Bash calls.** Every command must use absolute paths or `cd <abs> && …` chains.
- **Do NOT run `git submodule update --init`** — submodules in this worktree are intentionally uninitialised.
- **Spec is source of truth.** `docs/superpowers/specs/2026-06-28-payoff-zero-slippage-design.md` (rev 4, commit `d9f4164`). Source code MUST come from the spec's `gams` code blocks via extraction (`spec-preflight` does this), never hand-transcription.
- **Pre-state (verified at planning time, 2026-06-28):**
  - Branch `feat/gams-payoff` HEAD = `d9f4164 docs(gams): spec rev 4 — actually-pre-flighted on the spec text`.
  - Worktree clean (`git status` empty).
  - `make compile-gams` → `8 ok / 0 failed`. `make test-gams` → `2 passed / 0 failed`. (`Lean PR #2` already on `develop` at the spec's pinned commit.)
- **Scale conventions locked to spec values:** `Q96 = 2^96`; `Q128 = 2^128`; `etaQ128 = 2^127`; `lambdaWad = 1.0001·1e18`; `diffTolerance = 1e-12`; `zeroTolerance = 1e-20`; `tieBreaking = 1`; `diMinInt = 1`; `diMaxInt = 200`; canonical config `iCfg=60, LbarQ128=Q128, DICfgQ128=Q128/10`.
- **`spec-preflight` is the pre-flight gate** — Task 1 establishes it; every subsequent task that touches the spec must re-run it before commit. Hand-transcribed code is forbidden.
- **Out of scope** (owned by other peers): `tools/gamsdiff/`, `cfmm-wt/plank/*`, the Foundry diff test, the JSON fixture, `cfmm-wt/lean4-spec/*`, the Makefile's existing `plank`/`gams-fixtures` targets (don't modify).
- **Final state after all 5 tasks:** 5 commits on `feat/gams-payoff`, pushed to `origin/feat/gams-payoff`, PR opened against `develop`. `make compile-gams` = 10/0; `make test-gams` = 3/0; `make payoff-fixtures` produces `model/payoff_zero_slippage.gdx`; `make spec-preflight` passes.

---

## Task 1: Makefile + `.gitignore` — pre-flight discipline foundation

**Files:**
- Modify: `/home/jmsbpp/cfmms-playground/cfmm-wt/gams/Makefile` (append 2 new targets, update `.PHONY`)
- Modify: `/home/jmsbpp/cfmms-playground/cfmm-wt/gams/.gitignore` (add 1 re-include line)

**Interfaces:**
- Consumes: nothing from earlier tasks (this is Task 1).
- Produces (for Tasks 2-5):
  - `make spec-preflight` — extracts §5 + §6 from spec MD via Python regex, copies into `model/build/spec/`, runs `gams … action=ce`, greps the `.lst` for `Compilation error` / `Execution error`. Exits non-zero on any error marker.
  - `make payoff-fixtures` — runs each `model/payoff/eta_*.gms` with `action=ce` from inside `model/` (so `execute_unload 'payoff_zero_slippage.gdx'` lands at `model/`); greps `.lst` for error markers (since `gams` exits 0 even on compile errors — RC's finding).
  - `.gitignore` admits `model/payoff_zero_slippage.gdx` for `git add` (no `git add -f` needed).

- [ ] **Step 1: Inspect existing Makefile shape (to know where to append)**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && \
    grep -n '^\.PHONY' Makefile && \
    grep -n 'gams-fixtures\|compile-gams\|test-gams' Makefile | head -10
  ```

  Expected: existing `.PHONY: compile-plank clean-plank compile-gams test-gams clean-gams` line (line ~138) and the gams targets above it. The two new targets append AFTER `clean-gams` and BEFORE `.PHONY` (or anywhere, but keep the gams targets contiguous).

- [ ] **Step 2: Append `payoff-fixtures` target to Makefile**

  Open the file, find the line `# clean-gams: remove GAMS listings, save/scratch, and build artifacts.` (look for the `clean-gams:` target block, ~line 128). Insert this block AFTER the `clean-gams` recipe's `@rm -rf …` line and BEFORE the existing `# gams-fixtures` block or the `.PHONY` line at the bottom.

  Recipe lines start with **literal TABs** (not spaces). When pasting from this MD, ensure each indented recipe line is `\t`-prefixed.

  ```makefile

  # payoff-fixtures: regenerate committed per-theorem payoff GDX(s).
  # Detects compile/execution errors by post-grepping the .lst — `gams` exits 0
  # even on compile errors, so the recipe MUST grep, not rely on exit code alone.
  .PHONY: payoff-fixtures
  payoff-fixtures:
  	@mkdir -p $(GAMS_DIR)/$(GAMS_BUILD)
  	@cd $(GAMS_DIR) && rc=0; \
  	for f in $$(find payoff -name 'eta_*.gms' 2>/dev/null | sort); do \
  		out="$(GAMS_BUILD)/$$(echo "$$f" | tr / _ | sed 's/\.gms$$//').lst"; \
  		printf '>> regenerating fixture from %s\n' "$$f"; \
  		$(GAMS) "$$f" action=ce o="$$out" scrdir="$(GAMS_BUILD)" lo=0 >/dev/null 2>&1 ; \
  		if grep -qE 'Status: (Compilation|Execution) error' "$$out"; then \
  			printf '   FAIL %s -> %s/%s (status line indicates error)\n' "$$f" "$(GAMS_DIR)" "$$out"; rc=1; \
  		else \
  			printf '   OK %s\n' "$$f"; \
  		fi; \
  	done; \
  	exit $$rc
  ```

- [ ] **Step 3: Append `spec-preflight` target to Makefile**

  Append immediately after the `payoff-fixtures` block:

  ```makefile

  # spec-preflight: extract code blocks from the rev-4 spec MD and verify they
  # compile + run clean. Codifies the rev-4 discipline: before any spec commit,
  # this target must pass. Uses Python regex to extract §5 + §6 verbatim.
  .PHONY: spec-preflight
  spec-preflight:
  	@mkdir -p $(GAMS_DIR)/$(GAMS_BUILD)/spec
  	@SPEC=docs/superpowers/specs/2026-06-28-payoff-zero-slippage-design.md; \
  	python3 -c "import re, sys; \
  text = open('$$SPEC').read(); \
  secs = re.split(r'^(## \d+\.[^\n]*)\n', text, flags=re.M); \
  out5 = '$(GAMS_DIR)/$(GAMS_BUILD)/spec/_PayoffScaffolding.gms'; \
  out6 = '$(GAMS_DIR)/$(GAMS_BUILD)/spec/eta_pi_trader_zero_slippage.gms'; \
  [open(out5,'w').write(re.search(r'\`\`\`gams\n(.*?)\n\`\`\`', secs[i+1], re.S).group(1)) for i in range(1,len(secs),2) if secs[i].startswith('## 5.')]; \
  [open(out6,'w').write(re.search(r'\`\`\`gams\n(.*?)\n\`\`\`', secs[i+1], re.S).group(1)) for i in range(1,len(secs),2) if secs[i].startswith('## 6.')]"; \
  cp $(GAMS_DIR)/PricingKernel.gms $(GAMS_DIR)/primitives.gms $(GAMS_DIR)/$(GAMS_BUILD)/spec/; \
  cd $(GAMS_DIR)/$(GAMS_BUILD)/spec && \
  $(GAMS) eta_pi_trader_zero_slippage.gms action=ce o=run.lst scrdir=. lo=0 >/dev/null 2>&1 ; \
  if grep -qE 'Status: (Compilation|Execution) error' run.lst; then \
  	printf 'spec-preflight FAIL: see $(GAMS_DIR)/$(GAMS_BUILD)/spec/run.lst\n'; \
  	grep -A1 '^\*\*\*\*' run.lst | head -10; exit 1; \
  else \
  	printf 'spec-preflight OK (canonical config: diStarInt=35)\n'; \
  fi
  ```

- [ ] **Step 4: Update the bottom `.PHONY` line to include the two new targets**

  Find the line at end of Makefile: `.PHONY: compile-plank clean-plank compile-gams test-gams clean-gams`. Each of `payoff-fixtures` and `spec-preflight` already has its own `.PHONY:` declaration above (Step 2/3), but adding them to the consolidated line at bottom is conventional. Edit:

  ```makefile
  .PHONY: compile-plank clean-plank compile-gams test-gams clean-gams payoff-fixtures spec-preflight
  ```

- [ ] **Step 5: Update `.gitignore` to re-include `model/payoff_zero_slippage.gdx`**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && \
    grep -n 'price_impact_kernel.gdx\|payoff_zero_slippage.gdx\|model/\*\*/\*\.gdx' .gitignore
  ```

  Expected: line `model/**/*.gdx` (the broad ignore) followed by `!model/price_impact_kernel.gdx` (the prior cycle's re-include). Add a sibling line `!model/payoff_zero_slippage.gdx` immediately after the existing `!model/price_impact_kernel.gdx` line, using the Edit tool:

  ```
  !model/price_impact_kernel.gdx
  !model/payoff_zero_slippage.gdx
  ```

- [ ] **Step 6: Verify gitignore patch is surgical (regression check)**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && \
    git check-ignore -v model/payoff_zero_slippage.gdx ; echo "payoff exit=$?" ; \
    git check-ignore -v model/price_impact_kernel.gdx ; echo "price_impact exit=$?" ; \
    git check-ignore -v model/build/scratch.gdx ; echo "scratch exit=$?"
  ```

  Expected:
  - `payoff exit=1` (NOT ignored — the re-include works).
  - `price_impact exit=1` (still NOT ignored — sister fixture, regression check).
  - `scratch exit=0` (still ignored — sub-dir GDXs are not re-included).

- [ ] **Step 7: Smoke-test `make spec-preflight` against the already-committed rev-4 spec**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && make spec-preflight
  ```

  Expected: `spec-preflight OK (canonical config: diStarInt=35)`, exit 0. (If FAIL, the spec text in the MD has drifted from the empirically-verified canonical pre-flight; investigate the listing at `model/build/spec/run.lst` before continuing.)

- [ ] **Step 8: Smoke-test `make payoff-fixtures` reports no-op cleanly**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && make payoff-fixtures
  ```

  Expected: no output between the recipe lines and `exit 0` (the `find payoff -name 'eta_*.gms'` glob returns nothing because Task 2 hasn't created `model/payoff/` yet). The target is a no-op until per-theorem files exist; this confirms the recipe is syntactically valid.

- [ ] **Step 9: Verify the existing `compile-gams` and `test-gams` still work (no regression)**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && make compile-gams 2>&1 | tail -3 && make test-gams 2>&1 | tail -3
  ```

  Expected: `compile-gams: 8 ok, 0 failed, 0 skipped` and `test-gams: 2 passed, 0 failed`. (Unchanged from pre-state.)

- [ ] **Step 10: Commit**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && \
    git add Makefile .gitignore && \
    git commit -m "$(cat <<'EOF'
  build(gams): payoff-fixtures + spec-preflight Makefile targets + gitignore re-include

  Foundation for the payoff zero-slippage cycle. Two new Make targets:
   - payoff-fixtures: regenerates per-theorem GDXs from model/payoff/eta_*.gms;
     post-greps the .lst for compile/exec errors (GAMS exits 0 even on parse
     failures, per RC's rev-3 finding).
   - spec-preflight: extracts §5 + §6 from the rev-4 spec MD via Python regex,
     runs gams on the actual text, greps for error markers. Codifies the
     rev-4 lesson: hand-transcription is forbidden; verify the MD text itself.

  .gitignore re-includes model/payoff_zero_slippage.gdx (mirrors prior
  cycle's !model/price_impact_kernel.gdx pattern). git add -f forbidden;
  scratch GDXs under model/build/ stay ignored.

  Smoke tests: spec-preflight passes on committed rev-4 spec; payoff-fixtures
  is a no-op until model/payoff/ exists; compile-gams (8 ok) and test-gams
  (2 passed) unchanged.

  Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Task 2: Extract scaffolding + per-theorem + edit orchestrator

**Files:**
- Create: `/home/jmsbpp/cfmms-playground/cfmm-wt/gams/model/payoff/_PayoffScaffolding.gms` (extracted from spec §5)
- Create: `/home/jmsbpp/cfmms-playground/cfmm-wt/gams/model/payoff/eta_pi_trader_zero_slippage.gms` (extracted from spec §6)
- Modify: `/home/jmsbpp/cfmms-playground/cfmm-wt/gams/model/PayoffModule.gms` (stub → orchestrator from spec §7)

**Interfaces:**
- Consumes: `make spec-preflight` from Task 1.
- Produces (for Tasks 3-4):
  - `model/payoff/_PayoffScaffolding.gms` — include-guarded; defines `Q96`, `Q128`, `diMinInt`, `diMaxInt`, `etaQ128`, `lambdaWad`, `diffTolerance`, `zeroTolerance`, `tieBreaking`, plus dual-coord macros (`P_Lean_at`, `P_Lean_post`, `piTrader_Half_Lean`, `sqrtPX96_at`, `priceImpactQ128_Add0`, `traderTerm_Half_Plank`, `traderDeltaO_Half_Plank`, `piTrader_Half_Plank`). No `$eolcom` directive — caller sets it.
  - `model/payoff/eta_pi_trader_zero_slippage.gms` — `$title`, `$eolcom #`, `$include _PayoffScaffolding.gms`, 11 asserts, GDX `execute_unload`. Caller's `$eolcom #` propagates into the include.
  - `model/PayoffModule.gms` — orchestrator (`$eolcom #` + `$include payoff/eta_pi_trader_zero_slippage.gms`).

- [ ] **Step 1: Create `model/payoff/` directory and extract scaffolding from spec MD**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && \
    mkdir -p model/payoff && \
    python3 -c "
  import re
  text = open('docs/superpowers/specs/2026-06-28-payoff-zero-slippage-design.md').read()
  secs = re.split(r'^(## \d+\.[^\n]*)\n', text, flags=re.M)
  for i in range(1, len(secs), 2):
      h, b = secs[i], secs[i+1]
      m = re.search(r'\`\`\`gams\n(.*?)\n\`\`\`', b, re.S)
      if not m: continue
      if h.startswith('## 5.'):
          open('model/payoff/_PayoffScaffolding.gms', 'w').write(m.group(1) + '\n')
          print(f'wrote scaffolding ({len(m.group(1).splitlines())} lines)')
      elif h.startswith('## 6.'):
          open('model/payoff/eta_pi_trader_zero_slippage.gms', 'w').write(m.group(1) + '\n')
          print(f'wrote per-theorem ({len(m.group(1).splitlines())} lines)')
  "
  ```

  Expected output: `wrote scaffolding (~43 lines)` and `wrote per-theorem (~198 lines)`.

- [ ] **Step 2: Edit `model/PayoffModule.gms` (stub → orchestrator)**

  Use the Edit tool. Read current content first (it's `$include primitives.gms` per the spec). Replace entirely with the orchestrator from spec §7:

  ```gams
  $title PayoffModule orchestrator — $include the per-theorem subset the driver wants.
  $eolcom #
  # Per-theorem files $include _PayoffScaffolding.gms themselves (include-guarded).
  $include payoff/eta_pi_trader_zero_slippage.gms
  # Future cycles append per-theorem $include lines here.
  ```

  Note: this matches §7 of the spec verbatim. If spec §7 has been edited since rev-4 commit `d9f4164`, re-extract from the current MD.

- [ ] **Step 3: Verify `make compile-gams` reports 10 ok**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && make compile-gams 2>&1 | tail -4
  ```

  Expected: `compile-gams: 10 ok, 0 failed, 0 skipped`. The 2 new files (`_PayoffScaffolding.gms`, `eta_pi_trader_zero_slippage.gms`) are auto-discovered by the recursive `find` under `model/payoff/`.

  If FAIL: the spec-preflight target succeeded but compile-gams fails standalone — likely the scaffolding has a `#` comment that fails when not included (Q3-locked: scaffolding uses column-1 `*` only, so should not happen; investigate the .lst).

- [ ] **Step 4: Verify `make spec-preflight` still passes (sanity — code on disk matches spec)**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && make spec-preflight
  ```

  Expected: `spec-preflight OK (canonical config: diStarInt=35)`, exit 0.

- [ ] **Step 5: Commit**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && \
    git add model/PayoffModule.gms model/payoff/_PayoffScaffolding.gms model/payoff/eta_pi_trader_zero_slippage.gms && \
    git commit -m "$(cat <<'EOF'
  feat(gams): payoff scaffolding + first per-theorem program (zero-slippage)

  Extracted verbatim from spec rev-4 (commit d9f4164) §5 and §6 via the
  spec-preflight Python regex — no hand-transcription. PayoffModule.gms
  goes from stub to thin orchestrator ($include of the one per-theorem
  file shipping this cycle).

  - model/payoff/_PayoffScaffolding.gms: dual-coord macros for the Lean
    coordinate (P_Lean_at, piTrader_Half_Lean) and the Plank coordinate
    (sqrtPX96_at, piTrader_Half_Plank) plus boundary adapter
    priceImpactQ128_Add0 wrapping the prior-cycle's priceImpactKernel_Add0.
    Scale constants (Q96, Q128, etaQ128 = 2^127), provenance + tolerances
    (diffTolerance=1e-12, zeroTolerance=1e-20, tieBreaking=1). Column-1
    * comments only so the file is compile-clean standalone.
  - model/payoff/eta_pi_trader_zero_slippage.gms: first per-theorem
    program. 11 asserts: bridge (X), A_Lean, A_Plank, B_Plank (no sqrt,
    rev-3 bug fixed), 2×B_indep (probe-pair kernel-shape), B_ext
    (external ref vs tunablePricingKernel at canonical), C_Plank (NLP
    modelStat + 1-tick bound, no precision claim — rev-3 lesson), D_Plank
    (enumeration argmin matches round(Δᵢ⋆_Plank)), 2×E (V-shape left/right),
    G (parabolic boundary guard), F (parabolic-interp argmin matches Lean
    to ~1e-3).
  - model/PayoffModule.gms: orchestrator (stub before this commit). Future
    cycles append one $include line each.

  Empirically pre-flighted via make spec-preflight; compile-gams=10/0.

  Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Task 3: Test rollup file (`model/test/PayoffModuleTest.gms`)

**Files:**
- Create: `/home/jmsbpp/cfmms-playground/cfmm-wt/gams/model/test/PayoffModuleTest.gms` (extracted from spec §8)

**Interfaces:**
- Consumes: `model/PayoffModule.gms` from Task 2 (which `$include`s the per-theorem file).
- Produces: a `test-gams`-discoverable file that drives all per-program asserts under `action=ce`.

- [ ] **Step 1: Extract §8 from spec MD into the test rollup file**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && \
    python3 -c "
  import re
  text = open('docs/superpowers/specs/2026-06-28-payoff-zero-slippage-design.md').read()
  secs = re.split(r'^(## \d+\.[^\n]*)\n', text, flags=re.M)
  for i in range(1, len(secs), 2):
      if secs[i].startswith('## 8.'):
          m = re.search(r'\`\`\`gams\n(.*?)\n\`\`\`', secs[i+1], re.S)
          open('model/test/PayoffModuleTest.gms', 'w').write(m.group(1) + '\n')
          print(f'wrote test rollup ({len(m.group(1).splitlines())} lines)')
  "
  ```

  Expected output: `wrote test rollup (~5 lines)`.

- [ ] **Step 2: Run `make test-gams` — verify 3 passed**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && make test-gams 2>&1 | tail -6
  ```

  Expected: `test-gams: 3 passed, 0 failed`. (Prior 2 + the new `PayoffModuleTest.gms`.) The new test invokes the NLP solver (CONOPT); this is the first `test-gams` run that requires a working solver.

  If FAIL: the test driver `$include`s `PayoffModule.gms` which `$include`s the per-theorem file. Common failure mode: an `abort` fires inside one of the 11 cross-checks. Inspect `model/build/test_PayoffModuleTest.lst` for the failing abort message.

- [ ] **Step 3: Confirm `make compile-gams` still 10 ok (no regression)**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && make compile-gams 2>&1 | tail -3
  ```

  Expected: `compile-gams: 10 ok, 0 failed, 0 skipped`. The new test file lives under `model/test/` which `compile-gams` excludes — count is unchanged.

- [ ] **Step 4: Commit**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && \
    git add model/test/PayoffModuleTest.gms && \
    git commit -m "$(cat <<'EOF'
  test(gams): PayoffModule rolled-up assertion test driver

  Thin rollup that $includes PayoffModule.gms (which $includes the per-theorem
  files). action=ce (from make test-gams) drives all 11 asserts in the
  zero-slippage program. This is the first test-gams run that invokes a real
  NLP Solve (CONOPT); the existing tests were assertion-only.

  test-gams: 3 passed / 0 failed (prior 2 + this new file).

  Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
  EOF
  )"
  ```

---

## Task 4: Generate + commit GDX fixture; verify §10 success criteria

**Files:**
- Create (generated, committed): `/home/jmsbpp/cfmms-playground/cfmm-wt/gams/model/payoff_zero_slippage.gdx`

**Interfaces:**
- Consumes: `make payoff-fixtures` from Task 1; per-theorem file from Task 2.
- Produces (for the gamsdiff peer + future EVM controller):
  - `model/payoff_zero_slippage.gdx` — 16 explicit symbols (`inputs`, `optimum`, `gamsVersion`, `modelVersion`, `lambdaWad`, `etaQ128`, `diffTolerance`, `zeroTolerance`, `tieBreaking`, `theoremStatus`, `theoremNameSet`, `leanFileSet`, `leanLineSet`, `aristotleProjectSet`, `diArgminContinuousExport`, `diSolverContinuousExport`) plus auto-promoted domain sets (`inputD`, `targetD`, `sourceD`, `diGrid`, `leftArmBreaks`, `rightArmBreaks`).
  - Canonical control target: `optimum('enumeration', 'diStarInt') = 35`.

- [ ] **Step 1: Run `make payoff-fixtures` to generate the GDX**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && make payoff-fixtures
  ```

  Expected: `>> regenerating fixture from payoff/eta_pi_trader_zero_slippage.gms` and `   OK payoff/eta_pi_trader_zero_slippage.gms`. The GDX lands at `model/payoff_zero_slippage.gdx` (relative `execute_unload` from `cd model && gams payoff/...`).

- [ ] **Step 2: Confirm the GDX file exists and has reasonable size**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && \
    ls -la model/payoff_zero_slippage.gdx
  ```

  Expected: a binary file ≤ 8 KB. (Spec §10 success criterion.)

- [ ] **Step 3: Verify the GDX schema via `gdxdump Symbols`**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && \
    gdxdump model/payoff_zero_slippage.gdx Symbols 2>&1 | head -25
  ```

  Expected: lists `inputs`, `optimum`, `gamsVersion`, `modelVersion`, `lambdaWad`, `etaQ128`, `diffTolerance`, `zeroTolerance`, `tieBreaking`, `theoremStatus`, `theoremNameSet`, `leanFileSet`, `leanLineSet`, `aristotleProjectSet`, `diArgminContinuousExport`, `diSolverContinuousExport` (16 explicit) plus auto-promoted domain sets (`inputD`, `targetD`, `sourceD`, `diGrid`, `leftArmBreaks`, `rightArmBreaks`).

- [ ] **Step 4: Verify the canonical control target = 35**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && \
    gdxdump model/payoff_zero_slippage.gdx Symb=optimum 2>&1 | grep "enumeration.*diStarInt"
  ```

  Expected: a line showing `'enumeration'.'diStarInt' 35` (the EVM control target). Per §10: `round(2·log(10/9)/(log(1.0001)·60)) = round(35.117) = 35`.

- [ ] **Step 5: Verify the `lean` row exports 18 and `lean` provenance scalars are correct**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && \
    gdxdump model/payoff_zero_slippage.gdx Symb=optimum  2>&1 | grep "lean.*diStarInt" ; \
    gdxdump model/payoff_zero_slippage.gdx Symb=theoremStatus 2>&1 | tail -3 ; \
    gdxdump model/payoff_zero_slippage.gdx Symb=etaQ128       2>&1 | tail -3
  ```

  Expected:
  - `'lean'.'diStarInt' 18` (= `round(17.559)`, Lean-coord audit value).
  - `theoremStatus = 1` (proven).
  - `etaQ128 = 1.70141183460469e+38` (= `2^127`, η=½ in Q0.128).

- [ ] **Step 6: Verify `.gitignore` admits the new GDX (no `git add -f` needed)**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && \
    git check-ignore -v model/payoff_zero_slippage.gdx ; echo "exit=$?"
  ```

  Expected: `exit=1` (no output before — the file is NOT ignored thanks to Task 1's re-include).

- [ ] **Step 7: Stage and commit the GDX (plain `git add`, no `-f`)**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && \
    git add model/payoff_zero_slippage.gdx && \
    git commit -m "$(cat <<'EOF'
  feat(gams): committed payoff zero-slippage control-target GDX fixture

  Generated by make payoff-fixtures from model/payoff/eta_pi_trader_zero_slippage.gms.
  16 explicit symbols including the canonical control target:
    optimum('enumeration','diStarInt') = 35
  (= round(2·log(10/9)/(log(1.0001)·60)) = round(35.117), the discrete
  Plank-coordinate argmin in {1..200} that the future EVM controller reads).

  Plus 'lean' column for audit (diStarInt = 18, the Lean-coord rounded value),
  full Lean-theorem provenance (theoremName, leanFile, leanLine, aristotleProject),
  tolerances exported (diffTolerance=1e-12, zeroTolerance=1e-20), and the
  parabolic-interp + NLP continuous-argmin scalars for audit (diArgminContinuous
  ≈ 35.118, matches diStarPlankReal=35.117 to ~1e-4).

  Added via plain `git add` (not -f) — the rev-4 .gitignore re-include for
  this file is the right pattern.

  Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
  EOF
  )"
  ```

- [ ] **Step 8: Final §10 success-criteria check — all three Make targets clean**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && \
    echo '=== compile-gams ===' && make compile-gams 2>&1 | tail -3 && \
    echo '=== test-gams ===' && make test-gams 2>&1 | tail -3 && \
    echo '=== spec-preflight ===' && make spec-preflight && \
    echo '=== gdxdump summary ===' && gdxdump model/payoff_zero_slippage.gdx Symbols 2>&1 | grep -c '^Set\|^Parameter\|^Scalar'
  ```

  Expected, in order:
  - `compile-gams: 10 ok, 0 failed, 0 skipped`.
  - `test-gams: 3 passed, 0 failed`.
  - `spec-preflight OK (canonical config: diStarInt=35)`.
  - gdxdump summary line count ≥ 16 (16 explicit + auto-promoted).

  If any line is off, do not push — diagnose against §10 success criteria before continuing to Task 5.

---

## Task 5: Push to `origin`; open PR against `develop`

**Files:** none modified (this is a remote-push + PR-creation task).

**Interfaces:**
- Consumes: clean local state from Task 4.
- Produces: `origin/feat/gams-payoff` with 4 commits ahead of `develop`; an open PR linking the work for review.

- [ ] **Step 1: Confirm clean working tree + 4 commits ahead of develop**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && \
    git status --short && \
    git --no-pager log --oneline origin/develop..HEAD
  ```

  Expected:
  - `git status --short` empty (no uncommitted changes).
  - 4 commits from this plan + 1 prior commit (`d9f4164` = the rev-4 spec) = **5 commits** total ahead of `develop`. (If the prior commit count differs, that's OK — just verify the 4 task commits are present in addition to `d9f4164`.)

- [ ] **Step 2: Push to `origin` with `-u` (set upstream)**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && git push -u origin feat/gams-payoff 2>&1 | tail -4
  ```

  Expected: `branch 'feat/gams-payoff' set up to track 'origin/feat/gams-payoff'`, plus GitHub's PR-creation suggestion URL.

- [ ] **Step 3: Open the PR with `gh`, base = `develop`, target = `JMSBPP/cfmm-replicationPlank`**

  ```bash
  cd /home/jmsbpp/cfmms-playground/cfmm-wt/gams && \
    cat > /tmp/payoff_pr_body.md <<'EOF'
  ## Summary

  Cycle 1 of the PayoffModule series — adds the scaffolding and the first
  per-theorem program (zero-slippage Δᵢ⋆) corroborating Lean's
  `pi_trader_half_zero_at_deltaI_star` theorem AND the Plank `cesLongPayoff`
  evaluator zero via the bridge `Δᵢ⋆_Plank = 2·Δᵢ⋆_Lean`.

  - **Scaffolding (`model/payoff/_PayoffScaffolding.gms`)**: dual-coord macros
    (`piTrader_Half_Lean` / `piTrader_Half_Plank`), Q-scale constants, provenance.
  - **First program (`model/payoff/eta_pi_trader_zero_slippage.gms`)**: 11 asserts
    (bridge, A_Lean, A_Plank, B_Plank, 2×B_indep, B_ext, C_Plank, D_Plank, 2×E, F, G).
  - **Test rollup (`model/test/PayoffModuleTest.gms`)**: drives the asserts via
    `make test-gams` (now requires CONOPT, since C_Plank invokes a real Solve).
  - **Committed GDX (`model/payoff_zero_slippage.gdx`)**: 16 symbols, EVM control
    target `optimum('enumeration','diStarInt') = 35`.
  - **Makefile**: new `payoff-fixtures` + `spec-preflight` targets. `spec-preflight`
    extracts spec MD via Python regex, runs gams, greps `.lst` for compile errors
    (`gams` exits 0 on parse failures — RC's rev-3 finding).
  - **.gitignore**: re-include for `model/payoff_zero_slippage.gdx`.

  ## Spec + rev history

  Spec: `docs/superpowers/specs/2026-06-28-payoff-zero-slippage-design.md` (rev 4).
  Three two-step reviews caught:
   - Rev 1: `2^96`/sqrt coordinate mismatch (Lean P_half un-sqrted vs Plank sqrtPX96).
   - Rev 2: B_Plank wrong-by-sqrt; NLP tolerance unsatisfiable.
   - Rev 3: inline `*` comments illegal; pre-flight was on stripped copy.
   - Rev 4: actually pre-flighted on the spec MD via `make spec-preflight`.

  ## Verification

  - `make compile-gams` → 10 ok / 0 failed
  - `make test-gams` → 3 passed / 0 failed
  - `make spec-preflight` → OK (canonical config: diStarInt=35)
  - `make payoff-fixtures` → produces the GDX cleanly
  - All 11 asserts pass at canonical config (`i=60, L̄=1 Q128.128, Δ^I=0.1 Q128.128`)

  ## Out of scope (for future cycles)

  - EVM controller that consumes this GDX
  - gamsdiff peer's pipeline extension for the payoff GDX
  - Per-theorem files for band_min / band_max / variance_target / kernel_split
  - Multi-config sweeps (Q3-locked single-config for cycle 1)
  - Lean-side rebroadcast of `P_half := λ^(i·Δᵢ/2)`

  🤖 Generated with [Claude Code](https://claude.com/claude-code)
  EOF
    gh pr create --repo JMSBPP/cfmm-replicationPlank --base develop --head feat/gams-payoff \
      --title "feat(gams): PayoffModule cycle 1 — zero-slippage Δᵢ⋆ scaffolding + first program" \
      --body-file /tmp/payoff_pr_body.md
  ```

  Expected: a PR URL printed (e.g., `https://github.com/JMSBPP/cfmm-replicationPlank/pull/N`). Save this URL — it's the deliverable.

- [ ] **Step 4: No commit. Done.**

  (Push + PR are remote actions; no local commit needed.)

---

## Self-Review (checked by plan author at write time)

**Spec coverage:**
- §3 Decisions (D1–D14): the scaffolding macros (D4d, D4e, D4i) land in Task 2; the tolerances (D7) land via scaffolding scalars in Task 2; the `_Half_Lean/_Half_Plank` naming (D12) is in the spec text Task 2 extracts; the `$eolcom #` discipline (D13) is in the extracted §6; `spec-preflight` (D14) lands in Task 1.
- §4 file layout: every file in the layout is created by Task 1 (Makefile/.gitignore), Task 2 (3 source files), Task 3 (test rollup), or Task 4 (generated GDX).
- §5 scaffolding: extracted verbatim in Task 2 Step 1.
- §6 first program: extracted verbatim in Task 2 Step 1.
- §7 orchestrator: edited in Task 2 Step 2.
- §8 test rollup: extracted in Task 3 Step 1.
- §9 GDX schema: verified in Task 4 Steps 3-5.
- §10 success criteria: verified end-to-end in Task 4 Step 8.
- §11 out of scope: respected (no task touches Plank, Lean, gamsdiff, etc.).
- §12 workflow (branch, Makefile targets): Task 1 lands the targets; the spec-preflight discipline is exercised in Tasks 2/3/4.
- §13 references: documentation-only; no implementation needed.

**Placeholder scan:** No `TBD`, `TODO`, `implement later`, or "similar to Task N" patterns. Every step has its exact code or command.

**Type/name consistency:** All Make targets, file paths, GDX symbol names, and scale constants match the spec verbatim (extracted, not hand-typed). The spec is the source of truth.

**Hidden assumption check:** Task 4 Step 1's `make payoff-fixtures` relies on `cd $(GAMS_DIR)` (set in the existing Makefile) — confirmed in Task 1 Step 2 the recipe uses `cd $(GAMS_DIR)`. Task 5 Step 3's `gh pr create --repo JMSBPP/cfmm-replicationPlank` mirrors the prior PR (#1) creation pattern; the gh CLI defaults to `wvs-finance` (the upstream parent), so `--repo` is required.
