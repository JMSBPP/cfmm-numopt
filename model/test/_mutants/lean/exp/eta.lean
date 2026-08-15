/- TEST-09 negative control for GATE-07, SECOND kind. NOT part of the Lake
   project, never imported, never built.

   `model/test/_mutants/lean/` is laid out as a drop-in LEAN4_SPEC_DIR, so

     make spec-preflight      LEAN4_SPEC_DIR=model/test/_mutants/lean
     make spec-preflight-band LEAN4_SPEC_DIR=model/test/_mutants/lean

   find `exp/eta.lean` HERE and must redden because the Lean gate REJECTS the
   declarations, not because a file is missing. Without this fixture the only
   proof that the two preflight targets consult the Lean leg is
   `LEAN4_SPEC_DIR=/nonexistent`, which reddens for the wrong reason — the D1
   failure mode: a check whose success is indistinguishable from its own absence.

   All four cited declarations are present, correctly named, and carry a REAL
   `sorry`. The names must be kept byte-identical to the ids in the Makefile's
   two `for ID in …` loops; if a rename ever desynchronises them the gate returns
   2 (not found) instead of 1 (sorry), and the rows below pin `nonzero` through
   make, so the mismatch shows up in the direct-invocation rows instead. -/
namespace CFMM.Eta

theorem pi_trader_half_zero_at_deltaI_star (n : Nat) : n + 0 = n := by
  sorry

theorem pi_trader_half_strictly_increasing_in_Δi (n : Nat) : n + 0 = n := by
  sorry

theorem pi_trader_half_band_min_at_left (n : Nat) : n + 0 = n := by
  sorry

theorem pi_trader_half_band_max_large_trade (n : Nat) : n + 0 = n := by
  sorry

end CFMM.Eta
