############################################################
# 05_process_statcast_strikeouts.R
# Purpose: Pull ONLY strikeout plate-appearance events from Baseball Savant
#          for the 2026 season.  Each row = one strikeout PA (final pitch only).
#          Much smaller than full pitch-by-pitch pull — enables backwards-K
#          (called-strikeout) analysis without pulling all ~700 k pitches.
#
# Backwards K logic (applied in analysis/07_backwards_k.R):
#   description == "called_strike"  → batter took strike 3 (ꓘ)
#   otherwise (swinging_strike, swinging_strike_blocked, foul_tip) → swinging K
############################################################

source(here::here("code", "00_setup.R"))

# ---- Config ----
SEASON      <- 2026
SEASON_START <- as.Date("2026-03-26")
SEASON_END   <- Sys.Date()        # pull through today

RAW_DIR <- file.path(DATA_RAW, "statcast")
dir.create(RAW_DIR, showWarnings = FALSE, recursive = TRUE)

OUT_FILE <- file.path(RAW_DIR, sprintf("statcast_strikeouts_%d.parquet", SEASON))

# ---- Helper: build strikeout-filtered Baseball Savant CSV URL ----
# hfAB=strikeout%7C → filter to "strikeout" at-bat result only.
# Each returned row is the FINAL PITCH of the PA (events == "strikeout").
# player_type=pitcher → player_name column = pitcher's name.
statcast_k_url <- function(start, end) {
  season <- format(as.Date(start), "%Y")
  pairs <- c(
    "all=true",
    "hfPT=",
    "hfAB=strikeout%7C",           # ← filter: strikeouts only
    "hfBBT=", "hfPR=", "hfZ=", "stadium=",
    "hfBBL=", "hfNewZones=",
    "hfGT=R%7CPO%7CS%7C&hfC",
    paste0("hfSea=", season, "%7C"),
    "hfSit=", "hfOuts=", "opponent=", "pitcher_throws=", "batter_stands=",
    "hfSA=",
    "player_type=pitcher",          # ← pitcher names in player_name column
    "hfInfield=", "team=", "position=", "hfOutfield=", "hfRO=", "home_road=",
    paste0("game_date_gt=", start),
    paste0("game_date_lt=", end),
    "hfFlag=", "hfPull=", "metric_1=", "hfInn=",
    "min_pitches=0", "min_results=0", "group_by=name", "sort_col=pitches",
    "player_event_sort=h_launch_speed", "sort_order=desc", "min_abs=0",
    "type=details"
  )
  paste0("https://baseballsavant.mlb.com/statcast_search/csv?",
         paste(pairs, collapse = "&"))
}

# ---- Helper: pull one week of strikeout events ----
pull_k_week <- function(start, end) {
  message("  Pulling K events: ", start, " to ", end)
  Sys.sleep(3)
  url <- statcast_k_url(start, end)
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)
  utils::download.file(url, tmp, mode = "wb", quiet = TRUE)
  dt <- data.table::fread(tmp, showProgress = FALSE)
  if (nrow(dt) == 0 || !("pitch_type" %in% names(dt))) return(NULL)
  # Keep only rows where events == "strikeout" (safety filter — URL should already do this)
  dt <- dt[events == "strikeout"]
  dt
}

# ---- Pull in weekly chunks ----
# Re-pull if file doesn't exist OR if the existing file is stale (from a past run
# of the current in-progress season).
if (file.exists(OUT_FILE)) {
  existing <- arrow::read_parquet(OUT_FILE)
  last_date <- max(as.Date(existing$game_date), na.rm = TRUE)
  stale <- last_date < (Sys.Date() - 1)
  if (!stale) {
    message("Statcast strikeouts up-to-date (last game: ", last_date, "). Skipping pull.")
    cat("05_process_statcast_strikeouts.R complete.\n")
    quit(save = "no", status = 0)
  }
  message("Re-pulling strikeouts — last saved date: ", last_date)
}

message("Pulling Statcast strikeout events: ", SEASON, " (", SEASON_START, " → ", SEASON_END, ")")

week_starts <- seq(SEASON_START, SEASON_END, by = "7 days")

chunks <- purrr::map(seq_along(week_starts), function(i) {
  s <- week_starts[i]
  e <- min(s + 6L, SEASON_END)
  tryCatch(
    pull_k_week(s, e),
    error = function(err) {
      message("  WARNING: failed ", s, " to ", e, ": ", conditionMessage(err))
      NULL
    }
  )
})

chunks <- purrr::compact(chunks)

if (length(chunks) == 0) {
  message("No strikeout data retrieved.")
} else {
  df <- data.table::rbindlist(chunks, fill = TRUE)

  # Derive pitcher team: Top of inning → home team pitching; Bot → away team pitching
  df[, pitcher_team := data.table::fifelse(inning_topbot == "Top", home_team, away_team)]

  # Classify backwards K vs swinging K
  df[, k_type := data.table::fifelse(
    description == "called_strike", "called", "swinging"
  )]

  arrow::write_parquet(df, OUT_FILE)
  message("Saved ", nrow(df), " strikeout PAs → ", basename(OUT_FILE))
}

cat("05_process_statcast_strikeouts.R complete.\n")
