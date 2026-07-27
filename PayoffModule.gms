$title PayoffModule registry
$eolcom #
# REGISTRY ONLY — this file deliberately does NOT $include the per-theorem files.
#
# Why: every per-theorem file declares its own fixture (iCfg, LbarQ128, DICfgQ128,
# diProbeA/B, inputD/targetD/sourceD, theoremNameSet, ...) plus its own Model,
# Equation payoffEq and Variables piVal/di. Those names are intentionally reused
# across theorems because each theorem is a DIFFERENT numerical fixture — e.g.
# zero_slippage runs L̄=1, Δ^I=0.1 while band_monotone_large runs L̄=0.1, Δ^I=1.0.
#
# GAMS has a single global symbol namespace, so $include-ing two theorem files
# into one compilation unit raises $194 (symbol redefined) and $171 (domain
# violation) — and would only get worse as more theorems land.
#
# Architecture: each per-theorem file under payoff/ is an INDEPENDENT execution
# unit with its own driver under test/. `make compile-gams` compiles each one
# separately and `make test-gams` executes each driver separately, so per-theorem
# asserts still gate the build — without sharing a namespace.
#
# Registered theorem units (payoff/ source -> test/ driver):
#   eta_pi_trader_zero_slippage.gms       -> test/PayoffZeroSlippageTest.gms
#   eta_pi_trader_band_monotone_large.gms -> test/PayoffBandMonotoneLargeTest.gms
#
# Future cycles: add the payoff/ file AND its test/ driver, then list the pair here.

display "PayoffModule: registry only — see test/Payoff*Test.gms for the per-theorem units.";
