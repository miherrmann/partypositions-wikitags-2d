## Prepare data for Stan estimation and save results as RData file.
## Calculate starting values for estimation with correspondence analysis
## and logit regression. Transform binary data matrix to stacked (long)
## format for estimation (vectorized processing in Stan)


library(readr)
# "MASS::" used below; not loaded to avoid tidyverse conflicts (esp. "select()")


min_tags <- 10    # minimum number of ideology tag occurrences
min_parties <- 2  # minimum number of ideology tags per party

data_source_file <- "02-data-preparation/02-wp-data.csv"


## Functions ----

select_submat <- function(mat, row_min, col_min) {

  # select sub-matrix with row and
  # col margins not lower than min

  while (any(rowSums(mat) < row_min)) {

    row_select <- rowSums(mat) >= row_min
    mat <- mat[row_select, ]

    while (any(colSums(mat) < col_min)) {

      col_select <- colSums(mat) >= col_min
      mat <- mat[, col_select]

    }

  }

  return(mat)

}

stack_tag_mat <- function(mat) {

  # reshape tag presence-absence matrix
  # to long format and make party id var

  names(mat) <- gsub("^", "outcome.", names(mat))
  mat$party <- seq_len(nrow(mat))

  mat <- reshape(
    mat,
    direction = "long",
    varying = grep("\\.", names(mat), value = TRUE),
    sep = ".",
    idvar = "party",
    timevar = "tag"
  )
  mat$tag <- as.factor(mat$tag)

  return(mat)

}

generate_ab <- function(y_mat, x, o = NULL) {

  # make starting values for alpha and beta
  # (via logit reg) given binary data matrix
  # y and values for x and (optionally) o

  if (is.null(o)) {

    predictor <- rep(list(x), times = ncol(y_mat))
    names_est <- c("delta", "lambda")

  } else {

    predictor <- sapply(o, function(.o) (rep(.o, times = length(x)) - x) ^ 2)
    names_est <- c("alpha", "beta")

  }

  est <- mapply(
    function(.y, .x)
      coef(suppressWarnings(glm(.y ~ .x, family = binomial(link = "logit")))),
    y_mat,
    data.frame(predictor)
  )
  est <- t(est)
  colnames(est) <- names_est

  return(est)

}


## Files output ----

filename_out <- "03-estimation/estimation-model/01-data-m%d.RData"


### Data preparation ----

bcm_raw <- read_csv(data_source_file)

lr <- c(
  "far_left",
  "left_wing",
  "centre_left",
  "centre",
  "centre_right",
  "right_wing",
  "far_right"
)

# Create partyfacts vector for later use and remove it from data ----

bcm_raw <- as.data.frame(bcm_raw)
row.names(bcm_raw) <- paste0("id_", bcm_raw[, "partyfacts_id"])
partyfacts_id_all <- bcm_raw[, "partyfacts_id"]
bcm_raw <- bcm_raw[, names(bcm_raw) != "partyfacts_id"]



## Model 2 ----

wp_model <- 2

ideology_mat <- select_submat(
  bcm_raw[, ! names(bcm_raw) %in% lr],
  row_min = min_parties,
  col_min = min_tags
)


partyfacts_id <- partyfacts_id_all[
  partyfacts_id_all %in% as.integer(gsub("id_", "", row.names(ideology_mat)))
]


# Select parties for analysis: n_parties ideology tags ----

bcm <- bcm_raw[row.names(ideology_mat), union(names(ideology_mat), lr)]

# exclude parties with one ideology tag and no lr-position tag
# IMPROVE: this hack doesn't ensure min_tags is met (but it often will be)
if (min_parties == 1) {

  bcm <- bcm[any(rowSums(bcm) > 1), ]

  partyfacts_id <- partyfacts_id_all[
    partyfacts_id_all %in% as.integer(gsub("id_", "", row.names(bcm)))
  ]
  ideology_mat <- bcm[, ! names(bcm) %in% lr]

}


# Data set: parties (stacked) and their ideology tags ----

ideology <- stack_tag_mat(ideology_mat)


# Data set: parties (stacked) and their lr-position tags ----

left_right <- mapply(function(.x, .y) .x * .y, bcm[, lr], seq_along(lr))
left_right <- stack_tag_mat(data.frame(left_right))
left_right <- left_right[left_right$outcome > 0, ! names(left_right) == "tag"]
left_right$single_tag <- left_right$party %in% which(rowSums(bcm[, lr]) == 1)


# Starting values ----

ca <- MASS::corresp(as.matrix(bcm), nf = 2)

x_init_1 <- ca$rscore[, 1]
x_init_2 <- ca$rscore[, 2]
o_init_1 <- ca$cscore[colnames(ideology_mat), 1]
ab_init_1 <- generate_ab(ideology_mat, x = x_init_1, o = o_init_1)
dl_init_1 <- cbind(
  delta = ab_init_1[, "alpha"] - abs(ab_init_1[, "beta"]) * o_init_1 ^ 2,
  lambda = abs(ab_init_1[, "beta"]) * o_init_1 * 2
)
dl_init_2 <- generate_ab(ideology_mat, x = x_init_2)

party <- setNames(seq_len(nrow(ideology_mat)), nm = partyfacts_id)
ologit <- MASS::polr(factor(left_right$outcome) ~ x_init_1[left_right$party])

g_init <- coef(ologit)
t_init <- ologit$zeta

save(
  left_right,
  ideology,
  ca,
  x_init_1,
  x_init_2,
  ab_init_1,
  dl_init_1,
  dl_init_2,
  g_init,
  t_init,
  party,
  partyfacts_id,
  file = sprintf(filename_out, wp_model)
)
