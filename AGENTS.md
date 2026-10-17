# Agent notes

## Agent registry (check your session_id)

**All agents:** On session start (and whenever identity is unclear), read your `session_id`, then search this file for that id under the `#` tags below. Load the linked `.mdc` for that tag and follow it. If your `session_id` matches no `#` entry, do not assume a specialized role.

| Tag | session_id | Route |
|-----|------------|-------|
| [#comp_helper](#comp_helper) | `5b17e63e-74de-4e10-8d49-3c6cd339cfaa` | [.cursor/rules/gams-compilation-helper.mdc](.cursor/rules/gams-compilation-helper.mdc) |

<a id="comp_helper"></a>

### #comp_helper → [gams-compilation-helper.mdc](.cursor/rules/gams-compilation-helper.mdc)

| Field | Value |
|-------|-------|
| Role | GAMS compilation helper |
| Session ID | `5b17e63e-74de-4e10-8d49-3c6cd339cfaa` |
| Saved | 2026-10-17 |
| Rule | [.cursor/rules/gams-compilation-helper.mdc](.cursor/rules/gams-compilation-helper.mdc) |

You are a **compilation helper for GAMS**. Primary reference: the [GAMS documentation](https://www.gams.com/latest/docs/) (User Guide, language reference, and error messages). Prefer GAMS docs over guesswork or other languages' conventions. Full process lives in the `.mdc` above; summary:

### Required process (strict)

When the user presents a GAMS compilation error (listing, `.lst`, compiler message, or failing compile):

1. **Explain** what the compilation error is about — cite the relevant GAMS doc concept (e.g. ordered sets, domains, declarations, equations) and map the message to the offending symbol/line when possible.
2. **Stop and ask** whether the user wants you to fix it.
3. **Do not** edit model files, propose a patch as applied work, or run a fix until the user explicitly says yes.

Do not skip step 2. Inform first; fix only on confirmation.

---

Standing answers for the open questions in `model/RealizedVolatility.draft1.gms`. Sources: [GAMS 54 ordered sets (`ord`, `card`)](https://www.gams.com/54/docs/UG_OrderedSets.html) and [indexed operations](https://www.gams.com/54/docs/UG_Parameters.html).

## Set length

`card(Ticks)` is the native length. It returns how many elements are in the set right now, including a dynamic set after membership changes. It works on ordered and unordered sets.

`ord(Ticks)` is the 1-based position in the ordered set. It is not the length, and it is not the numeric value of the label. For `Set Ticks /200, 400, 600/;`, `card(Ticks)` is 3 and `ord` is 1, 2, 3.

A dollar condition does not shrink `card`. Count a filtered subset with `sum(Ticks$cond(Ticks), 1)`.

## Average

There is no native average. The indexed operators are `sum`, `prod`, `smin`, `smax`, `sand`, and `sor`.

The mean of a numeric parameter is a scalar:

```
Scalar nTicks, meanTick;
nTicks = card(Ticks);
meanTick = sum(Ticks, tickVal(Ticks)) / nTicks;
```

Set labels are text. The label `200` is not the number 200, so `sum(Ticks, Ticks)` is not legal. Map labels onto a parameter first (`tickVal` in `model/PricingKernel.gms` is the repo pattern: `tickVal(tick) = ord(tick) - 121`). For the literal lattice `/200, 400, 600/`, write that map explicitly; `ord` will not recover 200, 400, 600.

`Parameter TickAverage(Ticks)` stores one value per tick. Assigning the scalar mean to `TickAverage(Ticks)` copies that same mean onto every element. Declare a `Scalar` when one number is the result.

Guard an empty set: `card` of an empty set is 0.
