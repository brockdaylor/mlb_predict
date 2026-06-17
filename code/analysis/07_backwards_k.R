############################################################
# 07_backwards_k.R
# Purpose: Identify pitchers with the highest called-strikeout (backwards K / ꓘ)
#          rate in the 2026 season, plus pitch-type breakdown for called Ks.
#
#   Backwards K = batter takes strike 3 looking (called_strike on strikeout PA)
#   K rate = called_K / total_K
#
# Two versions:
#   MLB-wide:  all pitchers with 30+ strikeouts (T±100 → sorted, take top/bottom)
#   Twins:     all Twins pitchers (any K count)
#
# Outputs:
#   output/tables/backwards_k_2026.xlsx
#   output/figures/backwards_k_rate_mlb_2026.png
#   output/figures/backwards_k_rate_twins_2026.png
#   output/figures/backwards_k_pitch_mix_2026.png
#
# Requires: data/raw/statcast/statcast_strikeouts_2026.parquet
#   → run code/data_processing/05_process_statcast_strikeouts.R first
############################################################

source(here::here("code", "00_setup.R"))

SEASON  <- 2026
MIN_K   <- 30    # minimum total Ks for pitcher to be included in MLB-wide analysis
TOP_N   <- 100   # show top N by called_K_pct for each direction (MLB-wide)

# ============================================================
# 1. Load strikeout data
# ============================================================

k_file <- file.path(DATA_RAW, "statcast", sprintf("statcast_strikeouts_%d.parquet", SEASON))

if (!file.exists(k_file)) {
  stop(
    "Missing ", k_file, "\n",
    "Run code/data_processing/05_process_statcast_strikeouts.R first."
  )
}

k_raw <- arrow::read_parquet(k_file) |> as.data.table()
message("Strikeout events loaded: ", nrow(k_raw), " rows")

# Ensure k_type and pitcher_team columns exist (derived in processing script)
if (!"k_type" %in% names(k_raw)) {
  k_raw[, k_type := fifelse(description == "called_strike", "called", "swinging")]
}
if (!"pitcher_team" %in% names(k_raw)) {
  k_raw[, pitcher_team := fifelse(inning_topbot == "Top", home_team, away_team)]
}

# Filter to 2026 season (game_date or game_year)
year_col <- intersect(names(k_raw), c("game_year", "year"))[1]
if (!is.na(year_col)) {
  k_raw <- k_raw[get(year_col) == SEASON]
  message("After year filter: ", nrow(k_raw), " rows")
}

# Determine player name column (varies by Statcast pull version)
name_col <- intersect(names(k_raw), c("player_name", "pitcher_name", "name"))[1]
if (is.na(name_col)) {
  # Fallback: use pitcher MLBAM ID as name
  k_raw[, pitcher_label := as.character(pitcher)]
  name_col <- "pitcher_label"
} else {
  k_raw[, pitcher_label := get(name_col)]
}

# ============================================================
# 2. Aggregate by pitcher: called K rate + pitch type breakdown
# ============================================================

# Overall rates per pitcher
k_by_pitcher <- k_raw[, .(
  total_K    = .N,
  called_K   = sum(k_type == "called", na.rm = TRUE),
  swinging_K = sum(k_type == "swinging", na.rm = TRUE)
), by = .(pitcher, pitcher_label, pitcher_team)]

k_by_pitcher[, called_K_pct  := called_K  / total_K]
k_by_pitcher[, swinging_K_pct := swinging_K / total_K]
k_by_pitcher <- k_by_pitcher[order(-called_K_pct)]

# Pitch type breakdown for called Ks only
k_pitch_mix <- k_raw[k_type == "called" & !is.na(pitch_type), .(
  called_K_n = .N
), by = .(pitcher, pitcher_label, pitcher_team, pitch_type)]

# Pivot to wide: one column per pitch type, values = % of pitcher's called Ks
k_pitch_mix[, total_called_K := sum(called_K_n), by = pitcher]
k_pitch_mix[, pitch_pct := called_K_n / total_called_K]

k_pitch_wide <- data.table::dcast(
  k_pitch_mix,
  pitcher + pitcher_label + pitcher_team ~ pitch_type,
  value.var = "pitch_pct",
  fill = 0
)
# Rename pitch cols to be clear
pt_cols <- setdiff(names(k_pitch_wide), c("pitcher", "pitcher_label", "pitcher_team"))
setnames(k_pitch_wide, pt_cols, paste0("called_K_pct_", pt_cols))

# Join pitch mix onto main table
k_full <- merge(k_by_pitcher, k_pitch_wide,
                by = c("pitcher", "pitcher_label", "pitcher_team"), all.x = TRUE)

# ============================================================
# 3. MLB-wide: top TOP_N by called K rate (min MIN_K total Ks)
# ============================================================

mlb_qualified <- k_full[total_K >= MIN_K][order(-called_K_pct)]
mlb_top <- mlb_qualified[1:min(TOP_N, .N)]

message("MLB-wide pitchers with ", MIN_K, "+ K: ", nrow(mlb_qualified))

# ============================================================
# 4. Twins
# ============================================================

twins_k <- k_full[grepl("MIN", pitcher_team, ignore.case = TRUE)][order(-called_K_pct)]
message("Twins pitchers: ", nrow(twins_k))

# ============================================================
# 5. Excel output
# ============================================================

write_k_excel <- function(mlb_data, twins_data, full_data, filename) {
  if (!requireNamespace("openxlsx2", quietly = TRUE)) {
    message("openxlsx2 not found — writing CSV fallback")
    data.table::fwrite(mlb_data, file.path(OUTPUT_TABLES,
      sub("\\.xlsx$", "_mlb.csv", filename)))
    data.table::fwrite(twins_data, file.path(OUTPUT_TABLES,
      sub("\\.xlsx$", "_twins.csv", filename)))
    return(invisible(NULL))
  }

  path <- file.path(OUTPUT_TABLES, filename)
  wb <- openxlsx2::wb_workbook(creator = "mlb_predict")

  # MLB top sheet
  wb <- openxlsx2::wb_add_worksheet(wb, sheet = "MLB_Top100")
  wb <- openxlsx2::wb_add_data_table(
    wb, sheet = "MLB_Top100", x = as.data.frame(mlb_data),
    table_name = "tbl_mlb_k", table_style = "TableStyleMedium2"
  )

  # Twins sheet
  wb <- openxlsx2::wb_add_worksheet(wb, sheet = "Twins")
  wb <- openxlsx2::wb_add_data_table(
    wb, sheet = "Twins", x = as.data.frame(twins_data),
    table_name = "tbl_twins_k", table_style = "TableStyleMedium7"
  )

  # Full league (all pitchers, no K minimum)
  wb <- openxlsx2::wb_add_worksheet(wb, sheet = "All_Pitchers")
  wb <- openxlsx2::wb_add_data_table(
    wb, sheet = "All_Pitchers", x = as.data.frame(full_data),
    table_name = "tbl_all_k", table_style = "TableStyleLight1"
  )

  openxlsx2::wb_save(wb, path, overwrite = TRUE)
  message("Saved → ", path)
}

write_k_excel(mlb_top, twins_k, k_full, "backwards_k_2026.xlsx")

# ============================================================
# 6. ggplot2: called K rate — MLB top 30
# ============================================================

plot_mlb <- mlb_top[1:min(30, .N)]
plot_mlb[, pitcher_fac := factor(pitcher_label, levels = rev(pitcher_label))]

p_mlb_k <- ggplot(plot_mlb, aes(x = called_K_pct, y = pitcher_fac)) +
  geom_col(fill = "#1a5276", width = 0.7, alpha = 0.85) +
  geom_text(
    aes(label = sprintf("%.1f%%\n(%d/%d)", called_K_pct * 100, called_K, total_K)),
    hjust = -0.05, size = 2.8
  ) +
  scale_x_continuous(
    labels = scales::percent_format(accuracy = 1),
    expand = expansion(mult = c(0, 0.25))
  ) +
  labs(
    title    = paste0("Called Strikeout (Backwards K) Rate — ", SEASON,
                      " MLB Top 30 (min ", MIN_K, " K)"),
    subtitle = "% of strikeouts that were called (batter looking at strike 3)",
    x        = "Called K %",
    y        = NULL,
    caption  = "Source: Baseball Savant via direct CSV pull"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.major.y = element_blank(),
    axis.text.y = element_text(size = 9)
  )

save_plot(p_mlb_k, "backwards_k_rate_mlb_2026.png", width = 9, height = 10)

# ============================================================
# 7. ggplot2: called K rate — Twins
# ============================================================

if (nrow(twins_k) > 0) {
  twins_plot <- copy(twins_k)
  twins_plot[, pitcher_fac := factor(
    pitcher_label,
    levels = pitcher_label[order(called_K_pct)]
  )]

  p_twins_k <- ggplot(twins_plot, aes(x = called_K_pct, y = pitcher_fac)) +
    geom_col(fill = "#002B5C", width = 0.7, alpha = 0.85) +
    geom_text(
      aes(label = sprintf("%.1f%%\n(%d/%d)", called_K_pct * 100, called_K, total_K)),
      hjust = -0.05, size = 3
    ) +
    scale_x_continuous(
      labels = scales::percent_format(accuracy = 1),
      expand = expansion(mult = c(0, 0.3))
    ) +
    labs(
      title    = paste0("Called Strikeout (Backwards K) Rate — ",
                        SEASON, " Minnesota Twins"),
      subtitle = "% of strikeouts that were called (batter looking at strike 3)",
      x        = "Called K %",
      y        = NULL,
      caption  = "Source: Baseball Savant via direct CSV pull"
    ) +
    theme_minimal(base_size = 12) +
    theme(panel.grid.major.y = element_blank())

  save_plot(p_twins_k, "backwards_k_rate_twins_2026.png",
            width = 8, height = max(4, nrow(twins_k) * 0.5))
}

# ============================================================
# 8. ggplot2: pitch type mix for called Ks (MLB top 20)
# ============================================================

# Long format for pitch mix plot
pitch_mix_long <- k_raw[k_type == "called" & !is.na(pitch_type)]
# For MLB top pitchers only
top_pitcher_ids <- mlb_top$pitcher[1:min(20, nrow(mlb_top))]
pitch_mix_top <- pitch_mix_long[pitcher %in% top_pitcher_ids, .(
  n = .N
), by = .(pitcher, pitcher_label, pitch_type)]
pitch_mix_top[, total := sum(n), by = pitcher]
pitch_mix_top[, pct := n / total]

# Order pitchers by called K rate
pitcher_order <- mlb_top$pitcher_label[1:min(20, nrow(mlb_top))]
pitch_mix_top[, pitcher_fac := factor(pitcher_label, levels = rev(pitcher_order))]

# Keep top 6 pitch types by frequency; lump rest as "Other"
top_types <- pitch_mix_top[, .(total_n = sum(n)), by = pitch_type][
  order(-total_n)][1:min(6, .N), pitch_type]
pitch_mix_top[, pitch_grp := fifelse(pitch_type %in% top_types, pitch_type, "Other")]
pitch_mix_agg <- pitch_mix_top[, .(pct = sum(pct)), by = .(pitcher_fac, pitch_grp)]

p_mix <- ggplot(pitch_mix_agg, aes(x = pct, y = pitcher_fac, fill = pitch_grp)) +
  geom_col(position = "fill", width = 0.7) +
  scale_x_continuous(labels = scales::percent_format(accuracy = 1)) +
  scale_fill_brewer(palette = "Set2", name = "Pitch type") +
  labs(
    title    = paste0("Pitch Type on Called Ks — ", SEASON, " Top 20 by Called K%"),
    subtitle = "What pitches generated backwards Ks?",
    x        = "Share of called Ks",
    y        = NULL,
    caption  = "Source: Baseball Savant via direct CSV pull"
  ) +
  theme_minimal(base_size = 11) +
  theme(panel.grid.major.y = element_blank(),
        axis.text.y = element_text(size = 8))

save_plot(p_mix, "backwards_k_pitch_mix_2026.png", width = 10, height = 8)

# ============================================================
# 9. Console summary
# ============================================================

cat("\n=== Backwards K Rate Summary (", SEASON, ", min ", MIN_K, " K) ===\n")
cat("Total pitchers: ", nrow(k_full), " | Qualified (", MIN_K, "+ K): ", nrow(mlb_qualified), "\n")
cat("\nTop 10 highest called K rate:\n")
print(mlb_top[1:min(10, .N), .(
  pitcher = pitcher_label, team = pitcher_team,
  total_K, called_K, called_K_pct = round(called_K_pct, 3)
)], row.names = FALSE)

if (nrow(twins_k) > 0) {
  cat("\nTwins pitchers (all):\n")
  print(twins_k[, .(
    pitcher = pitcher_label, total_K, called_K,
    called_K_pct = round(called_K_pct, 3)
  )], row.names = FALSE)
}

cat("07_backwards_k.R complete.\n")
