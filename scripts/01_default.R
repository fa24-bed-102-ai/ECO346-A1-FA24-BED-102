# Question 4: the DEFAULT figure. Nothing added: R's defaults, untouched.
# Run from the repository root.
library(tidyverse)
library(svglite)

person <- read_csv("data/pslm_person_subset.csv", show_col_types = FALSE)
hh     <- read_csv("data/pslm_hh_subset.csv",     show_col_types = FALSE)

# Attach weight, province, area from the household file; keep variant 2 = Sindh rural
d <- person %>%
  left_join(hh %>% select(hhid, hhweight, prov_code, urban_rural), by = "hhid") %>%
  filter(prov_code == 3, urban_rural == 1)

# Literacy sample: aged 10-64, literate not missing
lit <- d %>% filter(age >= 10, age <= 64, !is.na(literate))

p <- ggplot(lit, aes(age, literate)) + geom_point()

dir.create("figures", showWarnings = FALSE)
ggsave("figures/default.svg", p, width = 7, height = 5)
