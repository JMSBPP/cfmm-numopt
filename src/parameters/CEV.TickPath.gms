$include "gams-deps.inc"
$include "%GAMS_EVM_TRANSPORT_SRC%GdxComptimeHandshake.gms"
$funcLibIn Commands %GAMS_EVM_TRANSPORT_RPC%lib/exec/CommandDispatcher.so

Function broadcast_tick_path /Commands.broadcast_tick_path/;

$onText
==========================================================================
------------------> CEV.TickPath < -------------------------------------
  Spec: cfmm-vol-markets-spec/spec/models/sets/CEV.TickPath.md

  Two-pass hybrid (same file):
    Pass 1 (no src/build/tickPath.gdx): fill path, gdxWrite, $goto tickpath_handoff
      (broadcast_tick_path path-sidecar → external service; sync).
    Pass 2 (gdx present): $load at compile time, write ACK, stop.
  cwd: project root (as in `just gams …`); idir=src for local includes.
  Transport utils pin: GdxWriter + handshake (GAMS_EVM_TRANSPORT_SRC).
  Transport RPC pin: Commands.broadcast_tick_path (GAMS_EVM_TRANSPORT_RPC @ 1a112ba; APP_ADDRESS).
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

* ---------------------- Pass 1: generate snapshot + handoff ----------
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
  Snapshot: src/build/tickPath.gdx → tickpath_handoff → broadcast_tick_path
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
$goto tickpath_handoff

* ---------------------- Handoff: path sidecar + sync broadcast_tick_path ----------
$label tickpath_handoff
execute 'printf "%s\n" "src/build/tickPath.gdx" > build/.gdx-publish-path';
Scalar broadcastStatus;
broadcastStatus = broadcast_tick_path;
abort$(broadcastStatus <> 0) 'broadcast_tick_path failed';

$label cev_tickpath_done
