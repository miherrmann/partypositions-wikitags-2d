// Stan code for model 2
// estimate party positions from ideology and lr-position tags
// two dimensions


data {

  int<lower=1> tag_right_ideo;
  int<lower=1> tag_down_ideo;
  int<lower=1> I;
  int<lower=1> J;
  int<lower=1> N;
  int<lower=1> M;
  int<lower=2> K;
  int<lower=1, upper=J> tag[N];
  int<lower=1, upper=I> party_ideo[N];
  int<lower=1, upper=I> party_lr[M];
  int<lower=1, upper=J> not_tag_down_ideo[J - 1];
  int<lower=0, upper=1> y_ideo[N];
  int<lower=1, upper=K> y_lr[M];

}

parameters {

  vector[I] x_1_star;
  vector[I] x_2_star;
  vector[J] delta_star;
  vector[J - 1] lambda_1_star_free;
  vector[J] lambda_2_star;
  vector<lower=0>[J - 1] beta_star_free;
  ordered[K - 1] tau_star;
  real gamma_star;

}

transformed parameters {

  vector[J] lambda_1_star = rep_vector(0, J);
  vector[J] beta_star = rep_vector(0, J);

  lambda_1_star[not_tag_down_ideo] = lambda_1_star_free;
  beta_star[not_tag_down_ideo] = beta_star_free;

}

model {

  x_1_star ~ std_normal();
  x_2_star ~ std_normal();
  delta_star ~ std_normal();
  lambda_1_star_free ~ std_normal();
  lambda_2_star ~ std_normal();
  beta_star_free ~ exponential(1);
  tau_star ~ std_normal();
  gamma_star ~ std_normal();

  y_ideo ~ bernoulli_logit(
    delta_star[tag] 
    + lambda_1_star[tag] .* x_1_star[party_ideo] 
    - beta_star[tag] .* x_1_star[party_ideo] .* x_1_star[party_ideo]
    + lambda_2_star[tag] .* x_2_star[party_ideo]
  );
  y_lr ~ ordered_logistic(gamma_star * x_1_star[party_lr], tau_star);

}

generated quantities {

  int<lower=-1, upper=1> sign_1;
  int<lower=-1, upper=1> sign_2;
  vector[I] x_1;
  vector[I] x_2;
  vector[J] delta;
  vector[J] lambda_1;
  vector[J] lambda_2;
  vector<lower=0>[J] beta;
  vector[K - 1] tau;
  real gamma;
  real mean_x_1 = mean(x_1_star);
  real mean_x_2 = mean(x_2_star);
  real sd_x_1 = sd(x_1_star);
  real sd_x_2 = sd(x_2_star);

  sign_1 = 0 < lambda_1_star[tag_right_ideo] ? 1 : -1;
  sign_2 = 0 < lambda_2_star[tag_down_ideo] ? -1 : 1;
  x_1 = sign_1 * (x_1_star - mean_x_1) / sd_x_1;
  x_2 = sign_2 * (x_2_star - mean_x_2) / sd_x_2;
  delta = delta_star 
    + mean_x_1 * (lambda_1_star - 2 * beta_star * mean_x_1) 
    + mean_x_2 * lambda_2_star;
  lambda_1 = sign_1 * sd_x_1 * (lambda_1_star - 2 * beta_star * mean_x_1);
  lambda_2 = sign_2 * sd_x_2 * lambda_2_star;
  beta = beta_star * sd_x_1 ^ 2;
  tau = tau_star - gamma_star * mean_x_1;
  gamma = sign_1 * sd_x_1 * gamma_star;

}
