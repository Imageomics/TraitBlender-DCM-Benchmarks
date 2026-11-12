#!/usr/bin/env Rscript
#
# Simulate trees and trait tables for one scenario config.
#
# From CODE_ROOT on a compute node:
#   Rscript scripts/sim_traits/simulate_traits.R <config.yaml> <data_root>
#
# Example:
#   cd "$CODE_ROOT"
#   Rscript scripts/sim_traits/simulate_traits.R \
#     configs/tabular/balanced_bm.yaml "$DATA_ROOT"
#
# Writes under <data_root>:
#   trees/<shared_name>                 untransformed shared topology
#   <id>/tabular/<sim>.csv              tip + node traits
#   <id>/trees/…                        see helpers (BM .nwk, OU .nex,
#                                       λ-transformed lambda_XX.nwk for viz)
#   <id>/params.csv                     sim id → parameter values
#   <id>/run_meta.yaml                  seed, process, config path


# --- args (run with cwd = CODE_ROOT) -------------------------------------

args <- commandArgs(TRUE)
config_path <- args[[1]]
data_root <- args[[2]]

source("scripts/sim_traits/helpers.R")
cfg <- yaml::read_yaml(config_path)


# --- output folders ------------------------------------------------------

tab_dir <- file.path(data_root, cfg$id, "tabular")
tre_dir <- file.path(data_root, cfg$id, "trees")

dir.create(tab_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(tre_dir, recursive = TRUE, showWarnings = FALSE)


# --- shared tree (RNG seed from yaml — source of truth for reproducibility)

if (is.null(cfg$seed)) {
  stop("scenario config must set seed: <integer>", call. = FALSE)
}
set.seed(cfg$seed)
phy <- make_tree(cfg$tree)

# optional copy when several tabular configs share this topology
if (!is.null(cfg$tree$shared_name)) {
  shared_dir <- file.path(data_root, "trees")
  dir.create(shared_dir, recursive = TRUE, showWarnings = FALSE)
  ape::write.tree(phy, file.path(shared_dir, cfg$tree$shared_name))
}


# --- look up runner by yaml `process:` and run ---------------------------

runner <- PROCESS_RUNNERS[[cfg$process]]

if (is.null(runner)) {
  stop(
    "unknown process '", cfg$process, "'. ",
    "Known: ", paste(names(PROCESS_RUNNERS), collapse = ", "),
    call. = FALSE
  )
}

runner(phy, cfg, tab_dir, tre_dir)


# --- record seed + config used for this run ------------------------------

yaml::write_yaml(
  list(
    id = cfg$id,
    process = cfg$process,
    seed = cfg$seed,
    config = normalizePath(config_path),
    data_root = normalizePath(data_root, mustWork = FALSE),
    created_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)
  ),
  file.path(data_root, cfg$id, "run_meta.yaml")
)
