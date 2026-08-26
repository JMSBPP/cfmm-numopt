
Let \(n \in \mathbb{N}\) index state and output vectors and *fix* \(N \in \mathbb{N} > n\) be terminal state step:

\[
	\begin{aligned}
		x (n) &= 
		\begin{bmatrix}
		    \bar L_{(\cdot)} \\
			i (n) \\
			\bar \phi
		\end{bmatrix} 
		\, \quad y(n) 
		\, = \, 
		\begin{bmatrix}
			\Delta Q_X \, (n) \\
			\Delta Q_M \, (n)
		\end{bmatrix}; \quad \forall_{n\leq N} \, \quad \Delta Q_X \, (n) \Delta Q_M \, (n) < 0 ; \quad
		\bar \phi = 1 - (1 - \bar \phi_X)(1 \, - \bar \phi_M)
	  \end{aligned} 
\]


\[
	\begin{aligned}
		\Delta Q_M \, (\Delta Q_X \, (n), n) \, &= \, - \frac{\bar L_{(\cdot)} p_{(2,\Delta_i)} \, (i(n))\, \Delta Q_X}{\bar L_{(\cdot)} \, + \, p_{(1,\Delta_i)} \, (i(n)) \, \Delta Q_X}
	\end{aligned}
\];
\[
p_{(1,\Delta_i)}(i(n+1))
=
\frac{
\bar L,p_{(1,\Delta_i)}(i(n))
}{
\bar L+
p_{(1,\Delta_i)}(i(n)) \, \Delta Q_X \, (n)
}.
\]


Impose the terminal state condition region \(i (0) = i(N)\), and under that defintion define:

\[
	\begin{aligned}
		\bar p \equiv p_{(2,\Delta_i)} \, (i(0))
	\end{aligned}
\];

Define the functionals:

\[
	\begin{aligned}
		\begin{cases}
			\pi^{\phi} (n) &\equiv \sum_{j=0}^n \, \Big [\bar \phi_X \, \bar p \, |\Delta Q_X \, (j)| \, + \, \bar \phi_M |\Delta Q_M \, (j)|\Big] \\
			\nu_{\text{trans}} \, (n) &\equiv \, \sum_{j=0}^n \sqrt{ \bar p|\Delta Q_X \, (j) \, \Delta Q_M \, (j)|} \\
			\bar \pi (n) &\equiv \sum_{j=0}^n \, \Big [\bar p \, |\Delta Q_X \, (j)| \, + \,  |\Delta Q_M \, (j) |\Big]
		\end{cases}
	\end{aligned}
\]

And the rates:
 
\[
	\begin{aligned}
		r_n^{\phi} \, \equiv \, \frac{\pi^{\phi} (n)}{\bar \pi (n)} \quad \delta_{\text{trans}} (n) \, = \frac{\nu_{\text{trans}} \, (n)}{\bar \pi (n)}\, 
	\end{aligned}
\];

Given \(\delta_{\text{trans}}^{\star}  \in (0,1)\) we need to find the sequence \(\{\Delta Q_X \, (n)\}^{N}_{n=0}\) such that:

\[
	\begin{aligned}
		\delta_{\text{trans}} (N) = \delta_{\text{trans}}^{\star}; \, \quad \wedge \,\quad  r_N^{\phi} = \bar \phi \,  \delta_{\text{trans}}^{\star}
	\end{aligned}
\]




