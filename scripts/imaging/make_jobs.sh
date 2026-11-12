#!/usr/bin/env bash
# Build tip-only CSVs + TraitBlender job YAMLs from tabular sims.
# Safe on login (light shell only).
#
# Required env:
#   CODE_ROOT   — this code repo (GitHub)
#   DATA_ROOT   — dataset root (HF working copy): trees/, <tabular_id>/, …
#   SSM_ROOT    — MorphoWeave SSM databases (not shipped on HF; site path)
#
# Optional:
#   RENDER_ROOT — where renders land (default: DATA_ROOT). Use /projects/… for heavy mesh/PNG output.
#   TEMPLATES   — space-separated ids matching configs/traitblender/<id>.yaml
#   SCENARIOS   — space-separated tabular ids (default: all three)
#
#   export CODE_ROOT=... DATA_ROOT=... SSM_ROOT=...
#   bash scripts/imaging/make_jobs.sh
#
set -euo pipefail

: "${CODE_ROOT:?set CODE_ROOT}"
: "${DATA_ROOT:?set DATA_ROOT}"
: "${SSM_ROOT:?set SSM_ROOT (MorphoWeave SSM parent dir)}"

RENDER_ROOT="${RENDER_ROOT:-$DATA_ROOT}"
SCENARIOS="${SCENARIOS:-balanced_bm balanced_ou pagel_lambda_bm}"
TEMPLATES="${TEMPLATES:-vertebra_3000_smooth mus_musculus_cranium_v1 primates_multitaxon_second_mandibular_molar_v1}"

JOB_DIR="${CODE_ROOT}/configs/traitblender/jobs"
MANIFEST="${CODE_ROOT}/manifests/imaging.txt"
TEMPLATE_ROOT="${CODE_ROOT}/configs/traitblender"

mkdir -p "$JOB_DIR" "$(dirname "$MANIFEST")"
: > "$MANIFEST"

# Tip-only tables for TraitBlender (tabular/ may also contain internal nodes).
for scen in $SCENARIOS; do
  src="${DATA_ROOT}/${scen}/tabular"
  tips="${DATA_ROOT}/${scen}/tabular_tips"
  mkdir -p "$tips"
  shopt -s nullglob
  for csv in "$src"/*.csv; do
    base=$(basename "$csv")
    awk -F',' 'NR==1 || $1 ~ /^"?t[0-9]+"?$/' "$csv" > "$tips/$base"
  done
  shopt -u nullglob
  echo "tips: ${scen} -> $(ls "$tips"/*.csv 2>/dev/null | wc -l) files"
done

for scen in $SCENARIOS; do
  tips_dir="${DATA_ROOT}/${scen}/tabular_tips"
  shopt -s nullglob
  for csv in "$tips_dir"/*.csv; do
    sid=$(basename "$csv" .csv)
    for morph in $TEMPLATES; do
      tmpl="${TEMPLATE_ROOT}/${morph}.yaml"
      ssm_dir="${SSM_ROOT}/${morph}"
      [[ -f "$tmpl" ]] || { echo "missing template: $tmpl" >&2; exit 1; }
      [[ -d "$ssm_dir" ]] || { echo "missing SSM dir: $ssm_dir" >&2; exit 1; }

      job_id="${scen}__${morph}__${sid}"
      render_dir="${RENDER_ROOT}/${scen}/renders/${morph}/${sid}"
      out_yaml="${JOB_DIR}/${job_id}.yaml"
      mkdir -p "$render_dir"

      csv_esc=${csv//&/\\&}
      rd_esc=${render_dir//&/\\&}
      ssm_esc=${ssm_dir//&/\\&}
      sed -e "s|{csv}|${csv_esc}|g" \
          -e "s|{render_dir}|${rd_esc}|g" \
          -e "s|{ssm_dir}|${ssm_esc}|g" \
          "$tmpl" > "$out_yaml"

      echo "configs/traitblender/jobs/${job_id}.yaml" >> "$MANIFEST"
    done
  done
  shopt -u nullglob
done

n=$(grep -cve '^\s*$' "$MANIFEST" || true)
echo "Wrote ${n} job configs -> ${JOB_DIR}"
echo "Manifest: ${MANIFEST}"
echo "Next: sbatch with scripts/slurm/run_imaging.slurm (set CODE_ROOT / array size = ${n})"
