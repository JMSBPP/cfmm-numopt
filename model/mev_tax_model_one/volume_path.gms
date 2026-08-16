$title VolumePath solver — Shocks -> {dQx(n)} realizing a target transactional rate
$eolcom #
* ---------------------------------------------------------------------------
* Standalone. Depends on NO existing scaffold: not _PayoffScaffolding.gms, not
* primitives.gms, not the payoff units. Reads only the spec in
* model/mev_tax_model_one/notes.md.
*
* SPEC (notes.md), with p_(k,Di)(i) = lambda^(k * i * Di / 2), so p2 = p1^2:
*   dQM(n)     = - Lbar * p2(i(n)) * dQx(n) / (Lbar + p1(i(n)) * dQx(n))
*   p1(i(n+1)) =   Lbar * p1(i(n))          / (Lbar + p1(i(n)) * dQx(n))
*
* TWO SIMPLIFICATIONS, both verified numerically before being used here:
*
* (1) Substituting p2 = p1^2 into dQM and recognising the recursion inside it:
*         dQM(n) = - p1(n) * p1(n+1) * dQx(n)                 [err 0.000]
*     No division survives in the output map.
*
* (2) The swap sign condition dQx(n)*dQM(n) < 0 is AUTOMATIC, not a constraint:
*         dQx * dQM = -p1(n)*p1(n+1)*dQx^2 < 0  for p1 > 0, dQx =/= 0.
*     Imposing it would add N nonconvex constraints that can never bind.
*
* (3) RECIPROCAL COORDINATES make the recursion AFFINE:
*         1/p1(n+1) - 1/p1(n) = dQx(n)/Lbar
*     so the closed loop i(0)=i(N) is exactly the LINEAR constraint
*         sum_n dQx(n) = 0
*     The nonlinear recursion is never inverted and never solved through.
*
* PRECISION: every quantity here is O(1)-O(1e18), inside the 53-bit exact-integer
* ceiling. No Q64.96 value enters this model. Q96 belongs to EMISSION only, where
* exact values are substituted from the committed tick table by index.
* ---------------------------------------------------------------------------

Set  n        "swap events 0..N-1"        / n0*n7 /;
Alias (n, nn);
Scalar nEv;  nEv = card(n);

* ---- shock inputs (would arrive decoded from the ShocksWriter event) -------
Scalar p1_0     "sqrt-price at i(0); SQRT_PRICE_1_1 => 1.0"      / 1.0    /;
Scalar Lbar     "pool liquidity, model units"                    / 1.0    /;
Scalar phiX     "fee on the X leg"                               / 0.0005 /;
Scalar phiM     "fee on the M leg"                               / 0.0060 /;
Scalar dStar    "TARGET transactional rate, delta_trans*, in (0,1)" / 0.490 /;
Scalar volTgt   "TOTAL traded X notional, sum|dQx| -- THE MISSING SCALE"  / 0.50 /;

Scalar phiBar;  phiBar = 1 - (1 - phiX)*(1 - phiM);
Scalar pbar;    pbar   = sqr(p1_0);
Scalar u0;      u0     = 1/p1_0;

* ---- decision variables ---------------------------------------------------
* dQx split into non-negative parts so |dQx| is smooth: |dQx| = xp + xm.
Positive Variable xp(n), xm(n), absQx(n), absQM(n), nuTerm(n), p1(n), pNext(n);
Variable  dQx(n), u(n), dQM(n), piPhi, nuTrans, piTot, obj;

Equation eSplit(n), eAbsX(n), eU0, eRec(n), eClose, eScale, eP1(n),
         ePNextIn(n), ePNextLast(n), eDQM(n), eAbsM(n), eNuTerm(n),
         ePiPhi, eNu, ePiTot, eTargetDelta, eTargetFee, eObj;

eSplit(n)..  dQx(n)   =e= xp(n) - xm(n);
eAbsX(n)..   absQx(n) =e= xp(n) + xm(n);

* AFFINE recursion in reciprocal coordinates, u(n) = 1/p1(n).
eU0..                      u('n0') =e= u0;
eRec(n)$(ord(n) < nEv)..     u(n+1)  =e= u(n) + dQx(n)/Lbar;

* CLOSED LOOP i(0) = i(N)  <=>  sum dQx = 0. One LINEAR equality.
eClose..     sum(n, dQx(n)) =e= 0;

* SCALE. delta_trans and r^phi are both RATIOS, so the system is homogeneous:
* scaling every dQx leaves both targets unchanged. Without this the min-norm rule
* collapses to the |dQx| floor and returns a do-nothing path that still "hits"
* both targets. The shock must therefore supply a SIZE as well as a rate.
eScale..     sum(n, absQx(n)) =e= volTgt;

eP1(n)..     p1(n)*u(n) =e= 1;

* p1 at the NEXT event; the loop closes so the last one returns to p1(0).
ePNextIn(n)$(ord(n) < nEv)..   pNext(n) =e= p1(n+1);
ePNextLast(n)$(ord(n) = nEv).. pNext(n) =e= p1_0;

* dQM(n) = -p1(n)*p1(n+1)*dQx(n)   -- verified exact against the spec form.
eDQM(n)..    dQM(n)   =e= -p1(n)*pNext(n)*dQx(n);

* |dQM| needs no abs(): p1 > 0 and pNext > 0, so |dQM| = p1*pNext*|dQx|.
eAbsM(n)..   absQM(n) =e= p1(n)*pNext(n)*absQx(n);

eNuTerm(n).. sqr(nuTerm(n)) =e= pbar * absQx(n) * absQM(n);

ePiPhi..     piPhi   =e= sum(n, phiX*pbar*absQx(n) + phiM*absQM(n));
eNu..        nuTrans =e= sum(n, nuTerm(n));
ePiTot..     piTot   =e= sum(n, pbar*absQx(n) + absQM(n));

* ---- the two terminal targets --------------------------------------------
eTargetDelta.. nuTrans =e= dStar          * piTot;
eTargetFee..   piPhi   =e= phiBar * dStar * piTot;

* ---- SELECTION RULE (named, not smuggled) --------------------------------
* N is FIXED, so N unknowns face 3 equalities: underdetermined BY CONSTRUCTION,
* and any feasible path is an answer (VPATH-05). Minimum-norm picks one
* deterministically. It is a selection rule, not a modelling claim.
eObj..       obj =e= sum(n, sqr(dQx(n)));

u.lo(n)=1e-6;  u.up(n)=1e6;   p1.lo(n)=1e-6;  p1.up(n)=1e6;
pNext.lo(n)=1e-6; pNext.up(n)=1e6;
xp.up(n)=10;   xm.up(n)=10;   absQx.lo(n)=1e-9;
u.l(n)=u0;     p1.l(n)=p1_0;  pNext.l(n)=p1_0;
xp.l(n)=0.05;  xm.l(n)=0.05;  nuTerm.l(n)=0.05;

Model volumePath / all /;
option nlp = conopt;
option limrow = 0, limcol = 0, solprint = off, sysout = off;
Solve volumePath using nlp minimizing obj;

* ---- gates ----------------------------------------------------------------
abort$(volumePath.solveStat <> %solveStat.normalCompletion%)
    "solver did not terminate normally", volumePath.solveStat;
abort$(volumePath.modelStat > 2)
    "no locally optimal solution", volumePath.modelStat;

Scalar dRealized;  dRealized = nuTrans.l / piTot.l;
Scalar rRealized;  rRealized = piPhi.l   / piTot.l;
Scalar closeErr;   closeErr  = abs(sum(n, dQx.l(n)));
Scalar signWorst;  signWorst = smax(n, dQx.l(n)*dQM.l(n));
Scalar tol /1e-8/;

abort$(abs(dRealized - dStar) > tol)
    "delta_trans(N) missed its target", dRealized, dStar;
abort$(abs(rRealized - phiBar*dStar) > tol)
    "r^phi_N missed its target", rRealized, phiBar, dStar;
abort$(closeErr > tol)
    "the loop did not close: sum dQx =/= 0", closeErr;
abort$(signWorst >= 0)
    "a step was not a swap: dQx*dQM >= 0", signWorst;

file f /volume_path.txt/;  put f;
put '--- VolumePath solved ---------------------------------------' /;
put 'N events            = ', (card(n)):8:0 /;
put 'delta_trans target  = ', dStar:14:10 '   realized = ', dRealized:14:10 /;
put 'r^phi      target  = ', (phiBar*dStar):14:10 '   realized = ', rRealized:14:10 /;
put 'sum dQx (closure)   = ', closeErr:14:12 /;
put 'worst dQx*dQM       = ', signWorst:14:10 '  (must be < 0)' /;
put 'objective (min-norm)= ', obj.l:14:10 /;
put /;
put '  n        dQx(n)          dQM(n)          p1(n)' /;
loop(n,
  put '  ', n.tl:3, dQx.l(n):16:9, dQM.l(n):16:9, p1.l(n):16:9 /;
);
putclose f;
