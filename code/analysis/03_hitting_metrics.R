############################################################
# 03_hitting_metrics.R
# Purpose: hitting metric relationships and aging curves
# Data: Lahman player-season batting; FanGraphs (optional, if pulled)
############################################################

source(here::here("code", "00_setup.R"))

# ---- 1. Load processed data ----
bat_file <- file.path(DATA_PROCESSED, "lahman_batting_season.parquet")
if (!file.exists(bat_file)) {
  stop("Missing ", bat_file, " — run code/data_processing/04_process_lahman_data.R first.")
}
bat <- arrow::read_parquet(bat_file) |> as.data.table()

latest_yr <- max(bat$yearID)
qual <- bat[yearID == latest_yr & PA >= 400]
message("Latest Lahman season: ", latest_yr, " | qualified hitters (PA >= 400): ", nrow(qual))

# ---- 2. Summary statistics, qualified hitters ----
print(df_summary(qual[, .(PA, AVG, OBP, SLG, OPS, ISO, k_rate, bb_rate, age)]))
fwrite(
  qual[order(-OPS), .(name, age, PA, AVG, OBP, SLG, OPS, ISO, k_rate, bb_rate)],
  file.path(OUTPUT_TABLES, sprintf("hitters_qualified_%d.csv", latest_yr))
)

# ---- 3. Metric relationships ----
p_iso_k <- ggplot(qual, aes(k_rate, ISO)) +
  geom_point(alpha = 0.6) +
  geom_smooth(method = "lm", se = FALSE, color = "steelblue") +
  ggrepel::geom_text_repel(
    data = qual[ISO > quantile(ISO, 0.95) | k_rate > quantile(k_rate, 0.97)],
    aes(label = name), size = 3, max.overlaps = 15
  ) +
  labs(title = sprintf("Power vs. strikeouts, qualified hitters %d", latest_yr),
       x = "K%", y = "ISO")
save_plot(p_iso_k, "hitting_iso_vs_krate.png")

p_obp_slg <- ggplot(qual, aes(OBP, SLG)) +
  geom_point(alpha = 0.6) +
  ggrepel::geom_text_repel(
    data = qual[OPS > quantile(OPS, 0.93)],
    aes(label = name), size = 3, max.overlaps = 15
  ) +
  labs(title = sprintf("OBP vs. SLG, qualified hitters %d", latest_yr),
       x = "OBP", y = "SLG")
save_plot(p_obp_slg, "hitting_obp_vs_slg.png")

# ---- 4. Aging curve (within-player, fixed effects) ----
# OPS on age dummies with player and year FE, 1947+ (integration era), PA >= 300
panel <- bat[yearID >= 1947 & PA >= 300 & age %between% c(20, 38)]
m_age <- feols(OPS ~ i(age, ref = 27) | playerID + yearID,
               cluster = ~playerID, data = panel)

age_eff <- as.data.table(broom::tidy(m_age, conf.int = TRUE))
age_eff[, age := as.integer(gsub("age::", "", term))]

p_age <- ggplot(age_eff, aes(age, estimate)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high), color = "steelblue") +
  labs(title = "OPS aging curve (player + year FE, ref. age 27), 1947–present",
       x = "Age", y = "OPS relative to age 27")
save_plot(p_age, "hitting_aging_curve_ops.png")
save_table(m_age, "hitting_aging_curve_ops.html")

# ---- 5. Optional: FanGraphs advanced metrics (if pulled) ----
fg_file <- file.path(DATA_PROCESSED, "fg_batters_all.parquet")
if (file.exists(fg_file)) {
  fg <- arrow::read_parquet(fg_file) |> as.data.table()
  message("FanGraphs batters loaded: ", nrow(fg), " rows — extend analysis here (wOBA, wRC+, barrels).")
} else {
  message("fg_batters_all.parquet not found — skipping FanGraphs section.")
}

cat("03_hitting_metrics.R complete.\n")
