############################################################
# 01_process_statcast_data.R
# Purpose: Pull Statcast pitch-by-pitch data for 2025–2026
#          Incremental: skips completed months, re-pulls current month
############################################################

source("00_setup.R")

# ---- Config ----
SEASONS <- c(2025, 2026)

SEASON_START <- c(
  "2025" = as.Date("2025-03-27"),
  "2026" = as.Date("2026-03-26")
)

SEASON_END <- c(
  "2025" = as.Date("2025-10-01"),
  "2026" = Sys.Date()
)

RAW_DIR <- file.path(DATA_RAW, "statcast")
dir.create(RAW_DIR, showWarnings = FALSE, recursive = TRUE)

# ---- Helper: pull one week of Statcast pitches ----
pull_statcast_week <- function(start, end) {
  message("  Pulling: ", start, " to ", end)
  Sys.sleep(3)
  baseballr::statcast_search(
    start_date  = as.character(start),
    end_date    = as.character(end),
    player_type = "batter"
  )
}

# ---- Helper: pull one calendar month of Statcast pitches ----
pull_statcast_month <- function(year, month, season_start, season_end) {

  month_first <- as.Date(paste0(year, "-", sprintf("%02d", month), "-01"))
  month_last  <- seq(month_first, by = "month", length.out = 2)[2] - 1

  pull_start <- max(month_first, season_start)
  pull_end   <- min(month_last,  season_end, Sys.Date())

  if (pull_start > pull_end) return(NULL)

  week_starts <- seq(pull_start, pull_end, by = "7 days")

  chunks <- purrr::map(seq_along(week_starts), function(i) {
    s <- week_starts[i]
    e <- min(s + 6L, pull_end)
    tryCatch(
      pull_statcast_week(s, e),
      error = function(err) {
        message("  WARNING: failed to pull ", s, " to ", e, ": ", conditionMessage(err))
        NULL
      }
    )
  })

  chunks <- purrr::compact(chunks)
  if (length(chunks) == 0) return(NULL)

  data.table::rbindlist(chunks, fill = TRUE)
}

# ---- Main: iterate over seasons and months ----
current_year  <- as.integer(format(Sys.Date(), "%Y"))
current_month <- as.integer(format(Sys.Date(), "%m"))

for (season in SEASONS) {

  s_start <- SEASON_START[[as.character(season)]]
  s_end   <- SEASON_END[[as.character(season)]]

  first_month <- as.integer(format(s_start, "%m"))
  last_month  <- as.integer(format(min(s_end, Sys.Date()), "%m"))

  for (month in first_month:last_month) {

    out_file <- file.path(RAW_DIR, sprintf("statcast_%d_%02d.parquet", season, month))

    # Month is complete only if it ended before the current calendar month
    month_is_done <- !(season == current_year && month >= current_month)

    if (month_is_done && file.exists(out_file)) {
      message("Skipping ", season, "-", sprintf("%02d", month), " — already downloaded")
      next
    }

    message("Pulling Statcast: ", season, "-", sprintf("%02d", month))
    df <- pull_statcast_month(season, month, s_start, s_end)

    if (!is.null(df) && nrow(df) > 0) {
      arrow::write_parquet(df, out_file)
      message("  Saved ", nrow(df), " rows → ", basename(out_file))
    } else {
      message("  No data for ", season, "-", sprintf("%02d", month))
    }
  }
}

# ---- Combine all monthly files → processed ----
message("\nCombining all Statcast monthly files...")
raw_files <- list.files(RAW_DIR, pattern = "\\.parquet$", full.names = TRUE)

if (length(raw_files) > 0) {
  df_all <- purrr::map(raw_files, arrow::read_parquet) |>
    data.table::rbindlist(fill = TRUE)
  out_processed <- file.path(DATA_PROCESSED, "statcast_all.parquet")
  arrow::write_parquet(df_all, out_processed)
  message("Saved combined dataset: ", nrow(df_all), " rows → ", basename(out_processed))
} else {
  message("No raw files found to combine.")
}

cat("01_process_statcast_data.R complete.\n")
