############################################################
# 06_xba_ba_gap.R
# Purpose: Identify hitters with the largest gap between expected BA (xBA / xAVG)
#          and actual BA for the 2026 season, for hitters with 50+ AB.
#
#   Positive gap (xAVG > AVG) → hitter is "unlucky" (outperforming peripherals)
#   Negative gap (xAVG < AVG) → hitter is "lucky" (underperforming peripherals)
#
# Two versions:
#   MLB-wide:  top 100 positive gap + top 100 negative gap ("T±100")
#   Twins:     all Twins hitters with 50+ AB
#
# Outputs:
#   output/tables/xba_ba_gap_mlb_2026.xlsx
#   output/tables/xba_ba_gap_twins_2026.xlsx
#   output/figures/xba_ba_gap_mlb_2026.png
#   output/figures/xba_ba_gap_twins_2026.png
############################################################

source(here::here("code", "00_setup.R"))

SEASON   <- 2026
MIN_AB   <- 50
TOP_N    <- 100      # top/bottom N for MLB-wide display

# ============================================================
# 1. Load FanGraphs batting leaders
# ============================================================
fg_file <- file.path(DATA_PROCESSED, "fg_batters_all.parquet")
if (!file.exists(fg_file)) {
  stop("Missing fg_batters_all.parquet — run code/data_processing/03_process_fangraphs_data.R first.")
}

fg <- arrow::read_parquet(fg_file) |> as.data.table()
message("FG batters loaded: ", nrow(fg), " rows across seasons: ",
        paste(sort(unique(fg$Season)), collapse = ", "))

# ============================================================
# 2. Filter to 2026, 50+ AB; compute gap
# ============================================================

# Confirm key columns exist
needed <- c("Season", "AB", "AVG", "xAVG")
missing_cols <- setdiff(needed, names(fg))
if (length(missing_cols) > 0) {
  stop("Missing columns: ", paste(missing_cols, collapse = ", "),
       "\nAvailable: ", paste(names(fg), collapse = ", "))
}

bat_2026 <- fg[Season == SEASON & AB >= MIN_AB]
message("2026 hitters with ", MIN_AB, "+ AB: ", nrow(bat_2026))

bat_2026[, xAVG_BA_gap := xAVG - AVG]
bat_2026[, gap_direction := fifelse(xAVG_BA_gap > 0, "Unlucky (xAVG > AVG)", "Lucky (AVG > xAVG)")]
bat_2026 <- bat_2026[order(-xAVG_BA_gap)]

# Identify the player name column (FG uses PlayerName)
name_col <- intersect(names(bat_2026), c("PlayerName", "Name", "player_name"))[1]
team_col <- intersect(names(bat_2026), c("team_name_abb", "Team", "team"))[1]

# Core display columns
display_cols <- intersect(names(bat_2026), c(
  name_col, "Season", team_col, "Age", "G", "PA", "AB",
  "AVG", "xAVG", "xAVG_BA_gap", "gap_direction",
  "BABIP", "HardHit_pct", "Barrel_pct", "EV", "wOBA", "xwOBA", "wRC_plus"
))

bat_display <- bat_2026[, ..display_cols]

# ============================================================
# 3. MLB-wide: top 100 positive + top 100 negative
# ============================================================

unlucky_top <- bat_display[xAVG_BA_gap > 0][order(-xAVG_BA_gap)][1:min(TOP_N, .N)]
lucky_top   <- bat_display[xAVG_BA_gap < 0][order(xAVG_BA_gap)][1:min(TOP_N, .N)]

mlb_wide <- rbindlist(list(unlucky_top, lucky_top), fill = TRUE)
mlb_wide <- mlb_wide[order(-xAVG_BA_gap)]

# ============================================================
# 4. Twins filter
# ============================================================

twins_mask <- grepl("MIN|Twins|Minnesota", bat_display[[team_col]], ignore.case = TRUE)
twins_bat  <- bat_display[twins_mask][order(-xAVG_BA_gap)]
message("Twins hitters with ", MIN_AB, "+ AB: ", nrow(twins_bat))

# ============================================================
# 5. Excel output
# ============================================================

write_gap_excel <- function(data_mlb, data_twins, filename) {
  if (!requireNamespace("openxlsx2", quietly = TRUE)) {
    message("openxlsx2 not found — writing CSV fallback")
    data.table::fwrite(data_mlb,
      file.path(OUTPUT_TABLES, sub("\\.xlsx$", "_mlb.csv", filename)))
    data.table::fwrite(data_twins,
      file.path(OUTPUT_TABLES, sub("\\.xlsx$", "_twins.csv", filename)))
    return(invisible(NULL))
  }
  path <- file.path(OUTPUT_TABLES, filename)
  wb <- openxlsx2::wb_workbook(creator = "mlb_predict")

  # MLB-wide sheet
  wb <- openxlsx2::wb_add_worksheet(wb, sheet = "MLB_Top200")
  wb <- openxlsx2::wb_add_data_table(
    wb, sheet = "MLB_Top200", x = as.data.frame(data_mlb),
    table_name = "tbl_mlb_gap", table_style = "TableStyleMedium2"
  )

  # Twins sheet
  wb <- openxlsx2::wb_add_worksheet(wb, sheet = "Twins")
  wb <- openxlsx2::wb_add_data_table(
    wb, sheet = "Twins", x = as.data.frame(data_twins),
    table_name = "tbl_twins_gap", table_style = "TableStyleMedium7"
  )

  # Full league sheet (all 50+ AB hitters, for pivot-table use)
  all_data <- bat_display[order(-xAVG_BA_gap)]
  wb <- openxlsx2::wb_add_worksheet(wb, sheet = "All_50AB")
  wb <- openxlsx2::wb_add_data_table(
    wb, sheet = "All_50AB", x = as.data.frame(all_data),
    table_name = "tbl_all_gap", table_style = "TableStyleLight1"
  )

  openxlsx2::wb_save(wb, path, overwrite = TRUE)
  message("Saved → ", path)
}

write_gap_excel(mlb_wide, twins_bat, "xba_ba_gap_2026.xlsx")

# ============================================================
# 6. ggplot2 visualizations
# ============================================================

# --- MLB-wide: lollipop chart of top/bottom 30 ---
plot_data_mlb <- rbindlist(list(
  bat_display[xAVG_BA_gap > 0][order(-xAVG_BA_gap)][1:min(30, .N)],
  bat_display[xAVG_BA_gap < 0][order(xAVG_BA_gap)][1:min(30, .N)]
), fill = TRUE)

plot_data_mlb[, player_label := get(name_col)]
plot_data_mlb[, player_label := factor(
  player_label,
  levels = player_label[order(xAVG_BA_gap)]
)]

p_mlb <- ggplot(plot_data_mlb, aes(x = xAVG_BA_gap, y = player_label, fill = gap_direction)) +
  geom_col(width = 0.7, alpha = 0.85) +
  geom_vline(xintercept = 0, color = "grey30", linewidth = 0.4) +
  scale_fill_manual(
    values = c("Unlucky (xAVG > AVG)" = "#2166ac",
               "Lucky (AVG > xAVG)"   = "#d6604d"),
    name = NULL
  ) +
  scale_x_continuous(labels = function(x) sprintf("%+.3f", x)) +
  labs(
    title    = paste0("xBA vs. BA Gap — ", SEASON, " MLB (Top/Bottom 30, min ", MIN_AB, " AB)"),
    subtitle = "Blue = xBA exceeds BA (unlucky) | Red = BA exceeds xBA (lucky)",
    x        = "xAVG − AVG",
    y        = NULL,
    caption  = "Source: FanGraphs via baseballr"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position = "none",
    panel.grid.major.y = element_blank(),
    axis.text.y = element_text(size = 8)
  )

save_plot(p_mlb, "xba_ba_gap_mlb_2026.png", width = 10, height = 10)

# --- Twins: bar chart with labels ---
if (nrow(twins_bat) > 0) {
  twins_plot <- copy(twins_bat)
  twins_plot[, player_label := factor(
    get(name_col),
    levels = get(name_col)[order(xAVG_BA_gap)]
  )]

  p_twins <- ggplot(twins_plot, aes(x = xAVG_BA_gap, y = player_label, fill = gap_direction)) +
    geom_col(width = 0.7, alpha = 0.85) +
    geom_vline(xintercept = 0, color = "grey30", linewidth = 0.4) +
    geom_text(
      aes(label = sprintf("%+.3f", xAVG_BA_gap),
          hjust = ifelse(xAVG_BA_gap >= 0, -0.1, 1.1)),
      size = 3
    ) +
    scale_fill_manual(
      values = c("Unlucky (xAVG > AVG)" = "#002B5C",
                 "Lucky (AVG > xAVG)"   = "#D31145"),
      name = NULL
    ) +
    scale_x_continuous(
      labels = function(x) sprintf("%+.3f", x),
      expand = expansion(mult = c(0.15, 0.15))
    ) +
    labs(
      title    = paste0("xBA vs. BA Gap — ", SEASON, " Minnesota Twins (min ", MIN_AB, " AB)"),
      subtitle = "Blue = xBA exceeds BA (unlucky) | Red = BA exceeds xBA (lucky)",
      x        = "xAVG − AVG",
      y        = NULL,
      caption  = "Source: FanGraphs via baseballr"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      legend.position = "none",
      panel.grid.major.y = element_blank()
    )

  save_plot(p_twins, "xba_ba_gap_twins_2026.png",
            width = 9, height = max(4, nrow(twins_bat) * 0.45))
  message("Twins plot saved")
} else {
  message("No Twins hitters matched filters — skipping Twins plot.")
}

# Console summary
cat("\n=== xBA vs BA Gap Summary (", SEASON, ", ", MIN_AB, "+ AB) ===\n")
cat("Total hitters:", nrow(bat_display), "\n")
cat("Most unlucky (xAVG >> AVG):\n")
print(bat_display[1:min(10, .N), .(
  player = get(name_col), team = get(team_col), AB, AVG, xAVG, xAVG_BA_gap
)], row.names = FALSE)
cat("\nMost lucky (AVG >> xAVG):\n")
print(bat_display[.N - min(10, .N) + 1:.N][order(xAVG_BA_gap), .(
  player = get(name_col), team = get(team_col), AB, AVG, xAVG, xAVG_BA_gap
)], row.names = FALSE)

cat("06_xba_ba_gap.R complete.\n")
