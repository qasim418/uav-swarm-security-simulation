# UAV Swarm Security Simulation

Simulation-based UAV swarm security: GPS/RSSI mismatch (Phase 1), GRiFFIN-style jury verification (Phase 2), and SAC adaptive thresholds.

## Ownership (important)

See [`OWNERSHIP.md`](OWNERSHIP.md) for the full map. Short version:

- **Phase 1 (Qasim):** `code/finalcode.py`, `data/`, `models/`, `results/`, `figures/`
- **Phase 2 final (Faraz):** `Matlab/`
- **Early Phase 2 / RL CSV gen (Qasim):** `datsetgeneration/` (kept for history/data gen, not final Phase 2)

## Repository structure

```text
OWNERSHIP.md       Who owns Phase 1 vs Phase 2
code/              SAC training/eval (Phase 1)
data/              Detection + RL datasets
models/            Trained SAC models
results/ figures/  Phase 1 evaluation outputs
Matlab/            Finalized Phase 2 GRiFFIN sims + plots (Faraz)
datsetgeneration/  Early Phase 2 + RL dataset generation (Qasim)
archive/           Older runs + Faraz Phase 1 notebook for review
```

## Remotes

- Primary: `origin` → https://github.com/qasim418/uav-swarm-security-simulation.git
- Collaborator backup: `collaborator` → https://github.com/MFARAZ24/Swarm-UAV-Security.git

New work should land on feature branches against `origin`.
