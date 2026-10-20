
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
	\bigg (W\, ,\, \{i \, (t_j)\}_{j=1}^{N_K} \bigg) \, \, \overbrace{\leadsto}^{\texttt{CEV.TickPath.broadcast\_tick\_path}} \, \texttt{Tx}
	
\]	

`broadcast_tick_path` has as pre-requirements 

```bash
just dispatcher
# → lib/exec/CommandDispatcher.so
```

### 2. Start Anvil and deploy Tick + Multicaller

```bash
anvil --port 8545   # leave running

cd evm
forge script script/DeployTick.s.sol:DeployTick \
  --rpc-url "${ANVIL_RPC_URL:-http://127.0.0.1:8545}" \
  --broadcast \
  --private-key "${ANVIL_PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}" \
  -vv
cd ..
```

Deploy writes `build/anvil-addresses.json` with `TICK_ADDRESS` and `MULTICALLER_ADDRESS`.

```bash
export ANVIL_RPC_URL="${ANVIL_RPC_URL:-http://127.0.0.1:8545}"
export TICK_ADDRESS=
$(python3 -c 'import json;print(json.load(open("build/anvil-addresses.json"))["TICK_ADDRESS"])')
export MULTICALLER_ADDRESS=$(python3 -c 'import json;print(json.load(open("build/anvil-addresses.json"))["MULTICALLER_ADDRESS"])')
# optional: ANVIL_FROM (defaults to Anvil account #0)
```
The next requirement is to wrap all this on a command line wrapper
Or can we deploy any tickAddress, multicaller and once pluging them as env it works ?


Let's see. Having the anvil server up, we have:






This is, up to now we can build a Tx that writes a tick to a given `address` such that given address exposes the `setTick(int256)` method AND the `readTick()` and theay are read from TSTORE


However few things are still on they fly, specially for reproducibility. This is we want to call the start of the anvil server and pass an address that is deployed on that server and ask the service to write the Tx on such address for such purpose. 

We want the following a command line 

```
<command> <file-location-ref>
``
This file location ref can be of the form of a github gist or a reference to a local file and it must be a plank contract and the command deploys the contract on anvil and sets the enviroment TICK_ADDRESS to the contract deployed and then runs the gams file that triggers the call of that AND returns the Tx has number. The server must remain live

As the golden test example consider this

```
just tick-path <gist syntax reference to JMSBPP/cfmm-vol-markets branch feat-tick-path> src/TickPath.plk
```






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

