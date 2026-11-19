#!/bin/bash
# TraitBlender imaging — one job YAML per array task (CPU node + Xvfb).
# Not for BioEncoder. Site accounts/paths via sbatch CLI or local/ wrapper.
#
#   export CODE_ROOT=...
#   # after make_jobs.sh: one list per scenario, e.g. manifests/imaging_balanced_bm.txt
#   export MANIFEST="$CODE_ROOT/manifests/imaging_balanced_bm.txt"
#   N=$(grep -cve '^\s*(#|$)' "$MANIFEST")
#   sbatch --export=ALL,CODE_ROOT,MANIFEST --account=... --partition=... --qos=... \
#     --array=1-"$N" \
#     --output="$CODE_ROOT/logs/%x_%A_%a.out" \
#     --error="$CODE_ROOT/logs/%x_%A_%a.err" \
#     "$CODE_ROOT/scripts/slurm/run_imaging.slurm"
#
#SBATCH --job-name=tb_imaging
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=12:00:00
#SBATCH --array=1-1

set -euo pipefail

: "${CODE_ROOT:?set CODE_ROOT}"

# Paths (override with env if needed).
# MANIFEST should be a per-scenario list from make_jobs.sh (imaging_<scenario>.txt).
MANIFEST="${MANIFEST:?set MANIFEST to manifests/imaging_<scenario>.txt}"
DRIVER="${DRIVER:-$CODE_ROOT/scripts/imaging/run_imaging_pipeline.py}"
mkdir -p "$CODE_ROOT/logs"

# Pick this array task's job YAML from the manifest (1-based line, skip blanks/comments)
CONFIG_REL=$(grep -vE '^\s*(#|$)' "$MANIFEST" | sed -n "${SLURM_ARRAY_TASK_ID}p")
CONFIG="$CODE_ROOT/$CONFIG_REL"
[[ -n "$CONFIG_REL" && -f "$CONFIG" ]] || {
  echo "No config for array task ${SLURM_ARRAY_TASK_ID} in $MANIFEST" >&2
  exit 1
}

# Read output.rendering_directory from the YAML (where PNGs/PLYs land)
OUT_DIR=$(grep -E '^\s*rendering_directory:' "$CONFIG" | head -1 \
  | sed -e 's/.*rendering_directory:[[:space:]]*//' -e 's/[\"'\'']//g')
mkdir -p "$OUT_DIR"

export CONFIG
cd "$CODE_ROOT"

echo "HOST=$(hostname) DATE=$(date -Is) TASK=${SLURM_ARRAY_TASK_ID}"
echo "CONFIG=$CONFIG"
echo "OUT_DIR=$OUT_DIR"

# Headless display + Blender (site modules; override in a local/ wrapper if needed)
module reset
module load Xvfb/21.1.14-GCCcore-13.3.0
module load Blender/5.1.2-linux-x86_64-CUDA-12.8.0

# Match Blender/OpenMP thread count to the Slurm CPU allocation
export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-16}"
BLENDER_THREADS="${SLURM_CPUS_PER_TASK:-16}"

# Compute nodes have no real X11 display; Blender/OpenGL still often need one.
# Xvfb provides a throwaway virtual screen so headless bpy doesn't fail to init.
xvfb-run -a -s "-screen 0 1920x1080x24" \
  blender --background \
    --threads "$BLENDER_THREADS" \
    --python "$DRIVER"
