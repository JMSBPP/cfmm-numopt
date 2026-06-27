
import [*](./primitives.md)
import [*](./pricingKernel.md)

<!-- Spec for model/LiquidityKernel.gms                                  -->
<!-- $include primitives.gms                                             -->
<!-- $include PricingKernel.gms                                          -->
<!-- Scope: the per-tick liquidity kernel only. The pool-liquidity       -->
<!-- decomposition, trading identity, and aggregate counts live in the   -->
<!-- TradingRegion / dynamic specs, not here.                            -->


## GLOSSARY

| symbol | meaning | GAMS |
|---|---|---|
| \(X,Y\) | pool inventory, \(\in \text{WAD}\) | `inventory` |
| \(\xi\) | geometric decay base | `xiNorm = xiVal / unity` |
| \(\iota\) | integer kernel support length | `iotaVal` |
| \(i\) | tick index / kernel exponent | `tickOrder(tick) = ord(tick) - 1` |
| \(\ell(\xi,\iota;i)\) | per-tick liquidity weight | `liquidityKernel(xiDomain, iotaDomain, tick)` |
| \(\Theta_{\ell}\) | structural parameter set \(\{\xi,\iota\}\) | — |

GAMS-mapping notes:

- \(\xi^{\, i} \mapsto \texttt{power(xiNorm, tickOrder)}\), \(\quad \xi^{\,\iota} \mapsto \texttt{power(xiNorm, iotaVal)}\)
- the math constant \(1\) in the kernel is coded as \(\texttt{unityTick}\) (load-bearing: \(\texttt{unityTick}=1\), `primitives.gms`).


## MATH

### Decay base :: xi

\[
	\begin{aligned}
		\xi \, &= \, \texttt{xiNorm} \, = \, \frac{\texttt{xiVal}}{\texttt{unity}}
	\end{aligned}
\]

Two admissible regimes (`xiDomain`):

\[
	\begin{aligned}
		\xi \, \in \, (0, 1) \quad \text{(\texttt{belowOne})} \qquad
		\xi \, \in \, (1, \, \texttt{uintMax}\,] \quad \text{(\texttt{aboveOne})}
	\end{aligned}
\]

### Kernel support :: iota

\[
	\begin{aligned}
		\iota \, &= \, \texttt{iotaVal} ; \qquad
		\iota \, \in \, [\,\texttt{unityTick}, \, \texttt{maxTick}\,]
	\end{aligned}
\]

### Liquidity kernel :: per-tick weight

\[
	\begin{aligned}
		\ell \, (\xi, \iota; i) \, &= \,
			\frac{\xi^{\, i}}
			     {\Big(\dfrac{1 \, - \, \xi^{\,\iota}}{1 - \xi}\Big)}
	\end{aligned}
\]

The denominator is the geometric partial sum
\(\sum_{j=0}^{\iota-1} \xi^{\,j} = \tfrac{1-\xi^{\iota}}{1-\xi}\); hence over the
support \(i = 0, \dots, \iota-1\) the kernel is a normalized weight,
\(\sum_{i=0}^{\iota-1} \ell(\xi,\iota;i) = 1\). This is a **formal** identity over
the \(\iota\)-tick window only.

> Implementation caveat. The code evaluates `liquidityKernel(...,tick)` over the
> **full** tick set (`tick = k1..k241`, \(i = 0,\dots,240\)), not over the
> \(\iota\)-tick support. With the shipped constant \(\iota = \texttt{iotaVal} =
> \texttt{unityTick} = 1\) the denominator collapses to \(1\), so the array the
> code actually computes is the raw geometric ramp \(\ell(i) = \xi^{\,i}\); its
> sum over the 241-tick grid is \(\tfrac{1-\xi^{241}}{1-\xi}\), **not** \(1\). The
> unit-sum normalization is therefore unrealized in the current configuration.

### Parameters

\[
	\begin{aligned}
		\Theta_{\ell} \, = \, \{\xi, \iota\}
	\end{aligned}
\]

> Note: \(\lambda\) (pricing-kernel base, `PricingKernel.gms`) and \(\xi\) are both
> per-tick geometric ratios normalized by \(\texttt{unity}\), but they are not
> interchangeable: the pricing kernel raises \(\lambda\) to \(i\,\Delta_i\) whereas
> the liquidity kernel raises \(\xi\) to plain \(i\), and their magnitudes differ
> (\(\lambda/\texttt{unity}=1.0001\) vs \(\xi\) as low as \(10^{-6}\)).

