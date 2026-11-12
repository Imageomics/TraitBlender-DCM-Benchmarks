#!/bin/bash
# Tabular phylo sims (trees + tip traits) — one configs/tabular/*.yaml per array task.
# Not for TraitBlender imaging (separate slurm script later).
#
#   export CODE_ROOT=... DATA_ROOT=...
#   sbatch --account=... --partition=... --qos=... \
#     --output="$CODE_ROOT/logs/%x_%A_%a.out" \
#     --error="$CODE_ROOT/logs/%x_%A_%a.err" \
#     "$CODE_ROOT/scripts/slurm/run_tabular_sims.slurm"
#
#SBATCH --job-name=tabular_sims
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --array=1-3

set -euo pipefail

: "${CODE_ROOT:?set CODE_ROOT}"
: "${DATA_ROOT:?set DATA_ROOT}"

MANIFEST="${MANIFEST:-$CODE_ROOT/manifests/tabular.txt}"
mkdir -p "$CODE_ROOT/logs" "$DATA_ROOT"

CONFIG_REL=$(grep -vE '^\s*(#|$)' "$MANIFEST" | sed -n "${SLURM_ARRAY_TASK_ID}p")
CONFIG="$CODE_ROOT/$CONFIG_REL"

cd "$CODE_ROOT"
Rscript scripts/sim_traits/simulate_traits.R "$CONFIG" "$DATA_ROOT"
