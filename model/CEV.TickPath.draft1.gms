$include CEV.TickStrikes.draft1.gms

$onText
==========================================================================
------------------> CEV.TickPath < -------------------------------------
  Spec: cfmm-vol-markets-spec/spec/models/sets/CEV.TickPath.md
  Model: model/CEV.TickPath.draft1.gms
==========================================================================
$offText

$onText
===============================================================================
--------------------------------> INPUTS < -----------------------------------
==============================================================================
$offText

* ---------------------- \(W\)
Scalar Window /86400/;
Scalar dtBar;
dtBar = Window / max(nStrikes - 1, 1);

* Reproducible draws for draft1.
execseed = 314159;

$onText
==========================================================================
-------------------------> OUTPUTS < ------------------------------
  |TickPath| = nStrikes; step j uses localTickDrift(j), localTickVol(j).
  Δi = toTickSpace(μ)·dt + σ·ΔW,  ΔW = √dt · ε,  ε ~ N(0,1).
==========================================================================
$offText

Set TickPath(strikeIdx);
TickPath(strikeIdx) = no;

Parameter pathTickVal(strikeIdx);
pathTickVal(strikeIdx) = 0;

Scalar iPath, epsDraw, dW, dTick;

iPath = tickStrikeVal('1');

loop(strikeIdx$TickStrikes(strikeIdx),
   TickPath(strikeIdx) = yes;
   pathTickVal(strikeIdx) = iPath;

   epsDraw = normal(0, sqrt(TickSpacing));
   dW      = sqrt(dtBar) * epsDraw;
   dTick   = toTickSpace(localTickDrift(strikeIdx)) * dtBar
             + localTickVol(strikeIdx) * dW;
   iPath   = max(MIN_TICK, min(MAX_TICK, iPath + dTick));
);

display Window, dtBar, nStrikes, pathTickVal;
