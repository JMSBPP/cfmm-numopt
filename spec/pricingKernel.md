
import [*](./primitives.md)

<!-- Spec for model/PricingKernel.gms                                    -->
<!-- $include primitives.gms                                             -->


## GLOSSARY

| symbol | meaning | GAMS |
|---|---|---|
| \(X,Y\) | pool inventory, \(\in \text{WAD}\) | `inventory` |
| \(i\) | tick index | `tickVal(tick) = ord(tick) - 121` |
| \([i_{-}, i_{+}]\) | tick (state-grid) domain | `tick = k1..k241` |
| \(\Delta_i\) | tick spacing / state-partition step | `tickSpacingVal(tickSpacingDomain)` |
| \(\lambda\) | pricing-kernel base, \(=1.0001\) | `lambda / unity` |
| \(P_X(\Delta_i;i)\) | pricing kernel | `priceKernel(tickSpacingDomain, tick)` |


## MATH

### Tick domain :: state grid

\[
	\begin{aligned}
		i \, \in \, [i_{-}, i_{+}]
	\end{aligned}
\]

### State partition delta :: tick spacing

\[
	\begin{aligned}
		\Delta_i
	\end{aligned}
\]

### Pricing kernel

\[
	\begin{aligned}
		P_{X} \, (\Delta_i; i) \, &= \, \lambda^{\, i \, \Delta_i}
	\end{aligned}
\]; \(\lambda = 1.0001\)
