# ARCHITECTURE




# QUESTION

Recall the chain (`eta_pi_trader_delta_control.md` /
`eta_pi_variance_swap_signature.md`): at η = 1/2 with `L̄ ≤ Δ^I` the
trader payoff is strictly monotonic-increasing in Δᵢ. In the
**complementary regime** \(0 < \Delta^I < \bar L\) (small trade), the
residual \(P\cdot\Delta^I - \Delta^O\) factors (from `slippage_residual`) as
\[
	\Delta^I \cdot P \cdot \big(\bar L + P\,(\Delta^I - \bar L)\big)
		\big/ (\bar L + \Delta^I\cdot P)
\]
which has a ROOT at \(P = \bar L / (\bar L - \Delta^I)\). Inverting
\(P = \lambda^{i\,\Delta_i}\) gives a closed-form **zero-slippage tick
spacing** that the protocol can pick:
\[
	\boxed{\,\Delta_i^{\star} \;=\;
		\frac{\log\!\big(\bar L / (\bar L - \Delta^I)\big)}{\log \lambda \,\cdot\, i}\,}
\]


### [Proven — `lean/exp/eta.lean` :: `pi_trader_half_zero_at_deltaI_star`](https://aristotle.harmonic.fun/projects/88d393e7-ec4e-438f-a5fd-9f34aab1c2e5)


\[
	\begin{aligned}
		& \text{For } \, 1 < \lambda, \; 0 < i, \; 0 < \bar L, \; 0 < \Delta^I < \bar L : \\
		& \quad \pi_{1/2}^{\text{trader}}\big(\lambda, \, \Delta_i^{\star}, \, i, \, \bar L, \, \Delta^I\big) \;=\; 0 .
	\end{aligned}
\]

Hypotheses were **not narrowed** by Aristotle (the requested
preconditions sufficed). Since \(\pi \ge 0\) always (it is a square),
\(\Delta_i^{\star}\) is a **global minimizer** of `pi_trader_half` over
\((0, \infty)\): the protocol can pick the tick spacing that drives
trader slippage to exactly zero.

Helper lemma added by Aristotle: `P_half_at_deltaI_star` — at the
zero-slippage spacing the pricing kernel evaluates to
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

> **Complement to the L̄ ≤ Δ^I regime.**
> The narrowing in `pi_trader_half_strictly_increasing_in_Δi` (large-trade
> monotonicity) ruled out global monotonicity precisely because of this
> zero — \(\pi\) first decreases to \(0\) at \(\Delta_i^{\star}\), then
> increases. The two regimes therefore compose: the protocol's optimal
> Δᵢ policy is
>   • \(\Delta_i^{\star}\) (the formula above) when \(\Delta^I < \bar L\)
>     — drives slippage to zero,
>   • the left edge of any band when \(\bar L \le \Delta^I\)
>     — monotonic in Δᵢ, no interior optimum.
> Both branches are formal theorems (this one and
> `pi_trader_half_band_min_at_left`).

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
