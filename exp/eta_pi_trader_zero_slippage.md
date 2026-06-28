# ARCHITECTURE




# QUESTION

The trader payoff \(\pi_{1/2}^{\text{trader}} = (P_{1/2}(i)\Delta^I - \Delta^O)^2\)
at \(\eta = 1/2\) is **long realized variance** (cf.
`eta_pi_variance_swap_signature.md`): \(\pi\) is the trader's
variance-swap PAYOFF, increasing with realized vol. The trader's
welfare optimization is therefore a **MAXIMIZATION** of \(\pi\), not a
minimization.

That said, the underlying scalar function \(\pi(\Delta_i)\) is U-shaped
in the small-trade regime: from `slippage_residual` the residual factors
as
\[
	\Delta^I \cdot P \cdot \big(\bar L + P\,(\Delta^I - \bar L)\big)
		\big/ (\bar L + \Delta^I\cdot P)
\]
and has a ROOT at \(P = \bar L / (\bar L - \Delta^I)\). Inverting
\(P = \lambda^{i\,\Delta_i}\) gives a closed-form **landmark tick spacing**
\[
	\boxed{\,\Delta_i^{\star} \;=\;
		\frac{\log\!\big(\bar L / (\bar L - \Delta^I)\big)}{\log \lambda \,\cdot\, i}\,}
\]
at which the variance-swap payoff is exactly **zero**.


### [Proven — `lean/exp/eta.lean` :: `pi_trader_half_zero_at_deltaI_star`](https://aristotle.harmonic.fun/projects/88d393e7-ec4e-438f-a5fd-9f34aab1c2e5)


\[
	\begin{aligned}
		& \text{For } \, 1 < \lambda, \; 0 < i, \; 0 < \bar L, \; 0 < \Delta^I < \bar L : \\
		& \quad \pi_{1/2}^{\text{trader}}\big(\lambda, \, \Delta_i^{\star}, \, i, \, \bar L, \, \Delta^I\big) \;=\; 0 .
	\end{aligned}
\]

Hypotheses were **not narrowed** by Aristotle. Since \(\pi \ge 0\)
always (squared residual), \(\Delta_i^{\star}\) is the **global MINIMUM**
of \(\pi\) over \((0, \infty)\).

> **Interpretation under the variance-swap (PAYOFF) framing.**
> \(\Delta_i^{\star}\) is **NOT a trader-optimal point** — it is the
> **trader-pessimal / fair-trade / zero-payoff equilibrium**: the
> spacing at which the long-variance position pays exactly zero. A
> trader maximizing welfare wants to be far from \(\Delta_i^{\star}\),
> not at it. The protocol-side optimal-\(\Delta_i\) policy for max
> trader payoff is therefore at the BOUNDARY of the admissible band
> $[\Delta_i^{\min}, \Delta_i^{\max}]$, specifically at the endpoint
> **farthest from \(\Delta_i^{\star}\)** — that companion theorem (max
> over band) is a planned follow-up, not yet formalized.
>
> So why is the zero-payoff point worth a theorem at all? Two reasons.
> First, \(\Delta_i^{\star}\) is a structural landmark — the
> at-the-money point of the variance swap, the spacing at which trader
> and LP are mutually indifferent on the variance leg. Second, it is
> the **divider between the two control regimes**: π is monotonically
> decreasing in \(\Delta_i\) for \(\Delta_i < \Delta_i^{\star}\) and
> monotonically increasing for \(\Delta_i > \Delta_i^{\star}\), so the
> protocol's max-payoff policy is "pick the band endpoint on the side
> of \(\Delta_i^{\star}\) where the band is longer".

Helper lemma added by Aristotle: `P_half_at_deltaI_star` — at the
zero-payoff spacing the pricing kernel evaluates to
\(P = \bar L / (\bar L - \Delta^I)\). Proof unfolds `P_half` /
`deltaI_star`, cancels the \(i\) factor (\(i > 0 \Rightarrow i \ne 0\)),
rewrites \(\lambda^x = \exp(\log \lambda \cdot x)\) via
`Real.rpow_def_of_pos`, cancels \(\log \lambda\) (nonzero since
\(\lambda > 1\)), and applies `Real.exp_log` (the argument
\(\bar L / (\bar L - \Delta^I) > 0\) since \(\Delta^I < \bar L\)).

The main theorem then substitutes \(P = \bar L / (\bar L - \Delta^I)\)
into the closed-form residual: the bracket
\(\bar L + P\cdot(\Delta^I - \bar L)\) collapses to
\(\bar L - \bar L = 0\), so the slippage residual is zero, hence
\(\pi_{1/2}^{\text{trader}} = (\text{residual})^2 = 0\).

> **Composition with the large-trade regime.** In the complementary
> regime \(\bar L \le \Delta^I\), \(\pi\) is strictly monotonic-INCREASING
> in \(\Delta_i\) (`pi_trader_half_strictly_increasing_in_Δi`), so on a
> band \([\Delta_i^{\min}, \Delta_i^{\max}]\) the max-payoff endpoint
> is \(\Delta_i^{\max}\) (right edge — see
> `eta_pi_trader_band_min.md` for the min-cost dual statement, which
> formalizes the boundary structure even though its framing as "min"
> assumed the cost reading).

**Reproduce** (continuation of the same project, ~17 min cached):

```bash
# set ARISTOTLE_API_KEY in your shell first (do NOT paste inline)
cd lean4-spec
aristotle continue 88d393e7-ec4e-438f-a5fd-9f34aab1c2e5 \
  'Discharge the sorry for theorem pi_trader_half_zero_at_deltaI_star \
   in CFMM.Eta. Strategy: prove a helper lemma showing P = L̄/(L̄−Δ^I) \
   at deltaI_star (via Real.rpow_def_of_pos + Real.exp_log), then \
   substitute into slippage_residual; the bracket L̄ + P·(Δ^I − L̄) \
   collapses to zero, hence residual = 0 and π = 0.' \
  --mode instruct --files lean/exp/eta.lean --wait
```
