#!/usr/bin/env bash
# Submit shell_bm TraitBlender imaging — maximize wall-clock throughput.
# Rebuilds job YAMLs from shell_default.yaml, then submits the array.
# One collective email (not per array task) via a tiny afterany notify job.
#
#   bash scripts/slurm/submit_shell_imaging.sh
#
# Defaults: all 75 array tasks eligible at once, 16 CPUs each (Blender/OMP
# match Slurm allocation), long walltime for Cycles + tips/ancestors.
#
set -euo pipefail

export CODE_ROOT="${CODE_ROOT:-/home/calebc22/projects/TraitBlender-DCM-Benchmarks/code}"
export DATA_ROOT="${DATA_ROOT:-/home/calebc22/projects/TraitBlender-DCM-Benchmarks/dataset}"
# Renders stay in the project dataset (same tree as tabular). Do not default to /scratch.
export RENDER_ROOT="${RENDER_ROOT:-$DATA_ROOT}"
export MANIFEST="${MANIFEST:-$CODE_ROOT/manifests/imaging_shell_bm.txt}"

ACCOUNT="${ACCOUNT:-imageomics-biosci}"
PARTITION="${PARTITION:-normal_q}"
QOS="${QOS:-tc_normal_base}"
THROTTLE="${THROTTLE:-75}"
CPUS="${CPUS:-16}"
MEM="${MEM:-64G}"
# shell Cycles @ 620² × 255 rows × 3 views × 5 frames — keep long walltime
TIME="${TIME:-48:00:00}"
MAIL_USER="${MAIL_USER:-calebc22@vt.edu}"

mkdir -p "$CODE_ROOT/logs" "$RENDER_ROOT"

echo "Rebuilding job YAMLs from shell_default.yaml (RENDER_ROOT=$RENDER_ROOT)…"
bash "$CODE_ROOT/scripts/imaging/make_shell_jobs.sh"

[[ -f "$MANIFEST" ]] || {
  echo "missing $MANIFEST after make_shell_jobs.sh" >&2
  exit 1
}

N=$(grep -cve '^\s*(#|$)' "$MANIFEST")
[[ "$N" -gt 0 ]] || { echo "empty manifest: $MANIFEST" >&2; exit 1; }

echo "CODE_ROOT=$CODE_ROOT"
echo "DATA_ROOT=$DATA_ROOT"
echo "RENDER_ROOT=$RENDER_ROOT"
echo "MANIFEST=$MANIFEST"
echo "array=1-${N}%${THROTTLE}  cpus=${CPUS}/task  mem=${MEM}  time=${TIME}"
echo "mail (collective): $MAIL_USER"

jid=$(sbatch --parsable \
  --account="$ACCOUNT" \
  --partition="$PARTITION" \
  --qos="$QOS" \
  --cpus-per-task="$CPUS" \
  --mem="$MEM" \
  --time="$TIME" \
  --export=ALL,CODE_ROOT,MANIFEST \
  --array=1-"${N}%${THROTTLE}" \
  --output="$CODE_ROOT/logs/%x_%A_%a.out" \
  --error="$CODE_ROOT/logs/%x_%A_%a.err" \
  "$CODE_ROOT/scripts/slurm/run_imaging.slurm")

echo "submitted imaging array $jid"

# One email for the whole array: inspect sacct, exit 0/1 → END/FAIL mail once.
notify=$(sbatch --parsable \
  --account="$ACCOUNT" \
  --partition="$PARTITION" \
  --qos="$QOS" \
  --dependency=afterany:"${jid}" \
  --job-name=shell_bm_img_notify \
  --cpus-per-task=1 \
  --mem=1G \
  --time=00:10:00 \
  --mail-user="$MAIL_USER" \
  --mail-type=END,FAIL \
  --output="$CODE_ROOT/logs/%x_%j.out" \
  --error="$CODE_ROOT/logs/%x_%j.err" \
  --wrap="set -euo pipefail
    echo \"shell_bm imaging array ${jid} finished at \$(date -Is)\"
    sacct -j ${jid} --format=JobID,State,ExitCode,Elapsed -P | tee \"$CODE_ROOT/logs/shell_bm_img_${jid}_sacct.txt\"
    n_bad=\$(sacct -j ${jid} -X -n -P -o State | awk '\$1!=\"COMPLETED\" && \$1!=\"\" {c++} END{print c+0}')
    echo \"non-COMPLETED array tasks: \$n_bad\"
    if [[ \"\$n_bad\" -gt 0 ]]; then
      echo \"FAIL: one or more shell imaging array tasks did not complete\"
      exit 1
    fi
    echo \"OK: all shell imaging array tasks COMPLETED\"
  ")

echo "submitted collective notify job $notify → $MAIL_USER"
