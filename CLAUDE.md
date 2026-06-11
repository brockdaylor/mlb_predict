# CLAUDE.md — mlb_predict

## Project

MLB data pipeline + analysis in R. Owner: Brock Daylor. Must remain **git-replicable**: anyone cloning the repo should reproduce all outputs with `renv::restore()` + running the scripts. Ask before making structural decisions; never commit without confirmation.

## Environment

- R 4.5.2 on Windows, RStudio project (`mlb_predict.Rproj`), packages managed by `renv` (lockfile at root).
- Run scripts with `Rscript -e 'source(here::here("code", "<path>"))'` or in an R session from the project root.
- After installing any new package: `renv::install()` then `renv::snapshot()`.
- `data/raw/` and `data/processed/` are **not** tracked by git and are never hand-edited.

## Conventions (follow strictly)

- Every script sources `code/00_setup.R` (renv bootstrap, packages, paths, helpers).
- Paths via `here::here()` and the constants `DATA_RAW`, `DATA_PROCESSED`, `OUTPUT_FIGURES`, `OUTPUT_TABLES`. No hard-coded paths.
- `data.table` for manipulation; `fixest::feols` for regressions; figures via `save_plot()`, tables via `save_table()` or `fwrite()` to `OUTPUT_TABLES`.
- Data pulls are **incremental**: skip raw files that already exist; only re-pull the in-progress season/month. Raw → parquet in `data/raw/<source>/`; combined analysis-ready parquet in `data/processed/`.
- Header comment block on every script (name, purpose); `cat("<script>.R complete.\n")` at end.

## Current state (2026-06-11)

- Pipelines: `01_process_statcast_data.R` (Statcast, monthly parquet), `02_process_bref_data.R`, `03_process_fangraphs_data.R`, `04_process_lahman_data.R` (new; Lahman package, version-aware skip).
- New analysis scripts (written but **never executed** — authored without an R runtime): `analysis/02_league_trends.R`, `analysis/03_hitting_metrics.R`, `analysis/04_pitching_metrics.R`, `models/02_team_wins_model.R`. All depend only on the Lahman pipeline; Statcast/FanGraphs sections skip gracefully if those files are absent.
- `analysis/01_analysis.R` and `models/01_modeling.R` are commented templates — leave them as-is.
- No raw data currently downloaded (`data/raw/` nearly empty).

## Immediate tasks

1. `renv::restore()`, then `renv::install("Lahman")` and `renv::snapshot()`.
2. Run `code/data_processing/04_process_lahman_data.R`; verify three parquet files appear in `data/processed/`.
3. Run `analysis/02_league_trends.R`, `analysis/03_hitting_metrics.R`, `analysis/04_pitching_metrics.R`, `models/02_team_wins_model.R`. Fix any runtime errors **minimally**, preserving the conventions above; spot-check figures in `output/figures/` and tables in `output/tables/` for sanity (e.g., Pythagorean exponent ≈ 1.8–1.9; aging curve peaks ~26–28).
4. Optionally run the Statcast/B-Ref/FanGraphs pipelines (network-heavy, rate-limited — confirm with Brock first; Statcast pulls take a long time).
5. Report what was fixed; propose a commit message but do not commit without Brock's approval.

## Verification checklist

- Fresh-clone replicability: scripts must not depend on anything outside the repo except CRAN packages and (for scraping pipelines) the data sources themselves.
- No absolute paths, no `setwd()`, no manual steps undocumented in README.
- If you add a package, snapshot it; if you add a script, add it to README's Project Structure and Workflow sections.
