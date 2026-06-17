############################################################
# 05_query_pipeline.R
# Purpose: Interactive query layer over all processed data sources.
#          Filter by team, age, PA/IP, season, and any numeric field.
#          Writes results to Excel workbooks (one sheet per query / data source).
#
# Usage: set the QUERY_* params below, then source this script.
############################################################

source(here::here("code", "00_setup.R"))

# ============================================================
# USER-SETTABLE QUERY PARAMETERS
# ============================================================

QUERY_SEASON   <- 2026          # season year; NULL = all seasons in data
QUERY_TEAM     <- NULL          # e.g. "MIN" or "Twins"; NULL = all teams
QUERY_MIN_PA   <- 50            # minimum plate appearances for batters; 0 = no filter
QUERY_MIN_IP   <- 10            # minimum innings pitched for pitchers; 0 = no filter
QUERY_MIN_AGE  <- NULL          # e.g. 25; NULL = no lower bound
QUERY_MAX_AGE  <- NULL          # e.g. 30; NULL = no upper bound

# Additional numeric field filters (list of lists): each list has
#   field = column name, min = lower bound (NULL = ignore), max = upper bound (NULL = ignore)
# Example: list(list(field = "AVG", min = 0.25), list(field = "ISO", min = 0.15))
QUERY_EXTRA_FILTERS <- list()

# Output file name (saved to OUTPUT_TABLES)
QUERY_OUTFILE <- "query_results.xlsx"

# ============================================================
# HELPER: apply query filters to a data.table
# ============================================================
apply_filters <- function(dt, team_col, pa_col = NULL, ip_col = NULL,
                          age_col = "Age", season_col = "Season") {

  # Season filter
  if (!is.null(QUERY_SEASON) && season_col %in% names(dt)) {
    dt <- dt[get(season_col) == QUERY_SEASON]
  }

  # Team filter — fuzzy match on team name or abbreviation columns
  if (!is.null(QUERY_TEAM)) {
    team_cols <- intersect(names(dt),
                           c("team_name_abb", "team_name", "Team", "Tm", "team"))
    if (length(team_cols) > 0) {
      mask <- Reduce("|", lapply(team_cols, function(tc) {
        grepl(QUERY_TEAM, dt[[tc]], ignore.case = TRUE)
      }))
      dt <- dt[mask]
    }
  }

  # PA filter
  if (!is.null(QUERY_MIN_PA) && QUERY_MIN_PA > 0) {
    pa_candidates <- intersect(names(dt), c("PA", "pa"))
    if (length(pa_candidates) > 0)
      dt <- dt[get(pa_candidates[1]) >= QUERY_MIN_PA]
  }

  # IP filter
  if (!is.null(QUERY_MIN_IP) && QUERY_MIN_IP > 0) {
    ip_candidates <- intersect(names(dt), c("IP", "ip"))
    if (length(ip_candidates) > 0)
      dt <- dt[get(ip_candidates[1]) >= QUERY_MIN_IP]
  }

  # Age filters
  if (!is.null(QUERY_MIN_AGE)) {
    age_candidates <- intersect(names(dt), c("Age", "age"))
    if (length(age_candidates) > 0)
      dt <- dt[get(age_candidates[1]) >= QUERY_MIN_AGE]
  }
  if (!is.null(QUERY_MAX_AGE)) {
    age_candidates <- intersect(names(dt), c("Age", "age"))
    if (length(age_candidates) > 0)
      dt <- dt[get(age_candidates[1]) <= QUERY_MAX_AGE]
  }

  # Extra numeric filters
  for (flt in QUERY_EXTRA_FILTERS) {
    if (flt$field %in% names(dt)) {
      col <- flt$field
      if (!is.null(flt$min)) dt <- dt[get(col) >= flt$min]
      if (!is.null(flt$max)) dt <- dt[get(col) <= flt$max]
    }
  }

  dt
}

# ============================================================
# LOAD DATA SOURCES
# ============================================================

datasets <- list()

# FanGraphs batters
fg_bat_file <- file.path(DATA_PROCESSED, "fg_batters_all.parquet")
if (file.exists(fg_bat_file)) {
  fg_bat <- arrow::read_parquet(fg_bat_file) |> as.data.table()
  fg_bat_q <- apply_filters(fg_bat, team_col = "team_name_abb", season_col = "Season")
  # Select core columns for readability (keep all if fewer than 60)
  core_bat_cols <- intersect(names(fg_bat_q), c(
    "PlayerName", "Season", "team_name_abb", "Age", "G", "PA", "AB",
    "H", "HR", "RBI", "SB", "BB", "SO",
    "AVG", "OBP", "SLG", "OPS", "ISO", "BABIP",
    "wOBA", "wRC_plus", "xAVG", "xwOBA",
    "K_pct", "BB_pct", "SwStr_pct", "HardHit_pct", "Barrel_pct",
    "EV", "LA", "maxEV", "WAR"
  ))
  if (length(core_bat_cols) > 0)
    fg_bat_q <- fg_bat_q[, ..core_bat_cols]
  datasets[["FG_Batters"]] <- fg_bat_q
  message("FG batters: ", nrow(fg_bat_q), " rows")
}

# FanGraphs pitchers
fg_pit_file <- file.path(DATA_PROCESSED, "fg_pitchers_all.parquet")
if (file.exists(fg_pit_file)) {
  fg_pit <- arrow::read_parquet(fg_pit_file) |> as.data.table()
  fg_pit_q <- apply_filters(fg_pit, team_col = "team_name_abb", season_col = "Season",
                             pa_col = NULL)
  core_pit_cols <- intersect(names(fg_pit_q), c(
    "PlayerName", "Season", "team_name_abb", "Age", "G", "GS", "IP", "W", "L", "SV",
    "ERA", "FIP", "xFIP", "SIERA",
    "K_pct", "BB_pct", "K_BB_pct", "HR_FB", "BABIP", "LOB_pct",
    "SwStr_pct", "CSW_pct", "GB_pct", "FB_pct",
    "vFA", "WAR"
  ))
  if (length(core_pit_cols) > 0)
    fg_pit_q <- fg_pit_q[, ..core_pit_cols]
  datasets[["FG_Pitchers"]] <- fg_pit_q
  message("FG pitchers: ", nrow(fg_pit_q), " rows")
}

# Baseball Reference batters
bref_bat_file <- file.path(DATA_PROCESSED, "bref_batters_all.parquet")
if (file.exists(bref_bat_file)) {
  bref_bat <- arrow::read_parquet(bref_bat_file) |> as.data.table()
  bref_bat_q <- apply_filters(bref_bat, team_col = "Team", season_col = "season")
  core_bref_cols <- intersect(names(bref_bat_q), c(
    "Name", "season", "Team", "Age", "Level",
    "G", "PA", "AB", "H", "X1B", "X2B", "X3B", "HR",
    "RBI", "BB", "SO", "SB", "CS",
    "BA", "OBP", "SLG", "OPS"
  ))
  if (length(core_bref_cols) > 0)
    bref_bat_q <- bref_bat_q[, ..core_bref_cols]
  datasets[["BRef_Batters"]] <- bref_bat_q
  message("BRef batters: ", nrow(bref_bat_q), " rows")
}

# Baseball Reference pitchers
bref_pit_file <- file.path(DATA_PROCESSED, "bref_pitchers_all.parquet")
if (file.exists(bref_pit_file)) {
  bref_pit <- arrow::read_parquet(bref_pit_file) |> as.data.table()
  bref_pit_q <- apply_filters(bref_pit, team_col = "Team", season_col = "season",
                               pa_col = NULL)
  datasets[["BRef_Pitchers"]] <- bref_pit_q
  message("BRef pitchers: ", nrow(bref_pit_q), " rows")
}

# ============================================================
# WRITE EXCEL WORKBOOK
# ============================================================

out_path <- file.path(OUTPUT_TABLES, QUERY_OUTFILE)

if (exists("openxlsx2") || requireNamespace("openxlsx2", quietly = TRUE)) {
  wb <- openxlsx2::wb_workbook(creator = "mlb_predict")

  for (sheet_name in names(datasets)) {
    dt <- datasets[[sheet_name]]
    if (nrow(dt) == 0) next

    wb <- openxlsx2::wb_add_worksheet(wb, sheet = sheet_name)
    wb <- openxlsx2::wb_add_data_table(
      wb,
      sheet      = sheet_name,
      x          = as.data.frame(dt),
      table_name = paste0("tbl_", sheet_name),
      table_style = "TableStyleMedium9"
    )
  }

  openxlsx2::wb_save(wb, out_path, overwrite = TRUE)
  message("Excel workbook saved → ", out_path)

} else {
  # Fallback: write CSVs
  for (sheet_name in names(datasets)) {
    csv_path <- file.path(OUTPUT_TABLES, paste0("query_", sheet_name, ".csv"))
    data.table::fwrite(datasets[[sheet_name]], csv_path)
    message("CSV saved → ", csv_path)
  }
  message("Install openxlsx2 for Excel output: renv::install('openxlsx2'); renv::snapshot()")
}

# Also print a brief summary to console
cat("\n=== Query Summary ===\n")
cat("Season:", ifelse(is.null(QUERY_SEASON), "all", QUERY_SEASON), "\n")
cat("Team filter:", ifelse(is.null(QUERY_TEAM), "none", QUERY_TEAM), "\n")
cat("Min PA:", QUERY_MIN_PA, " | Min IP:", QUERY_MIN_IP, "\n")
for (nm in names(datasets)) {
  cat(nm, ":", nrow(datasets[[nm]]), "rows\n")
}

cat("05_query_pipeline.R complete.\n")
