# ARCHITECTURE




# QUESTION

Fixed \(\eta = 1/2\), NOT considering the LP payoff. The trader payoff is the
Carr-Madan variance / squared-slippage form (cf. `eta.md`):

\[
	\begin{aligned}
		\pi_{1/2}^{\text{trader}} \, &= \, \big(P_{1/2}(i) \, \Delta^I - \Delta^O \big)^2
	\end{aligned}
\]

with \(P_{1/2}(i) = \lambda^{\, i \, \Delta_i}\) (`lean/exp/eta.lean` :: `P_half`)
and \(\Delta^O\) the Plank-derived output (`Delta_O_half`, matching
`getAmount1DeltaUnsigned`).

What is the connection between \(\pi_{1/2}^{\text{trader}}\) and the KERNEL.md
cross-section vol-term-structure
\(\sigma(\Delta_i) = (i_- - i_\mu)^2 - \Delta_i(i_- - i_\mu)\#(\#-1) + \Delta_i^2 \#(\#-1)(2\#-1)/6\)
(a quadratic in \(\Delta_i\))? Can the protocol **adaptively control trader
payoff by adjusting tick spacing**, i.e. is \(\pi_{1/2}^{\text{trader}}\)
monotonic in \(\Delta_i\)?

\[
	\begin{aligned}
		\Delta_i \, \nearrow \, &\overset{?}{\implies} \, \pi_{1/2}^{\text{trader}} \, \nearrow
	\end{aligned}
\]


### [Proven — `lean/exp/eta.lean` :: `pi_trader_half_strictly_increasing_in_Δi`](https://aristotle.harmonic.fun/projects/88d393e7-ec4e-438f-a5fd-9f34aab1c2e5)


\[
	\begin{aligned}
		& \text{If } \, \bar L \le \Delta^I \, \text{ and } \, i > 0, \, \lambda > 1, \, \bar L > 0 : \\
		& \quad \Delta_i < \Delta_i' \, \implies \, \pi_{1/2}^{\text{trader}}(\Delta_i) \, < \, \pi_{1/2}^{\text{trader}}(\Delta_i')
	\end{aligned}
\]

The residual factors as
\(P \, \Delta^I - \Delta^O = \Delta^I \, P \, \big(\bar L + P\,(\Delta^I - \bar L)\big) \, / \, (\bar L + \Delta^I \, P)\).

\(\Delta_i\)-control is **regime-dependent**:

- **Large-trade regime \(\Delta^I \ge \bar L\):** the factor \(\bar L + P(\Delta^I - \bar L)\) stays positive,
  the residual is strictly positive and strictly increasing in \(\Delta_i\),
  and \(\pi = (\text{residual})^2\) strictly increases — tick spacing is a
  clean one-parameter control knob.
- **Small-trade regime \(\Delta^I < \bar L\):** the factor flips sign at
  \(P = \bar L/(\bar L - \Delta^I)\), so \(\pi\) first **decreases to zero** then
  increases — non-monotonic. Adaptive control here becomes piecewise and
  requires conditioning on which side of the zero-crossing the current
  trade lies.

Both \(\pi_{1/2}^{\text{trader}}\) and \(\sigma(\Delta_i)\) are algebraic
functions of \(\Delta_i\); in the large-trade regime they move monotonically
together, so the **formal connection** is via the shared monotonic
dependence on tick spacing.

**Reproduce** (~19 min on Aristotle, cached build; auto-narrows the
theorem statement with the `L̄ ≤ Δ^I` precondition if global monotonicity
is asked):

```bash
# set ARISTOTLE_API_KEY in your shell first (do NOT paste inline)
cd lean4-spec
aristotle submit 'Discharge the sorry in exp/eta.lean: theorem \
  pi_trader_half_strictly_increasing_in_Δi in namespace CFMM.Eta. \
  If global monotonicity over Δ^I > 0 fails, narrow with a precondition.' \
  --project-dir ./lean --wait --destination ./lean/.aristotle-out.tar.gz
```
