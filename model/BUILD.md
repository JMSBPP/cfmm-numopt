# Build Manifest

One model: `model/mev_tax_model_one/volume_path.gms` (the VolumePath prover).
Spec: `model/mev_tax_model_one/notes.md`. Usage contract: `docs/volume-path.md`.

Toolchain pin: **GAMS 54.1 + CONOPT 4.39** (determinism guarantee is per-toolchain;
see docs/volume-path.md §3).

- `make compile-gams` — `action=c` syntax check of every tracked `.gms`
- `make test-gams`    — `action=ce` prover self-test: in-model gates + JSON
  validity + byte-identical double run
- `make clean-gams`

GAMS writes listings/scratch to the *invocation* working directory; both targets
run from the model's own directory with `scrdir=build`, so all artifacts land in
`model/mev_tax_model_one/build/` (gitignored).
