
<!-- Spec for model/primitives.gms — base constants for all kernels. -->


## GLOSSARY

| symbol | meaning | GAMS |
|---|---|---|
| \(\text{WAD}\) | fixed-point scaling unit, \(10^{18}\) | `unity /1000000000000000000/` |
| \(\overline{u}\) | max uint256, \(2^{256}-1\) | `uintMax /1.157920892373162e77/` |
| \(\varepsilon\) | precision floor, \(10^{12}\) | `precision /1000000000000/` |
| \(\mathbb{1}_i\) | unit tick, \(1\) | `unityTick /1/` |
| \(\mathbb{0}_i\) | zero tick, \(0\) | `zeroTick /0/` |
| \(i_{\max}\) | max tick, \(2^{24}-1\) | `maxTick /16777215/` |
| \(i_{\min}\) | mid/min tick, \(2^{23}-1\) | `minTick /8388607/` |


## MATH

\[
	\begin{aligned}
		\text{WAD} \, &= \, 10^{18} \\
		\overline{u} \, &= \, 2^{256} - 1 \, \approx \, 1.157920892373162 \times 10^{77} \\
		\varepsilon \, &= \, 10^{12} \\
		i_{\max} \, &= \, 2^{24} - 1 \, = \, 16777215 \\
		i_{\min} \, &= \, 2^{23} - 1 \, = \, 8388607
	\end{aligned}
\]
