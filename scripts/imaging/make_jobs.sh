#!/usr/bin/env bash
# Build one TraitBlender job YAML per (scenario × morph × sim).
# Uses full tabular CSVs (tips + ancestral / internal nodes).
# Login-safe (light shell only).
#
# One manifest per scenario (rewritten only for scenarios in SCENARIOS):
#   manifests/imaging_<scenario>.txt
# Other scenario manifests are left alone — safe to add Shell later without
# wiping MorphoWeave lists (and vice versa).
#
# Required:
#   CODE_ROOT  — this code repo
#   DATA_ROOT  — dataset root (trees/, balanced_bm/, …)
#   SSM_ROOT   — parent of MorphoWeave SSM dirs (not on HF)
#
# Optional:
#   RENDER_ROOT — where renders go (default: DATA_ROOT)
#   SCENARIOS   — default: balanced_bm balanced_ou pagel_lambda_bm
#   TEMPLATES   — default: the three MorphoWeave morph ids
#
#   export CODE_ROOT=... DATA_ROOT=... SSM_ROOT=...
#   bash scripts/imaging/make_jobs.sh
#
set -euo pipefail

# Fail fast if the three path roots are missing
: "${CODE_ROOT:?set CODE_ROOT}"
: "${DATA_ROOT:?set DATA_ROOT}"
: "${SSM_ROOT:?set SSM_ROOT (MorphoWeave SSM parent dir)}"

# Defaults: write renders next to the dataset; all three MorphoWeave scenarios × morphs
RENDER_ROOT="${RENDER_ROOT:-$DATA_ROOT}"
SCENARIOS="${SCENARIOS:-balanced_bm balanced_ou pagel_lambda_bm}"
TEMPLATES="${TEMPLATES:-vertebra_3000_smooth mus_musculus_cranium_v1 primates_multitaxon_second_mandibular_molar_v1}"

JOB_DIR="${CODE_ROOT}/configs/traitblender/jobs"
MANIFEST_DIR="${CODE_ROOT}/manifests"
TEMPLATE_ROOT="${CODE_ROOT}/configs/traitblender"

mkdir -p "$JOB_DIR" "$MANIFEST_DIR"

# Fill templates → job YAMLs + per-scenario manifests
# Each MorphoWeave template has placeholders: {csv} {render_dir} {ssm_dir}.
# Dataset CSVs are tips (t1…) plus internal nodes (numeric ids); all are rendered.
n_jobs_total=0
for scen in $SCENARIOS; do
  # Only this scenario's list is cleared/rewritten; other manifests stay as-is
  manifest="${MANIFEST_DIR}/imaging_${scen}.txt"
  : > "$manifest"

  tabular_dir="${DATA_ROOT}/${scen}/tabular"
  n_scen=0

  for csv in "$tabular_dir"/*.csv; do
    # Skip the literal glob if the directory is empty
    [[ -f "$csv" ]] || continue
    # Sim id from filename, e.g. sig2_01__rep_01.csv → sig2_01__rep_01
    sid=$(basename "$csv" .csv)

    for morph in $TEMPLATES; do
      tmpl="${TEMPLATE_ROOT}/${morph}.yaml"
      # SSM library for this morph lives under SSM_ROOT/<morph>/
      ssm_dir="${SSM_ROOT}/${morph}"
      [[ -f "$tmpl" ]] || { echo "missing template: $tmpl" >&2; exit 1; }
      [[ -d "$ssm_dir" ]] || { echo "missing SSM dir: $ssm_dir" >&2; exit 1; }

      # Stable job id used for YAML name, render folder, and Slurm array mapping
      job_id="${scen}__${morph}__${sid}"
      render_dir="${RENDER_ROOT}/${scen}/renders/${morph}/${sid}"
      out_yaml="${JOB_DIR}/${job_id}.yaml"
      mkdir -p "$render_dir"

      # Copy template → job YAML with the three paths filled in.
      # ${var//&/\\&} escapes & so sed does not treat it as a backreference.
      sed \
        -e "s|{csv}|${csv//&/\\&}|g" \
        -e "s|{render_dir}|${render_dir//&/\\&}|g" \
        -e "s|{ssm_dir}|${ssm_dir//&/\\&}|g" \
        "$tmpl" > "$out_yaml"

      # Manifest lines are relative to CODE_ROOT; run_imaging.slurm reads them
      # in order as Slurm array tasks 1..N for this scenario only
      echo "configs/traitblender/jobs/${job_id}.yaml" >> "$manifest"
      n_scen=$((n_scen + 1))
      n_jobs_total=$((n_jobs_total + 1))
    done
  done

  echo "scenario ${scen}: ${n_scen} jobs -> ${manifest}"
done

echo "Wrote ${n_jobs_total} job configs -> ${JOB_DIR}"
echo "Submit one array per scenario, e.g.:"
echo "  MANIFEST=\$CODE_ROOT/manifests/imaging_balanced_bm.txt"
echo "  N=\$(grep -cve '^[[:space:]]*\\(#\\|$\\)' \"\$MANIFEST\")"
echo "  sbatch --export=ALL,CODE_ROOT,MANIFEST --array=1-\$N ... \$CODE_ROOT/scripts/slurm/run_imaging.slurm"
