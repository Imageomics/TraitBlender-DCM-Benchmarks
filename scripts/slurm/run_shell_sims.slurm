#!/bin/bash
# Shell BM trait sims — ape + phytools::fastBM → TraitBlender CSVs.
# Tips + ancestors → dataset/shell_bm/tabular/<morph>/rep_XX.csv
#
#   export CODE_ROOT=... DATA_ROOT=...
#   sbatch --account=... --partition=... --qos=... \
#     --output="$CODE_ROOT/logs/%x_%j.out" \
#     --error="$CODE_ROOT/logs/%x_%j.err" \
#     "$CODE_ROOT/scripts/slurm/run_shell_sims.slurm"
#
#SBATCH --job-name=shell_bm_sim
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:30:00

set -euo pipefail
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1

: "${CODE_ROOT:?set CODE_ROOT}"
: "${DATA_ROOT:?set DATA_ROOT}"
mkdir -p "${CODE_ROOT}/logs"

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate tb_sims

cd "$CODE_ROOT"
Rscript scripts/sim_traits/simulate_shell_bounded_bm.R "$DATA_ROOT"
