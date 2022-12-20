library(tidyverse)
library(glue)


path_select <- "01-data-sources/03-party-positions/01-sources-select/"


## Party left/right positions

## Read and prepare data ----

pf_core <- read_csv(
  "01-data-sources/01-partyfacts/core-parties.csv",
  guess_max = 10000
)
pf_ext <- read_csv(
  "01-data-sources/01-partyfacts/external-parties.csv",
  guess_max = 10000
)

ches_raw <- read_csv(glue("{path_select}ches-positions.csv"))


# Add Party Facts ID to source dataset
get_pf_link <- function(dataset) {
  pf_ext %>%
    filter(dataset_key == dataset) %>%
    select(partyfacts_id, dataset_party_id, name_short)
}


## CHES // Chapel Hill Expert Survey ----

ches_link <- get_pf_link("ches") %>% rename(ches_short = name_short)

ches_pos <-
  ches_raw %>%
  select(
    ches_id = party_id,
    ches_left_right = lrgen,  # "overall ideological stance"
    ches_eu_integration = eu_position,  # "overal orientation towards European integration"
##    ches_eu_blur = eu_blur,  # "how blurry was position towards European integration"
    ches_gal_tan = galtan,  # "democratic freedoms and rights -- libertarian/postmaterialist vs. traditional/authoritarian
    ches_economy = lrecon,  #  government role economy (active vs. reduced)
    ches_redistribute = redistribution  # "redistribution of wealth from the rich to the poor"
) %>%
  mutate(ches_id = as.character(ches_id)) %>%
  left_join(ches_link, by = c("ches_id" = "dataset_party_id")) %>%
  select(ches_short, everything()) %>%
  distinct(partyfacts_id, .keep_all = TRUE)


## Final dataset ----

# create vector of Party Facts IDs with party position data
pf_id_to_keep <-
  pf_ext %>%
  filter(dataset_key %in% "ches") %>%
  pull(partyfacts_id)

# select Party Facts parties
pos_out <-
  pf_core %>%
  filter(partyfacts_id %in% pf_id_to_keep) %>%
  select(country, partyfacts_id, name_short)

# add position data
pos_out <-
  pos_out %>%
  left_join(ches_pos)

# some clean-up
pos_out <-
  pos_out %>%
  mutate(across(where(is.numeric), round, 2)) %>%
  arrange(country, name_short)

write_csv(
  pos_out,
  "01-data-sources/03-party-positions/02-party-positions.csv",
  na = ""
)


# count observations in final dataset
map_df(pos_out %>% select(ends_with("_id")), ~ sum(! is.na(.)))
