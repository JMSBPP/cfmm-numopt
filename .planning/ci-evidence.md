# GATE-06 — CI reachability evidence

`make ci-selftest` (`mk/gates.mk`) is the standing, re-running gate. This file records the
one-shot facts it cannot re-derive, and the ordering that makes the configuration safe.

## Pre-state, measured 2026-08-15 before any change

```
$ gh api repos/JMSBPP/cfmm-gams/environments/gams-gate --jq '{created_at, rules: (.protection_rules|length)}'
{"created_at":"2026-07-27T23:24:41Z","protection_rules":[],"rules":0}

$ gh api repos/JMSBPP/cfmm-gams/actions/runners --jq '.total_count'
0

$ gh run list --limit 5
completed  cancelled  chore: restructure split-out GAMS tree into a standalone repository  gams  main  push  30314047591  24h0m12s  2026-07-27T23:24:41Z
```

**The `gams-gate` environment already existed, and it was auto-created.** Its
`created_at` is identical to the timestamp of the only workflow run this repository has
ever had (`30314047591`, 2026-07-27T23:24:41Z) — GitHub materialises an environment the
first time a job references it. Nobody configured it. It had **zero** protection rules,
which means the `approve` job in `.github/workflows/gams.yml` would have been waved
through automatically, and **zero** runners, which is why that single run sat for
**24h0m12s** and was cancelled without the `gams` job ever starting.

So: finding the environment present is **not** the criterion being met. GATE-06's work is
*configuring* an environment that was already there.

```
$ make ci-selftest          # pre-state
gams-gate protection_rules: 0
ci-selftest FAIL: gams-gate has 0 protection rules. A PUBLIC repo with a
  self-hosted runner behind an inert gate is the fork-PR arbitrary-code
  execution scenario. Add a required reviewer BEFORE registering a runner.
make: *** [mk/gates.mk:81: ci-selftest] Error 1     # recipe rc=1, make rc=2
```

## The change: a required reviewer, added BEFORE any runner exists

```
$ gh api user --jq .id
127243770
$ gh api --method PUT repos/JMSBPP/cfmm-gams/environments/gams-gate --input - <<JSON
{"wait_timer":0,"reviewers":[{"type":"User","id":127243770}],"deployment_branch_policy":null}
JSON
```

Post-state:

```
$ gh api repos/JMSBPP/cfmm-gams/environments/gams-gate --jq '{rules:(.protection_rules|length), type:.protection_rules[0].type, reviewers:[.protection_rules[0].reviewers[].reviewer.login], prevent_self_review:.protection_rules[0].prevent_self_review, can_admins_bypass:.can_admins_bypass}'
{"can_admins_bypass":true,"prevent_self_review":false,"reviewers":["JMSBPP"],"rules":1,"type":"required_reviewers"}

$ make ci-selftest          # post-state
gams-gate protection_rules: 1
self-hosted runners: 0
ci-selftest FAIL: 0 runners registered -- the gams job can never start.
```

**That transition is the evidence that the rules were added first**: the same command
failed on the *rules* leg before and fails on the *runner* leg after. It has never once
reported OK.

### Why the ordering is load-bearing

`cfmm-gams` is a **public** repository. The `gams` job runs `runs-on: [self-hosted,
cfmm-build]` because GAMS 54.1 + CONOPT exist only on that machine. A fork PR against a
public repo with a self-hosted runner executes attacker-controlled code on that machine
unless something blocks *before checkout*. The `environment:` approval on the `approve`
job is that something, and with zero protection rules it approves instantly — i.e. it was
inert. Registering a runner first would have opened exactly that window for as long as it
took to add the reviewer.

### Two honest limits of this protection rule

- `prevent_self_review: false` — the single required reviewer is the repository owner,
  who is also the person pushing. A self-approval is possible. This bounds the gate to
  "a human deliberately clicks approve", not "a second pair of eyes".
- `can_admins_bypass: true` — an admin can bypass the environment gate. Both fields are
  defaults and neither is claimed to be more than it is.

Neither is checked by `make ci-selftest`, which probes only `protection_rules|length`
and `actions/runners.total_count`.

## Runner status

**Runners registered: 0.** Registering one is a `sudo` service installation on the machine
holding the GAMS licence, attached to a public repository, so it was **not** performed
autonomously. It is task 4 of plan 00-04 — a blocking human-action checkpoint.

Until it happens, `make ci-selftest` exits non-zero and the registry row
`nc-ci-selftest-positive` is RED. **That redness is the correct report, not a defect to be
worked around**: GATE-06 is not met until the `gams` job can actually run. The row must not
be deleted, re-expected, or commented out.

Run id: PENDING

> **UNVERIFIABLE-LEG (GATE-06).** "One workflow run reached the `gams` job and completed" is
> one-shot by nature. Its run id is recorded here when it happens; the two `gh api` probes in
> `make ci-selftest` are the standing, re-running gate. This leg is not restated as a repeatable
> check.

## What `make ci-selftest` actually asserts

| leg | probe | passes when |
|-----|-------|-------------|
| gate armed | `gh api repos/$(GH_REPO)/environments/gams-gate --jq '.protection_rules|length'` | ≥ 1 |
| runner present | `gh api repos/$(GH_REPO)/actions/runners --jq '.total_count'` | ≥ 1 |

A probe that answers with anything other than a count (a 404, an auth failure, an empty
body) is refused explicitly rather than compared numerically — measured:
`make ci-selftest GH_REPO=JMSBPP/this-repo-does-not-exist` prints `gh: Not Found (HTTP 404)`
and exits non-zero. It does not fall through to an OK.
