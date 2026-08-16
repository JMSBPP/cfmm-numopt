# cfmm-gams

The off-chain **GAMS prover** for the CFMM replication program — split out of
[`JMSBPP/cfmm-replicationPlank`](https://github.com/JMSBPP/cfmm-replicationPlank)
with its `model/` history preserved. The monorepo consumes it as a submodule
mounted at `gams/`.

## What is here

| Path | Contents |
|------|----------|
| `model/mev_tax_model_one/volume_path.gms` | **The VolumePath prover** — shock → swap-path JSON in exact EVM units |
| `model/mev_tax_model_one/notes.md` | The mathematical spec the prover implements |
| `docs/volume-path.md` | **The usage contract** — inputs, JSON schema, precision, failure modes |
| `model/BUILD.md` | Toolchain pin and build manifest |

## What it does

Given a shock — pool state `(sqrtPriceX96, liquidity)`, a target transactional
rate `txlVolumeRate`, the fee pair `(φ_X, φ_M)`, and a volume — the prover emits
`volume_path.json`: `N` signed swap quantities in wei that realize the target
fee revenue and return the pool to its starting price, with every claim gated
in-model (rate targets, volume, closure, swap-sign, solver status). Infeasible
shocks abort with a named reason, closed-form where possible. Same inputs +
same toolchain → byte-identical output. Full contract: `docs/volume-path.md`.

## Toolchain

GAMS **54.1.0** + **CONOPT 4.39**, linux x86_64.

## Build

```sh
make compile-gams   # action=c syntax check over every tracked .gms
make test-gams      # full prover self-test: gates + JSON validity + determinism
make clean-gams
```

## License

MIT — see [LICENSE](LICENSE).
