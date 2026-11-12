# Shared helpers for simulate_traits.R
# (trees, trait I/O, and BM / OU / λ runners).
# Source this file; do not run it alone.


# =============================================================================
# Trees and I/O
# =============================================================================

# Build a tree from the scenario yaml `tree:` block.
# Uses ape::stree + Grafen branch lengths, then scales to cfg_tree$height.
make_tree <- function(cfg_tree) {
  n_tips <- cfg_tree$n_tips
  labels <- paste0(cfg_tree$tip_prefix, seq_len(n_tips))

  phy <- ape::stree(n_tips, cfg_tree$type, tip.label = labels)
  phy <- ape::compute.brlen(phy, method = "Grafen", power = 1)
  phy$edge.length <- phy$edge.length / max(ape::node.depth.edgelength(phy))
  phy$edge.length <- phy$edge.length * cfg_tree$height

  phy
}


# Write tip + internal-node traits as CSV (species column + pc1..pcK).
write_traits <- function(X, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  colnames(X) <- paste0("pc", seq_len(ncol(X)))
  df <- data.frame(species = rownames(X), X, row.names = NULL)
  utils::write.csv(df, path, row.names = FALSE)
}


# Build ids like rep_01, rep_02, ...
rep_ids <- function(n_rep, prefix) {
  sprintf("%s%02d", prefix, seq_len(n_rep))
}


# Named parameter levels from a yaml block: values (list) + id_prefix.
param_grid <- function(block) {
  values <- as.numeric(unlist(block$values, use.names = FALSE))
  stopifnot(length(values) >= 1L, !is.null(block$id_prefix))
  ids <- sprintf("%s%02d", block$id_prefix, seq_along(values))
  list(values = values, ids = ids)
}


# Index of sim ids → parameter values (for later viz / imaging).
write_params <- function(path, df) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(df, path, row.names = FALSE)
}


# =============================================================================
# Process runners
# All take the same signature: function(phy, cfg, tab_dir, tre_dir)
# Registered by name in PROCESS_RUNNERS below (must match yaml `process:`).
# =============================================================================

# Shared topology; BM over a sig2 grid × replicates.
# Trees: one .nwk per sim id (same topology; pairs with the trait csv).
# Also keeps $DATA_ROOT/trees/<shared_name> from simulate_traits.R.
run_bm <- function(phy, cfg, tab_dir, tre_dir) {
  n_traits <- cfg$traits$n_traits
  grid <- param_grid(cfg$traits$sig2)
  reps <- rep_ids(cfg$reps$n_rep, cfg$reps$id_prefix)

  rows <- list()
  for (i in seq_along(grid$values)) {
    sig2 <- grid$values[[i]]
    level <- grid$ids[[i]]

    for (rep in reps) {
      id <- paste(level, rep, sep = "__")
      ape::write.tree(phy, file.path(tre_dir, paste0(id, ".nwk")))
      X <- phytools::fastBM(phy, sig2 = sig2, nsim = n_traits, internal = TRUE)
      write_traits(X, file.path(tab_dir, paste0(id, ".csv")))
      rows[[length(rows) + 1L]] <- data.frame(
        id = id, sig2_id = level, sig2 = sig2, rep = rep
      )
    }
  }

  write_params(file.path(dirname(tab_dir), "params.csv"), do.call(rbind, rows))
}


# =============================================================================
# OU with discrete Mk regimes
# =============================================================================

# Simulate a discrete regime history under Mk; return SIMMAP phylo.
sim_regime_history <- function(tr, Q) {
  mt <- phytools::sim.history(tr, Q, nsim = 1, message = FALSE)
  attr(mt, "map.order") <- "right-to-left"
  mt
}


# Equal-rate Mk generator: off-diagonal rate q to each other state.
make_equal_rate_Q <- function(states, q) {
  k <- length(states)
  Q <- matrix(q, k, k, dimnames = list(states, states))
  diag(Q) <- -(k - 1) * q
  Q
}


# Three optima as an equilateral triangle in trait space.
# Builds the triangle in 2D (centered at 0, vertex distance = scale), then
# embeds it in a random orthonormal plane of R^{n_traits} (uses RNG / seed).
pyramid_theta <- function(n_traits, scale, states) {
  s <- scale
  n_traits <- as.integer(n_traits)
  stopifnot(n_traits >= 2L, length(states) == 3L)

  verts_2d <- cbind(
    A = c(s, 0),
    B = c(-s / 2,  s * sqrt(3) / 2),
    C = c(-s / 2, -s * sqrt(3) / 2)
  )

  # Random 2D subspace of the full trait space
  U <- qr.Q(qr(matrix(stats::rnorm(n_traits * 2L), n_traits, 2L)))[, 1:2, drop = FALSE]

  thetas <- lapply(colnames(verts_2d), function(nm) {
    as.numeric(U %*% verts_2d[, nm, drop = FALSE])
  })
  names(thetas) <- colnames(verts_2d)
  thetas[states]
}


# Multivariate OU on a SIMMAP tree (independent axes per PC).
# Walks each painted segment toward that regime's optimum.
sim_ou_regimes <- function(tr, alpha, sig2, theta) {
  n_traits <- length(theta[[1]])
  ntip <- ape::Ntip(tr)
  nn <- ntip + tr$Nnode
  tip_names <- c(tr$tip.label, as.character((ntip + 1):nn))

  X <- matrix(NA_real_, nn, n_traits, dimnames = list(tip_names, NULL))
  X[ntip + 1L, ] <- 0

  for (i in seq_len(nrow(tr$edge))) {
    anc <- tr$edge[i, 1]
    des <- tr$edge[i, 2]
    cur <- X[anc, ]
    segs <- tr$maps[[i]]

    for (k in seq_along(segs)) {
      th <- theta[[names(segs)[k]]]
      t <- segs[[k]]
      mu <- th + (cur - th) * exp(-alpha * t)
      va <- sig2 / (2 * alpha) * (1 - exp(-2 * alpha * t))
      cur <- stats::rnorm(n_traits, mean = mu, sd = sqrt(va))
    }

    X[des, ] <- cur
  }

  X
}


# Alpha grid × reps. Trees are SIMMAP .nex (regime paint differs per rep).
run_ou <- function(phy, cfg, tab_dir, tre_dir) {
  n_traits <- cfg$traits$n_traits
  sig2 <- cfg$traits$sig2
  ou <- cfg$ou
  grid <- param_grid(ou$alpha)
  reps <- rep_ids(cfg$reps$n_rep, cfg$reps$id_prefix)

  states <- unlist(ou$states)
  Q <- make_equal_rate_Q(states, ou$q)
  theta <- pyramid_theta(n_traits, ou$theta_scale, states)

  rows <- list()
  for (i in seq_along(grid$values)) {
    alpha <- grid$values[[i]]
    level <- grid$ids[[i]]

    for (rep in reps) {
      id <- paste(level, rep, sep = "__")
      painted <- sim_regime_history(phy, Q)

      phytools::write.simmap(
        painted,
        file.path(tre_dir, paste0(id, ".nex")),
        format = "nexus"
      )

      X <- sim_ou_regimes(painted, alpha, sig2, theta)
      write_traits(X, file.path(tab_dir, paste0(id, ".csv")))
      rows[[length(rows) + 1L]] <- data.frame(
        id = id, alpha_id = level, alpha = alpha, rep = rep
      )
    }
  }

  write_params(file.path(dirname(tab_dir), "params.csv"), do.call(rbind, rows))
}


# λ grid × reps. One λ-transformed .nwk per λ level (for visualization);
# trait tables are per (λ, rep).
run_pagel_lambda_bm <- function(phy, cfg, tab_dir, tre_dir) {
  # phytools::rescale needs geiger's rescale.phylo registered
  invisible(loadNamespace("geiger"))

  n_traits <- cfg$traits$n_traits
  sig2 <- cfg$traits$sig2
  grid <- param_grid(cfg$lambda)
  reps <- rep_ids(cfg$reps$n_rep, cfg$reps$id_prefix)

  rows <- list()
  for (i in seq_along(grid$values)) {
    lam <- grid$values[[i]]
    level <- grid$ids[[i]]

    # Transformed tree once per λ (shared by all reps at this level)
    tr <- phytools::rescale(phy, "lambda", lam)
    ape::write.tree(tr, file.path(tre_dir, paste0(level, ".nwk")))

    for (rep in reps) {
      id <- paste(level, rep, sep = "__")
      X <- phytools::fastBM(tr, sig2 = sig2, nsim = n_traits, internal = TRUE)
      write_traits(X, file.path(tab_dir, paste0(id, ".csv")))
      rows[[length(rows) + 1L]] <- data.frame(
        id = id, lambda_id = level, lambda = lam, rep = rep,
        tree = paste0(level, ".nwk")
      )
    }
  }

  write_params(file.path(dirname(tab_dir), "params.csv"), do.call(rbind, rows))
}


# =============================================================================
# Dispatch table (yaml `process:` → runner)
# =============================================================================

PROCESS_RUNNERS <- list(
  bm = run_bm,
  ou = run_ou,
  pagel_lambda_bm = run_pagel_lambda_bm
)
