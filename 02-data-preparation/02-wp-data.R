## Create wide-format dataset of parties and tags
## Restrict sample:
##  - CHES countries, EU countries (2022), or Europe (geographic)
##  - 1999-present (CHES) vs. 1992-present (first euroscepticism)
## Manually exclude most common incorrect tags (e.g. news agencies)


library(tidyverse)


# "ches", "eu", or "europe"
countries <- "ches"

# startyear (1999: CHES; 1992: first eurosceptic EP group)
begin_obs_period <- 1992

# tags to exclude (regex patterns)
exclude_patterns <- c(
  "^abc",
  "(^agence|agency$)",
  "^al jazeera",
  "^balkan insight$",
  "^bbc$",
  "cent(re|er) for .+",
  ".+ cent(re|er)$",
  "comparative .+ politics",
  ".+ service",
  "^deutsche welle$",
  "\\(?broadcaster\\)?$",
  "^el .+",
  "express$",
  "^encyclop.+dia britannica$",
  "^euractiv$",
  "^euronews$",
  "^europe 1$",
  "^europe elects$",
  "^france 24$",
  "^freedom house",
  "^google books$",
  "(.+ journal$|^journal of .+)",
  "kathimerini",
  "\\(?magazine\\)?$",
  "e.?sharpe$",
  "new york",
  " news$",
  "^not found",
  "^palgrave.?macmillan",
  "^politico$",
  " presse?$",
  " publishers?$",
  "(.+ radio$|^radio .+)",
  "^reuters$",
  "(.+ review$|^review of .+)",
  "^routledge",
  "^rowman.?littlefield",
  "^rudy andeweg$",
  "^springer",
  " survey",
  "^taylor.?francis",
  "^the ",
  " times$"
)


# Load data ----

wp_raw <- read_csv("02-data-preparation/01-wp-infobox.csv")
cnt <- read_csv("01-data-sources/01-partyfacts/countries.csv")
pf <- read_csv("01-data-sources/01-partyfacts/core-parties.csv")


# Delete incorrect tags ----

tags_exclude <- grep(
  pattern = paste(exclude_patterns, collapse = "|"),
  unique(wp_raw$position),
  value = TRUE
)
wp_raw <- subset(wp_raw, !position %in% tags_exclude)

# check/see excluded tags
sort(tags_exclude)


# Select countries ----

countries_eu <- c(
  "AUT",
  "BEL",
  "BGR",
  "HRV",
  "CYP",
  "CZE",
  "DNK",
  "EST",
  "FIN",
  "FRA",
  "DEU",
  "GRC",
  "HUN",
  "IRL",
  "ITA",
  "LVA",
  "LTU",
  "LUX",
  "MLT",
  "NLD",
  "POL",
  "PRT",
  "ROU",
  "SVK",
  "SVN",
  "ESP",
  "SWE"
)

if (countries == "ches")
  countries_select <- c(countries_eu, "CHE", "ISL", "NOR", "TUR")

if (countries == "eu")
  countries_select <- countries_eu

if (countries == "europe")
  countries_select2 <- unique(cnt$country[cnt$continent == "Europe"])

wp_raw <-
  pf %>%
  left_join(cnt, by = "country") %>%
  select(partyfacts_id, year_last, country, continent) %>%
  left_join(wp_raw, ., by = "partyfacts_id") %>%
  filter(country %in% countries_select) %>%
  filter(year_last >= begin_obs_period | is.na(year_last)) %>%
  select(-c("year_last", "country", "continent"))


# Dataset in wide format with tags as variable names ----

ib_out <-
  wp_raw %>%
  select(-source) %>%
  distinct() %>%
  mutate(
    value = 1,
    position = str_replace_all(position, "\\W+", "_")
    ) %>%
  spread(position, value, fill = 0)

write_csv(ib_out, "02-data-preparation/02-wp-data.csv")