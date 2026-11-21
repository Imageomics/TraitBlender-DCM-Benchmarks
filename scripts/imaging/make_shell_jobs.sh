#!/usr/bin/env bash
# Build TraitBlender job YAMLs for shell_bm (tips + ancestors).
# Login-safe. No MorphoWeave SSM required.
#
# Expects tabular CSVs from scripts/sim_traits/simulate_shell_bounded_bm.R:
#   $DATA_ROOT/shell_bm/tabular/<shell_*trait>/rep_XX.csv
#
#   export CODE_ROOT=... DATA_ROOT=...
#   bash scripts/imaging/make_shell_jobs.sh
#
set -euo pipefail

: "${CODE_ROOT:?set CODE_ROOT}"
: "${DATA_ROOT:?set DATA_ROOT}"

RENDER_ROOT="${RENDER_ROOT:-$DATA_ROOT}"
SCEN="shell_bm"
MORPHS="${MORPHS:-shell_1trait shell_3trait shell_5trait}"
TEMPLATE="${CODE_ROOT}/configs/traitblender/shell_default.yaml"
JOB_DIR="${CODE_ROOT}/configs/traitblender/jobs"
MANIFEST="${CODE_ROOT}/manifests/imaging_${SCEN}.txt"

[[ -f "$TEMPLATE" ]] || { echo "missing $TEMPLATE" >&2; exit 1; }
mkdir -p "$JOB_DIR" "$(dirname "$MANIFEST")"
: > "$MANIFEST"

n=0
for morph in $MORPHS; do
  tab_dir="${DATA_ROOT}/${SCEN}/tabular/${morph}"
  [[ -d "$tab_dir" ]] || { echo "missing $tab_dir (run shell sims first)" >&2; exit 1; }
  shopt -s nullglob
  for csv in "$tab_dir"/rep_*.csv; do
    sid=$(basename "$csv" .csv)
    job_id="${SCEN}__${morph}__${sid}"
    render_dir="${RENDER_ROOT}/${SCEN}/renders/${morph}/${sid}"
    out_yaml="${JOB_DIR}/${job_id}.yaml"
    mkdir -p "$render_dir"
    sed \
      -e "s|{csv}|${csv//&/\\&}|g" \
      -e "s|{render_dir}|${render_dir//&/\\&}|g" \
      "$TEMPLATE" > "$out_yaml"
    # path relative to CODE_ROOT for run_imaging.slurm
    echo "configs/traitblender/jobs/${job_id}.yaml" >> "$MANIFEST"
    n=$((n + 1))
  done
  shopt -u nullglob
done

echo "Wrote $n shell job YAMLs"
echo "Manifest -> $MANIFEST"
