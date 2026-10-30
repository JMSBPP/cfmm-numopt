# A1 — No-fee variance claim (locked)

**Status:** locked 2026-10-19  
**Pipeline name:** `NoFeeVarianceClaim`

## Claim

\[
	\pi^{\sigma}_{\text{no fee}} \;=\; G(\iota)\;\sigma_{\texttt{RV}}^{2}
\]

- \(G(\iota)\) — flat dollar-gamma level of the geometric ladder (Theorems 51–52 in `cfmm-vol-markets-spec` / `MAIN_SPEC`).
- \(\sigma_{\texttt{RV}}\) — realized volatility from `TickPathMoments` on a tick path.
- Scale is \(G\), not raw \(\bar L\). At \(\iota = 1\), \(G = \bar L/2\).

## CFMM reading

- On chain the mint primitive is CFMM liquidity \(L(i)\) (uint128 per range).
- \(G\) is bookkeeping / risk level implied by the ladder; Theorem 52 gives \(L(\Gamma_i) = 2\,G(\iota)\,\Gamma_i^{1/3}\).
- A1 does not mint; it settles the closed-form no-fee claim once \(G(\iota)\) and \(\sigma_{\texttt{RV}}\) exist.

## Pipeline

\[
	\big(G(\iota),\;\sigma_{\texttt{RV}}\big)
	\;\overbrace{\leadsto}^{\texttt{NoFeeVarianceClaim}}\;
	\pi^{\sigma}_{\text{no fee}}
\]

Producers:
- \(G(\iota)\): `LiquidityKernel` / `StripLengthFromGammaBudget` (`ExposureGlobalGamma` after \(\iota\) is solved).
- \(\sigma_{\texttt{RV}}\): `TickPathMoments`.

## Out of scope

- **A2** — path sum \(\sum_t \tfrac12 L(i_t)\,(\Delta\log p_t)^{2}\)
- **A3** — option on variance \(\Delta Q_v\,(\sigma_{\texttt{RV}}^{2}-\sigma_K^{2})^{+}\)
- Fees / LVR (`PathAccrual`)

## Later check

When the ladder is flat dollar gamma, A2 should match A1.
