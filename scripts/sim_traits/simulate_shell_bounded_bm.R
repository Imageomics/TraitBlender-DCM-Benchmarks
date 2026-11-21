#!/usr/bin/env Rscript
#
# Shell BM → TraitBlender CSVs (tips + ancestors).
#
# Nested morphs — free trait counts match the names (S is NOT free):
#   shell_1trait: b
#   shell_3trait: b, d, z
#   shell_5trait: b, d, z, a, c_depth
#
# S = fixed aperture-diameter scale (TraitBlender size); held constant.
#
# Geometry follows Contreras-Figueroa & Aragón (2023) / TraitBlender Shell docs:
#   b → 0 ≈ torus; larger b → more open coil; very large b → uncoiled.
#
# Whorl contact (planispiral apical view): tube width ≈ 2*a*exp(b*t),
# radial centerline step ≈ d*(1-exp(-2*pi*b))*exp(b*t). Touch when
#   d*(1-exp(-2*pi*b)) = 2*a  ⇒  b_touch = -log(1-2*a/d)/(2*pi)  (need d>2a).
#
#   cd "$CODE_ROOT"
#   Rscript scripts/sim_traits/simulate_shell_bounded_bm.R <data_root>

args <- commandArgs(TRUE)
if (length(args) < 1L) {
  stop("usage: simulate_shell_bounded_bm.R <data_root>", call. = FALSE)
}
data_root <- args[[1]]

source("scripts/sim_traits/helpers.R")

seed <- 20261120L
n_replicates <- 25L
sig2 <- 0.09

# Centers (1-trait holds d/a/z at these).
d_center <- 2.5
a_center <- 1.0
z_center <- 0
c_depth_center <- 0

recenter_bounds <- function(old_bounds, center) {
  half <- diff(range(old_bounds)) / 2
  c(center - half, center + half)
}

b_bounds <- c(0.1, 0.16)
d_bounds <- c(2.0, 3.0)
z_u_bounds <- c(0, 1)                                            # z = 4^u - 1 ∈ [0, 3]
a_bounds <- recenter_bounds(c(0.45, 1), a_center)                # [0.725, 1.275]
# Keep lower bound; upper ~4× prior (±0.03 → [-0.03, 0.12]).
c_depth_bounds <- c(-0.03, 0.12)

# S fixed (not a free trait); 30% below old 2.5 default.
S_fixed <- 2.5 * 0.7  # 1.75

shell_dir <- file.path(data_root, "shell_bm")
tree_dir <- file.path(shell_dir, "trees")
dir.create(tree_dir, recursive = TRUE, showWarnings = FALSE)

shared_nwk <- file.path(data_root, "trees", "balanced_128.nwk")
if (!file.exists(shared_nwk)) {
  stop("missing ", shared_nwk, " — run balanced_bm tabular sims first", call. = FALSE)
}
phy <- ape::read.tree(shared_nwk)
file.copy(shared_nwk, file.path(tree_dir, "original.nwk"), overwrite = TRUE)
ape::write.tree(phy, file.path(tree_dir, "simulation.nwk"))

simulate_free_traits <- function(phy, sig2) {
  list(
    b = sim_bounded_bm(phy, b_bounds, sig2),
    d = sim_bounded_bm(phy, d_bounds, sig2),
    z = 4^sim_bounded_bm(phy, z_u_bounds, sig2) - 1,
    a = sim_bounded_bm(phy, a_bounds, sig2),
    c_depth = sim_bounded_bm(phy, c_depth_bounds, sig2)
  )
}

constant_shell_cols <- function(n_rows) {
  data.frame(
    psi = rep(0, n_rows), k = rep(0, n_rows),
    n_depth = rep(0, n_rows), n = rep(0, n_rows),
    t = rep(80, n_rows), eps = rep(0.8, n_rows),
    h_0 = rep(0.1, n_rows),
    S = rep(S_fixed, n_rows)
  )
}

morph_tables_from_traits <- function(traits) {
  species <- names(traits$b)
  b <- as.numeric(traits$b)
  d <- as.numeric(traits$d)
  z <- as.numeric(traits$z)
  a <- as.numeric(traits$a)
  c_depth <- as.numeric(traits$c_depth)
  held_constant <- constant_shell_cols(length(species))

  list(
    shell_1trait = cbind(
      data.frame(
        species = species, b = b,
        d = d_center, z = z_center, a = a_center,
        phi = 0, c_depth = 0, c_n = 32,
        stringsAsFactors = FALSE
      ),
      held_constant
    ),
    shell_3trait = cbind(
      data.frame(
        species = species, b = b, d = d, z = z,
        a = a_center, phi = 0.175, c_depth = 0, c_n = 70,
        stringsAsFactors = FALSE
      ),
      held_constant
    ),
    shell_5trait = cbind(
      data.frame(
        species = species, b = b, d = d, z = z,
        a = a, phi = 0.175, c_depth = c_depth, c_n = 32,
        stringsAsFactors = FALSE
      ),
      held_constant
    )
  )
}

tab_dir <- file.path(shell_dir, "tabular")
if (dir.exists(tab_dir)) unlink(tab_dir, recursive = TRUE)

set.seed(seed)
message(sprintf(
  "free: 1=b; 3=b,d,z; 5=b,d,z,a,c_depth | b=[%.4f,%.4f] d=[%.3f,%.3f] a=[%.3f,%.3f] z->[0,3] c_depth=[%.3f,%.3f] | fixed S=%.2f t=80",
  b_bounds[1], b_bounds[2],
  d_bounds[1], d_bounds[2], a_bounds[1], a_bounds[2],
  c_depth_bounds[1], c_depth_bounds[2], S_fixed
))
for (rep_i in seq_len(n_replicates)) {
  rep_id <- sprintf("rep_%02d", rep_i)
  tables <- morph_tables_from_traits(simulate_free_traits(phy, sig2))
  for (morph in names(tables)) {
    write_trait_csv(tables[[morph]], file.path(tab_dir, morph, paste0(rep_id, ".csv")))
  }
  message(rep_id)
}
