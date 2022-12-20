library(tidyverse)
library(glue)


path_raw <- "01-data-sources/03-party-positions/00-sources-raw/"
path_select <- "01-data-sources/03-party-positions/01-sources-select/"


# CHES // Chapel Hill Expert Survey ----

ches_raw <- read_csv(
  glue("{path_raw}ches/1999-2019_CHES_dataset_means(v3).csv")
)

ches <-
  ches_raw %>%
  select(
    year,
    party_id,
    party,
    eu_position,
    eu_blur,
    lrgen,
    galtan,
    lrecon,
    redistribution
  ) %>%
  group_by(party_id) %>%
  filter(year == max(year))

write_csv(ches, glue("{path_select}/ches-positions.csv"))
