# ARCHITECTURE




# QUESTION

Following the proven cross-section identity
\(\sigma_{\text{xs}} = \#\cdot\sigma_{\text{realized}} - (\#-1)d^2 - 2d\,\Delta_i\#(\#-1)\)
(`eta_sigma_xs_realized_connection.md`), the **protocol-side** question:
can the protocol pick \(\Delta_i\) to drive \(\sigma_{\text{xs}}\) to a
desired target \(\sigma_{\text{target}}\)?

With the tick count \(\#\) held as a free parameter \(n\) (decoupled
from the piecewise `sharp` floor — see `sigma_xs_poly` in
`lean/exp/eta.lean`), the σ_xs polynomial reduces to a **quadratic in
\(\Delta_i\)**:
\[
	\sigma_{\text{xs,poly}}(n, d, \Delta_i)
		\, = \, d^2 - \Delta_i\,d\,n(n-1) + \Delta_i^2\,n(n-1)(2n-1)/6
\]
with \(d := i_- - i_\mu\). For \(n \ge 2\) the leading coefficient is
positive, so the quadratic has at most two real roots; for the equation
\(\sigma_{\text{xs,poly}} = \sigma_{\text{target}}\) to admit a
**strictly positive** \(\Delta_i\), the discriminant has to be
strictly above the right threshold.


### [Proven — `lean/exp/eta.lean` :: `sigma_xs_poly_target_exists`](https://aristotle.harmonic.fun/projects/88d393e7-ec4e-438f-a5fd-9f34aab1c2e5)


\[
	\begin{aligned}
		& \text{For } n \ge 2, \; d^2 < \sigma_{\text{target}} : \\
		& \quad \exists \, \Delta_i > 0 \, : \,
			\sigma_{\text{xs,poly}}(n, d, \Delta_i) = \sigma_{\text{target}} .
	\end{aligned}
\]

**Closed form (positive-root branch):**
\[
	\Delta_i^{\star}(n, d, \sigma_{\text{target}}) \;=\;
		\frac{-c_1 + \sqrt{\text{disc}}}{2\,c_2}
		\;=\; \frac{d\,n(n-1) + \sqrt{\text{disc}}}{n(n-1)(2n-1)/3}
\]
with \(c_2 = n(n-1)(2n-1)/6\), \(c_1 = -d\,n(n-1)\), and discriminant
\(\text{disc} = c_1^2 - 4 c_2(d^2 - \sigma_{\text{target}})\). Under
\(\sigma_{\text{target}} > d^2\) the discriminant **strictly** exceeds
\(c_1^2\), so \(\sqrt{\text{disc}} > |c_1| \ge c_1\), giving a strictly
positive root, and the root satisfies the equation by
`linear_combination`.

> **Aristotle's narrowing.** Requested precondition was the non-strict
> \(d^2 \le \sigma_{\text{target}}\). Aristotle tightened it to the
> **strict** \(d^2 < \sigma_{\text{target}}\) because the non-strict
> bound allows the positive root to collapse to \(\Delta_i = 0\) (e.g.
> \(d = 0, \sigma_{\text{target}} = 0\), or any \(d < 0\) with
> \(\sigma_{\text{target}} = d^2\)) — at the equality the discriminant
> equals \(c_1^2\) exactly, and \(\sqrt{\text{disc}} = |c_1|\) can leave
> the numerator \(c_1 + |c_1|\) zero in the \(d \le 0\) cases. The
> strict bound is the right separation between feasible and degenerate.

> **\# decoupling caveat.** The theorem uses `sigma_xs_poly` (with
> \(n\) free), NOT the full `sigma_xs` (which has
> \(\# = \lfloor (i_+ - i_-)/\Delta_i \rfloor\) coupled to \(\Delta_i\)
> via the `sharp` floor). Inversion of the full `sigma_xs` would have
> to handle the piecewise-constant \(\#(\Delta_i)\); for protocol-level
> feedback control where the tick grid is held fixed across small
> Δᵢ-changes, the `_poly` form is the right object. Future refinement:
> identify a Δᵢ-interval where \(\#\) is constant and lift the
> existence to the full `sigma_xs`.

**Reproduce** (continuation of the same project, ~17 min cached):

```bash
# set ARISTOTLE_API_KEY in your shell first (do NOT paste inline)
cd lean4-spec
aristotle continue 88d393e7-ec4e-438f-a5fd-9f34aab1c2e5 \
  'Discharge the sorry for theorem sigma_xs_poly_target_exists in \
   CFMM.Eta. Treat sigma_xs_poly as the quadratic c2·Δᵢ² + c1·Δᵢ + c0 \
   with c2 = n(n-1)(2n-1)/6, c1 = -d·n(n-1), c0 = d². Take the \
   positive root via the quadratic formula. If d²≤σ_target leaves the \
   root non-strictly positive, NARROW to d²<σ_target.' \
  --mode instruct --files lean/exp/eta.lean --wait
```
