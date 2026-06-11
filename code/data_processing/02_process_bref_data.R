############################################################
# 02_process_bref_data.R
# Purpose: Pull Baseball Reference game-level batter and pitcher stats
#          Incremental: skips completed seasons, re-pulls current season
############################################################

source("00_setup.R")

# ---- Config ----
SEASONS <- c(2025, 2026)

SEASON_DATES <- list(
  "2025" = list(start = "2025-03-27", end = "2025-09-28"),
  "2026" = list(start = "2026-03-26", end = as.character(Sys.Date()))
)

RAW_DIR <- file.path(DATA_RAW, "baseball_reference")
dir.create(RAW_DIR, showWarnings = FALSE, recursive = TRUE)

current_year <- as.integer(format(Sys.Date(), "%Y"))

# ---- Pull batters and pitchers for each season ----
for (season in SEASONS) {

  dates       <- SEASON_DATES[[as.character(season)]]
  season_done <- season < current_year

  # --- Batters ---
  batter_file <- file.path(RAW_DIR, sprintf("bref_batters_%d.parquet", season))

  if (season_done && file.exists(batter_file)) {
    message("Skipping BRef batters ", season, " — already downloaded")
  } else {
    message("Pulling BRef batters: ", season, " (", dates$start, " to ", dates$end, ")")
    df_batters <- tryCatch(
      baseballr::bref_daily_batter(t1 = dates$start, t2 = dates$end),
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
  pitcher_file <- file.path(RAW_DIR, sprintf("bref_pitchers_%d.parquet", season))

  if (season_done && file.exists(pitcher_file)) {
    message("Skipping BRef pitchers ", season, " — already downloaded")
  } else {
    message("Pulling BRef pitchers: ", season, " (", dates$start, " to ", dates$end, ")")
    df_pitchers <- tryCatch(
      baseballr::bref_daily_pitcher(t1 = dates$start, t2 = dates$end),
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
}

# ---- Combine → processed ----
message("\nCombining BRef files...")

batter_files <- list.files(RAW_DIR, pattern = "bref_batters_.*\\.parquet$", full.names = TRUE)
if (length(batter_files) > 0) {
  df_all <- purrr::map(batter_files, arrow::read_parquet) |>
    data.table::rbindlist(fill = TRUE)
  out <- file.path(DATA_PROCESSED, "bref_batters_all.parquet")
  arrow::write_parquet(df_all, out)
  message("Saved: ", nrow(df_all), " rows → ", basename(out))
}

pitcher_files <- list.files(RAW_DIR, pattern = "bref_pitchers_.*\\.parquet$", full.names = TRUE)
if (length(pitcher_files) > 0) {
  df_all <- purrr::map(pitcher_files, arrow::read_parquet) |>
    data.table::rbindlist(fill = TRUE)
  out <- file.path(DATA_PROCESSED, "bref_pitchers_all.parquet")
  arrow::write_parquet(df_all, out)
  message("Saved: ", nrow(df_all), " rows → ", basename(out))
}

cat("02_process_bref_data.R complete.\n")
