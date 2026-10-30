
\[
	\begin{aligned}
		\Big (\Delta_i \Big ) \, \overbrace{\leadsto}^{\texttt{TickLattice}} \, \Big (\sigma_F, \mu_F, [\sigma_l, \sigma_u]\Big ) 
	\end{aligned}
\]

\[
	\begin{aligned}
		\Big (\sigma_F, \mu_F, [\sigma_l, \sigma_u]\Big ) \, \overbrace{\leadsto}^{\texttt{CEV.TickStrikes}} \, \bigg (N_K, \Big\{ (i_K, \sigma (i_K), \mu (i_K))\Big\}_{j=1}^{N_K} \bigg)
	\end{aligned}
\]


\[
	\begin{aligned}
	    \bigg (W\, , \, \bigg (N_K, \Big\{ (i_K, \sigma (i_K), \mu (i_K))\Big\}_{j=1}^{N_K} \bigg) \, \bigg )\, \overbrace{\leadsto}^{\texttt{CEV.TickPath}} \, \bigg (W\, ,\, \{i \, (t_j)\}_{j=1}^{N_K} \bigg)
	\end{aligned}
\]


\[
	\begin{aligned}
	   \bigg (W\, ,\, \{i \, (t_j)\}_{j=1}^{N_K} \bigg) \, \overbrace{\leadsto}^{\texttt{TickPathMoments}} \, \Big (\, i_{\mu}, \sigma_{\texttt{RV}}\Big)
	\end{aligned}
\]

\[
	\begin{aligned}
		\bigg (N_K, \Big\{ (i_K, \sigma (i_K), \mu (i_K))\Big\}_{j=1}^{N_K} \bigg)
		\, \overbrace{\leadsto}^{\texttt{LiquidityKernel}} \,
		\Big(
			\big(\Gamma_{\varphi},\; m_{\Gamma}\big),\;
			\ell,\;
			L(i_K),\;
			L(\Gamma_i)
		\Big)
	\end{aligned}
\]

\[
	\begin{aligned}
		\Big(
			\big(\Gamma_{\varphi},\; m_{\Gamma}\big),\;
			\ell,\;
			L(i_K),\;
			L(\Gamma_i),\;
			g
		\Big)
		\, \overbrace{\leadsto}^{\texttt{StripLengthFromGammaBudget}} \,
		\big(\iota\big)
	\end{aligned}
\]

\[
	\begin{aligned}
		\big(G(\iota),\;\sigma_{\texttt{RV}}\big)
		\, \overbrace{\leadsto}^{\texttt{NoFeeVarianceClaim}} \,
		\pi^{\sigma}_{\text{no fee}}
		\quad=\quad G(\iota)\,\sigma_{\texttt{RV}}^{2}
	\end{aligned}
\]

Then for a single Tx we are engineering this payoff assuming the tick path accrues over the span of a single Tx once we do this we are building the entry point to this


\[
	\begin{aligned}
		\{i \, (t_j)\}_{j=1}^{N_K} \, \, \overbrace{\leadsto}^{\texttt{CEV.TickPath.broadcast\_tick\_path}} \, \texttt{Tx} \\
		\\
		\texttt{Tx}	\, \leadsto \, W \\
		\\
		\Big ( W \, (\texttt{Tx})\, , \,\{i \, (t_j)\}_{j=1}^{N_K} \, \Big) \, \overbrace{\leadsto}^{\texttt{TickPathMoments}} \, \Big (\, i_{\mu}, \sigma_{\texttt{RV}}\Big)
	\end{aligned}
\]	


Let's fix a window W but its constructor can allow for multiple ways to define them


\[
	\begin{aligned}
		\pi^{\sigma}_{\text{no fee}} \, &\leftarrow \, \pi^{\sigma}_{\text{no fee}} (\texttt{Tx})
	\end{aligned}
\]


From that Tx we can build a test using test-driven-development, and then we start the engineering of plank until that tests lands green





# TODO

1. **A1 locked** — closed form \(G(\iota)\,\sigma_{\texttt{RV}}^{2}\) (see lock file). Remaining:
1.1 **A2 step sum along the path** — look up \(L(i(t))\), multiply by squared move, sum.
1.2 **A3 option on variance** — \(\Delta Q_v\,(\sigma_{\texttt{RV}}^{2}-\sigma_K^{2})^{+}\).

2. What does fees add to the model ?
3. Derive and find \(\sigma_{\texttt{IV}} = 2 \, \phi \sqrt{\frac{V}{L_{1/2}}}\)

4. Make a big justfile command that compiles all gams files and this goes on CI too ?

