# UAV Swarm Security Simulation

Simulation-based UAV swarm security framework using GPS/RSSI mismatch detection, GRiFFIN-style Phase 1 / Phase 2 verification, and SAC-based adaptive threshold learning.

## Project Overview

- **Phase 1:** GPS vs RSSI distance mismatch with a detection threshold
- **Phase 2:** Jury / geometric verification (GRiFFIN-style)
- **RL (SAC):** Learn a dynamic Phase 1 threshold across environments and formations
- **Evaluation:** Static vs SAC threshold comparisons and attack-scenario MATLAB tests

## Repository Structure

```text
archive/           Earlier RL runs and archived models
code/              SAC training/eval scripts and notebooks (see finalcode.py)
data/              Detection and RL datasets
datsetgeneration/  MATLAB dataset generation + Phase 2 malicious-data pipelines
Matlab/            Faraz Phase 2 attack scenarios, On/Off, gradual activation, plots
figures/           Paper-style figures
models/            Trained SAC models and exports
results/           Evaluation summaries and metrics
```

## Remotes

- Primary: `origin` → https://github.com/qasim418/uav-swarm-security-simulation.git
- Collaborator backup: `collaborator` → https://github.com/MFARAZ24/Swarm-UAV-Security.git

New work should land on feature branches against `origin`.
