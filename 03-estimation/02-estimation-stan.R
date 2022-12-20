## Estimation of left-right positions from tags (ideology and position).
## The Stan model is only estimated if no csv file with MCMC samples
## exists in sub-folder "estimation-models". Remove csv files to start
## estimation -- see below


library(readr)
library(rstan)


wp_model <- 2          # model to estimate -- M1 or M2

n_chains <- 4          # number of Markov chains
n_iter <- 2500         # total number of iterations
n_burn <- 250          # number of burn-in iterations
stan_seed <- 123456

ideology_tag_right <- "conservatism"
ideology_tag_down <- "euroscepticism"


## Stan config ----

options(mc.cores = parallel::detectCores())


## Files input/output ----

file_position_out <- "03-estimation/estimation-results/positions-2d-%s-m%d.csv"

file_stan <- sprintf("03-estimation/model-2d-m%d.stan", wp_model)
files_stan_samples <- sprintf(
  "03-estimation/estimation-model/02-stan-samples-2d-m%d_%d.csv",
  wp_model,
  seq_len(n_chains)
)
filename_stan_samples <- unique(
  gsub("_[[:digit:]]*.csv", "", files_stan_samples)
)
filename_stan_diags <- sprintf(
  "03-estimation/estimation-model/02-stan-diags-2d-m%d",
  wp_model
)


## Stan input ----

load(sprintf("03-estimation/estimation-model/01-data-m%d.RData", wp_model))

tags_1 <- setdiff(levels(ideology$tag), ideology_tag_down)

param_save <- c(
  c("delta", "beta"),
  paste(rep(c("lambda", "x"), each = 2), 1:2, sep = "_")
)

stan_inits <- list(
  delta_star = rowMeans(cbind(dl_init_1[, "delta"], dl_init_2[, "delta"])),
  lambda_1_star = dl_init_1[tags_1, "lambda"],
  lambda_2_star = dl_init_2[, "lambda"],
  beta_star = abs(ab_init_1[tags_1, "beta"]),
  x_1_star = x_init_1,
  x_2_star = x_init_2
)

stan_data <- list(
  tag_right_ideo = which(levels(ideology$tag) == ideology_tag_right),
  tag_down_ideo = which(levels(ideology$tag) == ideology_tag_down),
  not_tag_down_ideo = which(levels(ideology$tag) %in% tags_1),
  I = length(party),
  J = nlevels(ideology$tag),
  N = nrow(ideology),
  party_ideo = ideology$party,
  tag = as.integer(ideology$tag),
  y_ideo = as.integer(ideology$outcome)
)

if (wp_model == 2) {

  param_save <- c("gamma", "tau", param_save)
  
  stan_inits <- append(
    stan_inits,
    list(gamma_star = g_init, tau_star = t_init)
  )

  data_add <- list(
    M = nrow(left_right),
    K = length(unique(left_right$outcome)),
    party_lr = left_right$party,
    y_lr = as.integer(left_right$outcome)
  )
  stan_data <- append(stan_data, data_add)

}

stan_inits <- setNames(
  rep(list(stan_inits), n_chains),
  paste("chain", seq_len(n_chains), sep = "_")
)


## Run Stan ----

if (any(file.exists(files_stan_samples))) {

  error_msg <- "No Stan estimation. Remove incomplete '02-stan-*' files"
  stan_out <- tryCatch(
    {
      read_stan_csv(files_stan_samples)
    },
    error = function(cond) {
      message(cond)
      stop(error_msg)
    }
  )

} else {

  stan_out <- stan(
    file = file_stan,
    data = stan_data,
    iter = n_iter,
    warmup = n_burn,
    chains = n_chains,
    init = stan_inits,
    pars = param_save,
    include = TRUE,
    seed = stan_seed,
    sample_file = filename_stan_samples,
    diagnostic_file = filename_stan_diags
  )

}


## Export position estimates (and 95% CIs) to csv ----

samples <- rstan::extract(stan_out)
samples$o <- samples$lambda_1 / (2 * samples$beta)
samples$o <- samples$o[, which(levels(ideology$tag) != ideology_tag_down)]

pos_parties <- data.frame(
  partyfacts_id = names(party),
  x_1 = apply(samples$x_1, 2, median),
  lo_1 = apply(samples$x_1, 2, quantile, probs = 0.025),
  up_1 = apply(samples$x_1, 2, quantile, probs = 0.975),
  x_2 = apply(samples$x_2, 2, median),
  lo_2 = apply(samples$x_2, 2, quantile, probs = 0.025),
  up_2 = apply(samples$x_2, 2, quantile, probs = 0.975)
)
write_csv(pos_parties, sprintf(file_position_out, "parties", wp_model))

pos_tags <- data.frame(
  ideology = setdiff(levels(ideology$tag), ideology_tag_down),
  o = apply(samples$o, 2, median),
  lo = apply(samples$o, 2, quantile, probs = 0.025),
  up = apply(samples$o, 2, quantile, probs = 0.975)
)
write_csv(pos_tags, sprintf(file_position_out, "tags", wp_model))
