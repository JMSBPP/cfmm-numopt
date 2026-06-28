# ARCHITECTURE




# QUESTION

Two cross-section vol-term-structures live in KERNEL.md / `lean/exp/eta.lean`:

- closed-form quadratic in \(\Delta_i\) (KERNEL.md vol-term-structure):
  \[
    \begin{aligned}
      \sigma_{\text{xs}}(i_-, i_+, i_\mu, \Delta_i) \, &= \,
        (i_- - i_\mu)^2
        \, - \, \Delta_i \, (i_- - i_\mu) \, \# \, (\# - 1)
        \, + \, \Delta_i^2 \, \# \, (\# - 1) \, (2\# - 1) / 6
    \end{aligned}
  \]
  with \(\# = (i_+ - i_-) / \Delta_i\) per KERNEL.md (now derived in Lean via
  `sharp i_minus i_plus Δi := ⌊(i_+ − i_−)/Δᵢ⌋.toNat`).

- averaged variance over the \(\#\) discrete tick positions (user-posed):
  \[
    \begin{aligned}
      \sigma_{\text{realized}} \, &= \, \frac{1}{\#}
        \sum_{k=0}^{\# - 1} \big(i_- + k \, \Delta_i - i_\mu\big)^2
    \end{aligned}
  \]

What is the algebraic connection? The most natural candidate identity
\(\sigma_{\text{xs}} \, \overset{?}{=} \, \# \cdot \sigma_{\text{realized}}\) ?


### [Proven — `lean/exp/eta.lean` :: `sigma_xs_eq_sharp_mul_sigma_realized`](https://aristotle.harmonic.fun/projects/88d393e7-ec4e-438f-a5fd-9f34aab1c2e5)


The bare equality is **FALSE in general** — it holds only when
\(i_- = i_\mu\). The corrected closed-form relation (Aristotle, machine-
verified by expanding the average via the new `sum_sq_arith` lemma):

\[
	\begin{aligned}
		\sigma_{\text{xs}} \, &= \, \# \cdot \sigma_{\text{realized}}
			\, - \, (\# - 1) \, (i_- - i_\mu)^2
			\, - \, 2 \, (i_- - i_\mu) \, \Delta_i \, \# \, (\# - 1)
	\end{aligned}
\]

Both correction terms vanish at the centered case \(i_- = i_\mu\),
recovering the naive product form there. Off-centered the corrections
are explicit and the relation remains an exact algebraic identity.

> **Aristotle's load-bearing observation.** Only \(\# \ge 1\)
> (`h_sharp_pos`) is actually needed for the identity — it makes
> \(\#\cdot(1/\#)=1\) so the average inverts. The spacing / ordering
> hypotheses (\(\Delta_i > 0\), \(i_+ > i_-\), \(i_- \le i_\mu \le i_+\))
> are decorative; the identity holds even more broadly than the stated
> preconditions suggest.

Supporting lemma added: `sum_sq_arith` — the arithmetic-progression
sum-of-squares closed form
\(\sum_{k=0}^{n-1} (d + k \Delta_i)^2 = n d^2 + d\,\Delta_i\,n(n-1) + \Delta_i^2 n(n-1)(2n-1)/6\),
which Aristotle proves by induction + `Finset.sum_range_succ`.

**Reproduce** (~29 min on Aristotle, continuation of the trader-control
project — uploads only the updated `lean/exp/eta.lean` to the existing
project's workspace):

```bash
# set ARISTOTLE_API_KEY in your shell first (do NOT paste inline)
cd lean4-spec
aristotle continue 88d393e7-ec4e-438f-a5fd-9f34aab1c2e5 \
  'Discharge the new sorry in exp/eta.lean: theorem \
   sigma_xs_eq_sharp_mul_sigma_realized in CFMM.Eta. If the bare \
   equality fails, narrow with preconditions OR replace the conclusion \
   with the correct closed-form relation between sigma_xs and \
   sigma_realized.' \
  --mode instruct --files lean/exp/eta.lean --wait
```
