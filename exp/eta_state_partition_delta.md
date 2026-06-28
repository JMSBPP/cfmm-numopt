# ARCHITECTURE




# QUESTION

Shared setup (KERNEL.md vol term structure + `spec/pricingKernel.md`):

- pricing kernel \(P(i) \, = \, \lambda^{\, i \, \Delta_i}\)
- vol term structure \(\sigma(\eta, \cdot) \, = \, \delta \, P^{\eta} \, = \, \delta \, \lambda^{\, \eta \, i \, \Delta_i}\)
- trading function \(L_{\eta} \, = \, X^{\eta} \, Y^{1-\eta}\)

In \(\sigma\) the parameters \((\eta, \Delta_i)\) enter only through the
product \(\eta \, \Delta_i\). Can tick spacing replicate everything
elasticity does, or do they act independently in some observable?

\[
	\begin{aligned}
		\sigma(\eta, \Delta_i) \, &\overset{?}{=} \, \sigma(c \, \eta, \, \Delta_i / c) \\
		L_{\eta}(X, Y) \, &\overset{?}{=} \, L_{c \eta}(X, Y)
	\end{aligned}
\]


### [Proven — `lean/exp/eta.lean` :: `sigmaVTS_invariant_under_eta_Δi_rescaling` ∧ `eta_Δi_independent_in_sigma_and_L_eta`](https://aristotle.harmonic.fun/projects/e52db2cc-f1a7-4ef1-b8a1-1653613c37ad)


\[
	\begin{aligned}
		\sigma(\eta, \Delta_i) \, &= \, \sigma(c \, \eta, \, \Delta_i / c) , \qquad \forall c > 0 \\
		L_{\eta}(X, Y) \, &\neq \, L_{c \eta}(X, Y) , \qquad X \neq Y, \; c \neq 1
	\end{aligned}
\]

In \(\sigma\) the pair \((\eta, \Delta_i)\) collapses to the 1-D manifold
\(\{\eta \cdot \Delta_i = \text{const}\}\). In the joint \((\sigma, L_{\eta})\)
they separate — **tick spacing CANNOT replicate all effects of elasticity**.

**Reproduce** (~17 min on Aristotle, second run, build cache hit):

```bash
# set ARISTOTLE_API_KEY in your shell first (do NOT paste inline)
cd lean4-spec
aristotle submit "Discharge the two new sorries in exp/eta.lean: \
  sigmaVTS_invariant_under_eta_Δi_rescaling and \
  eta_Δi_independent_in_sigma_and_L_eta in namespace CFMM.Eta." \
  --project-dir ./lean --wait --destination ./lean/.aristotle-out.tar.gz
```
