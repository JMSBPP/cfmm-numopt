$title VolumePath solver — Shocks -> {dQx(n)} realizing the target rate pair
$eolcom #
* ---------------------------------------------------------------------------
* Standalone. Depends on NO existing scaffold. Reads only the spec in
* model/mev_tax_model_one/notes.md, with p_(k,Di)(i) = lambda^(k*i*Di/2), so
* p2 = p1^2 (user ruling: p2 is the NORMAL price).
*
* THE INVERSE PROBLEM, resolved. Per step, with
*     x_n = |dQM_n| / (pbar|dQx_n| + |dQM_n|)  in (0,1):
*     step rate   r_n   = phiX + (phiM-phiX)*x_n
*     step delta  d_n   = sqrt(x_n(1-x_n))
* Every step lies ON the half-ellipse centred at ((phiX+phiM)/2, 0) with
* semi-axes ((phiM-phiX)/2, 1/2); the path aggregate is a weighted mean, so
* the reachable (r, delta) set is the half-ellipse DISK. Hence:
*   (i)  delta <= 1/2 always (the ellipse top = the AM-GM ceiling);
*   (ii) equal fees collapse the disk to a segment at r = phiX and force
*        dStar = phiX/phiBar > 1/2: infeasible for EVERY target;
*   (iii) the joint target (r, delta) = (phiBar*dStar, dStar) is reachable
*        iff (phiBar^2+dphi^2)*d^2 - (phiX+phiM)*phiBar*d + phiX*phiM <= 0
*        -- a closed-form precheck (verified on 20000 random closed paths).
*   (iv) VOLUME IS A THIRD AXIS, not a gauge: x_n depends on the u-levels the
*        path visits, so the system is NOT homogeneous in dQx. Small
*        kappa = volTgt/Lbar confines levels near u0, pins every x_n near 1/2
*        and floors delta near 1/2. Measured at this fee schedule:
*        dStar = 0.49 needs kappa >= 1.4980 (volTgt >= 2.7632e19 at L = 2^64);
*        at kappa = 0.6505 the delta floor is 0.49797.
*
* FORMULATION: parametrize on the reciprocal levels u(np) = 1/p1 directly
* (NOT on a dQx sign-split -- xp/xm plus the ratio constraints trapped CONOPT
* at "locally infeasible"). The affine recursion 1/p1(n+1)-1/p1(n) = dQx/Lbar
* means pinning u(p0) = u(pN) = u0 IS the closed loop; no closure equation.
*     t(n) = p1(n)p1(n+1)/pbar = u0^2/(u(n)u(n+1)),   |dQM| = t|dQx|,
*     sqrt(|dQx||dQM|) = |dQx|sqrt(t)  -- so w = sqrt(t) replaces all abs().
*
* PRECISION: every solve-space quantity is O(1); EVM units live at the
* BOUNDARY. Measured ulp: 1e18 -> 128 wei ok; 2^64 -> 4096 ok; 2^96 -> 1.76e13
* NOT ok, so the sqrt price is carried only as the ratio sqrtPriceX96/2^96.
* ---------------------------------------------------------------------------

* ---- INPUTS ---------------------------------------------------------------
* The shock is an INPUT from the bridge (test -> Anvil -> reader -> prover),
* never a modelling constant. Every value below is overridable on the command
* line (gams volume_path.gms --sqrtPriceX96=... --volTgtWad=...); the defaults
* are a SELF-TEST FIXTURE only, each with its provenance:
*
*   nEvents       8       USER constant: fixed iteration count, sized by the
*                         computational cost of repeated runs. No derivation;
*                         awaiting the user's ruling on the production value.
*   sqrtPriceX96  2^96    = SQRT_PRICE_1_1, plank Constants.plk (verified).
*   liquidityRaw  2^64    = UNIT_LIQUIDITY, plank Constants.plk (verified).
*   txlVolumeRate 490000  PLACEHOLDER. A shock ARGUMENT of the ShocksWriter
*                         interfaces (next(..., txlVolumeRate, ...)); it has no
*                         canonical value. 0.49 was chosen INSIDE the measured
*                         feasible band for the fixture fees (see precheck).
*   phiXpips      500     PLACEHOLDER. No fee appears anywhere in the plank
*   phiMpips      6000    model; the pool's fee config must supply these. The
*                         only structural requirement is phiX <> phiM (equal
*                         fees are infeasible for EVERY target -- proven).
*                         The 1e6 pips denominator itself still needs to be
*                         verified against the pool's fee encoding.
*   volTgtWad     28e18   DERIVED from the fixture, not free: at these fees and
*                         dStar = 0.49 the joint target needs
*                         kappa = volTgt/Lbar >= 1.4980, i.e. volTgt >=
*                         2.7632e19 wei at L = 2^64 (measured, multistart SLSQP
*                         on this same algebra). 28e18 = 2.8e19 sits just above.
$if not set nEvents        $setGlobal nEvents        8
$if not set sqrtPriceX96   $setGlobal sqrtPriceX96   79228162514264337593543950336
$if not set liquidityRaw   $setGlobal liquidityRaw   18446744073709551616
$if not set txlVolumeRate  $setGlobal txlVolumeRate  490000
$if not set phiXpips       $setGlobal phiXpips       500
$if not set phiMpips       $setGlobal phiMpips       6000
$if not set volTgtWad      $setGlobal volTgtWad      28e18

Set  n  "swap events"        / n1*n%nEvents% /;
Set  np "path nodes, card+1" / p0*p%nEvents% /;
Scalar nEv; nEv = card(n);
abort$(card(np) <> nEv + 1) "np must have exactly card(n)+1 nodes";

Scalar Q96;  Q96  = power(2,96);
Scalar PIPS; PIPS = power(10,6);        # rate denominator, 1e6 = 100%
Scalar sqrtPriceX96 "uint160"                    / %sqrtPriceX96% /;
Scalar liquidityRaw "uint128"                    / %liquidityRaw% /;
Scalar txlVolumeRate "uint24, pips"              / %txlVolumeRate% /;
Scalar phiXpips      "fee on the X leg, pips"    / %phiXpips% /;
Scalar phiMpips      "fee on the M leg, pips"    / %phiMpips% /;
Scalar volTgtWad     "total |dQx| notional, wei" / %volTgtWad% /;

abort$(sqrtPriceX96 > power(2,160) - 1) "sqrtPrice exceeds uint160";
abort$(liquidityRaw > power(2,128) - 1) "liquidity exceeds uint128";
abort$(txlVolumeRate >= PIPS) "txlVolumeRate must be < 100%";
abort$(phiXpips = phiMpips)
    "equal fees: r^phi = phi path-free forces dStar = phi/phiBar > 1/2, infeasible";

* ---- decode to solve space ------------------------------------------------
Scalar p1_0;   p1_0   = sqrtPriceX96 / Q96;
Scalar Lbar;   Lbar   = liquidityRaw;
Scalar phiX;   phiX   = phiXpips / PIPS;
Scalar phiM;   phiM   = phiMpips / PIPS;
Scalar dStar;  dStar  = txlVolumeRate / PIPS;
Scalar phiBar; phiBar = 1 - (1-phiX)*(1-phiM);
Scalar u0;     u0     = 1/p1_0;
Scalar kappa "total u-travel = volTgt/Lbar";  kappa = volTgtWad / Lbar;
abort$(kappa > 1e12 or kappa < 1e-12) "volTgt/Lbar outside a solvable range", kappa;

* ---- feasibility precheck (iii), closed form ------------------------------
Scalar dphi;  dphi = phiM - phiX;
Scalar ellTest;
ellTest = (sqr(phiBar)+sqr(dphi))*sqr(dStar) - (phiX+phiM)*phiBar*dStar + phiX*phiM;
abort$(ellTest > 0)
    "dStar outside the half-ellipse: no path realizes the joint target", ellTest;

* ---- variables and equations ----------------------------------------------
Positive Variable dq(n) "|Delta u| per step",
                  t(n)  "u0^2/(u(n)u(n+1)) = |dQM|/|dQx| at pbar=1",
                  w(n)  "sqrt(t)";
Variable u(np) "reciprocal sqrt-price level 1/p1", obj;

Equation eT(n), eW(n), eDq(n), eVol, eRate, eDelta, eObj;

eT(n)..  t(n) * sum(np$(ord(np)=ord(n)), u(np))
              * sum(np$(ord(np)=ord(n)+1), u(np)) =e= sqr(u0);
eW(n)..  sqr(w(n)) =e= t(n);
eDq(n).. sqr(dq(n)) =e= sqr( sum(np$(ord(np)=ord(n)+1), u(np))
                           - sum(np$(ord(np)=ord(n)),   u(np)) );
eVol..   sum(n, dq(n)) =e= kappa;
eRate..  sum(n, (phiX + phiM*t(n))*dq(n)) =e= phiBar*dStar * sum(n, (1+t(n))*dq(n));
eDelta.. sum(n, w(n)*dq(n))               =e= dStar        * sum(n, (1+t(n))*dq(n));

* SELECTION RULE (named, not smuggled): N fixed leaves nEv-1 free levels facing
* 3 targets -- underdetermined by construction; any feasible path is an answer
* (VPATH-05). Min sum dq^2 picks one deterministically.
eObj..   obj =e= sum(n, sqr(dq(n)));

* closure: endpoints pinned, telescoping does the rest.
* ORDER MATTERS: blanket .lo/.up over np would re-open an earlier .fx (this
* exact bug emitted a non-closing path that still passed the ratio gates), so
* the bounds come FIRST and the endpoint pins LAST.
*
* SOLVER BOXES, not EVM semantics: u in [1e-3, 1e3] allows the sqrt price to
* move 3 orders of magnitude either way -- far wider than any feasible path at
* sane kappa, far narrower than the tick domain. dq/t/w floors keep CONOPT off
* the degenerate zero-trade manifold. None of these bind at a solution (a
* binding box would surface as modelStat > 2 and trip the gate).
u.lo(np) = 1e-3;  u.up(np) = 1e3;
dq.lo(n) = 1e-9;  t.lo(n) = 1e-6;  w.lo(n) = 1e-3;
u.fx(np)$(ord(np) = 1 or ord(np) = card(np)) = u0;

* initial point: down-then-up excursion (measured min-kappa shape; amplitude
* 0.28 ~ the measured solution's 0.72..1.47 span). The flat start u = u0 sits
* exactly on the delta = 1/2 ceiling and CONOPT stalls there.
u.l(np) = u0*( 1 - 0.28*sin(2*pi*(ord(np)-1)/nEv) );
u.l(np)$(ord(np) = 1 or ord(np) = card(np)) = u0;
loop(n,
  t.l(n)  = sqr(u0)/( sum(np$(ord(np)=ord(n)), u.l(np))
                    * sum(np$(ord(np)=ord(n)+1), u.l(np)) );
  w.l(n)  = sqrt(t.l(n));
  dq.l(n) = abs( sum(np$(ord(np)=ord(n)+1), u.l(np))
               - sum(np$(ord(np)=ord(n)),   u.l(np)) );
);

Model volumePath / all /;
option nlp = conopt;
option limrow = 0, limcol = 0, solprint = off, sysout = off;
* DETERMINISM: single-threaded solve. With 4 threads the output was measured
* byte-identical over repeated runs on this machine, but parallel floating-
* point reduction order is not a portable guarantee; one thread is.
option threads = 1;
Solve volumePath using nlp minimizing obj;

* ---- gates ----------------------------------------------------------------
abort$(volumePath.solveStat <> %solveStat.normalCompletion%)
    "solver did not terminate normally", volumePath.solveStat;
abort$(volumePath.modelStat > 2)
    "no locally optimal solution", volumePath.modelStat;

Parameter uu(np), dQxWei(n), dQMWei(n);
uu(np) = u.l(np);
dQxWei(n) = Lbar*( sum(np$(ord(np)=ord(n)+1), uu(np))
                 - sum(np$(ord(np)=ord(n)),   uu(np)) );
dQMWei(n) = -t.l(n)*dQxWei(n);          # dQM = -p1(n)p1(n+1)dQx, pbar = 1

Scalar tot, rReal, dReal, volReal, closeErr, signWorst;
tot      = sum(n, (1+t.l(n))*dq.l(n));
rReal    = sum(n, (phiX + phiM*t.l(n))*dq.l(n)) / tot;
dReal    = sum(n, w.l(n)*dq.l(n)) / tot;
volReal  = sum(n, abs(dQxWei(n)));
closeErr = abs(sum(n, dQxWei(n)))/volTgtWad;
signWorst= smax(n, dQxWei(n)*dQMWei(n));

* tol: gates on RATIOS, all O(1). CONOPT's feasibility tolerance is ~1e-9;
* double-precision emission at 1e19-wei scale contributes ~1e-16 relative.
* 1e-8 sits between the two: loose enough that a converged solve passes,
* tight enough that any structural miss (wrong target, open loop) trips it.
Scalar tol / 1e-8 /;
abort$(closeErr > tol)                    "loop did not close",   closeErr;
abort$(abs(dReal - dStar) > tol)          "delta_trans missed",   dReal, dStar;
abort$(abs(rReal - phiBar*dStar) > tol)   "r^phi missed",         rReal;
abort$(abs(volReal/volTgtWad - 1) > tol)  "volume missed",        volReal;
abort$(signWorst >= 0)                    "a step is not a swap", signWorst;

* ---- emission: JSON for the Foundry bridge (stdJson-readable) -------------
file fj /volume_path.json/;  fj.pw = 4000;  put fj;
put '{' /;
* uint160/uint128 exceed the 53-bit double-exact ceiling: putting the Scalar
* would round (2^64 printed 384 wei off). Emit the compile-time STRINGS.
put '  "sqrtPriceX96": "%sqrtPriceX96%",' /;
put '  "liquidity": "%liquidityRaw%",' /;
put '  "txlVolumeRate": ', txlVolumeRate:0:0, ',' /;
put '  "phiXpips": ',      phiXpips:0:0, ',' /;
put '  "phiMpips": ',      phiMpips:0:0, ',' /;
put '  "nEvents": ',       nEv:0:0, ',' /;
put '  "deltaRealized": ', dReal:0:10, ',' /;
put '  "rPhiRealized": ',  rReal:0:10, ',' /;
put '  "dQx": [';
loop(n, put dQxWei(n):0:0; put$(ord(n)<nEv) ', '; );
put '],' /;
put '  "dQM": [';
loop(n, put dQMWei(n):0:0; put$(ord(n)<nEv) ', '; );
put ']' /;
put '}' /;
putclose fj;

file f /volume_path.txt/;  put f;
put '--- VolumePath solved ---------------------------------------' /;
put 'N events           = ', nEv:8:0 /;
put 'delta_trans target = ', dStar:14:10, '   realized = ', dReal:14:10 /;
put 'r^phi       target = ', (phiBar*dStar):14:10, '   realized = ', rReal:14:10 /;
put 'volume      target = ', volTgtWad:22:0, '   realized = ', volReal:22:0 /;
put 'closure (rel)      = ', closeErr:14:12 /;
put 'worst dQx*dQM      = ', signWorst:14:4, '  (must be < 0)' /;
put 'kappa = volTgt/L   = ', kappa:20:15 /;
put /;
put '  n         dQx(n) [wei]           dQM(n) [wei]         u(n+1)' /;
loop(n,
  put '  ', n.tl:3, dQxWei(n):24:0, dQMWei(n):24:0,
      sum(np$(ord(np)=ord(n)+1), uu(np)):16:9 /;
);
putclose f;
