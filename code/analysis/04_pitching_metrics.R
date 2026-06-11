############################################################
# 04_pitching_metrics.R
# Purpose: pitching metric relationships; Statcast velocity/pitch mix
# Data: Lahman player-season pitching; Statcast (optional, if pulled)
############################################################

source(here::here("code", "00_setup.R"))

# ---- 1. Load processed data ----
pit_file <- file.path(DATA_PROCESSED, "lahman_pitching_season.parquet")
if (!file.exists(pit_file)) {
  stop("Missing ", pit_file, " — run code/data_processing/04_process_lahman_data.R first.")
}
pit <- arrow::read_parquet(pit_file) |> as.data.table()

latest_yr <- max(pit$yearID)
qual <- pit[yearID == latest_yr & IP >= 100]
message("Latest Lahman season: ", latest_yr, " | pitchers with IP >= 100: ", nrow(qual))

# ---- 2. Summary statistics ----
print(df_summary(qual[, .(IP, ERA, FIP, k9, bb9, hr9, age)]))
fwrite(
  qual[order(FIP), .(name, age, IP, W, L, ERA, FIP, k9, bb9, hr9)],
  file.path(OUTPUT_TABLES, sprintf("pitchers_qualified_%d.csv", latest_yr))
)

# ---- 3. ERA vs FIP ----
p_era_fip <- ggplot(qual, aes(FIP, ERA)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "grey50") +
  geom_point(alpha = 0.6) +
  ggrepel::geom_text_repel(
    data = qual[abs(ERA - FIP) > quantile(abs(ERA - FIP), 0.95)],
    aes(label = name), size = 3, max.overlaps = 15
  ) +
  labs(title = sprintf("ERA vs. FIP, pitchers with 100+ IP, %d", latest_yr),
       subtitle = "Points far from the 45° line over/under-performed their peripherals",
       x = "FIP", y = "ERA")
save_plot(p_era_fip, "pitching_era_vs_fip.png")

# ---- 4. K/9 vs BB/9 ----
p_k_bb <- ggplot(qual, aes(bb9, k9)) +
  geom_point(alpha = 0.6) +
  ggrepel::geom_text_repel(
    data = qual[k9 > quantile(k9, 0.95) | bb9 < quantile(bb9, 0.03)],
    aes(label = name), size = 3, max.overlaps = 15
  ) +
  labs(title = sprintf("Strikeouts vs. walks, pitchers with 100+ IP, %d", latest_yr),
       x = "BB/9", y = "K/9")
save_plot(p_k_bb, "pitching_k9_vs_bb9.png")

# ---- 5. League K/9 trend ----
lg_k <- pit[yearID >= 1901 & IP > 0,
            .(k9 = 9 * sum(SO) / sum(IP)), by = yearID][order(yearID)]
p_k_trend <- ggplot(lg_k, aes(yearID, k9)) +
  geom_line(color = "grey60") +
  geom_smooth(se = FALSE, span = 0.25, color = "steelblue") +
  labs(title = "League K/9, 1901–present", x = NULL, y = "K/9")
save_plot(p_k_trend, "pitching_league_k9_trend.png")

# ---- 6. Optional: Statcast velocity and pitch mix (if pulled) ----
sc_file <- file.path(DATA_PROCESSED, "statcast_all.parquet")
if (file.exists(sc_file)) {

  # Read only needed columns — full pitch-level file is large
  sc <- arrow::read_parquet(
    sc_file,
    col_select = c("game_year", "pitch_type", "release_speed")
  ) |> as.data.table()
  sc <- sc[!is.na(pitch_type) & !is.na(release_speed)]

  # Average four-seam velocity by season
  velo <- sc[pitch_type == "FF", .(avg_velo = mean(release_speed), n = .N), by = game_year]
  print(velo[order(game_year)])
  fwrite(velo, file.path(OUTPUT_TABLES, "statcast_ff_velocity_by_year.csv"))

  # Pitch mix shares by season
  mix <- sc[, .N, by = .(game_year, pitch_type)]
  mix[, share := N / sum(N), by = game_year]
  top_pitches <- mix[, sum(N), by = pitch_type][order(-V1)][1:6, pitch_type]

  p_mix <- ggplot(mix[pitch_type %in% top_pitches],
                  aes(game_year, share, color = pitch_type)) +
    geom_line() + geom_point() +
    labs(title = "Pitch mix shares by season (Statcast)",
         x = NULL, y = "Share of pitches", color = "Pitch")
  save_plot(p_mix, "pitching_statcast_pitch_mix.png")

} else {
  message("statcast_all.parquet not found — skipping Statcast section. ",
          "Run code/data_processing/01_process_statcast_data.R to enable.")
}

cat("04_pitching_metrics.R complete.\n")
