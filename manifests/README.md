# Imaging manifests

One file per tabular / imaging scenario. Each line is a job YAML path relative to `CODE_ROOT`.

| File | Scenario |
|------|----------|
| `imaging_balanced_bm.txt` | Brownian |
| `imaging_balanced_ou.txt` | Regime OU |
| `imaging_pagel_lambda_bm.txt` | Pagel’s λ |

`make_jobs.sh` rewrites **only** the manifests for scenarios listed in `SCENARIOS`. Adding Shell later means a new `imaging_<shell_scenario>.txt` without touching these.

Submit with `MANIFEST` set, e.g. `export MANIFEST=$CODE_ROOT/manifests/imaging_balanced_bm.txt`.
