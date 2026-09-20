# UAV Swarm Security Simulation

Simulation-based framework for detecting malicious UAVs in a swarm using **GPS/RSSI consistency checks**, **GRiFFIN-style two-phase verification**, and a **Soft Actor-Critic (SAC)** policy that learns an adaptive Phase-1 detection threshold.

Built for **CS 797V — Artificial Intelligence for Cybersecurity** at [Wichita State University](https://www.wichita.edu/), **Spring 2026**, under **Dr. Mohamed Anis Aguida**.

## Motivation

Civil GPS is unencrypted and easy to spoof. In a UAV swarm, a malicious drone can report false positions and disrupt formation, navigation, or trust. Related work compares GPS-derived distances with independent ranging (e.g. RSSI / UWB) to catch inconsistencies ([GPS-spoofing detection for UAV swarms](https://arxiv.org/abs/2301.12766), [RSSI-based resilience under GNSS compromise](https://doi.org/10.1109/WiMob66857.2025.11257460)).

A **fixed mismatch threshold** fails across environments: too low in noisy urban settings (many false alarms), too high in clean settings (missed attacks). This project learns a **dynamic threshold** with SAC and evaluates the full Phase-1 + Phase-2 pipeline under multiple attack scenarios.

## What this repo contains

| Area | Description |
|------|-------------|
| **Phase 1** | GPS vs RSSI distance mismatch vs threshold θ |
| **Phase 2** | Jury / geometric verification (GRiFFIN-style majority reject) |
| **RL** | SAC learns continuous adjustments `Δθ` from receiver-side features |
| **Eval** | Static θ vs SAC θ; random, intelligent, On/Off, and gradual attacks |

For the full technical design (state, reward, simulation setup, results), see **[`TECHNICAL.md`](TECHNICAL.md)**.

## Repository layout

```text
code/              SAC training & evaluation (Python / notebooks)
data/              Detection + RL datasets
models/            Trained SAC models and MATLAB actor export
Matlab/            Phase-2 GRiFFIN attack sims and plots
datsetgeneration/  MATLAB dataset / early simulation generation
results/ figures/  Evaluation tables and figures
archive/           Older runs and supporting docs
TECHNICAL.md       Single technical overview of the project
```

## Quick start

### Train / evaluate SAC (Phase 1 RL)

```bash
cd code
python finalcode.py \
  --rl_path ../data/uav_rl_dataset_clean.csv \
  --det_path ../data/uav_detection_dataset-updated.csv \
  --out_dir ../models \
  --timesteps 100000
```

Trained artifacts used in this project live under `models/sac_lam2_005/`.

### Run Phase-2 MATLAB evaluations

Open the scripts under `Matlab/` (six Griffin scenarios, On/Off attacks, gradual activation).  
Update hard-coded `projectDir` / `resultsDir` paths to your local clone before running. Each sim folder includes `sacActorPredictMATLAB.m` and `sac_actor_export.mat` for SAC-driven Phase-1 thresholds.

## Key results (summary)

SAC learns environment-aware thresholds roughly ordered as:

**Perfect < Open < Suburban < DenseUrban**

Compared with a static θ = 10, benign exceedance drops sharply in noisier environments (about **71%** reduction in Suburban and **82%** in DenseUrban in the Phase-1 study). Phase-2 MATLAB evals then compare **static GRiFFIN** vs **SAC + GRiFFIN** under attack scenarios. Details and tables are in [`TECHNICAL.md`](TECHNICAL.md) and `results/` / `figures/`.

## Team

| Role | Name |
|------|------|
| Authors | [Qasim](https://github.com/qasim418), [Faraz](https://github.com/MFARAZ24) (collaborator) |
| Course | CS 797V — Artificial Intelligence for Cybersecurity |
| Institution | Wichita State University, School of Computing |
| Instructor | Dr. Mohamed Anis Aguida |
| Term | Spring 2026 |

## License / academic use

Course project code and results. Cite the repo and course if you reuse ideas or figures.
