# Question 2: weighted histogram of annual education spending (log scale)
library(tidyverse)
library(svglite)
library(scales)

person <- read_csv("data/pslm_person_subset.csv", show_col_types = FALSE)
hh     <- read_csv("data/pslm_hh_subset.csv",     show_col_types = FALSE)

d <- person %>%
  left_join(hh %>% select(hhid, hhweight, prov_code, urban_rural), by = "hhid") %>%
  filter(prov_code == 3, urban_rural == 1)

# Students: ed_total > 0
s <- d %>% filter(ed_total > 0)

# Weighted quantile, exactly as defined in the assignment
wq <- function(x, w, p) {
  o <- order(x); x <- x[o]; w <- w[o]
  cs <- cumsum(w) / sum(w)
  x[which(cs >= p - 1e-12)[1]]
}

n_students <- nrow(s)
med_w   <- wq(s$ed_total, s$hhweight, 0.5)
med_u   <- median(s$ed_total)
p10     <- wq(s$ed_total, s$hhweight, 0.1)
p90     <- wq(s$ed_total, s$hhweight, 0.9)
ratio   <- p90 / p10

# Histogram range: Rs 100 to Rs 1,000,000 (log10 from 2 to 6)
inr        <- s %>% filter(ed_total >= 100, ed_total <= 1e6)
n_excluded <- n_students - nrow(inr)

# 40 bins, each 0.1 wide in log10 units. Density = weight share / bin width.
inr <- inr %>%
  mutate(lx  = log10(ed_total),
         bin = pmin(floor((lx - 2) / 0.1 + 1e-9), 39))
h <- inr %>%
  group_by(bin) %>%
  summarise(w = sum(hhweight), .groups = "drop") %>%
  complete(bin = 0:39, fill = list(w = 0)) %>%
  mutate(x = 2 + 0.1 * bin + 0.05,
         density = (w / sum(w)) / 0.1)

cat("Students:", n_students, "\n")
cat("Weighted median:", med_w, " Unweighted median:", med_u, "\n")
cat("Weighted p10:", p10, " p90:", p90, " ratio:", round(ratio, 2), "\n")
cat("Excluded (outside Rs 100 - 1,000,000):", n_excluded, "\n")

p <- ggplot(h, aes(x, density)) +
  geom_col(width = 0.1, fill = "#5b8db8", colour = "white", linewidth = 0.2) +
  geom_vline(xintercept = log10(med_w), linetype = "dashed") +
  geom_vline(xintercept = log10(p90),   linetype = "dashed") +
  annotate("text", x = log10(med_w) - 0.05, y = max(h$density) * 0.97,
           label = paste0("Weighted median\nRs ", comma(med_w)), hjust = 1, size = 3.6) +
  annotate("text", x = log10(p90) + 0.05, y = max(h$density) * 0.97,
           label = paste0("90th percentile\nRs ", comma(p90)), hjust = 0, size = 3.6) +
  scale_x_continuous(breaks = 2:6, limits = c(2, 6),
                     labels = c("Rs 100", "Rs 1,000", "Rs 10,000", "Rs 100,000", "Rs 1,000,000")) +
  labs(title = paste0("Half of rural Sindh students cost their family under Rs ", comma(med_w),
                      " a year; the top tenth, over Rs ", comma(p90)),
       x = "Annual education spending per student (log scale)",
       y = "Density per log10 unit",
       caption = paste0("Source: PSLM 2019-20, person file. Sample: students (ed_total > 0) in rural Sindh, n = ",
                        n_students, ". Weighted by hhweight. ",
                        n_excluded, " student(s) outside Rs 100 to Rs 1,000,000 excluded from the histogram.")) +
  theme_minimal(base_size = 12) +
  theme(plot.title.position = "plot", plot.caption.position = "plot",
        plot.title = element_text(face = "bold", size = 12),
        plot.caption = element_text(hjust = 0, size = 8),
        panel.grid.minor = element_blank())

dir.create("figures", showWarnings = FALSE)
ggsave("figures/spending_histogram.svg", p, width = 9, height = 5.5)
