# GAMS Vendoring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Vendor the external GAMS optimization sources into the repository under `model/` so the project is self-contained and a future GAMS CI workflow has an in-tree build target.

**Architecture:** Byte-for-byte copy of 6 GAMS **source** files from the untracked sibling dir `../experiments/gams/` into `model/` (preserving the `dynamic/` subdir), excluding the misnamed listing file `PriceKernel.gms` and all generated `.lst` files. Add a tracked `model/BUILD.md` manifest (entrypoints, fragments, pinned GAMS version, working-dir rule) and `.gitignore` rules (ignore GAMS artifacts under `model/`; un-ignore `docs/superpowers/` so the spec/plan are committable). No CI is built; the Foundry workflow is untouched.

**Tech Stack:** GAMS 54.1.0 (linux x86_64) source files; git; shell file ops. No build tooling runs in this plan.

**Spec:** `docs/superpowers/specs/2026-06-27-gams-vendoring-design.md` (approved 2026-06-27, post two-step review).

## Global Constraints

- Vendor target dir is **`model/`** (NOT `gams/`) — roadmap GAMS-01.
- `PriceKernel.gms` is **excluded entirely** (it is a `.lst` listing renamed `.gms`, an orphan, and the only carrier of an external absolute path).
- No `.lst` file is vendored.
- `.github/workflows/test.yml` must be **left untouched and unstaged**. `.github/` is currently **untracked** — never `git add` it; verify with `--untracked-files=no`.
- `../experiments/gams` is **not deleted** (untracked sibling; copy only).
- **Branch base & integration target is `master`.** No `main` branch exists locally or on origin (origin currently has **no** branches pushed). Do NOT target `main` on finish. First pushes (only if/when the user asks to push): `git push -u origin master` then `git push -u origin feat/gams-vendoring`.
- **The working tree is intentionally dirty** (modified `lib/*` submodules, untracked `.planning/`, `src/`, `test/`, `spec/`, `Makefile`, `README.md`, …) and is carried onto the feature branch. For the duration of this plan, **never run `git add -A`, `git add .`, or `git commit -a`** — only the explicit paths listed per task.
- Pinned toolchain to record: GAMS `54.1.0`, `linux x86_64`.

---

### Task 0: Create the working branch

**Files:** none (git branch only)

- [ ] **Step 1: Confirm base branch and that no target paths are already staged**

Run: `git branch --show-current && git status --short -- model .gitignore docs/superpowers`
Expected: prints `master`; then `?? .gitignore` and (if present) `?? docs/...` as untracked — but **nothing staged** (no lines beginning with `A `/`M ` in the left column). `model/` does not exist yet.

- [ ] **Step 2: Create and switch to a feature branch**

Run: `git switch -c feat/gams-vendoring`
Expected: `Switched to a new branch 'feat/gams-vendoring'`. (The dirty working tree rides along intentionally; do not stage it.)

---

### Task 1: Make planning artifacts trackable + ignore GAMS artifacts, then freeze-commit the spec & plan

This runs **first** so the spec and plan are committed **verbatim** (all checkboxes unchecked) before any execution edits them — avoiding a half-ticked snapshot in history.

**Files:**
- Modify: `.gitignore` (currently untracked — this commit adds it new)
- Commit (verbatim): `docs/superpowers/specs/2026-06-27-gams-vendoring-design.md`, `docs/superpowers/plans/2026-06-27-gams-vendoring.md`

**Interfaces:**
- Produces: `.gitignore` rules that un-ignore `docs/superpowers/` and ignore GAMS artifacts under `model/`. Consumed by every later task (their files live under `model/`, which the ignore rules scope).

- [ ] **Step 1: Replace the `# Docs` block to un-ignore the spec/plan subtree**

Find this exact block in `.gitignore`:
```gitignore
# Docs
docs/
```
Replace it with:
```gitignore
# Docs (ignore everything except the superpowers spec/plan subtree)
docs/*
!docs/superpowers/
```

- [ ] **Step 2: Append the GAMS artifacts block (all rules anchored under `model/`)**

```gitignore

# GAMS generated artifacts under model/ (listings, save/work files, scratch)
model/**/*.lst
model/**/*.g00
model/**/*.lxi
model/**/*.gdx
model/225*/
```

- [ ] **Step 3: Verify the spec/plan are now committable and GAMS artifacts are ignored**

```bash
git check-ignore docs/superpowers/specs/2026-06-27-gams-vendoring-design.md ; echo "spec exit=$?"
git check-ignore docs/superpowers/plans/2026-06-27-gams-vendoring.md ; echo "plan exit=$?"
git check-ignore model/PricingKernel.lst ; echo "lst exit=$?"
git check-ignore model/225a/ ; echo "scratch exit=$?"
git check-ignore docs/other-thing.md ; echo "other exit=$?"
```
Expected: spec and plan lines print **nothing** with `spec exit=1` / `plan exit=1` (NOT ignored); `model/PricingKernel.lst` prints with `lst exit=0` (ignored); `model/225a/` prints with `scratch exit=0`; `docs/other-thing.md` prints with `other exit=0` (negation correctly scoped — only `docs/superpowers/` is exempt).

- [ ] **Step 4: Commit the ignore rules + the frozen spec & plan**

```bash
git add .gitignore docs/superpowers/specs/2026-06-27-gams-vendoring-design.md \
        docs/superpowers/plans/2026-06-27-gams-vendoring.md
git commit -m "chore(gams): ignore GAMS artifacts; track superpowers specs/plans

Anchor GAMS scratch/listing ignores under model/; un-ignore docs/superpowers/
so the approved vendoring spec and plan are version-controlled (frozen verbatim
before execution).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```
Expected: commit succeeds with exactly 3 files (`.gitignore`, the spec, the plan).

---

### Task 2: Vendor the 6 GAMS source files into `model/`

**Files:**
- Create: `model/primitives.gms`, `model/PricingKernel.gms`, `model/LiquidityKernel.gms`, `model/TradingRegion.gms`, `model/PayoffModule.gms`, `model/dynamic/InitState.gms`
- Source (read-only, untracked sibling): `../experiments/gams/`

**Interfaces:**
- Produces: a flat `model/` GAMS source tree where every `$include` target (`primitives.gms`, `PricingKernel.gms`) is a sibling. Consumed by Task 3 (`BUILD.md` documents this layout) and the future CI workflow.

- [ ] **Step 1: Copy the 6 source files (exclude PriceKernel.gms and all .lst)**

```bash
mkdir -p model/dynamic
cp ../experiments/gams/primitives.gms      model/primitives.gms
cp ../experiments/gams/PricingKernel.gms   model/PricingKernel.gms
cp ../experiments/gams/LiquidityKernel.gms model/LiquidityKernel.gms
cp ../experiments/gams/TradingRegion.gms   model/TradingRegion.gms
cp ../experiments/gams/PayoffModule.gms    model/PayoffModule.gms
cp ../experiments/gams/dynamic/InitState.gms model/dynamic/InitState.gms
```

- [ ] **Step 2: Verify the exact file set (5 top-level + InitState, no PriceKernel, no .lst)**

```bash
ls model/*.gms | wc -l                          # expect: 5
test -f model/dynamic/InitState.gms && echo "InitState OK"
test ! -e model/PriceKernel.gms && echo "PriceKernel excluded OK"
find model -name '*.lst' | wc -l                # expect: 0
```
Expected: `5`, `InitState OK`, `PriceKernel excluded OK`, `0`.

- [ ] **Step 3: Verify no external-path references survive (hardened grep, spec criterion #3)**

Run: `grep -rIn 'experiments/gams' model/ ; echo "exit=$?"`
Expected: no matching lines, and `exit=1` (grep found nothing).

- [ ] **Step 4: Verify every `$include` target exists as a vendored sibling**

```bash
for t in $(grep -rhoE '\$include[[:space:]]+[^[:space:]]+\.gms' model | awk '{print $2}' | sort -u); do
  test -f "model/$t" && echo "resolves: $t" || echo "MISSING: $t"
done
```
Expected: `resolves: PricingKernel.gms` and `resolves: primitives.gms` only; no `MISSING:` lines.

- [ ] **Step 5: Verify byte-for-byte fidelity of each copied file**

```bash
for f in primitives.gms PricingKernel.gms LiquidityKernel.gms TradingRegion.gms PayoffModule.gms; do
  cmp ../experiments/gams/$f model/$f && echo "identical: $f"
done
cmp ../experiments/gams/dynamic/InitState.gms model/dynamic/InitState.gms && echo "identical: dynamic/InitState.gms"
```
Expected: six `identical:` lines, no `differ` output.

- [ ] **Step 6: Stage and commit the vendored sources only**

```bash
git add model/primitives.gms model/PricingKernel.gms model/LiquidityKernel.gms \
        model/TradingRegion.gms model/PayoffModule.gms model/dynamic/InitState.gms
git commit -m "feat(gams): vendor GAMS sources into model/ (GAMS-01)

Copy 6 GAMS source files from ../experiments/gams into model/, excluding
the misnamed listing file PriceKernel.gms and all generated .lst files.
Makes the GAMS track self-contained in-repo.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```
Expected: commit succeeds listing 6 new files under `model/`.

---

### Task 3: Add the `model/BUILD.md` build manifest

**Files:**
- Create: `model/BUILD.md`

**Interfaces:**
- Consumes: the `model/` layout produced by Task 2.
- Produces: the authoritative entrypoint/fragment/version record the future GAMS CI workflow reads instead of reverse-engineering the tree.

- [ ] **Step 1: Write `model/BUILD.md` with the exact content below**

```markdown
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
```

- [ ] **Step 2: Verify the manifest exists and names both entrypoints**

```bash
test -f model/BUILD.md && echo "BUILD.md OK"
grep -c 'PricingKernel.gms' model/BUILD.md     # expect: >= 2
grep -q '54.1.0' model/BUILD.md && echo "version pinned OK"
```
Expected: `BUILD.md OK`, a count `>= 2`, `version pinned OK`.

- [ ] **Step 3: Commit the manifest**

```bash
git add model/BUILD.md
git commit -m "docs(gams): add model/BUILD.md build manifest

Record compile entrypoints, fragments to skip, pinned GAMS 54.1.0, the
working-directory rule, and scratch-ignore policy so the future GAMS CI
workflow needs no reverse-engineering.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```
Expected: commit succeeds with `model/BUILD.md`.

---

### Task 4: Final verification against spec success criteria

**Files:** none (verification only)

- [ ] **Step 1: Run the full success-criteria sweep**

```bash
echo "C1 file count:"; ls model/*.gms | wc -l; test -f model/dynamic/InitState.gms && echo "InitState present"; test ! -e model/PriceKernel.gms && echo "PriceKernel absent"
echo "C2 no tracked lst:"; git ls-files 'model/*.lst' | wc -l
echo "C3 external path (source files only):"; grep -rIn 'experiments/gams' model/ --include='*.gms'; echo "grep exit=$?"  # exit=1 clean; model/BUILD.md provenance note is an accepted non-.gms reference
echo "C5 workflow untouched (untracked-aware):"; git status --short --untracked-files=no -- .github/
echo "C6 BUILD.md tracked:"; git ls-files model/BUILD.md
echo "C7 spec committable:"; git check-ignore docs/superpowers/specs/2026-06-27-gams-vendoring-design.md; echo "exit=$?"
```
Expected: `5` + `InitState present` + `PriceKernel absent`; `0`; no grep matches with `grep exit=1`; **no output** for C5 (no tracked `.github/` change — `--untracked-files=no` suppresses the benign `?? .github/`); `model/BUILD.md` printed; spec check-ignore prints nothing with `exit=1`.

- [ ] **Step 2: Confirm the branch history is the three scoped commits**

Run: `git log --oneline feat/gams-vendoring -3`
Expected, newest first: `docs(gams): add model/BUILD.md...`, `feat(gams): vendor GAMS sources...`, `chore(gams): ignore GAMS artifacts; track superpowers specs/plans`.
