############################################################
# 03_process_fangraphs_data.R
# Purpose: Pull FanGraphs season-level advanced batting, pitching, and park data
#          Incremental: skips completed seasons, re-pulls current season
############################################################

source(here::here("code", "00_setup.R"))

# ---- Config ----
SEASONS <- c(2025, 2026)

RAW_DIR <- file.path(DATA_RAW, "fangraphs")
dir.create(RAW_DIR, showWarnings = FALSE, recursive = TRUE)

current_year <- as.integer(format(Sys.Date(), "%Y"))

# ---- Pull by season ----
for (season in SEASONS) {

  season_done <- season < current_year

  # --- Batters ---
  batter_file <- file.path(RAW_DIR, sprintf("fg_batters_%d.parquet", season))

  if (season_done && file.exists(batter_file)) {
    message("Skipping FG batters ", season, " — already downloaded")
  } else {
    message("Pulling FanGraphs batters: ", season)
    df_batters <- tryCatch(
      baseballr::fg_batter_leaders(
        startseason = season,
        endseason   = season,
        lg          = "all",
        qual        = 0,
        ind         = 1
      ),
      error = function(e) {
        message("  ERROR: ", conditionMessage(e))
        NULL
      }
    )
    if (!is.null(df_batters) && nrow(df_batters) > 0) {
      arrow::write_parquet(df_batters, batter_file)
      message("  Saved ", nrow(df_batters), " rows → ", basename(batter_file))
    }
  }

  # --- Pitchers ---
  pitcher_file <- file.path(RAW_DIR, sprintf("fg_pitchers_%d.parquet", season))

  if (season_done && file.exists(pitcher_file)) {
    message("Skipping FG pitchers ", season, " — already downloaded")
  } else {
    message("Pulling FanGraphs pitchers: ", season)
    df_pitchers <- tryCatch(
      baseballr::fg_pitcher_leaders(
        startseason = season,
        endseason   = season,
        lg          = "all",
        qual        = 0,
        ind         = 1
      ),
      error = function(e) {
        message("  ERROR: ", conditionMessage(e))
        NULL
      }
    )
    if (!is.null(df_pitchers) && nrow(df_pitchers) > 0) {
      arrow::write_parquet(df_pitchers, pitcher_file)
      message("  Saved ", nrow(df_pitchers), " rows → ", basename(pitcher_file))
    }
  }

  # --- Park Factors ---
  park_file <- file.path(RAW_DIR, sprintf("fg_park_factors_%d.parquet", season))

  if (season_done && file.exists(park_file)) {
    message("Skipping FG park factors ", season, " — already downloaded")
  } else {
    message("Pulling FanGraphs park factors: ", season)
    df_park <- tryCatch(
      baseballr::fg_park(season),
      error = function(e) {
        message("  ERROR: ", conditionMessage(e))
        NULL
      }
    )
    if (!is.null(df_park) && nrow(df_park) > 0) {
      arrow::write_parquet(df_park, park_file)
      message("  Saved ", nrow(df_park), " rows → ", basename(park_file))
    }
  }
}

# ---- Combine → processed ----
message("\nCombining FanGraphs files...")

batter_files <- list.files(RAW_DIR, pattern = "fg_batters_.*\\.parquet$", full.names = TRUE)
if (length(batter_files) > 0) {
  df_all <- purrr::map(batter_files, arrow::read_parquet) |>
    data.table::rbindlist(fill = TRUE)
  out <- file.path(DATA_PROCESSED, "fg_batters_all.parquet")
  arrow::write_parquet(df_all, out)
  message("Saved: ", nrow(df_all), " rows → ", basename(out))
}

pitcher_files <- list.files(RAW_DIR, pattern = "fg_pitchers_.*\\.parquet$", full.names = TRUE)
if (length(pitcher_files) > 0) {
  df_all <- purrr::map(pitcher_files, arrow::read_parquet) |>
    data.table::rbindlist(fill = TRUE)
  out <- file.path(DATA_PROCESSED, "fg_pitchers_all.parquet")
  arrow::write_parquet(df_all, out)
  message("Saved: ", nrow(df_all), " rows → ", basename(out))
}

park_files <- list.files(RAW_DIR, pattern = "fg_park_factors_.*\\.parquet$", full.names = TRUE)
if (length(park_files) > 0) {
  df_all <- purrr::map(park_files, arrow::read_parquet) |>
    data.table::rbindlist(fill = TRUE)
  out <- file.path(DATA_PROCESSED, "fg_park_factors_all.parquet")
  arrow::write_parquet(df_all, out)
  message("Saved: ", nrow(df_all), " rows → ", basename(out))
}

cat("03_process_fangraphs_data.R complete.\n")
