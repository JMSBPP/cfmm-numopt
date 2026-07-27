# GAMS Tooling for AI Agents & Programmatic Integration — Research Report

*Deep-research synthesis · 2026-06-27 · 19 primary/official sources fetched, 91 claims extracted, 25 adversarially verified (25 confirmed, 0 killed), 12 findings after merge.*

> Scope: tooling to build a bridge between an **off-chain GAMS algebraic solver** and an **on-chain pipeline** (this repo's CFMM payoff-replication connection layer — see `.planning/PROJECT.md`).

---

## Executive summary

For an off-chain GAMS → on-chain bridge, the practical agent-callable surface is **Python**, supported as a first-party GAMS feature. GAMS ships four official API modules — **Control, Transfer, Core, Magic** — and Python is the only language with full coverage of all four, making it the most complete language for a programmatic bridge. Two pip-installable packages cover the workflow: **GAMSPy** (`pip install gamspy`) lets an agent author algebraic optimization models natively in Python and returns solve summaries as Pandas DataFrames, while **gamsapi** (the Control API `gams` module plus GAMS Transfer) runs existing `.gms` models, exchanges data, and reads/writes GDX files. For headless/CI, GAMS is invoked as `gams myfile key=value`, supports compile/execute stage separation via the `action` parameter, writes results to GDX via the `gdx=` parameter, and signals success/failure through documented numeric exit codes (`0`=success). The recommended bridge I/O format is **GDX**, consumed via GAMS Transfer (stored as Pandas DataFrames) and re-exported to CSV/JSON/Parquet for downstream on-chain tooling.

**Headline answer on AI tooling:** there is **no verified evidence of an official GAMS "Copilot"/AI assistant or an official GAMS MCP server.** "Agent-callable" here means ordinary importable Python packages any code-executing agent can drive — not a dedicated LLM product. If we want an MCP surface, we wrap GAMSPy/gamsapi ourselves.

---

## Findings

### Dimension 1 — AI-agent / LLM tooling

**[F1] GAMSPy is the primary agent-callable Python modeling interface.** *(confidence: high · vote 3-0)*
A Python-based algebraic modeling package combining the GAMS execution system with Python, exposing all GAMS symbols (`Set`, `Alias`, `Parameter`, `Variable`, `Equation`) to compose models natively, covering build / data-prep / solve / postprocess in one workflow, delegating expensive assignment/solve to GAMS's compiled low-level code. Installable via `pip install gamspy` (latest 1.24.2 on PyPI — live-verified).
Sources: https://www.gams.com/products/gamspy/ · https://github.com/GAMS-dev/gamspy · https://gamspy.readthedocs.io/en/latest/user/whatisgamspy.html · https://github.com/GAMS-dev/gamspy-examples · https://pypi.org/project/gamspy/

**[F2] No official GAMS Copilot / AI assistant / MCP server found.** *(confidence: medium · absence-of-evidence across the verified set)*
All 25 verified claims describe programmatic Python APIs; none assert an LLM assistant or MCP server. The "agent-callable" framing is accurate but means *ordinary importable Python packages a code-executing agent can call* (GAMSPy, gamsapi Control/Transfer, embedded code, Magic), not a dedicated LLM product. This is a documented gap, not a confirmed negative.
Sources: https://www.gams.com/latest/docs/API_MAIN.html · https://www.gams.com/products/gamspy/

### Dimension 2 — Compilation & execution model (headless / CI)

**[F3] GAMS exposes four first-party API modules; Python has the fullest coverage.** *(confidence: high · vote 3-0)*
Control (object-oriented automation), Transfer (data read/write), Core (expert-level GDX/GMO access), Magic (beta Jupyter integration). The official API support matrix shows Python checked across all four; Magic is Python-only. Matlab is next-closest (Control/Transfer/Core) but lacks Magic.
Source: https://www.gams.com/latest/docs/API_MAIN.html

**[F4] The official Python Control API (`gams` module) runs models and exchanges data.** *(confidence: high · vote 3-0)*
Provides `GamsWorkspace`, `GamsJob`, `GamsDatabase`. A `.gms` model executes via `ws = GamsWorkspace(); job = ws.add_job_from_file('model.gms'); job.run()`, where `run()` invokes the GAMS compiler + execution system and exposes results through `job.out_db`. **Naming gotcha:** the PyPI distribution is `gamsapi`, but the importable module is still `gams`.
Source: https://www.gams.com/latest/docs/API_PY_CONTROL.html

**[F5] Headless CLI invocation: `gams myfile key1=value1 key2=value2`.** *(confidence: high · vote 3-0)*
Searches for `myfile`/`myfile.gms`, compiles + executes, and writes a `myfile.lst` listing by default.
Source: https://www.gams.com/latest/docs/UG_GamsCall.html

**[F6] The `action` parameter separates compile and execute stages.** *(confidence: high · vote 3-0)*
`C` = compile only, `E` = execute only, `CE` = both (default); also accepts `R`, `GT`. Enables stage separation in a headless pipeline (e.g. compile-check in CI before a full solve).
Source: https://www.gams.com/latest/docs/UG_GamsCall.html

**[F7] Process exit codes signal success/failure type — CI-suitable.** *(confidence: high · vote 3-0)*
`0` = normal return, `2` = compilation error, `3` = execution error, `5` = file error, `7` = licensing error, `8` = GAMS system error, `10` = out of memory. **Caveat:** exit `0` means clean *process* completion, **not** optimality/feasibility — CI must also inspect solve/model status separately.
Source: https://www.gams.com/latest/docs/UG_GAMSReturnCodes.html

**[F8] Embedded Code Facility shares GAMS symbols in-memory with Python.** *(confidence: high · vote 3-0)*
Runs external code (Python, Connect, GAMS) during compile/execution with symbols shared in-memory (no disk round-trip). The `ECGamsDatabase` class is auto-instantiated as identifier `gams` on entering an embedded section; code reads via `gams.get(...)` and writes via `gams.set(...)` — bidirectional in-memory exchange.
Source: https://www.gams.com/latest/docs/UG_EmbeddedCode.html

**[F9] GAMSPy `Model.solve()` returns a Pandas DataFrame; three backends.** *(confidence: high · vote 3-0)*
Summary columns: solver name, solver status, objective value, solve time (also Model Status, #Equations/#Variables, Model Type). Return type `pd.DataFrame | None` — **handle `None`.** Backends: local GAMS install (default), GAMS Engine, NEOS Server, selectable via the `backend` parameter.
Source: https://gamspy.readthedocs.io/en/latest/user/basics/model.html

### Dimension 3 — Output formats for programmatic consumption

**[F10] Recommended I/O format is GDX, read/written from Python.** *(confidence: high · vote 3-0)*
Control API: `GamsDatabase.export('file.gdx')` and `GamsWorkspace.add_database_from_gdx('file.gdx')` for structured result exchange.
Source: https://www.gams.com/latest/docs/API_PY_CONTROL.html

**[F11] GAMS Transfer reads/writes GDX and stores everything as Pandas DataFrames.** *(confidence: high · vote 3-0)*
Ships with the GAMS Python API (`gamsapi`, via the `[transfer]` extra → `pip install gamsapi[transfer]`, introduced in GAMS 37); imported as `import gams.transfer as gt`. Reads all symbols with one line — `m = gt.Container('trnsport.gdx')` — and writes back via `m.write('out.gdx')`. All symbol data is stored internally as Pandas DataFrames (`m.data[sym].records`), enabling indexing/reshaping/merging and **export to CSV/JSON/Parquet via pandas.** This is the load-bearing serialization path for the bridge.
Sources: https://www.gams.com/latest/docs/API_PY_GAMSTRANSFER.html · https://pypi.org/project/gamsapi/

**[F12] GAMS writes solver results to GDX via the `gdx` CLI parameter.** *(confidence: high · vote 3-0)*
`gdx=` (output file name), `gdxCompress` (compression), `gdxConvert` (GDX version, for backward compatibility).
Source: https://www.gams.com/latest/docs/UG_GamsCall.html

---

## Bridge implications (off-chain GAMS → on-chain Plank)

Concrete recommendations for this repo's connection layer (`payoff → GAMS solves (xi*, iota*) → encoded → Plank simulates`):

1. **Agent-callable surface = Python, not a vendor MCP.** Drive GAMS from `gamsapi` (Control API `gams` module) to run the existing `.gms` sources (`primitives.gms`, `PricingKernel.gms`, `LiquidityKernel.gms`, `TradingRegion.gms`, `PayoffModule.gms`, `dynamic/InitState.gms`). Use **GAMSPy** only if/when we want to author models natively in Python; for *running existing `.gms`*, Control API + Transfer is the lighter path. If an MCP surface is desired later, wrap these ourselves — there is no off-the-shelf GAMS MCP server.
2. **I/O contract = GDX → GAMS Transfer → JSON/CSV.** Have GAMS emit results to GDX (`gdx=out.gdx` on the CLI, or `db.export()` from Python), load with `gams.transfer.Container`, then serialize the optimal parameters (`xi*`, `iota*`, LDF `alpha`, ticks) out of the resulting DataFrames to JSON for the encoder that feeds Plank's `IMarketDynamics.initVolTermStructure()` (selector `0xd9c112ef`).
3. **CI/headless invocation.** Call `gams model.gms gdx=out.gdx lo=2` (or via `GamsJob.run()`); gate on exit code (`0`=ok, `2`=compile error, `3`=exec error) **and** separately assert solve/model status = optimal before trusting parameters — exit `0` ≠ feasible.
4. **Compile-only fast check.** Use `action=C` in CI to catch `.gms` parse/type errors cheaply before running full solves — useful while the GAMS sources are still being vendored into `model/` and hardened.
5. **Fixed-point precision is the open risk.** GAMS produces IEEE double-precision floats; the bridge must define rounding/scaling from `double → GDX → pandas → JSON → on-chain u256 fixed-point` (WAD `1e18`, Q64.96). This must be specified **before** type implementation (per the project's "fixed-point rigor" constraint). See open question 3.
6. **Embedded Code Facility is an option for tight coupling** if we ever want Python pre/post-processing inside the GAMS run itself (in-memory symbol sharing, no disk round-trip) — but for the open-loop milestone, the simpler file/GDX boundary is cleaner and more testable.

---

## Caveats

- **The subagent's own write to `REPORT.md` was blocked by the harness** ("subagents must return findings as text"); this file was assembled by the orchestrator from the verified synthesis output.
- **No verified evidence** of an official GAMS Copilot/AI assistant or official GAMS MCP server — absence of evidence, not confirmed absence.
- **Licensing:** GAMSPy ships a free demo license with size limits (full free for academics; cannot reuse an existing GAMS license). Production scale may need a paid/sized license.
- **Naming gotchas:** PyPI distributions are `gamsapi` and `gamspy`, but the importable Control-API module is still `gams`; GAMS Transfer needs the `[transfer]` extra.
- **Exit code `0` ≠ optimality/feasibility** — always inspect solve/model status too.
- `Model.solve()` returns `pd.DataFrame | None` — handle `None`.
- **Time-sensitivity:** versions move (GAMSPy ~1.24.2; Magic is beta); cited docs use the `/latest/` path, so deep details may shift across releases.
- All cited sources are primary/official (gams.com docs, GAMSPy ReadTheDocs, GAMS-dev GitHub, PyPI), with two blog-quality items used only for context.

---

## Open questions

1. Does GAMS offer an official LLM/AI assistant ("Copilot") or an official/community MCP server for model authoring or invocation? Not established by the verified claims.
2. What are the exact GAMSPy/GAMS license size limits (variables/constraints) across free demo vs academic vs commercial tiers, and which tier does the off-chain bridge need at production scale?
3. What is the precision/serialization contract when moving GAMS double-precision results through GDX → pandas → JSON → on-chain fixed-point integers (rounding, scaling, decimals)?
4. Is **GAMS Connect** (YAML-driven data-exchange agent) preferable to GAMS Transfer for batch CSV/Parquet I/O in the bridge, and what are its programmatic invocation options? Connect is named as a supported embedded-code language but was not separately characterized here.

---

## Sources

| # | URL | Quality | Angle |
|---|-----|---------|-------|
| 1 | https://www.gams.com/products/gamspy/ | primary | AI-agent / LLM tooling |
| 2 | https://www.gams.com/blog/2025/09/gamspy-at-one-advancing-optimization-in-python/ | blog | AI-agent / LLM tooling |
| 3 | https://github.com/GAMS-dev/gamspy | primary | AI-agent / LLM tooling |
| 4 | https://gamspy.readthedocs.io/en/latest/user/whatisgamspy.html | primary | AI-agent / LLM tooling |
| 5 | https://github.com/GAMS-dev/gamspy-examples | primary | AI-agent / LLM tooling |
| 6 | https://www.databricks.com/blog/what-is-model-context-protocol | blog | AI-agent / LLM tooling (MCP background) |
| 7 | https://www.gams.com/latest/docs/API_MAIN.html | primary | Python APIs as agent interfaces |
| 8 | https://www.gams.com/latest/docs/API_PY_CONTROL.html | primary | Python APIs as agent interfaces |
| 9 | https://www.gams.com/latest/docs/API_PY_GAMSTRANSFER.html | primary | Python APIs as agent interfaces |
| 10 | https://www.gams.com/latest/docs/UG_EmbeddedCode.html | primary | Python APIs as agent interfaces |
| 11 | https://gamspy.readthedocs.io/en/latest/user/basics/model.html | primary | Python APIs as agent interfaces |
| 12 | https://www.gams.com/latest/docs/UG_GamsCall.html | primary | Compilation & headless execution |
| 13 | https://www.gams.com/latest/docs/UG_GAMSReturnCodes.html | primary | Compilation & headless execution |
| 14 | https://www.gams.com/latest/docs/UG_spawning_gams.html | primary | Compilation & headless execution |
| 15 | https://support.gams.com/gams:use_gams_return_codes_in_a_batch_file | primary | Compilation & headless execution |
| 16 | https://www.gams.com/latest/docs/UG_GDX.html | primary | Programmatic output & serialization |
| 17 | https://www.gams.com/latest/docs/T_GDXDUMP.html | primary | Programmatic output & serialization |
| 18 | https://www.gams.com/latest/docs/UG_GAMSCONNECT.html | primary | Programmatic output & serialization |
| 19 | https://gamspy.readthedocs.io/en/latest/ | primary | Authoritative docs & repos |
| + | https://pypi.org/project/gamsapi/ , https://pypi.org/project/gamspy/ | primary | live package checks |
