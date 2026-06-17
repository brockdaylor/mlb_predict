# MLB Prediction — Brock Daylor

## Overview

A general-purpose MLB data pipeline and analysis project. Pulls data from Statcast (pitch-level), Baseball Reference (traditional stats), and FanGraphs (advanced metrics) via the `baseballr` package, plus historical season-level data via the `Lahman` package. Supports descriptive analysis, regression modeling, and predictive modeling of player and team outcomes.

## Project Structure

``` text
data/
├── raw/
│   ├── statcast/                  # pitch-by-pitch (one parquet per month) +
│   │                              #   statcast_strikeouts_2026.parquet (K events only)
│   ├── baseball_reference/        # game-level batter/pitcher stats (one parquet per season)
│   ├── fangraphs/                 # season-level advanced metrics + park factors
│   └── lahman/                    # Lahman package tables (historical, season-level)
└── processed/                     # combined, analysis-ready parquet files

code/
├── 00_setup.R                     # global setup (paths, packages, helpers)
├── data_processing/
│   ├── 01_process_statcast_data.R     # Statcast pitch-by-pitch pull (full, chunked by month)
│   ├── 02_process_bref_data.R         # Baseball Reference traditional stats
│   ├── 03_process_fangraphs_data.R    # FanGraphs advanced metrics + park factors
│   ├── 04_process_lahman_data.R       # Lahman historical player/team season data
│   └── 05_process_statcast_strikeouts.R  # Strikeout-only Statcast pull (K events, 2026)
├── analysis/
│   ├── 01_analysis.R              # template: descriptive stats, plots, regressions
│   ├── 02_league_trends.R         # league-wide trends 1901–present (Lahman)
│   ├── 03_hitting_metrics.R       # hitting relationships + aging curve (Lahman, FG optional)
│   ├── 04_pitching_metrics.R      # ERA/FIP, K-BB; Statcast velo/mix optional
│   ├── 05_query_pipeline.R        # flexible filter/query over all sources → Excel
│   ├── 06_xba_ba_gap.R            # xBA vs BA gap, 50+ AB, 2026 (MLB + Twins)
│   └── 07_backwards_k.R           # called-K rate + pitch mix, 2026 (MLB + Twins)
└── models/
    ├── 01_modeling.R              # template: predictive modeling
    └── 02_team_wins_model.R       # team wins: OLS + Pythagorean, out-of-sample eval

output/
├── figures/            # plots and visualizations (.png)
└── tables/             # regression tables, CSVs, and Excel workbooks (.xlsx)

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

### One-time setup

```r
# Install Excel output package (not in default renv yet)
renv::install("openxlsx2")
renv::snapshot()
```

### 2026-focused pipeline (recommended)

1. `code/data_processing/02_process_bref_data.R` — Baseball Reference game-level batter/pitcher stats
2. `code/data_processing/03_process_fangraphs_data.R` — FanGraphs advanced metrics (xBA, wRC+, etc.)
3. `code/data_processing/05_process_statcast_strikeouts.R` — Strikeout-only Statcast pull (~40k rows for 2026; much faster than full pitch pull)
4. `code/analysis/05_query_pipeline.R` — Query any data source with team/age/PA filters → Excel
5. `code/analysis/06_xba_ba_gap.R` — xBA vs BA gap analysis (50+ AB, MLB-wide + Twins) → Excel + plots
6. `code/analysis/07_backwards_k.R` — Called-K (backwards K ꓘ) rate + pitch mix → Excel + plots

### Full historical pipeline (optional)

4. `code/data_processing/04_process_lahman_data.R` — Lahman historical data (no scraping)
5. `code/data_processing/01_process_statcast_data.R` — Full Statcast pitch-by-pitch (network-heavy; months of data)
6. `code/analysis/02_league_trends.R` — league-wide trends 1901–present
7. `code/analysis/03_hitting_metrics.R` — hitting relationships + aging curve
8. `code/analysis/04_pitching_metrics.R` — ERA/FIP, K-BB, Statcast velo
9. `code/models/02_team_wins_model.R` — team wins model

All outputs are saved automatically to `output/figures/` (PNG) and `output/tables/` (Excel/CSV).

To add a new season, extend `SEASONS <- c(2025, 2026, ...)` in each processing script and re-run.

### Customizing the query pipeline

Edit the `QUERY_*` parameters at the top of `05_query_pipeline.R`:

```r
QUERY_SEASON <- 2026          # season year; NULL = all seasons
QUERY_TEAM   <- "MIN"         # team abbreviation; NULL = all teams
QUERY_MIN_PA <- 50            # minimum plate appearances
QUERY_MIN_IP <- 10            # minimum innings pitched
QUERY_MIN_AGE <- 25           # optional age range
QUERY_MAX_AGE <- 30
```

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
| Statcast | Every pitch | Baseball Savant CSV (header-driven reader, see note) | `statcast_all.parquet` |
| Baseball Reference | Game-level | `bref_daily_batter()`, `bref_daily_pitcher()` | `bref_batters_all.parquet`, `bref_pitchers_all.parquet` |
| FanGraphs | Season-level | `fg_batter_leaders()`, `fg_pitcher_leaders()` | `fg_batters_all.parquet`, `fg_pitchers_all.parquet` |
| Lahman | Season-level, historical | `Lahman` package tables | `lahman_batting_season.parquet`, `lahman_pitching_season.parquet`, `lahman_teams_season.parquet` |

Raw data lives in `data/raw/` and is never modified. Processed parquet files in `data/processed/` are the entry point for analysis. Neither directory is tracked by git.

### Known limitations (CRAN `baseballr` 1.6.0)

The pinned CRAN `baseballr` (1.6.0) has two upstream bugs. The dev (GitHub) `baseballr` 2.0.0 fixes them but **cannot be installed reproducibly on R 4.5.2 / Windows** — its lazy-load step fails during `R CMD INSTALL`, which would also break `renv::restore()` — so we stay on CRAN and work around them:

- **Statcast** — `statcast_search()` hard-codes 92 column names and errors against Savant's current 119-column schema (`Can't assign 92 names to a 119-column data.table`). `01_process_statcast_data.R` instead queries the Baseball Savant CSV endpoint directly and reads column names from the CSV header (`statcast_csv_url()` / `pull_statcast_week()`), which is robust to upstream schema changes.
- **FanGraphs park factors** — `fg_park()` errors (`object 'park_table' not found`) and is currently **unavailable**. `03_process_fangraphs_data.R` attempts the pull, logs the error, and skips it; no `fg_park_factors_all.parquet` is produced. Batting/pitching leaders are unaffected.
