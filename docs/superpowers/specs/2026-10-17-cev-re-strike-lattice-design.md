# Design: CEV static RE strike lattice

## Context

GAMS layer for Maymin-style CEV/CPMM local tick vol ([`cfmm-vol-markets-spec/spec/models/sets/CEV.md`](../../../cfmm-vol-markets-spec/spec/models/sets/CEV.md)), used as a **static** substrate for scaled payoffs. No Wiener path in this slice.

Ticks are **strikes** (cross-section), not a simulated time path. The strike set is **endogenous**: rational-expectations image of flow depth/vol and a target vol band — not hand-picked labels like `/200,400,600/`.

## Locked decisions

| Decision | Choice |
|----------|--------|
| Lattice role | Cross-sectional strikes |
| Membership | RE-generated |
| Interior law | Tick-spacing fill between RE bounds |
| Vol band | One \(\bar\sigma\) plus std: \([\bar\sigma-\mathrm{std},\,\bar\sigma+\mathrm{std}]\) (absolute); require \(\bar\sigma-\mathrm{std}>0\) |
| Depth \(L_{1/2}\) | `VegaNotional` (`model/instruments/position.gms`) |
| Coordinates | `LN_GRID_RESOLUTION`, `toTickSpace`, `normTickVal`, `TickSpacing` (`model/infra/TickLattice.draft1.gms`) |
| Out of scope | Path simulation; \(\mu_F\) in set membership; payoff from RV vs striped vol |

## Math

\[
\alpha=\ln\frac{\sigma_F}{L_{1/2}\,\beta},\quad
\beta=\ln(1.0001),\quad
i(\sigma)=\frac{\alpha-\ln\sigma}{\beta}
\]

Local vol (price-free): \(\sigma(i)=e^{\alpha-\beta i}\).

Higher vol ↔ lower tick:

- \(i_{\mathrm{lo}}=i(\bar\sigma+\mathrm{std})\), \(i_{\mathrm{hi}}=i(\bar\sigma-\mathrm{std})\)
- Snap with `normTickVal(..., TickSpacing)`, clip to `[MIN_TICK, MAX_TICK]`
- `Ticks` = every spaced tick from \(i_{\mathrm{lo}}\) to \(i_{\mathrm{hi}}\)

## Implementation map

| Symbol | Role |
|--------|------|
| `cevAlpha(sigmaF, L)` | \(\alpha\) |
| `cevTickFromVol(sigmaF, L, sigma)` | \(i(\sigma)\) via `toTickSpace` |
| `cevLocalVol(sigmaF, L, tick)` | \(e^{\alpha-\beta\,\mathrm{tick}}\) |
| `cevLocalDrift(sigmaF, muF, L, tick)` | Markdown \(\mu(i)\) with \(\sqrt{p}=1.0001^{\mathrm{tick}}\) |
| Factory block in `CEV.draft1.gms` | Band → bounds → dynamic `Ticks` + `tickVal` |

## Files

- Spec: this document
- Model: `model/CEV.draft1.gms`
- Includes: `model/infra/TickLattice.draft1.gms`, `model/instruments/position.gms`
