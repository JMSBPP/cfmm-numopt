$title Price-impact kernel GDX fixture (priceImpact(s,t,dxD) in Q64.96 + provenance)
* Generator (not an assertion test) — writes model/price_impact_kernel.gdx for the
* gamsdiff peer to consume per spec §6/§8. Lives at model/ root (NOT model/test/)
* because compile-gams must syntax-check it; test-gams must NOT execute it.

$include PricingKernel.gms
$include _PriceImpactKernelInputs.gms

* Literal singleton declared locally so the GDX domain on `priceImpact` is
* reported as `s`, not the parent `tickSpacingDomain`. We index priceKernel
* with the string literal 's1' (which IS a label in tickSpacingDomain), so
* GAMS resolves it without a domain-mismatch error.
Set s / s1 /;

Parameter priceImpact(s, tick, dxD);
priceImpact('s1', tick, dxD) =
    priceImpactKernel_Add0(priceKernel('s1', tick), Lbar, dxVal(dxD));

* Provenance scalars (spec §D6) so the GDX is self-describing for version/parameters.
Scalar gamsVersion / 54.1 /;
Scalar etaWeight   / 0.5  /;
Scalar lambdaVal;  lambdaVal = lambda / unity;

* Determinism note: re-running this fixture produces the SAME schema (symbols,
* records, values within IEEE) but DIFFERENT bytes — GAMS embeds a build
* timestamp in the GDX header. Diffs against the committed GDX will show
* "Binary files differ" even when content is unchanged. See spec §6.
execute_unload 'price_impact_kernel.gdx',
    priceImpact, Lbar, dxVal,
    gamsVersion, etaWeight, lambdaVal;
