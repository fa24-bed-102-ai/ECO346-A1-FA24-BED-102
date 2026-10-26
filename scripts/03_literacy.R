# Question 3: weighted literacy rate by age band, women and men (the redesign)
library(tidyverse)
library(svglite)

person <- read_csv("data/pslm_person_subset.csv", show_col_types = FALSE)
hh     <- read_csv("data/pslm_hh_subset.csv",     show_col_types = FALSE)

d <- person %>%
  left_join(hh %>% select(hhid, hhweight, prov_code, urban_rural), by = "hhid") %>%
  filter(prov_code == 3, urban_rural == 1)

lit <- d %>% filter(age >= 10, age <= 64, !is.na(literate)) %>%
  mutate(band_start = (age %/% 5) * 5,
         mid = band_start + 2,
         sex_label = factor(sex, levels = c(1, 2), labels = c("Men", "Women")))

# Band table: unweighted n and weighted literacy rate per band and sex
tab <- lit %>%
  group_by(band_start, mid, sex_label) %>%
  summarise(n = n(),
            rate = 100 * weighted.mean(literate, hhweight),
            .groups = "drop") %>%
  mutate(thin = n < 30, rate = round(rate, 1))

dir.create("figures", showWarnings = FALSE)
write_csv(tab, "figures/band_table_R.csv")
print(as.data.frame(tab))

wide <- tab %>%
  select(band_start, mid, sex_label, rate) %>%
  pivot_wider(names_from = sex_label, values_from = rate) %>%
  mutate(gap = round(Men - Women, 1))
best <- wide %>% slice_max(gap, n = 1)
cat("Women 15-19:", wide$Women[wide$band_start == 15],
    " Men 15-19:",   wide$Men[wide$band_start == 15], "\n")
cat("Women 55-59:", wide$Women[wide$band_start == 55],
    " Men 55-59:",   wide$Men[wide$band_start == 55], "\n")
cat("Largest gap: ages", best$band_start, "-", best$band_start + 4, " gap =", best$gap, "\n")

cols <- c(Men = "#1f77b4", Women = "#d95f02")
ends <- tab %>% filter(mid == max(mid))

p <- ggplot(tab, aes(mid, rate, colour = sex_label, group = sex_label)) +
  geom_line(linewidth = 0.9) +
  geom_point(aes(shape = thin), size = 3, fill = "white", stroke = 1.1) +
  scale_shape_manual(values = c(`FALSE` = 16, `TRUE` = 1)) +
  geom_text(data = ends, aes(label = sex_label), hjust = -0.25, fontface = "bold", show.legend = FALSE) +
  annotate("segment", x = best$mid, xend = best$mid, y = best$Women, yend = best$Men,
           colour = "grey40", linetype = "dotted") +
  annotate("text", x = best$mid + 0.8, y = (best$Women + best$Men) / 2, hjust = 0, size = 3.4,
           label = paste0("Largest gap: ", best$gap, " points\n(ages ", best$band_start, "-", best$band_start + 4, ")")) +
  scale_colour_manual(values = cols) +
  scale_x_continuous(breaks = seq(12, 62, 5), limits = c(10, 70)) +
  scale_y_continuous(limits = c(0, 100)) +
  labs(title = "Literacy falls with age for rural Sindh women, far faster than for men",
       x = "Age band (plotted at midpoint)", y = "Literacy rate (%)",
       caption = paste0("Source: PSLM 2019-20, person file. Sample: persons aged 10-64 in rural Sindh, literate not missing. ",
                        "Weighted by hhweight.\nHollow markers = band with fewer than 30 observations for that sex.")) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none", plot.title.position = "plot", plot.caption.position = "plot",
        plot.title = element_text(face = "bold", size = 12),
        plot.caption = element_text(hjust = 0, size = 8),
        panel.grid.minor = element_blank())

ggsave("figures/literacy_by_age.svg", p, width = 9, height = 5.5)
