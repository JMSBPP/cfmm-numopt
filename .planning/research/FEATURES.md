# Feature Research

**Domain:** GAMS 54.1 pluggable time-series ingestion + windowed moment computation (the `mean_tick` / `realized_variance` layer over an ingestible `TimeWindow` domain)
**Researched:** 2026-07-27
**Confidence:** HIGH — every syntax claim below was executed against the repo's own GAMS 54.1.0 (`37378ce0 Jun 15, 2026 LEX-LEG x86 64bit/Linux`), not inferred from training data. Exit codes and listing errors are quoted verbatim. Two web-doc claims are corroborating only and marked MEDIUM inline.

---

## 0. The Governing Constraint (read this before the tables)

`make compile-gams` compiles **every** `.gms` under `model/` (excluding `test/` and `build/`) with `action=c`, and `GAMS_SKIP` is empty. So `model/PricingKernelMoments.gms` must compile **with no data file anywhere on disk**. That single requirement decides the entire architecture.

### Compile-time vs execution-time GDX loading — verified

| Statement | Phase | `action=c`, **no** data file | `action=ce`, no data file |
|---|---|---|---|
| `$gdxIn f.gdx` / `$load` / `$loadDC` | **COMPILE** | **rc=2 — HARD COMPILE ERROR** | rc=2 |
| `execute_load` / `execute_loadDC` | **EXECUTION** | **rc=0 — clean compile** | rc=3 (execution error) |

Verbatim failure for the compile-time form:

```
****  510  Unable to open gdx file for $gdxIn
****  502  GDXIN  file not open - ignore rest of line
**** 2 ERROR(S)   0 WARNING(S)
```

**Consequence:** a bare `$gdxIn`/`$load` in `PricingKernelMoments.gms` turns `compile-gams` red on every developer machine and in CI the moment the data file is absent — which is always, because a pluggable/undecided source means no committed data. `execute_loadDC` is therefore **the** ingestion boundary for this repo. `$load` is admissible only inside a producer/fixture file, and only behind a guard (§ anti-features).

### The two runtime-set laws that follow

Choosing execution-time loading is not free. Two GAMS rules bite immediately, and both were confirmed by execution:

**Law 1 — you cannot `execute_load` into a set that is used as a domain.**

```gams
Set t;
Parameter obs(t);
execute_load 'series.gdx', t, obs;
```
```
****  188  Assigning to this set is NOT allowed. The set may have been
****         used in a domain definition or is a predefined/readonly set.
```

**Law 2 — `ord()` and the lag/lead operators are illegal on a set whose membership is assigned at execution time.**

```gams
Set tRet(tAll);
tRet(t)$(ord(t) > 1) = yes;
r(tRet) = log( obs(tRet) / obs(tRet-1) );
```
```
****  197  Lag or 'ord' illegal with non constant set
****         $offOrder allows lag operations on dynamic sets, reset with
****         $onOrder or use of a * universe
```

A set is "constant" iff its membership is fixed at **compile** time — literal data (`/ t1*t9 /`) or a compile-time `$load`. A set filled by `execute_load*` is *not* constant. Since realized variance is *defined* by a lag (`log(P_t / P_{t-1})`), Law 2 is fatal to the naive design.

**Law 3 (the sharpest one) — execution-time loads cannot introduce new labels.** Verified:

```gams
Set t;                        * no static grid
Parameter obsFree(*);
execute_load 'series.gdx', t, obsFree=obs;   * gdx contains t1..t5
```
→ `rc=0`, `card(t) = 0`, `SET t  ( EMPTY )`. **Silent. No error. No warning.** GAMS docs corroborate: *"when an item is resident in a GDX file for set elements not present in the current file these items are ignored"* (MEDIUM — web doc, but matches the observed run exactly). Adding `Set tKnown / t1*t5 /;` elsewhere in the file makes the identical load yield `card(t)=5`, `sum=505`.

**The resolution of all three laws is one pattern**: a model-owned **static capacity grid** as the parent, with the producer supplying only *membership* and *values* keyed to that grid.

```gams
Set tAll  "static observation capacity grid" / o1*o4096 /;   * model owns this
Set tObs(tAll) "loaded observation membership";               * producer fills this
Parameter obsSqrtPX96(tAll), obsTick(tAll);
execute_loadDC 'data/tickseries.gdx', tObs, obsSqrtPX96, obsTick;
```

`ord()`/lag are then always applied to `tAll` (constant → legal), and `tObs` appears only as a `$` filter. Verified working end to end.

### Why this also fixes determinism

The GDX's label order **is** the set order. Loading a scrambled series through a bare `Set t;` at compile time produced `ord = t3→1, t1→2, t5→3, t2→4, t4→5` and therefore silently wrong returns (`[0.010, 0.020, -0.010, 0.020]` instead of the true `[0.010, -0.020, 0.040, -0.010]`) — **rc=0, no diagnostic**. Loading the *same scrambled GDX* through the static-grid pattern produced `ord = t1→1 … t5→5` and the correct returns. The static grid makes ordering a property of the **consumer**, not of the producer. That is the property that makes the source genuinely swappable.

---

## Feature Landscape

### Table Stakes — must-have for the data contract to work at all

| Feature | Why Expected | Complexity | Notes |
|---|---|---|---|
| **Static capacity grids `tAll`, `winAll`** | Without them execution-time loads silently return nothing (Law 3) and `ord`/lag are illegal (Law 2). Non-negotiable. | LOW | `Set tAll / o1*o4096 /; Set winAll / w1*w256 /;` Sized generously; a too-small grid is caught by `execute_loadDC`. |
| **`execute_loadDC` as the sole ingestion verb** | Execution-time (keeps `action=c` green with no data) *and* domain-checked (turns Law-3 silent-empty into a loud error). | LOW | `execute_loadDC 'data/tickseries.gdx', tObs, obsSqrtPX96, obsTick;` Compiles clean with the file absent — verified rc=0. |
| **Loaded membership set `tObs(tAll)`, never a bare `Set TimeWindow`** | Law 1: a bare set used as a domain cannot be `execute_load`ed ($188). | LOW | `Set tObs(tAll);` Parameters are declared over **`tAll`**, not over `tObs`. |
| **All `ord()`/lag confined to the static parent** | Law 2. This is a discipline, not a feature — but it must be written into the contract file's header comment or it will be violated. | MEDIUM | `r(tAll)$( tObs(tAll) and ord(tAll)>1 and obsSqrtPX96(tAll-1) ) = …` |
| **Guarded log returns with an explicit `hasRet` mask** | Unguarded, the first observation divides by zero. Verified: `**** Exec Error at line 6: division by zero (0)`, rc=3. Linear-lag out-of-range yields **0**, not "skip". | LOW | See §Realized Variance below. The mask is reused by every window, so compute it once. |
| **`mean_tick` / `realized_variance` as `Parameter(winAll)`, not `$macro`** | Moments are *data over a window domain*. A macro cannot carry a domain or be unloaded to GDX for the differential track. | LOW | Replaces the stub's two no-op macros. |
| **Window mapping set `winMap(winAll,tAll)`** | Two-index mapping is the only formulation that keeps `ord()` on static parents while expressing arbitrary (blocked, rolling, ragged) windows. | MEDIUM | Derived in-model in v1; loadable in v1.x. Same downstream algebra either way — that is the point. |
| **Cardinality guards on every division** | An empty or short series otherwise yields silent zeros or a division-by-zero abort. | LOW | `mean_tick(winAll)$winCard(winAll) = … / winCard(winAll);` |
| **Contract assertions (`abort$`)** | Matches the repo's existing `abort$(...)` vocabulary; converts silent-empty into a red build. | LOW | `abort$(nObs = 0) "CONTRACT: series is empty";` — verified fires, rc=3. |
| **Provenance block echoed from producer to GDX output** | The repo already unloads `gamsVersion`/`modelVersion`/theorem-name sets; ingested data must be traceable the same way or a moment cannot be traced to its input series. | MEDIUM | Split-load required — see the anti-feature on `execute_loadDC` for label sets. |
| **Consumer-side checksum re-derivation** | Cheapest possible defense against a producer whose declared provenance does not match its payload. | LOW | Verified round-trip. See §Provenance. |

### Differentiators — needed only once a real data source is chosen (defer)

| Feature | Value Proposition | Complexity | Notes |
|---|---|---|---|
| **Producer-supplied `winMap`** | Lets an API source define calendar windows (daily/hourly) the model cannot derive from index position alone. | MEDIUM | Contract already accommodates it: just `execute_loadDC … winMap` instead of deriving. **Defer** — nothing to calibrate against yet. |
| **`obsTimestamp(tAll)` + gap detection** | Real feeds have gaps; index position stops being a proxy for elapsed time, so RV needs time-scaling. | MEDIUM | Declare the symbol in v1 (cheap, keeps contract stable), enforce nothing. Depends on a real source existing. |
| **Rolling / overlapping windows** | Trailing-window RV for a control loop, vs. blocked windows for estimation. | MEDIUM | Same `winMap` machinery, different derivation. Defer until the controller track states which it needs. |
| **Time-scaled / annualized RV** | Converts a per-window sum of squared returns into a comparable volatility figure for `Upsilon`. | LOW | One scalar multiply — but the *right* scalar is unknowable without a real sampling frequency. Defer. |
| **Bipower variation / jump-robust estimators** | Robustness to the fat-tailed jumps that swap flow actually exhibits. | MEDIUM | `sum(..., abs(r(t))*abs(r(t-1)))`. Pure addition over the same contract; strictly v1.x. |
| **Multiple simultaneous series (pool dimension)** | One model run covering several pools. | HIGH | Adds a leading index to every contract symbol. Do **not** pre-build it — it doubles the algebra for an unvalidated need. |
| **GDX-diff regression fixture for the moments layer** | The differential-testing peer already consumes three GDX fixtures; a fourth would let moments be diffed against Solidity. | LOW | Reuses `payoff-fixtures`-style unloading. Add once a producer is chosen so the fixture is meaningful. |

### Anti-Features — deliberately avoid (GAMS-specific)

| Feature | Why Requested | Why Problematic | Alternative |
|---|---|---|---|
| **`$gdxIn` / `$load` at the top of `PricingKernelMoments.gms`** | It is the pattern in most GAMS textbooks and tutorials. | Compile-time. **Breaks `make compile-gams` with rc=2 whenever the data file is absent** — i.e. always, for an undecided source. | `execute_loadDC`, which is execution-time and compiles clean (rc=0 verified). |
| **Bare `execute_load` for the observation series** | Shorter; "domain checking is just noise". | Silently drops every off-grid observation. With `tAll / t1*t3 /` and a 5-point GDX it reported `card=3`, `sum=300` — **a wrong mean of 100 instead of 101, rc=0**. | `execute_loadDC`. Same input gives `rc=3`, `**** 2 Domain errors for symbol t`. |
| **No static parent grid ("just let the GDX define the set")** | It is the whole point of loading data. | Law 3: `card(t)=0`, `SET t ( EMPTY )`, **rc=0**. The model computes moments of nothing and exits successfully. | Static `tAll` + `tObs(tAll)` + `execute_loadDC`. |
| **Circular lag `t--1` for returns** | It "handles the boundary" and never errors. | It fabricates a return by wrapping the first observation to the **last**. Verified: `lagCirc(t2) = 50` where `t5` is the final element. Economically meaningless, statistically corrupting, silent. | Linear lag `t-1` with an explicit `hasRet` mask that drops the first observation. |
| **Unguarded `log(obs(t)/obs(t-1))`** | Reads exactly like the mathematical definition. | Linear lag out of range yields **0**, so the first element divides by zero: `**** Exec Error at line 6: division by zero (0)`, rc=3. | Guard on the *predecessor's value*: `$( … and obsSqrtPX96(tAll-1) )`. This also handles interior gaps. |
| **`$offOrder` to make `ord`/lag work on the loaded set** | It is what GAMS's own $197 message suggests, and it works (verified rc=0). | Global switch that disables the ordering check for the entire compilation unit, including included files. Worse, it makes `ord()` follow the **producer's GDX label order** — the exact determinism hole demonstrated above. | Static parent grid. Keeps the check on and makes ordering model-owned. |
| **`$macro mean_tick (…)` — the current stub** | It is what is in the file today. | **The stub compiles clean, rc=0** — CI is *green* on it, which is worse than an error. The space before `(` makes GAMS parse a **zero-argument text macro** whose body is the literal `(TimeWindow, priceKernelVal)`; expanding it produced `**** 125 Set is under control already`. It computes nothing and has no domain. | `Parameter mean_tick(winAll);` with a real assignment. |
| **`execute_loadDC` for free-text provenance label sets** | Consistency — "use DC for everything". | Provenance labels (`'sim-gbm-seed42-v1'`) are new UELs, so DC rejects them: `**** 1 Domain errors for symbol seriesIdSet`. Plain `execute_load` then *silently drops* them (`card=0`, abort fired). | Declare provenance labels in the **consumer** as a static set, or accept a compile-time `$load` for provenance only. See §Provenance. |
| **Committing `tickseries.gdx` to git** | Makes the build self-contained. | GAMS embeds a build timestamp in the GDX header, so re-generation produces "Binary files differ" with identical content — the repo already documents this in `PriceImpactKernelFixture.gms`. A committed data GDX will churn forever. | Commit a *tiny* deterministic fixture for `test/` only; keep production series untracked under `model/data/`. |
| **Treating `TimeWindow` as the ingested set** | The stub's name suggests it. | Conflates two different domains: the *observation* index (what is ingested) and the *window* index (what moments are reported over). Fusing them makes rolling windows inexpressible. | Two grids: `tAll` (observations) and `winAll` (windows), joined by `winMap`. |

---

## Concrete Formulations (all executed, all verified)

### Windowed moments — blocked windows

```gams
Scalar WLEN / 4 /;
Set tAll   "static observation capacity grid" / o1*o4096 /;
Set winAll "static window capacity grid"      / w1*w256  /;
Set tObs(tAll);
Parameter obsTick(tAll), obsSqrtPX96(tAll);

execute_loadDC 'data/tickseries.gdx', tObs, obsTick, obsSqrtPX96;

Scalar nObs; nObs = card(tObs);
abort$(nObs = 0) "CONTRACT: series is empty";
Scalar nWin; nWin = floor(nObs / WLEN);
abort$(nWin = 0) "CONTRACT: fewer observations than one window", nObs, WLEN;

* ord() touches only tAll and winAll -- both compile-time constant
Set winMap(winAll,tAll);
winMap(winAll,tAll)$( ord(winAll) <= nWin and tObs(tAll)
                      and ord(tAll) >  (ord(winAll)-1)*WLEN
                      and ord(tAll) <= ord(winAll)*WLEN ) = yes;

Parameter winCard(winAll);
winCard(winAll) = sum(winMap(winAll,tAll), 1);

Parameter mean_tick(winAll);
mean_tick(winAll)$winCard(winAll)
    = sum(winMap(winAll,tAll), obsTick(tAll)) / winCard(winAll);
```

Verified on a 12-point series with `WLEN=4`: `mean_tick = 102.5, 107.25, 112.25`, matching hand computation exactly.

### Realized variance — log returns, boundary-safe

```gams
* hasRet: an observation with an immediately preceding observation carrying a
* non-zero price. The obsSqrtPX96(tAll-1) test is what prevents the
* division-by-zero at the series head AND at any interior gap.
Parameter hasRet(tAll);
hasRet(tAll)$( tObs(tAll) and ord(tAll) > 1 and obsSqrtPX96(tAll-1) ) = 1;

* factor 2 because obsSqrtPX96 is a SQRT price in Q64.96;
* the Q96 scale cancels in the ratio, so no descaling is needed.
Parameter logRet(tAll);
logRet(tAll)$hasRet(tAll) = 2 * log( obsSqrtPX96(tAll) / obsSqrtPX96(tAll-1) );

Parameter rvCard(winAll), realized_variance(winAll);
rvCard(winAll) = sum(winMap(winAll,tAll)$hasRet(tAll), 1);
realized_variance(winAll)$winCard(winAll)
    = sum(winMap(winAll,tAll)$hasRet(tAll), sqr(logRet(tAll)));

* Comparable ACROSS windows: window 1 structurally owns one fewer return.
Parameter rv_bar(winAll);
rv_bar(winAll)$rvCard(winAll) = realized_variance(winAll) / rvCard(winAll);
```

**Boundary condition, stated explicitly:** with blocked windows the first window has `rvCard = WLEN-1` while all later windows have `WLEN` — verified `rvCard = 3, 4, 4`. Raw `realized_variance` is therefore **not** comparable across windows; either report `rv_bar`, or anchor each window's first return to the previous window's last observation. This is a real modelling decision, not an implementation detail, and must be recorded in the contract.

### A built-in cross-check the repo's assertion style already invites

Because `tick = log(P)/log(λ)`, log-space and tick-space RV must satisfy `RV_log = (log λ)² · RV_tick`. This gives a free internal consistency assertion that catches scale and factor-of-2 bugs:

```gams
Parameter dTick(tAll);
dTick(tAll)$hasRet(tAll) = obsTick(tAll) - obsTick(tAll-1);
Parameter rv_tick(winAll);
rv_tick(winAll)$winCard(winAll) = sum(winMap(winAll,tAll)$hasRet(tAll), sqr(dTick(tAll)));

Scalar maxRelErr;
maxRelErr = smax(winAll$realized_variance(winAll),
    abs(realized_variance(winAll) - sqr(log(lambdaTick))*rv_tick(winAll))
      / realized_variance(winAll));
abort$(maxRelErr > diffTolerance)
    "FAIL: RV_log = (log lambda)^2 * RV_tick identity violated", maxRelErr;
```

Verified: `maxRelErr = 4.01e-13`, inside the repo's `diffTolerance = 1e-12`.

### Bonus: the blocked `tickPerPriceKernel` inverse

`PricingKernel.gms` marks `tickPerPriceKernel` DO-NOT-USE for unbalanced parens and a nonexistent two-argument `log(base,x)`. The moments layer needs this inverse (observed sqrt price → tick). Verified fix:

```gams
$macro tickPerPriceKernel(sqrtPX96) ( 2 * log( (sqrtPX96) / power(2,96) ) / log(lambda/unity) )
```

Round-trip at tick 1234 returns 1234.000 at relative error **1.11e-15**.

---

## Data Contract vs. Data Producer — concrete layout

The split is: **the contract is declarations plus assertions and contains no data; the producer writes a GDX and contains no model algebra.** They meet only at the GDX symbol names.

```
model/
  moments/
    _MomentsContract.gms      # DECLARATIONS ONLY. No $load, no execute_load, no algebra.
    MomentsKernel.gms         # $include _MomentsContract.gms; the windowed algebra.
    PricingKernelMoments.gms  # replaces the stub: contract + kernel + loadDC + abort$ + unload
  data/
    tickseries.gdx            # UNTRACKED. Whatever producer ran last.
    producers/
      fabricate_tickseries.gms   # deterministic synthetic -- pure GAMS, execute_unload
      simulate_tickseries.gms    # stochastic swap-flow sim -- pure GAMS, seeded
      api_tickseries.py          # external fetch -> GDX (gams-transfer / gdxpds)
  test/
    MomentsKernelTest.gms     # drives the kernel against a tiny COMMITTED fixture
    fixtures/tickseries_ref.gdx
```

**Contract `tickseries-v1` — the exact symbols a producer must emit:**

| Symbol | Type | Domain | Meaning | Owner |
|---|---|---|---|---|
| `tAll` | Set | — | static capacity grid `/ o1*o4096 /` | **model** (never in the GDX) |
| `winAll` | Set | — | static window grid `/ w1*w256 /` | **model** |
| `tObs` | Set | `(tAll)` | which slots are populated | producer |
| `obsSqrtPX96` | Parameter | `(tAll)` | observed sqrt price, Q64.96 | producer |
| `obsTick` | Parameter | `(tAll)` | observed tick (int24 range) | producer |
| `obsTimestamp` | Parameter | `(tAll)` | unix seconds; 0 = unknown | producer (v1: may be all-zero) |
| `seriesIdSet` | Set | `*` | singleton, unique series id | producer |
| `producerSet` | Set | `*` | singleton, producing file/script | producer |
| `sourceKindSet` | Set | `*` | singleton: `fabricated`/`simulated`/`api` | producer |
| `contractVerSet` | Set | `*` | singleton: `tickseries-v1` | producer |
| `producerSeed` | Scalar | — | RNG seed, or 0 for non-stochastic | producer |
| `producedAtEpoch` | Scalar | — | unix seconds of production | producer |
| `seriesChecksum` | Scalar | — | `sum(tAll$tObs(tAll), obsTick(tAll)*ord(tAll))` | producer |
| `mean_tick` | Parameter | `(winAll)` | **output** | model |
| `realized_variance` | Parameter | `(winAll)` | **output** | model |

Note `tAll` and `winAll` are deliberately **absent from the GDX**. That is what makes ordering model-owned and the source swappable. A producer that tries to redefine the grid is, by construction, unable to.

A source is swapped by regenerating `model/data/tickseries.gdx`. Nothing under `model/moments/` changes.

---

## Determinism and Provenance

Verified round-trip. The load must be **split**, because domain-checking behaves oppositely for grid-keyed data and for free-text labels:

```gams
* (1) DOMAIN-CHECKED for grid-keyed numeric data -- catches off-grid labels loudly
execute_loadDC 'data/tickseries.gdx', tObs, obsTick, obsSqrtPX96, obsTimestamp;

* (2) Provenance label sets. Their labels are NEW UELs:
*       execute_loadDC -> "**** 1 Domain errors for symbol seriesIdSet"
*       execute_load   -> silently drops them (card = 0)
*     So the labels must be known to the consumer at compile time.
Set sourceKindSet  / fabricated, simulated, api /;
Set contractVerSet / 'tickseries-v1' /;
Set srcKindObs(sourceKindSet), contractVerObs(contractVerSet);
execute_loadDC 'data/tickseries.gdx',
    srcKindObs=sourceKindSet, contractVerObs=contractVerSet,
    producerSeed, producedAtEpoch, seriesChecksum;

abort$(card(contractVerObs) <> 1) "CONTRACT: series does not declare tickseries-v1";

* (3) Re-derive the checksum on the CONSUMER side.
Scalar checkRecomputed;
checkRecomputed = sum(tAll$tObs(tAll), obsTick(tAll)*ord(tAll));
abort$(abs(checkRecomputed - seriesChecksum) > 1e-9)
    "CONTRACT: checksum mismatch - GDX values do not match declared provenance",
    checkRecomputed, seriesChecksum;
```

The checksum is **position-weighted on purpose** (`* ord(tAll)`): a plain sum would not detect a reordered series, which is precisely the failure mode demonstrated in §0.

The free-text `seriesIdSet` / `producerSet` (arbitrary strings, unknown at compile time) cannot survive an execution-time load at all. Two honest options: (a) carry series identity as a **numeric** `seriesIdHash` scalar instead of a label — recommended, it survives `execute_loadDC` cleanly; or (b) accept a compile-time `$load` for provenance labels only, behind an exist-guard. Option (a) is preferred because it keeps the whole ingestion path execution-time and `action=c`-safe.

Finally, the output GDX must echo the input provenance so a moment traces to its series — matching the existing convention in `eta_pi_trader_zero_slippage.gms`:

```gams
execute_unload 'pricing_kernel_moments.gdx',
    mean_tick, realized_variance, rv_bar, winCard, rvCard, winMap,
    gamsVersion, modelVersion, diffTolerance,
    seriesIdHash, producerSeed, producedAtEpoch, seriesChecksum,
    srcKindObs, contractVerObs;
```

---

## Feature Dependencies

```
Static capacity grids (tAll, winAll)
    └──required-by──> execute_loadDC seeing ANY data (Law 3)
    └──required-by──> ord()/lag legality (Law 2)
                          └──required-by──> logRet / hasRet
                                                └──required-by──> realized_variance
                                                └──enhances────> RV_log = (log λ)²·RV_tick check

tObs(tAll) as a SUBSET (not a bare Set)
    └──required-by──> execute_loadDC into a domain-used symbol (Law 1)

winMap(winAll,tAll)
    └──required-by──> mean_tick, realized_variance
    └──enables─────> rolling windows, producer-supplied windows  [v1.x]

hasRet mask
    └──required-by──> realized_variance (division-by-zero guard)
    └──required-by──> rvCard  ──required-by──> rv_bar (cross-window comparability)

seriesChecksum (position-weighted)
    └──detects─────> reordering, the silent failure mode of GDX ingestion

obsTimestamp  ──enables──> gap detection ──enables──> time-scaled RV   [v1.x]

$offOrder  ──conflicts-with──> static capacity grids
    (both "solve" Law 2; using $offOrder discards the determinism guarantee)
```

### Dependency Notes

- **Everything requires the static grids.** They are not an optimization; without them `execute_load*` returns an empty set with `rc=0` and the whole layer silently computes nothing.
- **`realized_variance` requires `hasRet`, which requires legal lag, which requires the static parent.** This chain is the reason ingestion architecture and moment algebra cannot be phased separately — a phase that lands ingestion with a "we'll fix ord() later" note will have to redo the ingestion.
- **`rv_bar` is not cosmetic.** Blocked windows give the first window one fewer return (verified `3, 4, 4`); without normalization, cross-window comparisons are biased low on window 1.
- **`$offOrder` conflicts with the static-grid approach.** Do not combine — `$offOrder` reintroduces producer-controlled ordering, defeating the reason the grid exists.

---

## MVP Definition

### Launch With (v1)

- [ ] **Replace the stub `PricingKernelMoments.gms`** — the current file *compiles green* while computing nothing; that is a silent falsehood in CI and the highest-value fix here.
- [ ] **`_MomentsContract.gms`** — `tAll`, `winAll`, `tObs(tAll)`, `obsTick`, `obsSqrtPX96`, `obsTimestamp`, provenance scalars. Declarations only.
- [ ] **`execute_loadDC` ingestion + `abort$` contract assertions** — empty series, short series, checksum, contract version.
- [ ] **`hasRet` / `logRet` with the predecessor-value guard** — boundary-safe by construction.
- [ ] **`mean_tick(winAll)`, `realized_variance(winAll)`, `rv_bar(winAll)`** as Parameters, blocked windows derived in-model.
- [ ] **`RV_log = (log λ)² · RV_tick` assertion** — free, and it is the only independent check available before a real source exists.
- [ ] **`fabricate_tickseries.gms`** — one deterministic producer, so the contract has a real client and `test/` has a fixture.
- [ ] **Fixed `tickPerPriceKernel`** — unblocks tick recovery from observed prices.
- [ ] **`make compile-gams` green with `model/data/` absent** — the acceptance test for the whole design.

### Add After Validation (v1.x)

- [ ] **`simulate_tickseries.gms`** — trigger: the swap-flow model is specified.
- [ ] **Rolling windows** — trigger: the controller track states it needs trailing RV.
- [ ] **Producer-supplied `winMap`** — trigger: a calendar-based source is chosen.
- [ ] **Gap detection over `obsTimestamp`** — trigger: a source with real gaps.
- [ ] **Moments GDX fixture for the differential track** — trigger: a producer is chosen, so the fixture means something.

### Future Consideration (v2+)

- [ ] **Bipower variation / jump-robust estimators** — defer until plain RV is validated against something.
- [ ] **Multi-pool series dimension** — defer; it adds an index to every contract symbol for an unvalidated need.
- [ ] **Annualization / time-scaling** — defer; the correct scalar is unknowable without a real sampling frequency.
- [ ] **`api_tickseries.py`** — defer; explicitly out of scope per PROJECT.md until the Plank schema is fixed.

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---|---|---|---|
| Static capacity grids + `tObs(tAll)` | HIGH | LOW | P1 |
| `execute_loadDC` ingestion (compiles with no data) | HIGH | LOW | P1 |
| Replace stub macros with real Parameters | HIGH | LOW | P1 |
| `hasRet`/`logRet` boundary guard | HIGH | LOW | P1 |
| `mean_tick` / `realized_variance` / `rv_bar` | HIGH | MEDIUM | P1 |
| Contract `abort$` assertions + checksum | HIGH | LOW | P1 |
| `RV_log` ↔ `RV_tick` identity assertion | MEDIUM | LOW | P1 |
| `fabricate_tickseries.gms` | MEDIUM | LOW | P1 |
| Fixed `tickPerPriceKernel` | MEDIUM | LOW | P1 |
| `simulate_tickseries.gms` | MEDIUM | MEDIUM | P2 |
| Rolling windows | MEDIUM | MEDIUM | P2 |
| Producer-supplied `winMap` | LOW | LOW | P2 |
| Gap detection / time-scaled RV | MEDIUM | MEDIUM | P2 |
| Bipower variation | LOW | MEDIUM | P3 |
| Multi-pool dimension | LOW | HIGH | P3 |
| API producer | LOW | HIGH | P3 (out of scope) |

## Alternatives Considered (in place of competitor analysis)

| Concern | Option A: compile-time `$load` | Option B: `$offOrder` + `execute_load` | **Chosen: static grid + `execute_loadDC`** |
|---|---|---|---|
| `action=c`, no data file | **rc=2, fails CI** | rc=0 | **rc=0** |
| `ord()`/lag legal | yes | yes | yes (on the parent) |
| Ordering controlled by | producer's GDX | producer's GDX | **the model** |
| Off-grid data | error | **silently dropped** | **error (rc=3)** |
| Empty/missing series | compile error | **silent `card=0`, rc=0** | **error (rc=3)** |
| Verdict | fails the governing constraint | two silent-wrong-answer paths | **recommended** |

Option A remains valid *inside producer files and `test/` drivers*, where the data file is known to exist — and there it needs `$onEmpty` with `/ /` initializers, or `$onImplicitAssign`, to avoid `**** 141 Symbol declared but no values have been assigned` on the `$else` branch of an exist-guard. Both fixes verified rc=0.

## Sources

- **GAMS 54.1.0 (`37378ce0 Jun 15, 2026`, LEG x86 64bit/Linux), executed locally** — HIGH. All error codes (`$510/$502`, `$188`, `$197`, `$141`, `$125`, `$154`), exit codes, and numeric results above are from actual runs. This is the authoritative source and it outranks the docs.
- `https://www.gams.com/latest/docs/UG_GDX.html` — MEDIUM. Corroborates compile-vs-execution phase split and the "elements not present in the current file … are ignored" behavior of `execute_load`.
- `https://www.gams.com/latest/docs/UG_OrderedSets.html` — MEDIUM. Corroborates the static/ordered requirement for `ord()`, linear-vs-circular lag endpoint handling ("out-of-range references produce zero"), and `$onOrder`/`$offOrder`.
- Repo files read: `.planning/PROJECT.md`, `model/PricingKernelMoments.gms`, `model/PricingKernel.gms`, `model/PriceImpactKernelFixture.gms`, `model/payoff/eta_pi_trader_zero_slippage.gms`, `Makefile`, `model/dynamic/InitState.gms`.

### Correction to the project record

`PROJECT.md` (Context, "Known debt inherited at split time") states that `PricingKernelMoments.gms` "is an invalid stub". Verified: it **compiles cleanly, rc=0**, under `action=c`. `Set TimeWindow` without a terminator is legally closed by end-of-file, and the space before `(` in `$macro mean_tick (…)` makes GAMS accept a zero-argument text macro. The file is semantically empty but syntactically valid — so `compile-gams` is currently green on it. That makes the defect *harder* to notice than the project record implies, and is an argument for prioritizing its replacement.

### Gaps / not verified

- **`$loadDC` compile-time domain-violation behavior** was not exercised against an off-grid GDX (only `execute_loadDC` was). Low risk — it is the compile-time analogue — but unconfirmed.
- **`gams-transfer` / `gdxpds` Python-side GDX writing** was not tested; the API producer is out of scope for v1, so the external write path is unverified.
- **Grid sizing** (`o1*o4096`, `w1*w256`) is a placeholder. No performance measurement was made of `winMap(winAll,tAll)` density at large cardinalities — the mapping set is O(|winAll|·|tAll|) in the worst case and should be measured before the grid is enlarged much further.
- The GAMS runs were made under a **demo license** (`GAMS Demo, for EULA and demo limitations`). All tests here are small enough to be unaffected, but a demo-size limit could mask behavior at production series lengths.

---
*Feature research for: GAMS 54.1 pluggable time-series ingestion + windowed moments*
*Researched: 2026-07-27*
