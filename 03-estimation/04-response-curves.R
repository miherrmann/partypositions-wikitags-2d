## Plot response curves to visualize discrimination of tags
## along each dimension. Three plots per dimension, each
## holding x on other dimension constant at -1, 0, 1, resp.


library(rstan)


wp_model <- 2                # set model to estimate -- M1 or M2

other_at <- c(-1.5, 0, 1.5)  # values other dim is held constant at
lr_curv <- FALSE             # include curves for lr-position tags
eval <- 500                  # set curve smoothness (evaluation points)

filenames <- "response-curves"              # name output files
dir <- "03-estimation/estimation-results/"  # set output file location



## Functions ----

prob_ideo <- function(delta, lambda_1, lambda_2, beta, x_1, x_2) {

  xb <- delta + lambda_1 * x_1 - beta * x_1 ^ 2 + lambda_2 * x_2
  pr <- 1 / (1 + exp(-xb))

  return(pr)

}

prob_lr <- function(tau, gamma, x) {

  xb <- tau - gamma * x
  pr <- 1 / (1 + exp(-xb))

  return(pr)

}


## Data for plotting ----

load(sprintf("03-estimation/estimation-model/01-data-m%d.RData", wp_model))
tags_ideo <- levels(ideology$tag)

files_samples <- list.files(
  "03-estimation/estimation-model",
  pattern = sprintf("02-stan-samples-2d-m%d_[[:digit:]].csv", wp_model),
  full.names = TRUE
)
samples <- rstan::extract(read_stan_csv(files_samples))


## Create variables ----

pos <- lapply(
  setNames(1:2, nm = paste0("pos_", 1:2)),
  function(.dim) apply(samples[[paste0("x_", .dim)]], 2, median)
)

invisible(
  lapply(
    c("delta", "lambda_1", "lambda_2", "beta", "gamma", "tau"),
    function(.par) assign(.par, samples[[.par]], envir = .GlobalEnv)
  )
)

samples$o_1 <- samples$lambda_1 / (2 * samples$beta)
loc_1 <- apply(samples$o_1, 2, median)


## Create inputs for plot ----

domain <- lapply(
  setNames(1:2, nm = paste0("domain_", 1:2)),
  function(.dim) range(pos[[.dim]]) + 0.05 * diff(range(pos[[.dim]])) * c(-1, 1)
)

xvals <- lapply(
  setNames(1:2, nm = paste0("xvals_", 1:2)),
  function(.dim) seq(min(domain[[.dim]]), max(domain[[.dim]]), length.out = eval)
)


## lr-position tags: cut points and probabilities ----

if (wp_model == 2) {

  tags_lr <- c(
    "far_left",
    "left_wing",
    "centre_left",
    "centre",
    "centre_right",
    "right_wing",
    "far_right"
  )  # ordering is deliberate

  if (lr_curv) {

    pr_lr <- matrix(NA, nrow = length(xvals[[1]]), ncol = length(tags_lr))

    for (i in seq_len(ncol(pr_lr))) {

      tau_l <- ifelse(i == 1, -Inf, tau[, i - 1])
      tau_r <- ifelse(i == ncol(pr_lr), Inf, tau[, i])

      pr_lr[, i] <- sapply(
        xvals[[1]],
        function(.x) median(
          prob_lr(tau_r, gamma, .x) - prob_lr(tau_l, gamma, .x)
        )
      )

    }

  }

  # cut points
  cut <- apply(cbind(tau, gamma), 1, function(.x) .x / .x["gamma"])
  cut <- apply(cut, 1, median)
  cut <- cut[! names(cut) == "gamma"]

  # coordinates for placement of lr-position tags
  half_intervals <- (c(cut, max(domain[[1]])) - c(min(domain[[1]]), cut)) * 0.5
  x_lr <- c(min(domain[[1]]), cut) + half_intervals

}



## Ideology tags: probabilities and coordinates for text (tag names) ----

for (plot in seq_along(other_at)) {

  x_fix <- other_at[plot]

  pr_ideo_1 <- t(
    sapply(
      xvals[[1]],
      function(.x) apply(
        prob_ideo(delta, lambda_1, lambda_2, beta, .x, x_fix),
        2,
        median
      )
    )
  )

  pr_ideo_2 <- t(
    sapply(
      xvals[[2]],
      function(.x) apply(
        prob_ideo(delta, lambda_1, lambda_2, beta, x_fix, .x),
        2,
        median
      )
    )
  )

  pr_ideo <- list(pr_ideo_1, pr_ideo_2)


  # First dimension

  # if response peaks within x-range
  in_range_1 <- min(pos[[1]]) < loc_1 & loc_1 < max(pos[[1]])
  x_1_in <- loc_1[in_range_1]
  y_1_in <- apply(
    prob_ideo(
      delta,
      lambda_1,
      lambda_2,
      beta,
      sapply(loc_1, rep, times = nrow(delta)),
      x_fix
    ),
    2,
    median
  )
  y_1_in <- (y_1_in + 0.02)[in_range_1]

  # if response peaks left of x-range
  out_l_1 <- loc_1 < min(pos[[1]])
  x_1_l <- min(pos[[1]]) - 0.1
  y_1_l <- apply(
    prob_ideo(delta, lambda_1, lambda_2, beta, x_1_l, x_fix),
    2,
    median
  )[out_l_1]

  # if response peaks right of x-range
  out_r_1 <- loc_1 > max(pos[[1]])
  x_1_r <- max(pos[[1]]) + 0.1
  y_1_r <- apply(
    prob_ideo(delta, lambda_1, lambda_2, beta, x_1_r, x_fix),
    2,
    median
  )[out_r_1]


  # Second dimension

  lambda_2_negative <- sign(apply(lambda_2, 2, median)) == -1

  # if negative response slope
  x_2_l <- min(pos[[2]]) - 0.1
  y_2_l <- apply(
    prob_ideo(delta, lambda_1, lambda_2, beta, x_fix, x_2_l),
    2,
    median
  )[lambda_2_negative]

  # if positive response slope
  x_2_r <- max(pos[[2]]) + 0.1
  y_2_r <- apply(
    prob_ideo(delta, lambda_1, lambda_2, beta, x_fix, x_2_r),
    2,
    median
  )[! lambda_2_negative]


  ## Plots ----

  dim_names <- c("left-right", "anti-pro European integration")

  for (dim in 1:2) {

    file_graph_out <- sprintf(
      "%s%s-m%d-d%d-p%d.png",
      dir,
      filenames,
      wp_model,
      dim,
      plot
    )

    png(
      file_graph_out,
      width = 14,
      height = c(7, 14)[dim],
      units = "in",
      res = 216
    )

    plot(
      range(pos[[dim]]),
      c(0, 1),
      type = "n",
      main = "",
      sub = sprintf("(%s fixed at %g)", rev(dim_names)[dim], x_fix),
      ylab = "Probability of tag assignment",
      xlab = paste0(dim_names[dim], "\n")
    )

    if (dim == 1 & wp_model == 2) {

      invisible(lapply(cut, function(.x) abline(v = .x, col = "grey")))

      if (lr_curv) {

        invisible(
          apply(pr_lr, 2, function(.x) lines(xvals[[1]], .x, col = "grey"))
        )

      }

      text(x_lr, 1, labels = tags_lr, col = "grey")

    }

    invisible(
      apply(
        pr_ideo[[dim]],
        2,
        function(.x) lines(xvals[[dim]], .x, col = "grey50")
      )
    )

    if (dim == 1) {

      text(x_1_in, y_1_in, labels = tags_ideo[in_range_1])
      text(x_1_l, y_1_l, labels = tags_ideo[out_l_1], pos = 4)
      text(x_1_r, y_1_r, labels = tags_ideo[out_r_1], pos = 2)

    } else {

      text(x_2_l, y_2_l, labels = tags_ideo[lambda_2_negative], pos = 4)
      text(x_2_r, y_2_r, labels = tags_ideo[! lambda_2_negative], pos = 2)

    }

    rug(pos[[dim]])

    dev.off()

  }

}