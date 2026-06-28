# ARCHITECTURE




# QUESTION

Recall the original question (`eta.md`): the η = 1/2 trader payoff
\(\pi_{1/2}^{\text{trader}} = (P_{1/2}(i)\,\Delta^I - \Delta^O)^2\) is the
Bregman / squared-slippage **distance**, claimed to be "long realized
variance". The chain we wanted to close:

\[
	\begin{aligned}
		\pi_{1/2}^{\text{trader}}
		\, \overset{?}{\sim} \, \sigma_{\text{realized}}
		\, \overset{\text{proven}}{\longleftrightarrow} \, \sigma_{\text{xs}}
		\, \overset{\text{proven}}{\longleftrightarrow} \, \Delta_i \text{ control}
	\end{aligned}
\]

The first link — does \(\pi_{1/2}^{\text{trader}}\) actually exhibit a
variance-swap signature? — was the missing piece. Concretely: is the
leading-order behavior in the trade size \(\Delta^I\) **quadratic**
(variance-like), with coefficient determined by the price impact?


### [Proven — `lean/exp/eta.lean` :: `pi_trader_half_small_trade_quadratic`](https://aristotle.harmonic.fun/projects/88d393e7-ec4e-438f-a5fd-9f34aab1c2e5)


\[
	\begin{aligned}
		\lim_{\Delta^I \to 0^{+}} \, \frac{\pi_{1/2}^{\text{trader}}(\Delta^I)}{(\Delta^I)^2}
			\, &= \, P^2 \cdot (P - 1)^2
	\end{aligned}
\]

with \(P = P_{1/2}(i) = \lambda^{\, i \, \Delta_i}\). Formalized as a
`Filter.Tendsto` on \(\mathcal{N}_{>}(0)\) (right-neighborhood of zero).

Proof skeleton (Aristotle): using the already-proven `slippage_residual`,
\(\pi/(\Delta^I)^2 = g(\Delta^I)^2\) where
\(g(\Delta^I) = P\,(\bar L + P(\Delta^I - \bar L))/(\bar L + \Delta^I\,P)\).
The function \(g\) is continuous at \(0\) with value \(P\,(1 - P)\);
squaring and using `Filter.Tendsto.congr'` on the eventual equality over
`Set.Ioi 0` yields the limit \((P\,(1-P))^2 = P^2\,(P-1)^2\).

> **Aristotle's strengthening.** I requested hypotheses
> \(\lambda > 1\), \(i > 0\), \(\Delta_i > 0\), \(\bar L > 0\). Aristotle
> dropped \(i > 0\), \(\Delta_i > 0\) and weakened \(\lambda > 1\) to
> \(\lambda > 0\) — the asymptotic is a **structural** property of the
> squared-residual form and holds at any positive base, any tick (sign
> or zero), and any spacing. The price-impact factor \(P - 1\) may then
> be negative, but \((P-1)^2\) is non-negative either way — quadratic
> variance signature is preserved.

**Chain closed.** Combined with the previously-proven theorems:

| Link | Theorem | What it proves |
|---|---|---|
| π ↔ realized variance | `pi_trader_half_small_trade_quadratic` (this) | leading-order π ∝ (Δ^I)² with squared-impact coefficient |
| σ_realized ↔ σ_xs | `sigma_xs_eq_sharp_mul_sigma_realized` | corrected closed-form identity |
| σ_xs ↔ Δᵢ | (algebraic; σ_xs is polynomial in Δᵢ) | direct |
| Δᵢ ↔ π | `pi_trader_half_strictly_increasing_in_Δi` | π strictly monotonic in Δᵢ (regime L̄ ≤ Δ^I) |

So tick spacing controls both σ-quantities and (perturbatively) the
trader's long-realized-variance exposure π.

**Reproduce** (~20 min on Aristotle, continuation of the same project):

```bash
# set ARISTOTLE_API_KEY in your shell first (do NOT paste inline)
cd lean4-spec
aristotle continue 88d393e7-ec4e-438f-a5fd-9f34aab1c2e5 \
  'New sorry in exp/eta.lean: theorem pi_trader_half_small_trade_quadratic \
   in CFMM.Eta. Use slippage_residual to rewrite pi/(Δ^I)² = g(Δ^I)² with \
   g(Δ^I) = P·(L̄ + P·(Δ^I − L̄))/(L̄ + Δ^I·P); g is continuous at 0 with \
   value P·(1 − P); square and conclude via Filter.Tendsto.congr over \
   Set.Ioi 0.' \
  --mode instruct --files lean/exp/eta.lean --wait
```
