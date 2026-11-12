#!/bin/bash
# TraitBlender imaging — one job YAML per array task (CPU / software GL).
# Not for BioEncoder. Site accounts/paths via sbatch CLI or local/ wrapper.
#
#   export CODE_ROOT=...
#   # after scripts/imaging/make_jobs.sh wrote manifests/imaging.txt
#   N=$(grep -cve '^\s*(#|$)' "$CODE_ROOT/manifests/imaging.txt")
#   sbatch --account=... --partition=... --qos=... --array=1-"$N" \
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

MANIFEST="${MANIFEST:-$CODE_ROOT/manifests/imaging.txt}"
DRIVER="${DRIVER:-$CODE_ROOT/scripts/imaging/run_imaging_pipeline.py}"
mkdir -p "$CODE_ROOT/logs"

CONFIG_REL=$(grep -vE '^\s*(#|$)' "$MANIFEST" | sed -n "${SLURM_ARRAY_TASK_ID}p")
CONFIG="$CODE_ROOT/$CONFIG_REL"
[[ -n "$CONFIG_REL" && -f "$CONFIG" ]] || {
  echo "No config for array task ${SLURM_ARRAY_TASK_ID} in $MANIFEST" >&2
  exit 1
}

OUT_DIR=$(grep -E '^\s*rendering_directory:' "$CONFIG" | head -1 \
  | sed -e 's/.*rendering_directory:[[:space:]]*//' -e 's/[\"'\'']//g')
mkdir -p "$OUT_DIR"

if [[ -f "$OUT_DIR/rendering_log.txt" ]]; then
  echo "SKIP (has rendering_log.txt): $OUT_DIR"
  exit 0
fi

export CONFIG
cd "$CODE_ROOT"

echo "HOST=$(hostname) DATE=$(date -Is) TASK=${SLURM_ARRAY_TASK_ID}"
echo "CONFIG=$CONFIG"
echo "OUT_DIR=$OUT_DIR"

# Site modules (Xvfb / Blender / Mesa) — override in local/ wrapper if needed.
module reset
module load Xvfb/21.1.14-GCCcore-13.3.0
module load Blender/5.1.2-linux-x86_64-CUDA-12.8.0
module load Mesa/24.1.3-GCCcore-13.3.0

export LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-1}"
export GALLIUM_DRIVER="${GALLIUM_DRIVER:-llvmpipe}"
export MESA_LOADER_DRIVER_OVERRIDE="${MESA_LOADER_DRIVER_OVERRIDE:-llvmpipe}"
if [[ -n "${EBROOTMESA:-}" ]]; then
  export LD_LIBRARY_PATH="${EBROOTMESA}/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  export LIBGL_DRIVERS_PATH="${EBROOTMESA}/lib/dri${LIBGL_DRIVERS_PATH:+:$LIBGL_DRIVERS_PATH}"
fi
export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-16}"
BLENDER_THREADS="${SLURM_CPUS_PER_TASK:-16}"

xvfb-run -a -s "-screen 0 1920x1080x24" \
  blender --background \
    --threads "$BLENDER_THREADS" \
    --python "$DRIVER"
