# ARCHITECTURE



# AGENTS

Shared discrete setup over the tick span \(i \in \{i_l, \dots, i_u\}\) with spacing
\(\Delta_i\), reusing the spec layer:

- pricing kernel \(P_X(i) = \lambda^{\, i \, \Delta_i}\) (price of \(X\) in \(Y\));
- per-tick liquidity \(L(i) = \bar L \, \ell(i)\), with \(\ell(i)\) the liquidity kernel weight;
- elasticity \(\eta \in (0,1)\), the trading-function exponent \(L = X^{\eta} Y^{1-\eta}\).

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
