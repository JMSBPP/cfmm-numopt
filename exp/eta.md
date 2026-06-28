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


### [Proven — `lean/exp/eta.lean` :: `CFMM.Eta.eta_split_kernel_identity`](https://aristotle.harmonic.fun/projects/160ce65d-9e86-4bd3-a59b-527b02fa896f)


\[
	\begin{aligned}
		i_{-}(\eta) \, &= \, \lfloor \eta \, i \rfloor , \qquad
		i_{+}(\eta) \, = \, i \, - \, i_{-}(\eta)
	\end{aligned}
\]

**Reproduce** (one-shot, ~35 min on Aristotle):

```bash
# set ARISTOTLE_API_KEY in your shell first (do NOT paste inline)
cd lean4-spec
aristotle submit "Discharge the sorry in exp/eta.lean: theorem \
  eta_split_kernel_identity in namespace CFMM.Eta." \
  --project-dir ./lean --wait --destination ./lean/.aristotle-out.tar.gz
```


Then the [output](~/cfmms-playground/cfmm-replicationPlank/lib/plankified-univ3/plank/lib/math/sqrt_price_math.plk) following :

```
const getAmount1DeltaUnsigned = fn (sqrtRatioAX96: u256, sqrtRatioBX96: u256, liquidity: u256, roundUp: bool) u256
```

\[
	\begin{aligned}
		\Delta^O \, (P_{\eta} \, (\Delta^I), \Delta^I; i) \, &= \, \bar L \, \big( P_{\eta} \, (i) \, - \, P_{\eta} \, (\Delta^I) \big)
	\end{aligned}
\]


## TRADER


\[
	\begin{aligned}
		\pi_{\eta}^{\text{trader}}(\cdot) \, &= \, d (P_{\eta} \, (i) \, \Delta^I\, , \, \Delta^O \, (P_{\eta} \, (\Delta^I), \Delta^I; i) ) \propto \sigma 
	\end{aligned}
\]

The [(\1/2\)-pricing kernel](~/cfmms-playground/cfmm-replicationPlank/lib/plankified-univ3/plank/lib/math/sqrt_price_math.plk) gives a price impact function implemented as `getNextSqrtPriceFromAmount0RoundingUp` given pool liquidity \(\bar L\)

Working out the explicit design with $f(x) = x^{1/(1-\eta)}$ and σ(η) = δ·P^η. Showing each piece before I touch the file.

##  Trader (long-vol, convex in input)

$$\pi_\eta^{\text{trader}} = d \big(P_\eta(i)\cdot \Delta^I,\ \Delta^O\big)$$

###  CES LONG PAYOFF
$$\pi_\eta^{\text{trader}} \;=\; (P_\eta(i)\Delta^I)^{\frac{1}{1-\eta}} - (\Delta^O)^{\frac{1}{1-\eta}} - \frac{1}{1-\eta}\,(\Delta^O)^{\frac{\eta}{1-\eta}}\big(P_\eta(i)\Delta^I - \Delta^O\big)$$

For \(η = 1/2\) 
 $\pi_{1/2}^{\text{trader}} = \big(P_{1/2}(i)\Delta^I - \Delta^O\big)^2$ 


$$\pi_\eta^{\text{trader}} \;\propto\; (\Delta^O - P_\eta(i)\Delta^I)^{1/(1-\eta)} \cdot (\text{coeff in }\eta) \;\propto\; \sigma(\eta) \cdot (\text{size factor})$$


###  CES SHORT PAYOFF

If:
$$\pi^{\text{lp}}(\eta) \;=\; \frac{1}{\sigma(\eta,\cdot)} \;=\; \frac{1}{\delta}\,P_\eta(i)^{-\eta}$$

For \(η = 1/2\) 

\[
	\begin{aligned}
		\pi^{\text{lp}}_{1/2} \propto P^{-1/2} = 1/\sqrt{P}
	\end{aligned}
\]	
