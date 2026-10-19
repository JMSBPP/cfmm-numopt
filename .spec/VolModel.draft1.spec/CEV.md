
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
Lock: [`.planning/A1-no-fee-variance-claim.md`](../../.planning/A1-no-fee-variance-claim.md).

----------------
Then for a single Tx we are engineering this payoff assuming the tick path accrues over the span of a single Tx once we do this we are building the entry point to this


\[
	\begin{aligned}
	    \bigg (W\, ,\, \{i \, (t_j)\}_{j=1}^{N_K} \bigg) \, \leadsto \, \texttt{Tx}
	\end{aligned}
\]

How to write a tick path onto a single transaction ?

Since a Tx is a sequence of calls it uses MultiCall

BUT The multicall is the end point Tx is to be modelled on Idris-2 first


Well, angstrom has utilities for encoding things on a single Tx, but this process goes later. The first thing is running CEV.TickPath.gms produces a parameter tickVal series, we need to pass it to some ordered data structure that can be read by idris and then idris sends it to the multicaller
 
Then:
1. How from a GAMS Set generated internally we can pass the data to Idris2 such that from such data structure we then pass it to a Tx.

> Note that this intended to be atomic meaning from the requirements here we want a single operation that reads the tickVal and then inmediatly writes it to calldataBuffer, such that once the calldataBuffer lenght equals the length of the path it stops and then sends appends to the calldata the selector and sends the call

Done (gams-deps → gams-evm-transport):
- Pin in `gams-deps.toml` (`GAMS_EVM_TRANSPORT_SRC`); preamble `gams-deps.inc`
- `CEV.TickPath.gms` imports `GdxComptimeHandshake` (brings `gdxWrite`) from the pin





All $ commands in GAMS are comp-time, meaning once a Set is written internally in gams we need to find a way to once a Set is written on gams sends its data to an external process and that externall process read and acknowledge it received the data.

Then we need to find the best $ option such that one can pass as arg a Set decalration and be able to send it to an external process 



Once the transaction completes \(\pi^{\sigma}_{\text{no fee}}\) is to have been settled 

This is:

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

