$include "gams-deps.inc"
$include "%GAMS_EVM_TRANSPORT_SRC%GdxComptimeHandshake.gms"

$onText
==========================================================================
------------------> CEV.TickPath < -------------------------------------
  Spec: cfmm-vol-markets-spec/spec/models/sets/CEV.TickPath.md

  Two-pass hybrid (same file):
    Pass 1 (no src/build/tickPath.gdx): fill path, gdxWrite, re-invoke GAMS on self.
    Pass 2 (gdx present): $load at compile time, write ACK, stop.
  cwd: project root (as in `just gams …`); idir=src for local includes.
  Transport: pinned gams-evm-transport via gams-deps (GdxWriter + handshake).
==========================================================================
$offText

* ---------------------- Pass 2: comptime load + ACK, then stop ----------
$if not exist src/build/tickPath.gdx $goto tickpath_pass1

$gdxIn src/build/tickPath.gdx
Set TickPath(*);
Parameter pathTickVal(*);
$load TickPath pathTickVal
$gdxIn

$batInclude "%GAMS_EVM_TRANSPORT_SRC%gdxHandshakeWriteAck.gms" src/build/tickPath.ack "GdxComptimeHandshake pass2 ACK: loaded src/build/tickPath.gdx"

display 'CEV.TickPath pass2: loaded from src/build/tickPath.gdx', pathTickVal;
$goto cev_tickpath_done

* ---------------------- Pass 1: generate snapshot + re-compile ----------
$label tickpath_pass1

$if not declared TickStrikes $include parameters/CEV.TickStrikes.gms

$if declared TickPath $goto cev_tickpath_done

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
  Snapshot: src/build/tickPath.gdx → pass 2 $load; ACK: src/build/tickPath.ack
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
   iPath   = normTickVal(max(MIN_TICK, min(MAX_TICK, iPath + dTick)), TickSpacing);
);

display Window, dtBar, nStrikes, pathTickVal;

gdxWrite('src/build/tickPath.gdx') TickPath, pathTickVal;

execute.checkErrorLevel
   'gams src/parameters/CEV.TickPath.gms action=ce o=src/build/parameters_CEV_TickPath_pass2.lst scrdir=src/build idir=src:%GAMS_EVM_TRANSPORT_SRC% lo=3';

$batInclude "%GAMS_EVM_TRANSPORT_SRC%gdxHandshakeEnsureAck.gms" src/build/tickPath.ack "GdxComptimeHandshake pass1 ACK: src/build/tickPath.gdx written"

$label cev_tickpath_done
