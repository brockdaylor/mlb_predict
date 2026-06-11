############################################################
# 04_process_lahman_data.R
# Purpose: Build analysis-ready season-level datasets from the
#          Lahman package (historical data, ~1871–most recent release)
#          Incremental: skips rebuild if raw files match the installed
#          Lahman package version
############################################################

source(here::here("code", "00_setup.R"))

# ---- Config ----
if (!requireNamespace("Lahman", quietly = TRUE)) {
  stop("Package 'Lahman' is not installed. Run renv::install('Lahman') then renv::snapshot().")
}

RAW_DIR <- file.path(DATA_RAW, "lahman")
dir.create(RAW_DIR, showWarnings = FALSE, recursive = TRUE)

lahman_version <- as.character(packageVersion("Lahman"))
version_file   <- file.path(RAW_DIR, "lahman_version.txt")

# ---- 1. Snapshot raw tables (skip if current version already saved) ----
raw_tables <- c("People", "Batting", "Pitching", "Fielding", "Teams")

version_current <- file.exists(version_file) &&
  identical(readLines(version_file, warn = FALSE)[1], lahman_version)

if (version_current) {
  message("Lahman raw tables already saved for version ", lahman_version, " — skipping")
} else {
  for (tbl in raw_tables) {
    e <- new.env(parent = baseenv())
    utils::data(list = tbl, package = "Lahman", envir = e)
    df <- as.data.table(e[[tbl]])
    out_file <- file.path(RAW_DIR, paste0(tolower(tbl), ".parquet"))
    arrow::write_parquet(df, out_file)
    message("Saved ", nrow(df), " rows → ", basename(out_file))
  }
  writeLines(lahman_version, version_file)
}

# ---- 2. Load raw tables ----
people   <- arrow::read_parquet(file.path(RAW_DIR, "people.parquet"))   |> as.data.table()
batting  <- arrow::read_parquet(file.path(RAW_DIR, "batting.parquet"))  |> as.data.table()
pitching <- arrow::read_parquet(file.path(RAW_DIR, "pitching.parquet")) |> as.data.table()
teams    <- arrow::read_parquet(file.path(RAW_DIR, "teams.parquet"))    |> as.data.table()

# ---- 3. Player-season batting (aggregate stints, derive rate stats) ----
bat <- batting[, .(
  lgID = data.table::first(lgID),
  G   = sum(G),  AB = sum(AB), R = sum(R), H = sum(H),
  X2B = sum(X2B), X3B = sum(X3B), HR = sum(HR), RBI = sum(RBI, na.rm = TRUE),
  SB  = sum(SB, na.rm = TRUE), BB = sum(BB), SO = sum(SO, na.rm = TRUE),
  IBB = sum(IBB, na.rm = TRUE), HBP = sum(HBP, na.rm = TRUE),
  SH  = sum(SH, na.rm = TRUE), SF = sum(SF, na.rm = TRUE)
), by = .(playerID, yearID)]

bat[, `:=`(
  PA  = AB + BB + HBP + SH + SF,
  AVG = fifelse(AB > 0, H / AB, NA_real_),
  OBP = fifelse(AB + BB + HBP + SF > 0, (H + BB + HBP) / (AB + BB + HBP + SF), NA_real_),
  SLG = fifelse(AB > 0, (H + X2B + 2 * X3B + 3 * HR) / AB, NA_real_)
)]
bat[, `:=`(
  OPS    = OBP + SLG,
  ISO    = SLG - AVG,
  k_rate  = fifelse(PA > 0, SO / PA, NA_real_),
  bb_rate = fifelse(PA > 0, BB / PA, NA_real_)
)]

# Add name and age (season year minus birth year, July 1 cutoff convention)
bat <- merge(
  bat,
  people[, .(playerID, name = paste(nameFirst, nameLast), birthYear, birthMonth)],
  by = "playerID", all.x = TRUE
)
bat[, age := yearID - birthYear - fifelse(!is.na(birthMonth) & birthMonth > 6, 1L, 0L)]

arrow::write_parquet(bat, file.path(DATA_PROCESSED, "lahman_batting_season.parquet"))
message("Saved player-season batting: ", nrow(bat), " rows")

# ---- 4. Player-season pitching (aggregate stints, derive rate stats) ----
pit <- pitching[, .(
  lgID = data.table::first(lgID),
  W = sum(W), L = sum(L), G = sum(G), GS = sum(GS),
  IPouts = sum(IPouts), H = sum(H), ER = sum(ER), HR = sum(HR),
  BB = sum(BB), SO = sum(SO), HBP = sum(HBP, na.rm = TRUE),
  BFP = sum(BFP, na.rm = TRUE)
), by = .(playerID, yearID)]

pit[, IP := IPouts / 3]
pit[, `:=`(
  ERA = fifelse(IP > 0, 9 * ER / IP, NA_real_),
  k9  = fifelse(IP > 0, 9 * SO / IP, NA_real_),
  bb9 = fifelse(IP > 0, 9 * BB / IP, NA_real_),
  hr9 = fifelse(IP > 0, 9 * HR / IP, NA_real_)
)]

# FIP with league-year constant: cFIP = lgERA - lg[(13*HR + 3*(BB+HBP) - 2*K) / IP]
lg <- pit[IP > 0, .(
  lg_era  = 9 * sum(ER) / sum(IP),
  lg_core = (13 * sum(HR) + 3 * (sum(BB) + sum(HBP)) - 2 * sum(SO)) / sum(IP)
), by = yearID]
lg[, c_fip := lg_era - lg_core]
pit <- merge(pit, lg[, .(yearID, c_fip)], by = "yearID", all.x = TRUE)
pit[, FIP := fifelse(IP > 0, (13 * HR + 3 * (BB + HBP) - 2 * SO) / IP + c_fip, NA_real_)]

pit <- merge(
  pit,
  people[, .(playerID, name = paste(nameFirst, nameLast), birthYear, birthMonth)],
  by = "playerID", all.x = TRUE
)
pit[, age := yearID - birthYear - fifelse(!is.na(birthMonth) & birthMonth > 6, 1L, 0L)]

arrow::write_parquet(pit, file.path(DATA_PROCESSED, "lahman_pitching_season.parquet"))
message("Saved player-season pitching: ", nrow(pit), " rows")

# ---- 5. Team-season (wins, runs, Pythagorean expectation) ----
tm <- teams[, .(
  yearID, lgID, teamID, franchID, name,
  G, W, L, R, RA, H, HR, BB, SO, AB,
  attendance = if ("attendance" %in% names(teams)) attendance else NA_real_
)]
tm[, `:=`(
  win_pct  = W / (W + L),
  run_diff = R - RA,
  rpg      = R / G,
  pyth_wpct = R^2 / (R^2 + RA^2)
)]

arrow::write_parquet(tm, file.path(DATA_PROCESSED, "lahman_teams_season.parquet"))
message("Saved team-season: ", nrow(tm), " rows")

message("Lahman package version: ", lahman_version,
        " | most recent season: ", max(tm$yearID))
cat("04_process_lahman_data.R complete.\n")
