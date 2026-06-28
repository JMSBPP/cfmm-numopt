$title Shared inputs for price-impact-kernel test + fixture: Lbar, dxD, dxVal
* Included by both model/PriceImpactKernelFixture.gms (the GDX generator) and
* model/test/PriceImpactKernelTest.gms (the assertion test). Lifting these out
* of the two files means changing the fixture's input regime can't silently
* invalidate the test's spec D9 1e-12 tolerance -- both move together or the
* compile catches the drift. Include-guarded so a driver may include both
* files in the same run without re-declaring.

$if set PRICEIMPACT_INPUTS_INCLUDED $exit
$setGlobal PRICEIMPACT_INPUTS_INCLUDED 1

* unity = 1e18 = WAD scale
$include primitives.gms

* Lbar = unity = 1e18; fresh design choice (spec D4)
Scalar Lbar; Lbar = unity;

Set    dxD       / small, medium, large /;
Parameter dxVal(dxD);
* dxVal scale: small = 1e15, medium = 1e17, large = 1e18
dxVal('small')  = Lbar / 1000;
dxVal('medium') = Lbar /   10;
dxVal('large')  = Lbar;
