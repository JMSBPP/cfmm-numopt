# Architecture Research — GAMS Test Architecture

**Domain:** Executable-assertion test suite for a dual-representation (Lean-coordinate ↔ EVM fixed-point) GAMS algebraic model
**Researched:** 2026-07-27
**Confidence:** HIGH for everything marked `[V]` — verified by direct execution against the locally installed GAMS **54.1.0 37378ce0 LEG x86 64bit/Linux**, cross-checked against gams.com documentation. Gaps and unverifiable items are listed in [§12](#12-what-i-could-not-verify).

> **Read this as a specification, not a survey.** Every construct below was run.
> Where the existing repo convention is already correct, it is marked
> **CODIFY** (write it down, change nothing). Where it must change, **CHANGE**.

---

## 0. Executive verdict

The repo's *core* architecture — one execution unit per theorem, `abort$` assertions,
`action=ce`, GDX provenance, a registry file that deliberately does not aggregate — is
**correct, and matches how GAMS Development themselves structure their ~1000-model
`testlib` quality suite**. It should be codified essentially as-is.

There is exactly one **BLOCKER**: the `.lst` post-grep used by `payoff-fixtures`,
`spec-preflight` and `spec-preflight-band` is a **false-pass gate**. The string
`Status: Compilation error(s)` is written to the GAMS **log**, never to the `o=`
**listing**, so `grep -qE 'Status: ...' "$out"` can never match. Those three targets
report OK on every compile error and every execution error. See [§3](#3-exit-code-trustworthiness-the-central-question).

The premise behind that workaround — "`gams` can exit 0 even on a compile error" — is
**false for compile and execution errors** (they return 2 and 3 respectively) but
**true for four other situations** that the architecture must handle explicitly.

---

## 1. Standard Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────────────┐
│ ORCHESTRATION LAYER — Makefile / CI                                      │
│  exit-code gate · unit discovery · tier selection · result aggregation   │
├──────────────────────────────────────────────────────────────────────────┤
│ ┌────────────────┐ ┌────────────────┐ ┌────────────────┐ ┌─────────────┐ │
│ │ compile-gams   │ │ test-gams-pure │ │ test-gams-nlp  │ │ fixtures    │ │
│ │ action=c       │ │ action=ce      │ │ action=ce      │ │ action=ce   │ │
│ │ no solver      │ │ no solver      │ │ CONOPT req.    │ │ + gdxdiff   │ │
│ └───────┬────────┘ └───────┬────────┘ └───────┬────────┘ └──────┬──────┘ │
├─────────┴──────────────────┴──────────────────┴─────────────────┴────────┤
│ DRIVER LAYER — model/test/<Module><Theorem>Test.gms                      │
│  ONE $include of ONE theorem unit. Owns nothing but the include + banner. │
│  This is the unit of PROCESS ISOLATION — the namespace boundary.          │
├──────────────────────────────────────────────────────────────────────────┤
│ THEOREM-UNIT LAYER — model/<module>/<theorem_snake_name>.gms              │
│  fixture constants · closed forms · assertions · Model/Solve · GDX export │
│  Owns names freely (iCfg, LbarQ128, payoffEq, piVal, di) — never shared.  │
├──────────────────────────────────────────────────────────────────────────┤
│ SCAFFOLDING LAYER (include-guarded, idempotent, NO fixture values)        │
│ ┌──────────────────────────┐ ┌────────────────────────────────────────┐  │
│ │ _<Module>Scaffolding.gms │ │ _AssertLib.gms          [NEW]          │  │
│ │  dual-coordinate $macros │ │  assertApproxEqRel/Abs/Close           │  │
│ │  scale constants Q96/128 │ │  checkApproxEq* (soft) + assertNoFail  │  │
│ │  bridges, tolerances     │ │  assertModelOptimal, assertSolverAvail │  │
│ └──────────────────────────┘ └────────────────────────────────────────┘  │
├──────────────────────────────────────────────────────────────────────────┤
│ KERNEL LAYER — PricingKernel.gms, primitives.gms, TradingRegion.gms       │
│  pure definitions, compile-checkable without a solver                     │
├──────────────────────────────────────────────────────────────────────────┤
│ ARTIFACT LAYER — model/fixtures/*.gdx (golden, committed)                 │
│  full IEEE-double precision · provenance sets · consumed by gamsdiff peer │
└──────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Owns | MUST NOT contain |
|-----------|------|------------------|
| **Kernel** (`PricingKernel.gms`, `primitives.gms`) | Sets, scale constants, `$macro` evaluators shared by every module | Any `abort`, any fixture value, any `Model`/`Solve` |
| **`_AssertLib.gms`** (NEW) | Assertion macros + the scratch scalars they write into. Include-guarded. | Tolerance *values* (those are policy, see §5), any domain symbol |
| **`_<Module>Scaffolding.gms`** | Dual-coordinate macros, coordinate bridges, scale constants, tolerance scalars. Include-guarded. `$include`s `_AssertLib.gms`. | Fixture values (`iCfg`, `LbarQ128`), `Variable`/`Equation`/`Model` |
| **Theorem unit** `<module>/<name>.gms` | Everything specific to one theorem: fixture scalars, closed forms, all assertions, `Model`/`Solve`, provenance sets, `execute_unload` | `$include` of another theorem unit |
| **Driver** `test/<Name>Test.gms` | Exactly one `$include` of one theorem unit + one PASS banner | Assertions, fixtures, anything reusable |
| **Registry** `<Module>Module.gms` | A comment-table mapping unit → driver → tier → solver requirement, plus a `display`. Compile-checkable, executes trivially. | Any `$include` of a theorem unit |
| **Makefile** | Unit discovery, `action=` selection, **exit-code gating**, tier partitioning, result aggregation, `gdxdiff` invocation | Any assertion logic (assertions live in GAMS, not shell) |

**CODIFY:** the Driver / Theorem-unit / Registry split already exists and is right.
**CHANGE:** add `_AssertLib.gms`; split `test-gams` into tiers; fix the Makefile gate.

---

## 2. Assertion vocabulary (GAMS 54.1) `[V]`

All eight rows below were executed. `rc` is the process exit status of `gams`.

| Construct | Phase | Halts? | `rc` | Notes |
|-----------|-------|--------|------|-------|
| `abort$(cond) "msg", sym;` | execution | yes | **3** | The workhorse. Requires `action=ce`. |
| `abort "msg", sym;` | execution | yes | **3** | Unconditional. |
| `abort.noError$(cond) "msg", sym;` | execution | yes | **0** ⚠ | Halts **silently**. `*** Status:` is *not* emitted. **BANNED in this repo.** |
| `execError = N;` | execution | **no** | **3** (at end) | Marks failure, execution **continues**. Basis of soft assertions (§6). |
| `execError = execError + 1;` | execution | no | **3** | Accumulating form. |
| `$abort "msg"` | compilation | yes | **2** | Compile-time guard (e.g. missing `$include`). |
| `$abort.noError "msg"` | compilation | yes | 0 ⚠ | Same hazard as `abort.noError`. Banned. |
| `$if <cond> $exit` | compilation | ends **current file only** | 0 | Basis of the include guard. Confirmed: does not truncate the includer. |

### 2.1 `action=c` versus `action=ce`

`[V]` `action` is **`ce` by default**; the repo's explicit `action=ce` is harmless and
good documentation. What matters:

| | `action=c` | `action=ce` |
|---|---|---|
| `abort$` fires | **no** (rc 0) | **yes** (rc 3) |
| `execError` fires | no | yes |
| `$abort` fires | **yes** (rc 2) | yes (rc 2) |
| Syntax / unknown symbol | yes (rc 2) | yes (rc 2) |
| Unknown solver in `option nlp=` | **yes** (rc 2) | yes (rc 2) |
| Solver license consumed | no | yes |

`[V]` Proof: `t_abort.gms` with `action=c` → rc 0 (assertion never ran); with
`action=ce` → rc 3. **`compile-gams` therefore proves nothing about assertions** — it
is a syntax gate only. That is fine and should be stated explicitly in the doc.

### 2.2 The hard constraint on `abort` message payloads `[V]`

```gams
abort$(1) "msg", abs(x-y);        * ERROR $200,$409 — rc=2
abort$(1) "msg", someScalar;      * OK
```

**`abort` accepts identifiers only, never expressions.** This single fact dictates the
entire macro design in §6: an assertion macro *must* materialise its operands into
named scalars before it can report them.

`[V]` Second gotcha: `abort$(c) "text" nm, x;` (no comma before `nm`) compiles and runs
but emits `**** LIST OF STRAY NAMES - CHECK DECLARATIONS FOR SPURIOUS COMMAS`.
Always comma-separate: `abort$(c) "text", nm, x;`.

### 2.3 `putclose` diagnostics `[V]`

`display` is capped: `option decimals` must be in `0..8` (error `$258` at 15). For a
1e-12 tolerance regime the *error* value displays fine in E-notation
(`1.000000E-9`), but the *operands* are truncated. Full precision requires `put`:

```gams
File dbg / 'build/assert.log' /;  dbg.pw = 200;  dbg.ap = 1;
put dbg;
put 'ASSERT ', asrtName, ' lhs=', asrtLhs:30:20, ' rhs=', asrtRhs:30:20,
    ' err=', asrtErr:30:20 /;
putclose dbg;
```

`[V]` `v:30:20` on `1/3` yields `0.33333333333333330000` — full double precision.

**Recommendation:** do **not** build the primary diagnostic on `put`. Put the full-precision
record in **GDX** (`execute_unload`), which stores raw IEEE doubles, and use `display`
for the human-readable abort message. This aligns with the existing provenance convention.

---

## 3. Exit-code trustworthiness (the central question)

### 3.1 The complete return-code table

Official (gams.com `UG_GAMSReturnCodes`), the relevant rows `[V]` all reproduced locally:

| rc | Meaning | Reproduced |
|----|---------|-----------|
| 0 | Normal return | ✔ |
| 1 | Solver is to be called — should never be returned | — |
| **2** | **Compilation error** | ✔ unknown symbol; `$abort`; unknown solver name |
| **3** | **Execution error** | ✔ `abort$`; `execError=N`; `1/0`; GDX symbol not found |
| 4 | System limits reached | — |
| 5 | File error | — |
| 6 | Parameter error | — |
| 7 | Licensing error | — |
| 8 | GAMS system error | — |
| 9 | GAMS could not be started | — |
| 10 / 11 | Out of memory / disk | — |

### 3.2 When the exit code IS trustworthy `[V]`

For the four cases the question asks about:

| Failure mode | Detected by exit code? | rc |
|--------------|------------------------|----|
| **(a) Compilation error** | **YES** | 2 |
| **(b) Execution error** (`1/0`, GDX symbol missing, `execError`) | **YES** | 3 |
| **(c) Failed `abort$`** | **YES** | 3 |
| **(d) Solver returned non-optimal `modelStat`** | **NO — rc 0** ⚠ | 0 |

`[V]` (d) proof: an LP with `x >= 5` and `x <= 1` solved to `modelStat = 19`
(infeasible-no-solution), `solveStat = 1`, and **`gams` returned 0**. A non-optimal or
infeasible solve is *not* an error to GAMS. It must be asserted in the model:

```gams
abort$(m.modelStat <> %modelStat.optimal% and m.modelStat <> %modelStat.locallyOptimal%)
    "FAIL: <unit> NLP did not reach an optimum", m.modelStat, m.solveStat;
```

**CODIFY:** `eta_pi_trader_zero_slippage.gms` already does exactly this. It is the only
correct approach and must be mandatory for every `Solve`.

### 3.3 The four genuine exit-0-on-failure hazards `[V]`

| # | Hazard | rc | Fix |
|---|--------|----|----|
| 1 | `abort.noError$(...)` halts silently | 0 | **Ban it.** Add a `grep -rn 'abort\.noError\|\$abort\.noError' model/` lint to CI. |
| 2 | Non-optimal / infeasible `Solve` | 0 | Mandatory `modelStat` assertion (§3.2). |
| 3 | `execute 'cmd'` where `cmd` fails | 0 | Use `execute.checkErrorLevel 'cmd';` → rc **3**. |
| 4 | `$call 'cmd'` where `cmd` fails | 0 | Use `$call.checkErrorLevel 'cmd'` or `$onCheckErrorLevel` → rc **2**. |

`[V]` **Critical correction to a common misreading:** `$onCheckErrorLevel` governs
**`$call` only (compile time)**, *not* `execute` (execution time). Documentation wording:
*"Throw compilation error, if errorLevel is not 0 after `$[hidden]call`"*. Measured:

```
$onCheckErrorLevel + execute 'false'   → rc 0, execution continued   ⚠
execute.checkErrorLevel 'false'        → rc 3                        ✔
$call 'false'                          → rc 0                        ⚠
$onCheckErrorLevel + $call 'false'     → rc 2 (error $343)           ✔
$call.checkErrorLevel 'false'          → rc 2                        ✔
```

`errorLevel` is readable but is **not** a displayable identifier
(`display errorLevel` → `$200 Function not allowed here`); assign first:
`Scalar rc; rc = errorLevel;` `[V]` (measured 7 after `execute 'exit 7'`).

### 3.4 BLOCKER — the current `.lst` post-grep never matches `[V]`

The Makefile does, in three targets:

```make
$(GAMS) "$$f" action=ce o="$$out" scrdir="$(GAMS_BUILD)" lo=0 >/dev/null 2>&1 ;
if grep -qE 'Status: (Compilation|Execution) error' "$$out"; then ... fi
```

Measured facts:

1. `*** Status: Compilation error(s)` / `*** Status: Execution error(s)` are written to
   the **log stream**, never to the `o=` listing. Confirmed for **every** `lo` value
   0/1/2/3/4: `grep -c 'Status:' <lst>` = **0** in all five runs. With `lo=2` or `lo=4`
   plus `lf=<file>` the string appears in the **log file** only.
2. `lo=0` *suppresses the log entirely*, and the recipe additionally sends stdout to
   `/dev/null`. So the string is destroyed twice over.
3. The `;` before `if` discards the `gams` exit status.

**Net effect, reproduced end-to-end:** a theorem unit with a compile error returns
`rc=2`, the recipe prints `OK`, **and the previously committed `.gdx` is left untouched
and unchanged on disk** — so a stale fixture silently survives while the build stays
green. Verified with a two-run experiment (`v=111` written, then a broken `v=222`
source): recipe said OK, `gdxdump` still reported `111`, mtime unchanged.

**CHANGE — required fix.** Trust the exit code; keep the grep only as a *belt-and-braces
check on the log*:

```make
payoff-fixtures:
	@mkdir -p $(GAMS_DIR)/$(GAMS_BUILD)
	@cd $(GAMS_DIR) && rc=0; \
	for f in $$(find payoff -name 'eta_*.gms' | sort); do \
	  base=$$(echo "$$f" | tr / _ | sed 's/\.gms$$//'); \
	  out="$(GAMS_BUILD)/$$base.lst"; log="$(GAMS_BUILD)/$$base.log"; \
	  if $(GAMS) "$$f" action=ce o="$$out" lf="$$log" lo=2 scrdir="$(GAMS_BUILD)"; then \
	    printf '   OK   %s\n' "$$f"; \
	  else \
	    printf '   FAIL %s (gams rc=%s) -> %s/%s\n' "$$f" "$$?" "$(GAMS_DIR)" "$$log"; \
	    grep -E '^\*\*\*' "$$log" | head -20; rc=1; \
	  fi; \
	done; exit $$rc
```

Key changes: **no `;` before the gate** (use `if gams ...; then`), `lo=2 lf=<file>` so
the log is captured for diagnostics, and the grep moved to the *log* and demoted to
error-message extraction. `[V]` The `if cmd; then ... else` form does propagate `$?`
correctly — measured 2 and 3 in the else branch, so `compile-gams` and `test-gams`
are already sound and need only the tiering change.

**Recommended additional invariant** for fixtures, since a failed run leaves the old
GDX in place: regenerate into a temp path and `gdxdiff` against the committed golden,
so "unchanged" is an explicit assertion rather than an accident (§8).

---

## 4. Recommended project structure

```
model/
├── primitives.gms                   # scale/bound constants (kernel layer)
├── PricingKernel.gms                # shared $macro evaluators
├── TradingRegion.gms
│
├── test/
│   ├── _AssertLib.gms               # [NEW] assertion macros — include-guarded
│   ├── PricingKernelTest.gms        # property test, no solver     (tier: pure)
│   ├── PriceImpactKernelTest.gms    # property test, no solver     (tier: pure)
│   ├── PayoffZeroSlippageTest.gms   # 1 theorem, CONOPT            (tier: nlp)
│   └── PayoffBandMonotoneLargeTest.gms
│
├── payoff/                          # ── module dir, one per Lean module ──
│   ├── _PayoffScaffolding.gms       # macros + bridges + tolerances
│   ├── eta_pi_trader_zero_slippage.gms
│   └── eta_pi_trader_band_monotone_large.gms
├── volinstrument/                   # future: PosSpec, Main, Flow, ...
│   ├── _VolInstrumentScaffolding.gms
│   └── <theorem_snake_name>.gms
│
├── PayoffModule.gms                 # registry (no $include of units)
├── VolInstrumentModule.gms
│
├── fixtures/                        # committed golden GDX
│   ├── payoff_zero_slippage.gdx
│   └── ...
└── build/                           # transient: .lst, .log, .gdx, scratch
```

### 4.1 Structure rationale against the single-global-namespace constraint

The namespace constraint is **stronger than the repo currently documents**, and I have
proof. `PayoffModule.gms` says aggregation raises `$194` and `$171`. Measured, with two
theorem files that each declare `iCfg`, `Lbar`, `piVal`, `payoffEq`, `M`:

| Aggregation attempt | rc | Errors |
|---|---|---|
| plain `$include` both | 2 | 4 errors: `$194` ×2 (symbol redefined), `$150` (symbolic equations redefined) |
| **`$onMulti`** then `$include` both | **2** | **`$150` still fires** |

`[V]` **`$onMulti` cannot rescue this.** It relaxes re-declaration of Sets and
Parameters, but `Equation`/`Model` redefinition is unconditionally an error. Since every
theorem unit that carries a `Solve` declares an `Equation`, **aggregation of solver-bearing
theorem units is structurally impossible in GAMS, not merely inconvenient.**

Therefore the process boundary *is* the namespace boundary, and the unit of test
isolation must be the OS process. This is exactly what GAMS Development do: their
`testlib` ships ~1000 tests as ~1000 independent single-file GAMS programs, indexed by a
registry (`testmod.inc`) and driven by an orchestrator (`quality.gms`). **The repo has
independently converged on the vendor's own architecture.** Codify it with confidence.

### 4.2 Naming convention (mechanical, so the Makefile needs no table)

| Artifact | Rule | Example |
|---|---|---|
| Theorem unit | `<module>/<lean_theorem_name>.gms`, snake_case, verbatim from Lean, prefixed by Lean file stem | `payoff/eta_pi_trader_zero_slippage.gms` |
| Driver | `test/<Module><UpperCamelTheorem>Test.gms` | `test/PayoffZeroSlippageTest.gms` |
| Scaffolding | `<module>/_<Module>Scaffolding.gms` — leading `_` = "not a unit" | `payoff/_PayoffScaffolding.gms` |
| Golden fixture | `fixtures/<module>_<theorem>.gdx` | `fixtures/payoff_zero_slippage.gdx` |
| Guard symbol | `<MODULE>_SCAFFOLDING_INCLUDED` | `PAYOFF_SCAFFOLDING_INCLUDED` |

**CODIFY:** the leading-underscore convention and the `_PayoffScaffolding` guard already
follow this. Only the module-directory generalisation is new.

### 4.3 One driver per theorem, not per module — settled

| Option | Verdict |
|---|---|
| One driver per **module** | **Rejected.** Requires aggregating theorem units → `$150`, unfixable (§4.1). |
| One driver per **theorem** | **Adopted.** Forced by the namespace constraint; matches GAMS `testlib`; gives per-theorem attribution in CI; lets a single theorem be re-run in isolation. |

Cost: 134 GAMS process starts. `[V]` Measured cold-start overhead for a trivial program
is ~2 ms compile + process spawn; the dominant cost will be the CONOPT solves, not the
process count. Mitigate with parallelism (§7.3), not with aggregation.

---

## 5. Tolerance policy

### 5.1 The correct assertion form when a value may be zero

A pure relative check `|a−b|/|b|` is undefined at `b = 0`. `[V]` In GAMS an unguarded
`1/0` raises an **execution error → rc 3**, so it fails loudly rather than silently —
but it fails with a division-by-zero message, not with your assertion message. That is
a bad diagnostic, not a safety property.

Three semantics, three macros. **Do not fudge the denominator.**

| Situation | Macro | Formula |
|---|---|---|
| Reference is known non-zero | `assertApproxEqRel` | `|a−b| / |b| <= relTol`, with an explicit `b = 0` guard that aborts with a *distinct* message |
| Reference is exactly zero by construction (payoff at optimum) | `assertApproxEqAbs` | `|a−b| <= absTol` |
| Value may pass through zero (grid sweeps, residual sequences) | `assertClose` | `|a−b| <= absTol + relTol·|b|` (the NumPy `isclose` / Foundry-style combined form) |

`[V]` I initially drafted the common "safe denominator" trick
`max(|b|, zeroTolerance)` and **it is wrong**: with `zeroTolerance = 1e-20` it silently
converts the relative check into `|a−b| <= relTol · 1e-20 = 1e-32`, an absurdly strict
absolute check. Measured: `assertApproxEqRel(1e-30, 0, 1e-12)` *failed* under that
formulation. Use the guard-and-abort form instead.

### 5.2 `zeroTolerance = 1e-20` is only satisfiable because the payoff is squared `[V]`

Measured on the repo's own `eta_pi_trader_zero_slippage` fixture (λ=1.0001 WAD, i=60,
L̄=Q128, Δ^I=Q128/10), at the analytic optimum:

| Quantity | Value | Clears `zeroTolerance = 1e-20`? |
|---|---|---|
| `piTrader_Half_Lean(...)` (the **squared** payoff) | `1.73334E-33` | **yes** |
| `sqrt(...)` — the **unsquared** residual | `4.16334E-17` | **no** |

`4.16e-17` is the floating-point floor: catastrophic cancellation between two O(0.1)
terms leaves ≈ `eps · scale`. The global constant `1e-20` therefore encodes a hidden,
undocumented assumption — *that the asserted quantity is a square of an O(1) difference*.
The moment a theorem asserts a non-squared quantity ≈ 0 at O(1) scale, it fails for
purely numerical reasons.

**CHANGE — tolerance policy.** Absolute tolerance must be **derived from scale**, not
hard-coded globally:

```gams
* _AssertLib.gms — machine epsilon and a scale-derived absolute floor.
Scalar machEps      / 2.220446049250313e-16 /;   * IEEE-754 binary64
Scalar epsSlack     / 1e3 /;                     * safety factor over the FP floor
$macro absFloor(scale) ( epsSlack * machEps * abs(scale) )
```

Then a theorem asserts against a *justified* floor rather than a magic number:

```gams
* residual of an O(1) cancellation: floor ~ 1e3 * 2.2e-16 * 1 = 2.2e-13
assertApproxEqAbs("pi residual at di*", piResidual, 0, absFloor(1));
* the squared payoff: floor is the square of the above
assertApproxEqAbs("pi (squared) at di*", piAtStar, 0, sqr(absFloor(1)));
```

Keep `zeroTolerance / 1e-20 /` as a named constant for backward compatibility and
**document in the same file why it works for squared payoffs and nowhere else.**

`relTol = diffTolerance = 1e-12` needs no change: it is ≈ 4500 × `machEps`, comfortably
above the floating-point floor and scale-invariant. **CODIFY.**

---

## 6. Assertion macro library — `model/test/_AssertLib.gms`

`[V]` All of the following was executed as written. Design constraints it satisfies:

- `abort` takes **identifiers only** → operands are materialised into module-level scratch scalars.
- Scratch scalars are declared **once** in the guarded library, never inside the macro
  (a declaring macro raises `$194` on its second invocation).
- `$macro` **does** expand to multiple statements including `;`, and **does** support
  `\` line continuation. `[V]`
- `$macro` argument splitting **respects parenthesis nesting**, so `sum(i, x(i))` passes
  as a single argument. `[V]`
- Every failure message prints the assertion **name**, **both operands**, the **computed
  error**, and the **tolerance**.

```gams
* ============================================================================
* model/test/_AssertLib.gms — assertion vocabulary for the GAMS test suite.
* Include-guarded and idempotent. Contains NO domain symbols and NO fixtures.
* Verified against GAMS 54.1.0.
* ============================================================================
$if set ASSERTLIB_INCLUDED $exit
$setGlobal ASSERTLIB_INCLUDED 1

* --- scratch operands (declared ONCE; macros assign, never declare) ---------
Scalar asrtLhs, asrtRhs, asrtErr, asrtTol, asrtAbsTol;
Scalar asrtRun / 0 /, asrtFail / 0 /;

* --- floating-point floor ---------------------------------------------------
Scalar machEps  / 2.220446049250313e-16 /;   # IEEE-754 binary64
Scalar epsSlack / 1e3 /;
$macro absFloor(scale) ( epsSlack * machEps * abs(scale) )

* ============================ HARD ASSERTIONS ==============================
* Halt on first failure. rc=3. Use for invariants a unit cannot continue past.

$macro assertApproxEqRel(nm, lhs, rhs, relTol)                                \
    asrtRun = asrtRun + 1;                                                    \
    asrtLhs = (lhs); asrtRhs = (rhs); asrtTol = (relTol);                     \
    abort$(asrtRhs = 0)                                                       \
        "FAIL [assertApproxEqRel] zero reference - use assertApproxEqAbs:",   \
        nm, asrtLhs;                                                          \
    asrtErr = abs(asrtLhs - asrtRhs) / abs(asrtRhs);                          \
    abort$(asrtErr > asrtTol)                                                 \
        "FAIL [assertApproxEqRel]", nm, asrtLhs, asrtRhs, asrtErr, asrtTol

$macro assertApproxEqAbs(nm, lhs, rhs, absTol)                                \
    asrtRun = asrtRun + 1;                                                    \
    asrtLhs = (lhs); asrtRhs = (rhs); asrtTol = (absTol);                     \
    asrtErr = abs(asrtLhs - asrtRhs);                                         \
    abort$(asrtErr > asrtTol)                                                 \
        "FAIL [assertApproxEqAbs]", nm, asrtLhs, asrtRhs, asrtErr, asrtTol

* Combined form for values that may pass through zero:
*   |lhs - rhs| <= absTol + relTol * |rhs|
$macro assertClose(nm, lhs, rhs, relTol, absTol)                              \
    asrtRun = asrtRun + 1;                                                    \
    asrtLhs = (lhs); asrtRhs = (rhs);                                         \
    asrtTol = (relTol); asrtAbsTol = (absTol);                                \
    asrtErr = abs(asrtLhs - asrtRhs) - (asrtAbsTol + asrtTol*abs(asrtRhs));   \
    abort$(asrtErr > 0)                                                       \
        "FAIL [assertClose] (excess over allowance)",                         \
        nm, asrtLhs, asrtRhs, asrtErr, asrtTol, asrtAbsTol

$macro assertTrue(nm, cond)                                                   \
    asrtRun = asrtRun + 1;                                                    \
    abort$(not (cond)) "FAIL [assertTrue]", nm

$macro assertInRange(nm, v, lo, hi)                                           \
    asrtRun = asrtRun + 1;                                                    \
    asrtLhs = (v); asrtRhs = (lo); asrtTol = (hi);                            \
    abort$(asrtLhs < asrtRhs or asrtLhs > asrtTol)                            \
        "FAIL [assertInRange]", nm, asrtLhs, asrtRhs, asrtTol

* Mandatory after EVERY Solve — a non-optimal solve does NOT set rc<>0.
$macro assertModelOptimal(nm, mdl)                                            \
    asrtRun = asrtRun + 1;                                                    \
    abort$(mdl.modelStat <> %modelStat.optimal% and                           \
           mdl.modelStat <> %modelStat.locallyOptimal%)                       \
        "FAIL [assertModelOptimal]", nm, mdl.modelStat, mdl.solveStat

* ============================ SOFT ASSERTIONS ==============================
* Record and continue, so ONE run reports ALL failures (forge-style).
* Terminate every unit with assertNoFailures.

$macro checkApproxEqRel(nm, lhs, rhs, relTol)                                 \
    asrtRun = asrtRun + 1;                                                    \
    asrtLhs = (lhs); asrtRhs = (rhs); asrtTol = (relTol);                     \
    asrtErr = abs(asrtLhs - asrtRhs) / max(abs(asrtRhs), machEps);            \
    if(asrtRhs = 0 or asrtErr > asrtTol,                                      \
        asrtFail = asrtFail + 1;                                              \
        display "SOFT-FAIL [checkApproxEqRel]",                               \
                nm, asrtLhs, asrtRhs, asrtErr, asrtTol; )

$macro checkApproxEqAbs(nm, lhs, rhs, absTol)                                 \
    asrtRun = asrtRun + 1;                                                    \
    asrtLhs = (lhs); asrtRhs = (rhs); asrtTol = (absTol);                     \
    asrtErr = abs(asrtLhs - asrtRhs);                                         \
    if(asrtErr > asrtTol,                                                     \
        asrtFail = asrtFail + 1;                                              \
        display "SOFT-FAIL [checkApproxEqAbs]",                               \
                nm, asrtLhs, asrtRhs, asrtErr, asrtTol; )

$macro assertNoFailures                                                       \
    display "assertions run / failed:", asrtRun, asrtFail;                    \
    abort$(asrtFail > 0)                                                      \
        "FAIL: soft assertions failed in this unit", asrtRun, asrtFail
```

### 6.1 Measured behaviour

`[V]` Hard failure output — note both operands, error and tolerance are all printed:

```
----     26 FAIL [assertApproxEqRel]
            genuine 1e-9 rel gap
            PARAMETER asrtLhs              =   1.00000000
            PARAMETER asrtRhs              =   1.00000000
            PARAMETER asrtErr              =  1.000000E-9
            PARAMETER asrtTol              =  1.00000E-12
**** Exec Error at line 26: Execution halted: abort$1 'FAIL [assertApproxEqRel]'
```
→ `rc = 3`.

`[V]` Soft-assertion run with 4 checks, 2 failing: both SOFT-FAIL blocks printed, then
`asrtRun = 4, asrtFail = 2`, then the summary abort → `rc = 3`. **This is the single
biggest usability win available**: `abort` stops at the first failure, so a unit with 12
assertions needs up to 12 edit-run cycles. Soft assertions collapse that to one.

**Policy:** use *hard* assertions for preconditions and bound guards (where continuing
is meaningless — e.g. `diStarLeanReal` outside `[1,200]`), *soft* checks for the body of
independent property assertions, and always terminate with `assertNoFailures;`.

### 6.2 Known macro caveats `[V]`

- A macro argument containing a **top-level** comma (not inside parentheses) will
  mis-split. Wrap such arguments in parentheses.
- Macro names are global and collide like any other symbol; keep them all in `_AssertLib.gms`.
- `display` inside a macro obeys `option decimals` (max 8) — see §2.3.
- `machEps` is used as the soft-relative denominator floor purely to avoid a
  division-by-zero *crash* mid-sweep; the `asrtRhs = 0` term in the `if` makes the check
  fail explicitly rather than fudge.

---

## 7. Test organisation at 134 theorems

### 7.1 Tiering — replace the single `test-gams`

**CHANGE.** `test-gams` currently runs every `test/*.gms` and therefore requires CONOPT
for the whole suite. Partition by *what the unit needs*:

| Target | Selects | Solver | CI role |
|---|---|---|---|
| `compile-gams` | every non-test `.gms`, `action=c` | none | fast syntax gate, runs first |
| `test-gams-pure` | drivers with no `Model`/`Solve` | none | runs everywhere, incl. fork PRs |
| `test-gams-nlp` | drivers with a `Solve` | CONOPT | self-hosted runner only |
| `test-gams` | = `test-gams-pure` + `test-gams-nlp` | CONOPT | developer convenience |
| `payoff-fixtures` | regenerate + `gdxdiff` vs golden | CONOPT | fixture drift gate |

Selection must be **declared, not sniffed**. Follow GAMS's own `testmod.inc` pattern:
put the tier in the registry as a GAMS `Set`, and emit the file list from it, so the
registry is the single source of truth and is itself compile-checked.

```gams
* model/PayoffModule.gms — registry, machine-readable.
Set unit / eta_pi_trader_zero_slippage, eta_pi_trader_band_monotone_large /;
Set tier / pure, nlp /;
Set unitTier(unit, tier) /
    eta_pi_trader_zero_slippage       . nlp
    eta_pi_trader_band_monotone_large . nlp
/;
Set unitSkip(unit) 'units knowingly excluded, with reason' / /;
File lst / 'build/units_nlp.txt' /;
put lst; loop(unitTier(unit,'nlp')$(not unitSkip(unit)), put unit.tl:0 /); putclose lst;
```

`[V]` This mirrors `quality.gms`, which carries `SET ignore(m)`, `SET gskip(m)`,
`SET skip(solver,m)` — **every exclusion carrying a documented reason string**. Adopt
that discipline: a skip without a reason string is a review failure.

### 7.2 Keeping output readable at 100+ units

`[V]` A default listing for a 50-element sweep is ~200 lines; with
`$offListing` + `option limRow = 0, limCol = 0, solPrint = off;` it drops to **24 lines**.

Console contract — one line per unit, nothing else on success:

```
PASS  payoff/eta_pi_trader_zero_slippage            (2 solves,  18 asserts,  0.41s)
PASS  payoff/eta_pi_trader_band_monotone_large      (1 solve,   11 asserts,  0.29s)
FAIL  volinstrument/upsilon_monotone                (rc=3) -> build/volinstrument_upsilon_monotone.log
      **** Exec Error at line 88: Execution halted: abort$1 'FAIL [checkApproxEqRel]'

test-gams-nlp: 132 passed, 1 failed, 1 skipped (conopt unavailable)
```

Drop the current `>> testing <file>` pre-line (it doubles output at 134 units). Emit
failure detail *only* for failures, extracted from the captured log
(`grep -E '^\*\*\*' "$log" | head -20`). Additionally write a machine-readable
`build/results.tsv` (`unit  tier  rc  seconds  asserts`) for CI annotation.

The `asrtRun` / `asrtFail` counters from `_AssertLib.gms` make the assert counts real
rather than estimated — `execute_unload` them into the unit's GDX and read them back.

### 7.3 Parallelism

Convert the shell `for` loop into per-unit make targets with stamp files so
`make -j8 test-gams-nlp` works. `[V]` GAMS allocates a **unique** scratch subdirectory
(`225a`, `225b`, …) under `scrdir=`, so a shared `scrdir` is safe under moderate
parallelism; `clean-gams` already removes `225*`, confirming this. Give each unit its
own `o=` and `lf=` path (the naming rule in §4.2 already guarantees uniqueness).

### 7.4 Shared scaffolding include-guard `[V]`

**CODIFY exactly as-is.** The existing pattern is correct and I verified the semantics
that make it correct:

```gams
$if set PAYOFF_SCAFFOLDING_INCLUDED $exit
$setGlobal PAYOFF_SCAFFOLDING_INCLUDED 1
```

Documentation: *"`$exit` will cause the compiler to exit (stop reading) from the current
file… Unlike `$stop`, `$exit` only terminates the current include file."* Verified with a
driver that includes a guarded file twice and then asserts: statements after the second
include **did** execute and the trailing `abort` **did** fire (rc 3). The guard does not
truncate the includer. ⚠ Note the converse: `$exit` at the **top level** of a driver
*does* end the program — never use a bare `$exit` outside a guarded include.

---

## 8. Golden / reference GDX fixtures

Two mechanisms, both verified; they answer different questions and **both** belong in
the architecture.

### 8.1 In-GAMS shadow-symbol comparison — for *semantic* assertions `[V]`

Use when you want the tolerance policy and the failure message to be yours.
Prefer the **execution-time** `execute_load` over compile-time `$gdxIn`/`$load`, so the
comparison happens in the same deterministic order as the rest of the assertions.

```gams
* Shadow symbols: local name = name-in-file.
Parameter optimumRef(sourceD, targetD);
Scalar    diffToleranceRef;
execute_load 'fixtures/payoff_zero_slippage.gdx',
    optimumRef = optimum,
    diffToleranceRef = diffTolerance;

* Structural check first: the fixture must cover exactly what we computed.
assertTrue("fixture covers all (source,target) cells",
           card(optimumRef) = card(optimum));

* Then the numeric check, cell by cell, soft so all drift is reported at once.
loop((sourceD, targetD),
    checkApproxEqRel("golden optimum cell",
        optimum(sourceD, targetD), optimumRef(sourceD, targetD), diffTolerance);
);
assertNoFailures;
```

`[V]` Verified: a 3.33e-11 relative deviation against a committed golden aborted with
rc 3 and the correct message; an exact match returned rc 0.
`[V]` A missing symbol is caught: `execute_load 'g.gdx', x = doesNotExist;` →
`**** GDX ERROR AT LINE 2 - Unknown GDX symbol doesNotExist`, **rc 3**. So schema drift
in a fixture fails loudly.

Compile-time variant, if you need the data during compilation:

```gams
$gdxIn fixtures/payoff_zero_slippage.gdx
$load optimumRef=optimum diffToleranceRef=diffTolerance
$gdxIn
```

### 8.2 `gdxdiff` — for *whole-file* drift gating in the Makefile `[V]`

Use when the question is "did the fixture change at all?", which is the right question
for the committed-artifact gate consumed by the gamsdiff peer.

```
gdxdiff <file1.gdx> <file2.gdx> [diffFile.gdx] [Eps=<abs>] [RelEps=<rel>] [ID=<sym>...]
```

Measured behaviour:

| Invocation | rc | Report |
|---|---|---|
| identical files | **0** | `No differences found` |
| value differs by 3.3e-11, no tolerance | **1** | `v  Data are different` |
| same, `RelEps=1e-6` | 1 | value diff suppressed; **symbol-set** diff still reported |
| `Eps=1e-6 ID=v` (restricted to one symbol) | **0** | `No differences found` |

`gdxdiff` also reports **structural** differences (`k  Symbol not found in file 2`) that
a hand-written `execute_load` comparison would only catch symbol-by-symbol. Its exit
code is reliable — use it directly, no grep.

### 8.3 Fixture regeneration protocol

**CHANGE.** Make "the fixture is unchanged" an assertion rather than an accident:

```make
FIXTURES := model/fixtures
check-fixtures:
	@cd $(GAMS_DIR) && rc=0; \
	for f in $$(find payoff volinstrument -name '*.gms' -not -name '_*' | sort); do \
	  base=$$(basename $$f .gms); \
	  if ! $(GAMS) "$$f" action=ce o=build/$$base.lst lf=build/$$base.log lo=2 \
	                scrdir=build --FIXTURE_OUT=build/$$base.gdx; then \
	    printf 'FAIL %s (gams rc=%s)\n' "$$f" "$$?"; rc=1; continue; fi; \
	  if ! gdxdiff fixtures/$$base.gdx build/$$base.gdx build/$$base.diff.gdx \
	               RelEps=1e-12 >/dev/null; then \
	    printf 'DRIFT %s -> build/%s.diff.gdx\n' "$$f" "$$base"; rc=1; fi; \
	done; exit $$rc
```

Two rules that make this sound:

1. **`execute_unload` must be the last statement of the unit, after every assertion.**
   `[V]` **CODIFY** — `eta_pi_trader_zero_slippage.gms` already does this, and it is
   load-bearing: a failed assertion then leaves no new GDX.
2. **Never use the `gdx=` command-line parameter for fixtures.** `[V]` `gdx=` dumps all
   symbols *even when the run aborts* (rc 3 and a 408-byte GDX was still written), which
   would let a failed run overwrite a golden file. `gdx=` is excellent for *post-mortem
   debugging* and should be enabled on failure paths only.
3. Parameterise the output path (`--FIXTURE_OUT=`) so regeneration writes to `build/`
   and only an explicit `cp` promotes it to `fixtures/`.

---

## 9. Solver-dependent tests

### 9.1 GAMS exposes solver availability natively `[V]`

This is the mechanism GAMS Development use in `quality.gms`, and it works:

```gams
Set solver 'master set of solvers'          / system.solverNames /;
Set solverPlatformMap(solver, *)            / system.SolverPlatformMap /;
Set avail(solver) 'available on this platform';
avail(solver) = sum(solverPlatformMap(solver, '%system.platform%'), 1);

Scalar hasConopt; hasConopt = sum(avail$sameas(avail, 'conopt'), 1);
```

`[V]` Measured here: `card(solver) = 105`, `card(avail) = 91`, `%system.platform% = LEX`,
`hasConopt = 1`. `avail` enumerates `CONOPT`, `CONOPT3`, `IPOPT`, `MINOS`, `SNOPT`, …

⚠ **Honest limitation:** `system.SolverPlatformMap` reports what is *installed for the
platform*, **not** what the *license* permits. A solver can appear in `avail` and still
fail at solve time with a licensing error (rc 7) or a demo size limit. Treat `avail` as
necessary, not sufficient.

⚠ `avail('nosuchsolver')` is a **domain violation → rc 2**. Always probe with
`sum(avail$sameas(avail,'name'), 1)`, never with a literal element reference.

### 9.2 What `option nlp = <name>` does when the solver is unknown `[V]`

```
option nlp = notasolver;   →  rc 2, errors $... + $257 "Solve statement not checked
                              because of previous errors"
```

It is a **compile-time** error, so it is caught by `compile-gams` — but it is fatal and
cannot be caught in-program. That is why availability must be tested *before* the
`option` statement is compiled.

### 9.3 Compile-time graceful skip `[V]`

For a *conditional* skip you need the decision at compile time, before `option nlp=` is
seen. Two working forms:

**(a) Preferred — decide in the Makefile, pass a compile-time flag:**

```make
HAS_CONOPT := $(shell gams model/test/_ProbeSolvers.gms action=ce lo=0 o=/dev/null \
                        --SOLVER=conopt >/dev/null 2>&1 && echo 1 || echo 0)
```
where `_ProbeSolvers.gms` is the `avail` snippet from §9.1 plus
`abort$(hasSolver = 0) "solver unavailable";`. Then:

```make
ifeq ($(HAS_CONOPT),0)
test-gams-nlp:
	@echo "SKIP test-gams-nlp: CONOPT unavailable on this host"
endif
```

**(b) In-GAMS, self-skipping driver:**

```gams
$call gams test/_ProbeConopt.gms action=c lo=0 o=build/probe.lst
$if errorLevel 1 $log SKIP: CONOPT unavailable - unit not executed
$if errorLevel 1 $exit
$include payoff/eta_pi_trader_zero_slippage.gms
```

`[V]` Both branches verified: with CONOPT present the unit ran; with a bogus solver the
driver logged `SOLVER UNAVAILABLE - unit skipped`, executed nothing, and returned **rc 0**.

### 9.4 Skip vs fail — the policy

| Context | Behaviour | Rationale |
|---|---|---|
| Developer laptop, `make test-gams` | **skip with a loud line + count in the summary** | Do not block local iteration on a solver licence |
| CI `develop` / `master` gate | **fail** | A green gate that silently skipped 60 NLP units is a lie |

Implement with one switch: `make test-gams STRICT=1` turns every skip into a failure,
and CI always passes `STRICT=1`. The summary line **must always print the skip count**
(`132 passed, 0 failed, 2 skipped`) so a skip is never invisible.

---

## 10. Anti-patterns (all observed or verifiable here)

### AP-1: Gating a test on the presence of a string in the `.lst`
**What people do:** `grep -qE 'Status: (Compilation|Execution) error' run.lst`.
**Why it's wrong:** `[V]` that string is a **log** artefact, absent from the listing for
every `lo` value; and with `lo=0` plus `>/dev/null` it is destroyed twice. Result: a
false-pass gate that also lets committed fixtures go stale.
**Do this instead:** `if gams ...; then` — the exit code is reliable for compile (2) and
execution (3) errors. Capture the log with `lo=2 lf=<file>` for diagnostics only.

### AP-2: `abort.noError`
**What people do:** reach for it to "stop quietly".
**Why it's wrong:** `[V]` halts execution but returns **rc 0** and emits no `Status:`
line. A test that uses it can never fail the build.
**Do this instead:** plain `abort$`. Lint for `abort.noError` in CI.

### AP-3: Assuming a `Solve` that returns is a `Solve` that succeeded
**Why it's wrong:** `[V]` an infeasible LP returned `modelStat = 19` and **rc 0**.
**Do this instead:** `assertModelOptimal("<unit>", ModelName);` after every `Solve`,
without exception. **CODIFY** — the repo already does this.

### AP-4: A single global `zeroTolerance`
**Why it's wrong:** `[V]` `1e-20` is satisfiable only because the payoff is a *square*
(`1.73e-33`); the unsquared residual is `4.16e-17` and would fail. The constant encodes an
undocumented assumption.
**Do this instead:** `absFloor(scale) = epsSlack * machEps * |scale|` (§5.2).

### AP-5: Guarding a relative check with `max(|rhs|, zeroTolerance)`
**Why it's wrong:** `[V]` it silently degrades to an absolute check at `relTol × 1e-20`.
**Do this instead:** abort with a distinct "zero reference" message, or use `assertClose`.

### AP-6: Trying to aggregate theorem units, with or without `$onMulti`
**Why it's wrong:** `[V]` `$onMulti` reduces 4 errors to 1 but `$150 Symbolic equations
redefined` is unconditional. Aggregation of solver-bearing units is impossible.
**Do this instead:** one process per theorem (§4.1). **CODIFY.**

### AP-7: `execute 'cmd'` / `$call 'cmd'` without an error check
**Why it's wrong:** `[V]` both ignore the child's exit status by default, and
`$onCheckErrorLevel` covers **only `$call`**, not `execute`.
**Do this instead:** `execute.checkErrorLevel` and `$call.checkErrorLevel`.

### AP-8: `gdx=<file>` to produce a golden fixture
**Why it's wrong:** `[V]` it writes even when the run aborts (rc 3), so a failing run
can overwrite a good fixture.
**Do this instead:** `execute_unload` as the last statement, after all assertions.

### AP-9: One `abort` per property, halting at the first failure
**Why it's wrong:** a 12-assertion unit needs up to 12 edit-run cycles.
**Do this instead:** soft `check*` macros + `assertNoFailures;` (§6.1).

---

## 11. Build order — what must land before the 134-theorem port

| # | Deliverable | Type | Blocking? | Why this order |
|---|---|---|---|---|
| **1** | Fix the exit-code gate in `payoff-fixtures`, `spec-preflight`, `spec-preflight-band` | **CHANGE** | **BLOCKER** | Until this lands, every other gate's green is uninformative — including any gate added later. |
| **2** | `model/test/_AssertLib.gms` + adopt in the 2 existing theorem units | NEW | **BLOCKER** | 134 units must be *born* using the macros; retrofitting 134 files later is the expensive path. |
| **3** | Tolerance policy: `machEps`/`epsSlack`/`absFloor`, and document why `zeroTolerance=1e-20` works only for squares | **CHANGE** | **BLOCKER** | Every ported theorem picks a tolerance on day one. Get the rule right first. |
| **4** | Naming + module-directory convention (§4.2), applied to `payoff/` | CODIFY | High | The Makefile's unit discovery depends on it being mechanical. |
| **5** | Machine-readable registry (`Set unit`, `unitTier`, `unitSkip` with reason strings) | **CHANGE** | High | Tiering, skipping and reporting all read from it. |
| **6** | Tiered targets `test-gams-pure` / `test-gams-nlp` + `STRICT=1` | **CHANGE** | High | Lets fork PRs run the pure tier without a solver; keeps CI honest about skips. |
| **7** | Solver-availability probe (§9.1/9.3) | NEW | Medium | Needed before the suite spans hosts with different solver sets. |
| **8** | Fixture protocol: `execute_unload` last + `check-fixtures` via `gdxdiff` | CODIFY + NEW | Medium | Turns "fixture unchanged" into an assertion. Consumed by the gamsdiff peer. |
| **9** | Output contract: one line per unit, `build/results.tsv`, `$offListing` + `limRow/limCol/solPrint` | **CHANGE** | Medium | Becomes painful at ~40 units; do it before 134. |
| **10** | CI lints: `abort.noError`, bare `execute`/`$call`, `Model` without `assertModelOptimal` | NEW | Low | Cheap greps that prevent regression to AP-2/3/7. |
| **11** | Parallel per-unit make targets (`make -j`) | NEW | Low | Pure speed; correct only once 4–6 are in place. |
| **12** | Port the 9-module / 134-theorem closure | — | — | Everything above is a precondition. |

Items 1–3 are genuinely blocking. Items 4–6 are strongly recommended before porting more
than a handful of units. Items 7–11 can land during the port.

---

## 12. What I could NOT verify

Stated plainly, per the quality gate:

1. **Full-license behaviour.** The local GAMS is a **Demo license** (`GAMS Demo … Demo
   license for demonstration and instructional purposes only`). Model-size limits and
   solver-licence failures may behave differently on the CI runner. Specifically I could
   **not** test the case "solver present in `system.SolverPlatformMap` but not licensed",
   which I expect returns **rc 7** but did not observe.
2. **`gdxdiff` exit codes beyond {0, 1}.** I observed 0 (identical) and 1 (differences).
   I did not find documentation enumerating its full return-code set, so I cannot assert
   that 1 is the *only* non-zero value (e.g. a missing input file may return something
   else). **Verify before relying on `rc == 1` specifically; rely on `rc != 0`.**
3. **`execError` upper bound.** I verified `execError = N` marks a failure and continues
   with rc 3, but did not determine whether GAMS caps the number of accumulated
   execution errors before force-halting. If the soft-assertion pattern is used with
   `execError` (rather than the plain counter shown in §6), confirm this first. **The
   `_AssertLib.gms` given above deliberately uses a plain `asrtFail` counter and a single
   terminal `abort`, which avoids the question entirely.**
4. **Where the exit-0-on-compile-error belief originated.** The repo comment asserts
   `gams` exits 0 on compile errors. I could not reproduce that for any ordinary compile
   error (always rc 2). It is possible the original observation was the shell-level
   `$?`-clobbering shown below rather than GAMS behaviour:
   ```sh
   gams broken.gms ... ; echo ; echo "rc=$?"    # prints rc=0 — $? is echo's, not gams's
   ```
   I hit exactly this while testing. **Flagging as unresolved**, but it does not change
   any recommendation: §3.3 lists four *real* exit-0 hazards regardless.
5. **Performance at 134 units.** No timing data at scale; the parallelism recommendation
   (§7.3) is reasoned from GAMS's unique-scratch-directory behaviour, not measured under
   `-j8`.
6. **`%system.platform%` portability.** Measured `LEX` on this host. The `avail` set
   construction is taken verbatim from GAMS's own `quality.gms`, so it is authoritative,
   but I verified it on one platform only.

---

## 13. Codify vs. change — summary

| Existing convention | Verdict |
|---|---|
| One execution unit per theorem; registry does not aggregate | **CODIFY** — and strengthen the justification: `$onMulti` cannot rescue it (`$150`), so this is structurally forced `[V]` |
| `abort$(cond) "msg", sym;` as the assertion primitive | **CODIFY** — it is GAMS's own `testlib` idiom `[V]` |
| `action=ce` for tests, `action=c` for compile gate | **CODIFY** — and document that `action=c` proves nothing about assertions `[V]` |
| `modelStat` assertion after every `Solve` | **CODIFY** — mandatory; rc is 0 on infeasible `[V]` |
| `$if set X $exit` include guard | **CODIFY** — semantics verified correct `[V]` |
| `execute_unload` as the last statement, after assertions | **CODIFY** — load-bearing; prevents fixture overwrite on failure `[V]` |
| GDX provenance (`gamsVersion`, `modelVersion`, theorem/Lean/Aristotle sets, `theoremStatus`) | **CODIFY** — extend with `asrtRun`/`asrtFail` |
| Leading-underscore for non-unit files (`_PayoffScaffolding.gms`) | **CODIFY** |
| `diffTolerance = 1e-12` relative | **CODIFY** — ≈ 4500 × `machEps`, sound and scale-invariant |
| `compile-gams` / `test-gams` trusting the exit code | **CODIFY** — verified sound, incl. `$?` in the `else` branch `[V]` |
| `.lst` post-grep for `Status: … error` | **CHANGE — BLOCKER**, false-pass gate `[V]` |
| `zeroTolerance = 1e-20` as a global absolute tolerance | **CHANGE** — replace with scale-derived `absFloor()`; keep the constant, document its assumption `[V]` |
| Single `test-gams` requiring CONOPT for everything | **CHANGE** — tier into `pure` / `nlp` |
| `PayoffModule.gms` registry as prose comments | **CHANGE** — make it machine-readable Sets |
| Hard `abort` for every property | **CHANGE** — soft `check*` + `assertNoFailures` for property bodies |
| No assertion macros (inline `abs(a-b)/b > tol` everywhere) | **CHANGE** — adopt `_AssertLib.gms` |

---

## Sources

**Primary (executed locally — HIGH confidence).** GAMS 54.1.0 `37378ce0` LEG x86
64bit/Linux at `/usr/gams/gams54.1_linux_x64_64_sfx/`. ~40 purpose-built probe programs
covering: exit codes for clean/compile-error/execution-error/`abort`/`abort.noError`/
`execError`/`$abort` runs; `action=c` vs `ce`; `$onCheckErrorLevel` vs
`execute.checkErrorLevel` vs `$call.checkErrorLevel`; `$exit` include-guard scoping;
`$onMulti` aggregation; `$macro` multi-statement / continuation / comma-nesting;
`abort` payload restrictions; `option decimals` range; `put` precision; `execute_load`
shadow symbols and missing-symbol handling; `gdxdiff` exit codes with `Eps`/`RelEps`/`ID`;
`gdx=` on abort; infeasible-LP `modelStat`; unknown-solver handling; `system.solverNames`
/ `system.SolverPlatformMap`; and a numeric scale probe run against the repo's own
`_PayoffScaffolding.gms` fixture.

**Vendor test-suite architecture (HIGH).** GAMS Test Model Library, extracted with
`testlib`: `testmod.inc` (registry of ~1000 units with descriptions), `quality.gms`
(orchestrator: `SET solver / system.solverNames /`, `avail(solver)`, `ignore(m)`,
`gskip(m)`, `skip(solver,m)` with per-entry reason strings, trace/report/failure files),
`assign1.gms` (canonical `abort$(cond) 'message';` idiom), `testutil.gms`.

**Documentation (HIGH).**
- https://www.gams.com/latest/docs/UG_GAMSReturnCodes.html — complete return-code table
- https://www.gams.com/latest/docs/UG_DollarControlOptions.html — `$onCheckErrorLevel`, `$abort`, `$macro`, `$exit`
- https://www.gams.com/latest/docs/UG_GamsCall.html — `action`, `logOption`, `logFile`, `errMsg`, `errorLog`, `gdx`

**Repo sources reviewed.** `.planning/PROJECT.md`, `Makefile`,
`model/PayoffModule.gms`, `model/payoff/_PayoffScaffolding.gms`,
`model/payoff/eta_pi_trader_zero_slippage.gms`, `model/test/PricingKernelTest.gms`,
`model/test/PriceImpactKernelTest.gms`, `model/test/PayoffZeroSlippageTest.gms`.

---
*Architecture research for: GAMS test architecture, dual-representation CFMM model*
*Researched: 2026-07-27 · GAMS 54.1.0 37378ce0 · all `[V]` claims executed*
