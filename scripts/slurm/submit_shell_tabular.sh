#!/usr/bin/env bash
# Submit shell BM tabular sims (TraitBlender CSVs). Does not start imaging.
#
#   bash scripts/slurm/submit_shell_tabular.sh
#
set -euo pipefail

export CODE_ROOT="${CODE_ROOT:-/home/calebc22/projects/TraitBlender-DCM-Benchmarks/code}"
export DATA_ROOT="${DATA_ROOT:-/home/calebc22/projects/TraitBlender-DCM-Benchmarks/dataset}"

ACCOUNT="${ACCOUNT:-imageomics-biosci}"
PARTITION="${PARTITION:-normal_q}"
QOS="${QOS:-tc_normal_base}"

mkdir -p "$CODE_ROOT/logs" "$DATA_ROOT/shell_bm"

echo "CODE_ROOT=$CODE_ROOT"
echo "DATA_ROOT=$DATA_ROOT"
echo "Submitting shell_bm tabular sims…"

jid=$(sbatch --parsable \
  --account="$ACCOUNT" \
  --partition="$PARTITION" \
  --qos="$QOS" \
  --export=ALL,CODE_ROOT,DATA_ROOT \
  --output="$CODE_ROOT/logs/%x_%j.out" \
  --error="$CODE_ROOT/logs/%x_%j.err" \
  "$CODE_ROOT/scripts/slurm/run_shell_sims.slurm")

echo "submitted job $jid"
echo "CSVs will land under: $DATA_ROOT/shell_bm/tabular/shell_{1,3,5}trait/rep_XX.csv"
echo "After it finishes, imaging is: bash scripts/imaging/make_shell_jobs.sh && sbatch run_imaging.slurm"
