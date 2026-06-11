# MLB Prediction — Brock Daylor

## Overview

A general-purpose MLB data pipeline and analysis project. Pulls data from Statcast (pitch-level), Baseball Reference (traditional stats), and FanGraphs (advanced metrics) via the `baseballr` package, plus historical season-level data via the `Lahman` package. Supports descriptive analysis, regression modeling, and predictive modeling of player and team outcomes.

## Project Structure

``` text
data/
├── raw/
│   ├── statcast/                  # pitch-by-pitch (one parquet per month)
│   ├── baseball_reference/        # game-level batter/pitcher stats (one parquet per season)
│   ├── fangraphs/                 # season-level advanced metrics + park factors
│   └── lahman/                    # Lahman package tables (historical, season-level)
└── processed/                     # combined, analysis-ready parquet files

code/
├── 00_setup.R                     # global setup (paths, packages, helpers)
├── data_processing/
│   ├── 01_process_statcast_data.R     # Statcast pitch-by-pitch pull
│   ├── 02_process_bref_data.R         # Baseball Reference traditional stats
│   ├── 03_process_fangraphs_data.R    # FanGraphs advanced metrics + park factors
│   └── 04_process_lahman_data.R       # Lahman historical player/team season data
├── analysis/
│   ├── 01_analysis.R              # template: descriptive stats, plots, regressions
│   ├── 02_league_trends.R         # league-wide trends 1901–present (Lahman)
│   ├── 03_hitting_metrics.R       # hitting relationships + aging curve (Lahman, FG optional)
│   └── 04_pitching_metrics.R      # ERA/FIP, K-BB; Statcast velo/mix optional
└── models/
    ├── 01_modeling.R              # template: predictive modeling
    └── 02_team_wins_model.R       # team wins: OLS + Pythagorean, out-of-sample eval

output/
├── figures/            # plots and visualizations
└── tables/             # regression tables and results

docs/                   # notes, drafts, and writeups
```

## Reproducibility

This project uses `renv` for package management.

To restore the environment on a new machine:

``` r
renv::restore()
```

After installing new packages, lock them with:

``` r
renv::snapshot()
```

## Workflow

Run data processing scripts in order. Each script is **incremental** — it skips seasons whose raw files already exist and only re-pulls the current in-progress season. Re-running any script safely integrates new observations without duplicating existing data.

1. `code/data_processing/01_process_statcast_data.R` — Statcast pitch-by-pitch (chunked by month/week)
2. `code/data_processing/02_process_bref_data.R` — Baseball Reference game-level batter/pitcher stats
3. `code/data_processing/03_process_fangraphs_data.R` — FanGraphs advanced metrics + park factors
4. `code/data_processing/04_process_lahman_data.R` — Lahman historical season data (no scraping; skips rebuild unless the installed `Lahman` package version changes)
5. `code/analysis/02_league_trends.R` — league-wide trends (requires only step 4)
6. `code/analysis/03_hitting_metrics.R` — hitting metrics + aging curve (requires step 4; uses FanGraphs if available)
7. `code/analysis/04_pitching_metrics.R` — pitching metrics (requires step 4; uses Statcast if available)
8. `code/models/02_team_wins_model.R` — team wins baselines (requires step 4)
9. Outputs saved automatically to `output/`

The Lahman-based analyses (steps 5–8) are fully replicable from a fresh clone with only `renv::restore()` — no web scraping required. The Statcast/FanGraphs sections of the analysis scripts are optional and skip gracefully when those processed files are absent.

To add a new season, extend `SEASONS <- c(2025, 2026, ...)` in each processing script and re-run.

## Key Packages

| Package      | Purpose                                      |
|--------------|----------------------------------------------|
| `baseballr`  | Pull Statcast, Baseball Reference, FanGraphs |
| `Lahman`     | Historical season-level data (1871–present)  |
| `data.table` | Fast data manipulation                       |
| `tidyverse`  | General data wrangling and plotting          |
| `fixest`     | High-performance fixed-effects regression    |
| `ggrepel`    | Labeled scatter plots                        |
| `modelsummary` | Publication-ready regression tables        |
| `arrow`/`fst` | Fast read/write for large datasets          |

## Conventions

- All scripts source `code/00_setup.R`
- File paths use `here::here()` — no hard-coded paths
- Raw data lives in `data/raw/` and is never modified
- Processed data saved to `data/processed/`
- Figures saved via `save_plot()`, tables via `save_table()`

## Data Sources

| Source | Granularity | Key Functions | Processed Output |
|--------|------------|---------------|-----------------|
| Statcast | Every pitch | `statcast_search()` | `statcast_all.parquet` |
| Baseball Reference | Game-level | `bref_daily_batter()`, `bref_daily_pitcher()` | `bref_batters_all.parquet`, `bref_pitchers_all.parquet` |
| FanGraphs | Season-level | `fg_batter_leaders()`, `fg_pitcher_leaders()`, `fg_park()` | `fg_batters_all.parquet`, `fg_pitchers_all.parquet`, `fg_park_factors_all.parquet` |
| Lahman | Season-level, historical | `Lahman` package tables | `lahman_batting_season.parquet`, `lahman_pitching_season.parquet`, `lahman_teams_season.parquet` |

Raw data lives in `data/raw/` and is never modified. Processed parquet files in `data/processed/` are the entry point for analysis. Neither directory is tracked by git.
