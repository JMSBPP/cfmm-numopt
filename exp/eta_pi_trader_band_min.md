# ARCHITECTURE




# QUESTION

In the **large-trade regime** \(\bar L \le \Delta^I\), the trader payoff
\(\pi_{1/2}^{\text{trader}}\) is **strictly monotonic-increasing** in
\(\Delta_i\) (`pi_trader_half_strictly_increasing_in_Δi`, regime
narrowing). What does that imply for protocol-side optimization?

If the protocol is constrained to pick \(\Delta_i\) within a bounded
admissible band \([\Delta_i^{\min}, \Delta_i^{\max}]\) (because of grid
discretization, safety floors, etc.), the constrained minimizer of the
trader payoff is the **left endpoint** \(\Delta_i^{\min}\) — picking
the smallest admissible spacing always minimizes \(\pi\) in this regime.


### [Proven — `lean/exp/eta.lean` :: `pi_trader_half_band_min_at_left`](https://github.com/JMSBPP/cfmm-replicationPlank/blob/feat/lean4-spec/lean/exp/eta.lean)


\[
	\begin{aligned}
		& \text{For } \, 1 < \lambda, \; 0 < i, \; 0 < \bar L, \; \bar L \le \Delta^I, \\
		& \quad \, 0 < \Delta_i^{\min}, \; \Delta_i^{\min} \le \Delta_i : \\
		& \qquad \pi_{1/2}^{\text{trader}}\big(\Delta_i^{\min}\big)
			\, \le \, \pi_{1/2}^{\text{trader}}\big(\Delta_i\big) .
	\end{aligned}
\]

> **Proved inline, no Aristotle needed.** Direct 4-line corollary of
> the previously-discharged
> `pi_trader_half_strictly_increasing_in_Δi`:
> ```lean
> rcases lt_or_eq_of_le hΔi_ge with h | h
> · exact le_of_lt (pi_trader_half_strictly_increasing_in_Δi
>     lam hlam i hi_pos L_bar hL_bar Delta_I hDelta_I hDI Δi_min Δi hΔi_min h)
> · rw [← h]
> ```
> Strict monotonicity \(\Delta_i^{\min} < \Delta_i\) → strict inequality
> on \(\pi\); equality \(\Delta_i^{\min} = \Delta_i\) → equality on
> \(\pi\). `le_of_lt` and `rw` close the two cases.

**Complement to the small-trade regime.** Together with
`pi_trader_half_zero_at_deltaI_star`
(`eta_pi_trader_zero_slippage.md`), the optimal Δᵢ policy splits by
regime:

| Regime | Optimal Δᵢ | Achieved π |
|---|---|---|
| \(0 < \Delta^I < \bar L\)  (small trade) | \(\Delta_i^{\star} = \log(\bar L/(\bar L-\Delta^I)) / (\log \lambda \cdot i)\) (interior) | **0** (global min) |
| \(\bar L \le \Delta^I\)    (large trade) | \(\Delta_i^{\min}\) (left edge of admissible band) | minimized within band |

The two branches together give the protocol a complete, formally-verified
Δᵢ control policy for the trader-payoff objective.
