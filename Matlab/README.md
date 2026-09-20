# Matlab — finalized Phase 2 (Faraz)

This folder is the **Phase 2 source of truth**.

## Contents

- `Code for the exact six Griffin test scenarios/` — static vs SAC GRiFFIN sims + plots
- `Code with OnOFF attacks/` — On/Off attack evaluation
- `Code with same six test but Gradual Activation/` — gradual activation attacks
- `Other Plotting such as balance accuracy/` — cross-attack metric plots

Each simulation folder includes:

- Griffin Phase 1 + Phase 2 (jury majority) logic
- `sacActorPredictMATLAB.m` + `sac_actor_export.mat` to drive **Phase 1** dynamic thresholds from the trained SAC actor

## Note on paths

Scripts currently hard-code paths like:

`D:\WSU\3rd Semester\CS - 797Y - AI for CS\Project`

Update `projectDir` / `resultsDir` to your local clone before running.

## Not here

Early Phase 2 / RL CSV generation lives under `../datsetgeneration/` (Qasim). Phase 1 training lives under `../code/finalcode.py` and `../models/`.
