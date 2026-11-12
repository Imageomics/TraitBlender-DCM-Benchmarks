# TraitBlender-DCM-Benchmarks — code

<!-- Optional badge once you have a DOI / Zenodo / release:
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.XXXXXXX.svg)](https://doi.org/10.5281/zenodo.XXXXXXX)
-->

<!-- Overview: 2–4 sentences on what this repo is (simulation + TraitBlender imaging code for the benchmark). -->
This repository contains the **code** used to generate the [TraitBlender-DCM-Benchmarks](https://huggingface.co/datasets/imageomics/TraitBlender-DCM-Benchmarks) dataset: phylogenetic trait simulations, TraitBlender imaging configs and drivers, and related utilities. The released data live on Hugging Face (link below).

<!-- Link bar — fill in once available (BioCLIP-style). Remove unused links. -->
[Paper](URL_TO_PAPER) | [Dataset](https://huggingface.co/datasets/imageomics/TraitBlender-DCM-Benchmarks) | [Demo](URL_TO_DEMO_OPTIONAL)
<!-- If the Hub repo is not created yet, keep the intended id above or replace with “TBD”. -->

---

<!-- Optional hero / schematic figure (store under docs/ or assets/ and update the path).
|![Overview](docs/overview.png)|
|:--|
|**Figure.** Short caption (tree → traits → MorphoWeave renders → benchmark use).|
-->

## Table of contents

1. [Overview](#overview)
2. [Dataset](#dataset)
3. [Repository layout](#repository-layout)
4. [Setup](#setup)
5. [Running simulations](#running-simulations)
6. [Running imaging](#running-imaging)
7. [Citation](#citation)
8. [License](#license)
9. [Acknowledgements](#acknowledgements)

## Overview

<!-- Fill with ~1 short paragraph (optional bullets). Cover: problem (DCM / trait–image under known processes), pipeline (trees + tip traits → TraitBlender/MorphoWeave → HF), scope (e.g. BM / OU / λ × TraitBlender templates), link to paper when available. Skip install, paths, and file trees here. -->

[More information needed]

## Dataset

Released trees, tip traits, images, and metadata are published separately on Hugging Face:

- **[imageomics/TraitBlender-DCM-Benchmarks](https://huggingface.co/datasets/imageomics/TraitBlender-DCM-Benchmarks)** <!-- update if the slug changes -->

This code repo does **not** ship heavy renders. For generation or local working copies, point scripts at a data root via environment or config (see Setup).

## Repository layout

```text
code/
  README.md
  configs/
    tabular/         # phylo trees + tip-trait sims (fed into TraitBlender)
    traitblender/    # TraitBlender templates (one YAML per morphospace)
  scripts/
    sim_traits/      # simulate_traits.R + helpers.R
    slurm/           # publishable Slurm templates (no site paths/accounts)
    imaging/         # build TraitBlender jobs + Slurm drivers
  manifests/         # tabular list + (later) imaging job lists
```

Same experimental design shows up in both places: **tabular** configs produce trees/traits; **traitblender** configs render those traits. Job ids: `{tabular_id}__{template_id}__{sim}` (e.g. `balanced_bm__vertebra_3000_smooth__sig2_01__rep_03`).

**Checked in:** tabular YAMLs, TraitBlender templates, scripts, manifests, Slurm templates.  
**Generated:** tip CSVs, trees, `run_meta.yaml`, per-job TraitBlender YAMLs, renders (under the data root).

Add a shape template later with `configs/traitblender/<id>/` + new manifest lines — do not rewrite existing tabular configs.

## Setup

```bash
export CODE_ROOT=/path/to/TraitBlender-DCM-Benchmarks/code
export DATA_ROOT=/path/to/your/working/copy   # trees, tables, renders (not in git)
# conda activate <env>   # needs R + ape, phytools, geiger, yaml
```

**Seeds:** each tabular yaml sets `seed:` (source of truth). `simulate_traits.R` calls `set.seed()` once per config and writes `$DATA_ROOT/<id>/run_meta.yaml` with the seed and config path used.

**Slurm:** do **not** commit personal account, partition, qos, or home/project paths. Pass those on the `sbatch` CLI; the checked-in scripts only need `CODE_ROOT` and `DATA_ROOT`.

Requirements (draft):

- [ ] R + packages for trait simulation (`ape`, `phytools`, `geiger`, `yaml`)
- [ ] Blender **5.1+** + TraitBlender (pinned version TBD)
- [ ] Cluster: your site’s account / partition / qos (via `sbatch` flags)

## Running simulations

```bash
# Single tabular config on a compute node (not login); cwd must be CODE_ROOT:
cd "$CODE_ROOT"
Rscript scripts/sim_traits/simulate_traits.R \
  configs/tabular/balanced_bm.yaml "$DATA_ROOT"

# All configs in manifests/tabular.txt (parallel array):
mkdir -p "${CODE_ROOT}/logs"
sbatch \
  --account=YOUR_ACCOUNT \
  --partition=YOUR_PARTITION \
  --qos=YOUR_QOS \
  --output="${CODE_ROOT}/logs/%x_%A_%a.out" \
  --error="${CODE_ROOT}/logs/%x_%A_%a.err" \
  "${CODE_ROOT}/scripts/slurm/run_tabular_sims.slurm"
```

Each tabular config is 10 parameter levels × `n_rep` (trial uses `n_rep: 1`; full release `10`). Outputs under `$DATA_ROOT` (the HF dataset working copy):

```text
trees/balanced_128.nwk              # shared untransformed topology
balanced_bm/
  tabular/sig2_XX__rep_YY.csv       # tips + internal nodes
  trees/sig2_XX__rep_YY.nwk
  params.csv
  run_meta.yaml
balanced_ou/
  tabular/alpha_XX__rep_YY.csv
  trees/alpha_XX__rep_YY.nex        # SIMMAP regimes
  params.csv
pagel_lambda_bm/
  tabular/lambda_XX__rep_YY.csv
  trees/lambda_XX.nwk
  params.csv
```

Array size tracks non-comment lines in `manifests/tabular.txt`.

## Running imaging

Recycled from the prior TraitBlender workflow: morphospace `_template.yaml` + `_orientations.yaml`, a tiny Blender driver, `make_jobs.sh` (tip-only CSVs + filled job YAMLs), and Slurm.

```bash
export CODE_ROOT=/path/to/TraitBlender-DCM-Benchmarks/code
export DATA_ROOT=/path/to/TraitBlender-DCM-Benchmarks/dataset   # HF card + tabular
export SSM_ROOT=/path/to/morphoweave_ssms                       # MorphoWeave DBs (not on HF)
# optional: export RENDER_ROOT=/projects/.../renders            # heavy PNG/PLY off the card

bash "$CODE_ROOT/scripts/imaging/make_jobs.sh"
# writes DATA_ROOT/<id>/tabular_tips/ and configs/traitblender/jobs/*.yaml
# manifest: manifests/imaging.txt

N=$(grep -cve '^\s*(#|$)' "$CODE_ROOT/manifests/imaging.txt")
sbatch --account=... --partition=... --qos=... --array=1-"$N" \
  --output="$CODE_ROOT/logs/%x_%A_%a.out" \
  --error="$CODE_ROOT/logs/%x_%A_%a.err" \
  "$CODE_ROOT/scripts/slurm/run_imaging.slurm"
```

Job ids: `{tabular_id}__{template_id}__{sim}` (e.g. `balanced_bm__vertebra_3000_smooth__sig2_01__rep_01`).
One complete YAML per morphospace under `configs/traitblender/<template>.yaml` (orientations included).

## Citation

<!-- Add BibTeX for paper, this code repo, and the HF dataset when available (BioCLIP / ToL style). -->

**Paper**

```bibtex
@article{TBD,
  title  = {TBD},
  author = {TBD},
  year   = {TBD}
}
```

**Code (this repository)**

```bibtex
@software{TBD,
  title  = {TraitBlender-DCM-Benchmarks (code)},
  author = {TBD},
  year   = {TBD},
  url    = {URL_TO_GITHUB_TBD}
}
```

**Dataset**

```bibtex
@dataset{TBD,
  title     = {TraitBlender-DCM-Benchmarks},
  author    = {TBD},
  year      = {TBD},
  url       = {https://huggingface.co/datasets/imageomics/TraitBlender-DCM-Benchmarks},
  publisher = {Hugging Face}
}
```

Also consider citing [TraitBlender](https://github.com/Imageomics/TraitBlender) and MorphoWeave SSMs as appropriate.

## License

<!-- Code license (often MIT for Imageomics software). Dataset license is declared on the HF card. -->
[More information needed]

## Acknowledgements

This work was supported by the [Imageomics Institute](https://imageomics.org), which is funded by the US National Science Foundation's Harnessing the Data Revolution (HDR) program under [Award #2118240](https://www.nsf.gov/awardsearch/showAward?AWD_ID=2118240) (Imageomics: A New Frontier of Biological Information Powered by Knowledge-Guided Machine Learning). Any opinions, findings and conclusions or recommendations expressed in this material are those of the author(s) and do not necessarily reflect the views of the National Science Foundation.
