# CLAUDE.md — mlb_predict

## Project

MLB data pipeline + analysis in R. Owner: Brock Daylor. Must remain **git-replicable**: anyone cloning the repo should reproduce all outputs with `renv::restore()` + running the scripts. Ask before making structural decisions; never commit without confirmation.

## Environment

- R 4.6.1 (x64) on Windows, RStudio project (`mlb_predict.Rproj`), packages managed by `renv` (lockfile at root). Upgraded from R 4.5.2 on 2026-10-23; see `docs/NOTES.md`.
- Run scripts with `Rscript -e 'source(here::here("code", "<path>"))'` or in an R session from the project root.
- After installing any new package: `renv::install()` then `renv::snapshot()`. Set env var `RENV_CONFIG_INSTALL_STAGED=FALSE` first: the project sits in OneDrive, and OneDrive's file locks break renv's staged installs ("Access is denied").
- baseballr is pinned at 1.6.0 (scrapers were fixed against it; 2.0.0 is a major release). Don't upgrade without testing the scrapers.
- On this machine (x64 R emulated on ARM), the user env var `CLI_NO_THREAD=1` must be set. Otherwise R crashes at exit (code -1073741569) once `cli` is loaded, which happens via rlang, arrow, the tidyverse and others; see `docs/NOTES.md`. `run_pipeline.bat` judges success by each script's final `complete.` line either way.
- `data/raw/` and `data/processed/` are **not** tracked by git and are never hand-edited.

## Conventions (follow strictly)

- Every script sources `code/00_setup.R` (renv bootstrap, packages, paths, helpers).
- Paths via `here::here()` and the constants `DATA_RAW`, `DATA_PROCESSED`, `OUTPUT_FIGURES`, `OUTPUT_TABLES`. No hard-coded paths.
- `data.table` for manipulation; `fixest::feols` for regressions; figures via `save_plot()`, tables via `save_table()` or `fwrite()` to `OUTPUT_TABLES`.
- Data pulls are **incremental**: skip raw files that already exist; only re-pull the in-progress season/month. Raw → parquet in `data/raw/<source>/`; combined analysis-ready parquet in `data/processed/`.
- Header comment block on every script (name, purpose); `cat("<script>.R complete.\n")` at end.

## Current state (2026-06-17)

- **Data downloaded and in parquet format**: BRef batters/pitchers (2025–2026), FanGraphs batters/pitchers (2025–2026), Lahman (historical). Statcast NOT yet pulled.
- **Analysis scripts written (NEW, never executed)**:
  - `analysis/05_query_pipeline.R` — flexible filter/query → Excel
  - `analysis/06_xba_ba_gap.R` — xBA vs BA gap, 50+ AB, 2026 (uses `fg_batters_all.parquet`, column `xAVG`)
  - `analysis/07_backwards_k.R` — called-K rate + pitch mix, 2026 (uses `statcast_strikeouts_2026.parquet`)
  - `data_processing/05_process_statcast_strikeouts.R` — K-only Statcast pull for 2026
- `analysis/01_analysis.R` and `models/01_modeling.R` are commented templates — leave them as-is.
- Key FanGraphs column names: `PlayerName`, `Season`, `team_name_abb`, `AVG`, `xAVG`, `wRC_plus`, `xwOBA`, `K_pct`, `BB_pct`.
- Key BRef column names: `Name`, `season` (lowercase), `Team`, `BA`, `OBP`, `SLG`.

## Run order for 2026 analyses

1. `renv::restore()` if `renv::status()` reports packages out of sync (one-time per machine)
2. `data_processing/05_process_statcast_strikeouts.R` (pulls ~40k rows of K events)
3. `analysis/06_xba_ba_gap.R` (needs fg_batters_all.parquet — already present)
4. `analysis/07_backwards_k.R` (needs statcast_strikeouts_2026.parquet from step 2)
5. `analysis/05_query_pipeline.R` (ad-hoc queries; edit QUERY_* params at top)

## Verification checklist

- Fresh-clone replicability: scripts must not depend on anything outside the repo except CRAN packages and (for scraping pipelines) the data sources themselves.
- No absolute paths, no `setwd()`, no manual steps undocumented in README.
- If you add a package, snapshot it; if you add a script, add it to README's Project Structure and Workflow sections.
