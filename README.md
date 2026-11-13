# TraitBlender-DCM-Benchmarks

Code to generate the [TraitBlender-DCM-Benchmarks](https://huggingface.co/datasets/imageomics/TraitBlender-DCM-Benchmarks) dataset: phylogenetic trait simulations (Brownian motion, Pagel’s λ, regime OU), TraitBlender / MorphoWeave imaging configs, and Slurm drivers. The released trees, tip tables, meshes, and renders are on Hugging Face.

[Dataset](https://huggingface.co/datasets/imageomics/TraitBlender-DCM-Benchmarks) | [TraitBlender](https://github.com/Imageomics/TraitBlender) | [Docs](https://imageomics.github.io/TraitBlender/) | [Zenodo](https://doi.org/10.5281/zenodo.14804133)

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

This pipeline simulates tip PCs under known comparative processes on a shared ultrametric balanced tree (\(T = 1\)), then renders three MorphoWeave morphospaces (mouse cranium, primate molar, squamate vertebra) with TraitBlender. The Hugging Face release is **3 scenarios × 3 morphospaces × 10 parameter levels × 1 replicate (`rep_01`)** = **90** imaged simulations (128 tips × 3 views × 5 frames = 1,920 PNGs per simulation).

## Dataset

Released data: [imageomics/TraitBlender-DCM-Benchmarks](https://huggingface.co/datasets/imageomics/TraitBlender-DCM-Benchmarks).

To regenerate or extend the release, set `DATA_ROOT` to a local data directory and `SSM_ROOT` to your MorphoWeave SSM libraries (see Setup). MorphoWeave SSMs are not redistributed with the Hub dataset.

## Repository layout

```text
.
  README.md
  configs/
    tabular/              # balanced_bm / balanced_ou / pagel_lambda_bm
    traitblender/         # one MorphoWeave template YAML per morphospace
  scripts/
    sim_traits/           # simulate_traits.R + helpers.R
    imaging/              # make_jobs.sh + Blender Python driver
    slurm/                # array job templates
  manifests/
    tabular.txt
    imaging.txt
```

Job ids: `{tabular_id}__{template_id}__{sim}` (e.g. `balanced_bm__vertebra_3000_smooth__sig2_01__rep_01`).

To add a morphospace, add `configs/traitblender/<id>.yaml` and include `<id>` in `TEMPLATES` when running `make_jobs.sh`.

## Setup

```bash
export CODE_ROOT=/path/to/TraitBlender-DCM-Benchmarks
export DATA_ROOT=/path/to/data
export SSM_ROOT=/path/to/morphoweave_ssms
```

Requirements:

- R with `ape`, `phytools`, `geiger`, `yaml`
- Blender **5.1+** with [TraitBlender](https://github.com/Imageomics/TraitBlender)
- Site modules or binaries for headless rendering (edit `scripts/slurm/run_imaging.slurm` for your cluster)

Each tabular YAML sets `seed:`. Pass Slurm account / partition / qos on the `sbatch` command line—do not hard-code them in the checked-in scripts.

## Running simulations

```bash
cd "$CODE_ROOT"
Rscript scripts/sim_traits/simulate_traits.R \
  configs/tabular/balanced_bm.yaml "$DATA_ROOT"

mkdir -p "${CODE_ROOT}/logs"
sbatch \
  --account=YOUR_ACCOUNT \
  --partition=YOUR_PARTITION \
  --qos=YOUR_QOS \
  --output="${CODE_ROOT}/logs/%x_%A_%a.out" \
  --error="${CODE_ROOT}/logs/%x_%A_%a.err" \
  "${CODE_ROOT}/scripts/slurm/run_tabular_sims.slurm"
```

Configs use **10 parameter levels** with `n_rep: 1` for the HF release. Outputs under `$DATA_ROOT`:

```text
trees/balanced_128.nwk
balanced_bm/
  tabular/sig2_XX__rep_YY.csv
  tabular_tips/
  trees/sig2_XX__rep_YY.nwk
  params.csv
  run_meta.yaml
  renders/<morphospace>/<sim>/…
balanced_ou/
  tabular/alpha_XX__rep_YY.csv
  trees/alpha_XX__rep_YY.nex
  …
pagel_lambda_bm/
  tabular/lambda_XX__rep_YY.csv
  trees/lambda_XX.nwk
  …
```

## Running imaging

```bash
bash "$CODE_ROOT/scripts/imaging/make_jobs.sh"

N=$(grep -cve '^\s*(#|$)' "$CODE_ROOT/manifests/imaging.txt")
sbatch --account=... --partition=... --qos=... --array=1-"$N" \
  --output="$CODE_ROOT/logs/%x_%A_%a.out" \
  --error="$CODE_ROOT/logs/%x_%A_%a.err" \
  "$CODE_ROOT/scripts/slurm/run_imaging.slurm"
```

`make_jobs.sh` writes tip-only CSVs under `$DATA_ROOT` and filled TraitBlender job YAMLs under `configs/traitblender/jobs/` (gitignored).

## Citation

Please cite the dataset (and the forthcoming dataset paper when available). Cite [TraitBlender](https://github.com/Imageomics/TraitBlender) ([Zenodo](https://doi.org/10.5281/zenodo.14804133)) when using the imaging stack.

**Data**

```bibtex
@misc{charpentier_traitblender_dcm_benchmarks,
  author = {Charpentier, Caleb P.},
  title = {{TraitBlender-{DCM}-Benchmarks}},
  year = {2026},
  url = {https://huggingface.co/datasets/imageomics/TraitBlender-DCM-Benchmarks},
  publisher = {Hugging Face}
}
```

**Code (this repository)**

```bibtex
@software{charpentier_traitblender_dcm_benchmarks_code,
  author = {Charpentier, Caleb P.},
  title = {{TraitBlender-{DCM}-Benchmarks} (code)},
  year = {2026},
  url = {https://github.com/Imageomics/TraitBlender-DCM-Benchmarks}
}
```

**TraitBlender** ([GitHub](https://github.com/Imageomics/TraitBlender), [Zenodo](https://doi.org/10.5281/zenodo.14804133))

```bibtex
@software{charpentier_2026_traitblender,
  author = {Charpentier, Caleb and Linscott, T. Mason and Bradley, John and Campolongo, Elizabeth and Thompson, Matthew and Uyeda, Josef C.},
  title = {TraitBlender},
  year = {2026},
  publisher = {Zenodo},
  doi = {10.5281/zenodo.14804133},
  url = {https://doi.org/10.5281/zenodo.14804133}
}
```

## License

Code is [MIT](LICENSE). The Hugging Face dataset is [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). TraitBlender / MorphoWeave / Blender retain their own licenses.

## Acknowledgements

This work was supported by the [Imageomics Institute](https://imageomics.org), which is funded by the US National Science Foundation's Harnessing the Data Revolution (HDR) program under [Award #2118240](https://www.nsf.gov/awardsearch/showAward?AWD_ID=2118240) (Imageomics: A New Frontier of Biological Information Powered by Knowledge-Guided Machine Learning). Any opinions, findings and conclusions or recommendations expressed in this material are those of the author(s) and do not necessarily reflect the views of the National Science Foundation.
