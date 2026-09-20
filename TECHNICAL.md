# Technical Overview — UAV Swarm Security Simulation

Single technical reference for the project idea, pipeline, RL design, and evaluation.  
Course project: **CS 797V AI for Cybersecurity**, Wichita State University, Spring 2026 (Dr. Mohamed Anis Aguida).

---

## 1. Problem

Detect **malicious / spoofing UAVs** inside a cooperative swarm.

Each UAV reports GPS positions. Independently, receivers can estimate distance from **RSSI** (path-loss model). If GPS-implied distance and RSSI-implied distance disagree beyond a threshold, the target looks suspicious.

**Challenge:** noise depends on environment and formation. A single static threshold θ:

- works in clean / open settings,
- creates many **false positives** in suburban / dense urban noise,
- or must be raised so high that attacks are missed.

**Approach:** keep a two-phase GRiFFIN-style detector, and replace the fixed Phase-1 θ with a **SAC-learned dynamic threshold**.

---

## 2. System pipeline

```text
Swarm simulation (N UAVs, T steps, env × formation)
        │
        ▼
Phase 1: |d_GPS − d_RSSI|  ≷  θ
        │  fail → suspicious
        │  pass → Phase 2
        ▼
Phase 2: receiver + 3 jury UAVs, geometric residual / majority reject
        │
        ▼
final_flag = phase1_fail OR phase2_fail
```

### Phase 1 — mismatch test

For receiver *r* and target *t*:

```text
delta_d = |d_gps(r,t) − d_rssi(r,t)|
phase1_fail = delta_d > θ
```

- **Static baseline:** θ = 10 (meters, project default).
- **SAC dynamic:** each receiver maintains `current_θ`, updated each step by the actor:  
  `θ ← clip(θ + Δθ, 1, 50)`, with `Δθ ∈ [−2, +2]`.

### Phase 2 — jury verification (finalized in `Matlab/`)

If Phase 1 passes, verify claimed GPS using **receiver + 3 juries**:

- Compute geometric residuals between claimed target position and verifier GPS distances (paper-style reported distances).
- **Majority reject:** Phase 2 fails if reject votes ≥ 3 (`juryRejectThreshold = 3`).
- Phase-2 geometric tolerance uses a static-scale γ (does not scale with SAC θ).

Early prototype Phase-2 (max-residual RSSI check) lives under `datsetgeneration/` for dataset generation history; **evaluation SoT is `Matlab/`**.

---

## 3. Simulation setup

| Parameter | Value |
|-----------|--------|
| UAVs (N) | 20 |
| Time steps (T) | 120 |
| Environments | 0 Perfect / Vacuum, 1 Open, 2 Suburban, 3 DenseUrban |
| Formations | 0 Horizontal, 1 Random-Matrix, 2 Circular |
| Scenario grid | 4 × 3 = 12 base scenarios |

Environments control GPS/RSSI noise and link quality; Perfect/Vacuum was added after course feedback as a zero-noise reference.

---

## 4. Datasets

Primary files under `data/`:

| File | Level | Use |
|------|--------|-----|
| `uav_detection_dataset-updated.csv` | receiver–target–time | Phase-1/2 labels, `delta_d`, juries, `final_flag` |
| `uav_rl_dataset_clean.csv` | receiver–time | SAC observations |
| `uav_rl_reward_dataset.csv` | derived | Reward / threshold studies |

RL training uses **benign targets only** for exceedance calibration (professor guidance): learn normal mismatch behavior across noise levels, not attack labels as the reward signal.

### SAC observation (9-D)

```text
σ_rssi_bar, σ_gps_bar, snr_bar, plr_bar,
relative_speed_bar, relative_height_bar,
trusted_count, trust_bar, current_threshold
```

---

## 5. Reinforcement learning (SAC)

Implemented in `code/finalcode.py` (Gymnasium env + Stable-Baselines3 SAC).

### Why SAC

Action is continuous (`Δθ`), so Soft Actor-Critic fits better than discrete DQN-style methods.

### Reward

```text
r = −λ1 (exceedance − α)² − λ2 (θ / Tmax) − λ3 (Δθ)²
```

| Symbol | Typical | Meaning |
|--------|---------|---------|
| α | 0.05 | Target benign exceedance rate |
| λ1 | 1.0 | Track α |
| λ2 | 0.05 (best run) | Prefer smaller θ |
| λ3 | 0.01 | Smooth actions |
| Tmin, Tmax | 1, 50 | Threshold bounds |

Best HPC config in this repo: **`sac_lam2_005`** (`models/sac_lam2_005/`).

### Learned mean thresholds (Phase-1 study)

| Environment | Mean SAC θ |
|-------------|------------|
| Perfect | ~1.0 |
| Open | ~9.9 |
| Suburban | ~18.5 |
| DenseUrban | ~30.4 |

Order matches noise: **Perfect < Open < Suburban < DenseUrban**.

### Benign exceedance vs static θ = 10

| Environment | Static | SAC | Reduction |
|-------------|--------|-----|-----------|
| Open | 0.085 | 0.087 | ~−2% (mixed) |
| Suburban | 0.272 | 0.080 | ~71% |
| DenseUrban | 0.516 | 0.093 | ~82% |

SAC helps most where a fixed threshold is too aggressive.

MATLAB export: `sac_actor_export.mat` + `sacActorPredictMATLAB.m` load the MLP actor for in-sim Phase-1 updates.

---

## 6. Phase-2 attack evaluation (`Matlab/`)

Finalized evaluations compare **Static GRiFFIN** vs **SAC Dynamic + GRiFFIN** under:

1. **Exact six Griffin scenarios** — random RSSI-oriented attacks and intelligent spoofing / jury manipulation cases  
2. **On/Off attacks** — intermittent malicious behavior  
3. **Gradual activation** — attack strength ramps over time  
4. **Aggregate plots** — balanced accuracy and θ trajectories across attack types  

Scripts emit static vs SAC metrics (`phase1_fail`, `phase2_fail`, `final_flag`, etc.). Point `projectDir` / `resultsDir` at your machine before running.

---

## 7. Code map

| Path | Role |
|------|------|
| `code/finalcode.py` | SAC train / eval entry point |
| `code/*.ipynb` | Exploration and analysis notebooks |
| `models/sac_lam2_005/` | Trained model, vecnormalize, actor export, MATLAB smoke tests |
| `Matlab/` | Final Phase-2 scenario sims and figures |
| `datsetgeneration/` | Dataset generation / early malicious sim prototypes |
| `results/`, `figures/` | Summaries and paper-style plots |
| `archive/` | Older balanced runs and supporting documents |

---

## 8. Related ideas (background reading)

- GPS spoofing detection for UAV swarms via GPS vs independent ranging: [arXiv:2301.12766](https://arxiv.org/abs/2301.12766)  
- RSSI / intra-fleet protocols under GNSS compromise: [WiMob 2025](https://doi.org/10.1109/WiMob66857.2025.11257460)  
- Position spoofing detection/mitigation in cooperative formations: [arXiv:2312.03787](https://arxiv.org/abs/2312.03787)  
- Instructor research context: distributed misbehavior detection in UAV flocks (Aguida, WSU)

This project is a **course simulation + RL extension**, not a reproduction of any single paper end-to-end.

---

## 9. Practical notes

- Train SAC with the cleaned RL CSV and benign-filtered detection rows.  
- Keep `VecNormalize` stats aligned when evaluating or exporting the actor.  
- MATLAB Phase-2 scripts currently contain absolute Windows paths; update them locally.  
- Prefer `models/sac_lam2_005` as the reference policy for static-vs-SAC comparisons.
