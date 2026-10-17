$include CEV.TickStrikes.draft1.gms

$onText
==========================================================================
------------------> CEV.TickPath < -------------------------------------
  Spec: cfmm-vol-markets-spec/spec/models/sets/CEV.TickPath.md
  Math: Window / Wiener / TickDynamics in sets/CEV.md
  Consumes: localTickVol, localTickDrift, TickStrikes (nStrikes)
==========================================================================
$offText

$onText
==========================================================================
------------------> PATH TIME GRID < -----------------------------------
==========================================================================
$offText

* Window from CEV.md PRE-REQ (seconds).
Scalar Window /86400/;
Scalar dtBar;
dtBar = Window / max(nStrikes - 1, 1);

* Reproducible draws for draft1.
execseed = 314159;

$onText
==========================================================================
------------------> TICK PATH GENERATOR < ------------------------------
  |TickPath| = nStrikes; step j uses localTickDrift(j), localTickVol(j).
  Δi = toTickSpace(μ)·dt + σ·ΔW,  ΔW = √dt · ε,  ε ~ N(0,1).
==========================================================================
$offText

Set TickPath(strikeIdx);
TickPath(strikeIdx) = no;

Parameter pathTickVal(strikeIdx);
pathTickVal(strikeIdx) = 0;

Scalar iPath, epsDraw, dW, dTick;

* Active strikes are strikeIdx 1..nStrikes; start at first tickVal.
iPath = tickVal('1');

loop(strikeIdx$TickStrikes(strikeIdx),
   TickPath(strikeIdx) = yes;
   pathTickVal(strikeIdx) = iPath;

   epsDraw = normal(0, 1);
   dW      = sqrt(dtBar) * epsDraw;
   dTick   = toTickSpace(localTickDrift(strikeIdx)) * dtBar
             + localTickVol(strikeIdx) * dW;
   iPath   = max(MIN_TICK, min(MAX_TICK, iPath + dTick));
);

display Window, dtBar, nStrikes, pathTickVal;
