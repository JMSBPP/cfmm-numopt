# ARCHITECTURE




# QUESTION

Under the variance-swap (PAYOFF) framing, the trader maximizes
\(\pi_{1/2}^{\text{trader}}\) (cf. `eta_pi_trader_zero_slippage.md`).
On a bounded admissible tick-spacing band
\([\Delta_i^{\min}, \Delta_i^{\max}]\), what is the maximum achievable
\(\pi\)?

Naive intuition: in the small-trade regime (\(\Delta^I < \bar L\)),
\(\pi\) is U-shaped in \(\Delta_i\) with global minimum 0 at
\(\Delta_i^{\star}\), so the band-max is at the endpoint **farthest
from \(\Delta_i^{\star}\)** — i.e., \(\max(\pi(\Delta_i^{\min}), \pi(\Delta_i^{\max}))\).
In the large-trade regime (\(\bar L \le \Delta^I\)), \(\pi\) is
monotonic-increasing, so band-max is at the right endpoint
\(\Delta_i^{\max}\).

That intuition turns out to be **right for the large-trade regime, and
right in PART of the small-trade regime — but FALSE in the rest.**


### [Proven — `lean/exp/eta.lean` :: `pi_trader_half_band_max_large_trade` ∧ `pi_trader_half_band_max_small_trade`](https://aristotle.harmonic.fun/projects/88d393e7-ec4e-438f-a5fd-9f34aab1c2e5)


**Large-trade regime** (trivial corollary, proved inline):
\[
	\bar L \le \Delta^I \, \implies \,
		\pi_{1/2}^{\text{trader}}(\Delta_i)
		\le \pi_{1/2}^{\text{trader}}(\Delta_i^{\max})
	\quad \text{for all } \Delta_i \in [\Delta_i^{\min}, \Delta_i^{\max}] .
\]

**Small-trade regime** (Aristotle, narrowed):
\[
	\boxed{\,\Delta^I^2 + \Delta^I \cdot \bar L \le \bar L^2\,}
	\, \implies \,
		\pi_{1/2}^{\text{trader}}(\Delta_i)
		\le \max\big(\pi(\Delta_i^{\min}), \, \pi(\Delta_i^{\max})\big) .
\]

The narrowing condition rewrites as
\[
	\Delta^I \big/ \bar L \, \le \, \tfrac{\sqrt{5} - 1}{2} \, \approx \, 0.618...
\]

— the **inverse golden ratio**. Below this threshold of trade size
relative to pool liquidity, \(\pi\) is genuinely U-shaped and the
band-max is at the endpoint. **Above this threshold but still in the
small-trade regime** \((\sqrt{5}-1)/2 \cdot \bar L < \Delta^I < \bar L\),
\(\pi\) develops an **interior hump on the left branch** \(\Delta_i < \Delta_i^{\star}\)
that can exceed both endpoint values.

> **Aristotle's counterexample (machine-checked):**
> \(\bar L = 1\), \(\Delta^I = 0.9\). A band realizing
> \(P \in \{1.5, 2, 4\}\) gives \(\pi \approx (0.238, 0.265, 0.220)\)
> — the interior value beats both endpoints.

> **Why the golden ratio?** The U-shape requires the residual
> \(\Delta^I \cdot P \cdot \big(\bar L + P(\Delta^I - \bar L)\big) / (\bar L + \Delta^I P)\)
> to be monotone in \(\Delta_i\). The cross-difference (between two
> Δᵢ values) factors as
> \(\Delta^I (P - P')\big[\bar L^2 - (\bar L - \Delta^I)\bar L(P+P') - \Delta^I(\bar L - \Delta^I) P P'\big]\),
> and the sign-determining bracket reduces to the golden expression
> when \(P, P' > 1\). Exactly when \(\Delta^I/\bar L\) crosses the
> inverse golden ratio, the bracket flips sign on part of the domain
> and monotonicity breaks.

Proof structure: Aristotle added a helper `residual_antitone` (under
the golden bound the residual is decreasing in Δᵢ — cross-difference
factorization above, closed by `nlinarith`). Main theorem then uses
the elementary inequality \(r^2 \le \max(r_{\min}^2, r_{\max}^2)\) for
\(r \in [r_{\max}, r_{\min}]\) when residual is monotone.

> **Implication for protocol control.** In the "upper sub-regime"
> \((\sqrt{5}-1)/2 \cdot \bar L < \Delta^I < \bar L\), the protocol's
> max-π policy is NOT "pick a band endpoint" — interior Δᵢ values can
> dominate. The "control via Δᵢ" story is therefore strictly more subtle
> than the naive U-shape would suggest in that ≈0.382-wide sliver of
> the small-trade regime. A complete max-π policy would need either
> an interior-critical-point search OR an admissible band designed to
> exclude the hump.

**Reproduce** (continuation of the same project, ~25 min cached):

```bash
# set ARISTOTLE_API_KEY in your shell first (do NOT paste inline)
cd lean4-spec
aristotle continue 88d393e7-ec4e-438f-a5fd-9f34aab1c2e5 \
  'Discharge sorry for pi_trader_half_band_max_small_trade in \
   CFMM.Eta. Claim: U-shape band-max at endpoint. If FALSE in part \
   of the regime, narrow with the tight U-shape condition and prove \
   under the narrowing. Use slippage_residual, P_half_strictMono, \
   one_lt_P_half from the file.' \
  --mode instruct --files lean/exp/eta.lean --wait
```
