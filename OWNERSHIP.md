# Ownership map (Phase 1 vs Phase 2)

This repo combines two workstreams. Use this as the source-of-truth map.

## Phase 1 — Qasim (RL / dynamic threshold)

Keep these as the Phase 1 source of truth:

| Path | Role |
|------|------|
| [`code/finalcode.py`](../code/finalcode.py) | SAC trainer / HPC configs |
| [`code/updatedcode.ipynb`](../code/updatedcode.ipynb) | Phase 1 exploration notebook (your version) |
| [`code/evaluationtest.ipynb`](../code/evaluationtest.ipynb) | Eval notebook |
| [`code/UAV_*Context.md`](../code/) | Project context docs |
| [`data/`](../data/) | RL / detection CSVs |
| [`models/sac_lam2_005/`](../models/sac_lam2_005/) | Trained SAC model + vecnormalize |
| [`results/`](../results/) / [`figures/`](../figures/) | Phase 1 eval summaries and figures |
| [`archive/`](../archive/) | Older SAC balanced runs and archives |

Faraz’s later SAC notebook edit is preserved for review only at:

[`archive/phase1_review_from_faraz/updatedcode_faraz_UpdatedSAC.ipynb`](phase1_review_from_faraz/updatedcode_faraz_UpdatedSAC.ipynb)

Duplicate SAC CSVs/zips that were re-added under `code/` were removed; use `archive/` + `data/` + `models/` instead.

## Phase 2 — Faraz (finalized GRiFFIN evaluation)

Keep these as the Phase 2 source of truth:

| Path | Role |
|------|------|
| [`Matlab/`](../Matlab/) | Final Phase 2 sims + plots (six Griffin scenarios, On/Off, gradual activation, balanced-accuracy plots) |

Faraz’s sims compare **static GRiFFIN** vs **SAC dynamic Phase 1 θ** with paper-style Phase 2 majority jury voting.

### Early Phase 2 / data generation (Qasim, not final)

[`datsetgeneration/`](../datsetgeneration/) is **early Phase 2 + RL dataset generation**. Useful for reproducing training CSVs. Do **not** treat it as the finalized Griffin Phase 2 pipeline — that lives under `Matlab/`.

## Shared / review

- `README.md` at repo root describes the combined layout.
- Faraz’s MATLAB scripts still hard-code `D:\WSU\...` paths; point them at this repo (or local result folders) before running.
