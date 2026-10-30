# `src/` taxonomy (kalecky-semantics mirror)

Reference: [JMSBPP/kalecky-semantics](https://github.com/JMSBPP/kalecky-semantics) — `parameters/` / `variables/` / `equations/` / `models/`.

## Layout

```
src/
├── parameters/   sets, data scalars, macros, Parameter tables
├── variables/    endogenous Variable declarations
├── equations/    Equation declarations
├── models/       runnable hosts (Model/Solve and A1 join)
└── build/        listings (just gams)
```

## Map

| File | Role |
|---|---|
| `parameters/TickLattice.gms` | grid scalars + macros |
| `parameters/Exposure.gms` | \(\bar L\) / VegaNotional |
| `parameters/CEV.TickStrikes.gms` | strike factory |
| `parameters/CEV.TickPath.gms` | tick path |
| `parameters/TickPathMoments.gms` | \(\mu\), \(\sigma_{\texttt{RV}}\) |
| `parameters/LiquidityKernel.gms` | Liq macros + \(\Gamma\) tables |
| `variables/ReplicationStrip.gms` | \(\iota\) |
| `equations/GammaBudget.gms` | strip domains + \(G\ge g\) |
| `models/StripLengthFromGammaBudget.gms` | MINLP host |
| `models/NoFeeVarianceClaim.gms` | A1: \(G(\iota)\,\sigma_{\texttt{RV}}^{2}\) |

Include order: parameters → variables → equations → models (kalecky).
Guarded `$include` / `$goto` so A1 can pull strip + path without redeclaration.
