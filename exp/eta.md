# ARCHITECTURE



# AGENTS

Shared discrete setup over the tick span \(i \in \{i_l, \dots, i_u\}\) with spacing
\(\Delta_i\), reusing the spec layer:

- pricing kernel \(P_{1/2}(i) = \lambda^{\, i \, \Delta_i}\) (price of \(X\) in \(Y\));
- per-tick liquidity \(L(i) = \bar L \, \ell(i)\), with \(\ell(i)\) the liquidity kernel weight;
- elasticity \(\eta \in (0,1)\), the trading-function exponent \(L = X^{\eta} Y^{1-\eta}\).

The [(\1/2\)-pricing kernel](~/cfmms-playground/cfmm-replicationPlank/lib/plankified-univ3/plank/lib/math/sqrt_price_math.plk) gives a price impact function implemented as `getNextSqrtPriceFromAmount0RoundingUp` given pool liquidity \(\bar L\)


\[
	\begin{aligned}
		P_{1/2} \, (\Delta^I) \, &= \, \frac{\bar L \, P_{1/2}(i)}{\bar L + \Delta^I \,P_{1/2}(i)}
	\end{aligned}
\]

If we were to implement a generic \(\eta - \) price impact funcion, we need the \(\eta - \) pricing kernel  to stay on the \(1/2 - \) kernel:

This is we need to prove: 
\[
	\begin{aligned}
		\exists_{i_{-}, i_{+} \, \text{Ticks}} \quad \,  P_{\eta} \, (i) \ \, = P_{1/2} \, (i_{-}) \, P_{1/2} \, (i_{+}) = P_{1/2} \, (i)
	\end{aligned}
\]

becuase I think the multiplicative approach can have riskss iof falling out the 1/2 algebra

### Proven — `lean/exp/eta.lean` :: `CFMM.Eta.eta_split_kernel_identity`

The kernel-level claim above is **machine-verified** by Aristotle
(run `db7bdefd-6122-408f-8879-086e5a55a82a`,
[dashboard](https://aristotle.harmonic.fun/projects/160ce65d-9e86-4bd3-a59b-527b02fa896f)).
Witnesses (both depending on \(\eta\)):

\[
	\begin{aligned}
		i_{-}(\eta) \, &= \, \lfloor \eta \, i \rfloor , \qquad
		i_{+}(\eta) \, = \, i \, - \, i_{-}(\eta)
	\end{aligned}
\]

Sum equals \(i\) by construction (lemma `tickSplit_sum`), so the identity
reduces to the exponent law
\(\lambda^{a \Delta_i} \cdot \lambda^{b \Delta_i} = \lambda^{(a+b) \Delta_i}\).
The accepted Lean proof:

```lean
theorem eta_split_kernel_identity ... := by
  unfold P_half
  rw [← Real.rpow_add hlam]
  congr 1
  have hi2 : (i : ℝ) = (tickSplit_minus η i : ℝ) + (tickSplit_plus η i : ℝ) := by
    rw [← Int.cast_add, tickSplit_sum]
  rw [hi2]
  ring
```

`#print axioms eta_split_kernel_identity` returns only `propext`,
`Classical.choice`, `Quot.sound` (no `sorryAx`). Aristotle's note: the
`IsInt24` bounds and the \(\eta \in (0,1)\) constraints are **not**
load-bearing for the algebraic identity — they only guard that the
witnesses fit in Int24; the kernel identity itself holds for any real
\(\eta\) and any integer \(i\).

**Reproduce** (one-shot, ~35 min on Aristotle):

```bash
# set ARISTOTLE_API_KEY in your shell first (do NOT paste inline)
cd lean4-spec
aristotle submit "Discharge the sorry in exp/eta.lean: theorem \
  eta_split_kernel_identity in namespace CFMM.Eta." \
  --project-dir ./lean --wait --destination ./lean/.aristotle-out.tar.gz
```

> Caveat for the broader "stay on ½-algebra" goal: this theorem closes
> the claim at the **tick-kernel level** (where \(\eta\) does not appear
> in the price). It does **not** close it at the **price-impact** level —
> the η-impact involves the exponent \(1/(1-\eta)\), which is a separate
> open theorem.


Then the [output](~/cfmms-playground/cfmm-replicationPlank/lib/plankified-univ3/plank/lib/math/sqrt_price_math.plk) following :

```
const getAmount1DeltaUnsigned = fn (sqrtRatioAX96: u256, sqrtRatioBX96: u256, liquidity: u256, roundUp: bool) u256
```

\[
	\begin{aligned}
		\Delta^O \, (P_{\eta} \, (\Delta^I), \Delta^I; i) \, &= \, \bar L \, \big( P_{\eta} \, (i) \, - \, P_{\eta} \, (\Delta^I) \big)
	\end{aligned}
\]

Pinning the local price to \(P_X(i)\) on the \(\eta\)-CES curve gives each tick's reserves
(the one place \(\eta\) enters):

\[
	\begin{aligned}
		x(i;\eta) \, &= \, L(i) \, \Big(\tfrac{\eta}{1-\eta}\Big)^{1-\eta} \, P_X(i)^{-(1-\eta)} \\
		y(i;\eta) \, &= \, L(i) \, \Big(\tfrac{1-\eta}{\eta}\Big)^{\eta} \, P_X(i)^{\eta}
	\end{aligned}
\]

Both payoffs factor through one \(\eta\)-weighted liquidity–price aggregate over the span:

\[
	\begin{aligned}
		S(\eta) \, &= \, \sum_{i=i_l}^{i_u} \ell(i) \, P_X(i)^{\eta}
				   \, = \, \sum_{i=i_l}^{i_u} \ell(i) \, \lambda^{\, \eta \, i \, \Delta_i}
	\end{aligned}
\]


## TRADER

Consider a trader who always enter a fixed amount of input \(\Delta^I\) which is known to span a tick range 
\(i_l, i_u\). The trader sells \(X\) for \(Y\) (\(\Delta^I = \Delta X\)), valued in \(Y\).

We define the trader payoff as the total \(Y\) released by the crossed ticks:

\[
	\begin{aligned}
		\pi^{\text{trader}}(\eta) \, &= \, \sum_{i=i_l}^{i_u} y(i;\eta)
		\, = \, \Big(\tfrac{1-\eta}{\eta}\Big)^{\eta} \, \bar L \, S(\eta) ,
		\qquad \text{s.t. } \sum_{i=i_l}^{i_u} x(i;\eta) = \Delta^I
	\end{aligned}
\]


## LP

Consider an LP who has fixed liquidity \(\bar L\) which is fixed at spans \(i_u, i_l\).

We define the LP payoff as the mark-to-market inventory value in \(Y\),
\(\sum_i \big[y(i;\eta) + P_X(i)\, x(i;\eta)\big]\):

\[
	\begin{aligned}
		\pi^{\text{lp}}(\eta) \, &= \, c(\eta) \, \bar L \, S(\eta) ,
		\qquad c(\eta) = \Big(\tfrac{1-\eta}{\eta}\Big)^{\eta} + \Big(\tfrac{\eta}{1-\eta}\Big)^{1-\eta}
	\end{aligned}
\]

> Common parameter. Both payoffs are scalar \(\eta\)-functions times the same
> \(\bar L \, S(\eta)\). At \(\eta = \tfrac12\) (constant product) \(c=2\) and the trader
> prefactor is \(1\), so \(\pi^{\text{lp}} = 2\,\pi^{\text{trader}}\).
