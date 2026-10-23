# mlb_predict — Edit Summary

**Date:** June 17, 2026\
**Repo:** <https://github.com/brockdaylor/mlb_predict>

------------------------------------------------------------------------

## What Was Built

### New Files

#### `code/data_processing/05_process_statcast_strikeouts.R`

Pulls **only strikeout plate-appearance events** from Baseball Savant for the 2026 season using the `hfAB=strikeout%7C` URL filter. Each row = the final pitch of one strikeout PA, so you get \~40k rows instead of 700k+ for the full pitch-by-pitch pull. Two key derived columns are added: - `k_type`: `"called"` (batter took strike 3 looking = backwards K ꓘ) or `"swinging"` - `pitcher_team`: pitcher's team abbreviation (derived from `home_team`/`away_team` + `inning_topbot`)

Output: `data/raw/statcast/statcast_strikeouts_2026.parquet`

Run: incremental — re-pulls if last saved date is stale.

------------------------------------------------------------------------

#### `code/analysis/05_query_pipeline.R`

Flexible query layer over all data sources. Set parameters at the top:

``` r
QUERY_SEASON   <- 2026          # NULL = all seasons
QUERY_TEAM     <- "MIN"         # fuzzy-matches team_name_abb, Team, etc.
QUERY_MIN_PA   <- 50
QUERY_MIN_IP   <- 10
QUERY_MIN_AGE  <- NULL
QUERY_MAX_AGE  <- NULL
QUERY_EXTRA_FILTERS <- list(
  list(field = "AVG", min = 0.25),
  list(field = "wRC_plus", min = 120)
)
```

Loads FG batters, FG pitchers, BRef batters, BRef pitchers → applies filters → writes **multi-sheet Excel workbook** to `output/tables/query_results.xlsx`. Falls back to CSVs if `openxlsx2` not installed.

------------------------------------------------------------------------

#### `code/analysis/06_xba_ba_gap.R`

Identifies hitters with the largest gap between expected BA (`xAVG`) and actual BA (`AVG`) for 2026 hitters with 50+ AB.

-   **Positive gap** (xAVG \> AVG): hitter is "unlucky" — batted ball quality outperforms results
-   **Negative gap** (AVG \> xAVG): hitter is "lucky" — results outperform quality

**Two versions:** - MLB-wide: top 100 largest positive gap + top 100 largest negative gap ("T±100") - Twins: all Minnesota Twins hitters with 50+ AB

**Excel output** (`output/tables/xba_ba_gap_2026.xlsx`): - Sheet "MLB_Top200" — 200 hitters (top 100 unlucky + top 100 lucky) - Sheet "Twins" — all Twins hitters - Sheet "All_50AB" — all 50+ AB hitters (pivot-table-ready, unfiltered)

**Figures:** - `output/figures/xba_ba_gap_mlb_2026.png` — lollipop chart, top/bottom 30 - `output/figures/xba_ba_gap_twins_2026.png` — bar chart with gap labels (Twins colors)

Key column used from FanGraphs: `xAVG` (not `xBA` — the actual column name in the parquet).

------------------------------------------------------------------------

#### `code/analysis/07_backwards_k.R`

Calculates **called-strikeout (backwards K) rate** by pitcher for 2026: - `called_K_pct` = called strikeouts / total strikeouts - Pitch-type breakdown: which pitch types generated called Ks?

**Requires:** `statcast_strikeouts_2026.parquet` (run `05_process_statcast_strikeouts.R` first)

**Two versions:** - MLB-wide: pitchers with 30+ total Ks, sorted by called K rate; top 100 - Twins: all Twins pitchers regardless of K count

**Excel output** (`output/tables/backwards_k_2026.xlsx`): - Sheet "MLB_Top100" — top 100 by called K% - Sheet "Twins" — all Twins pitchers - Sheet "All_Pitchers" — every pitcher in the Statcast data

**Figures:** - `output/figures/backwards_k_rate_mlb_2026.png` — horizontal bar, top 30 pitchers - `output/figures/backwards_k_rate_twins_2026.png` — Twins pitchers (navy) - `output/figures/backwards_k_pitch_mix_2026.png` — stacked bar: pitch type breakdown for called Ks, top 20 pitchers

------------------------------------------------------------------------

### Modified Files

#### `code/00_setup.R`

Added conditional `openxlsx2` load (lines 55–64):

``` r
if (requireNamespace("openxlsx2", quietly = TRUE)) {
  library(openxlsx2)
} else {
  message("openxlsx2 not installed. Install with: renv::install('openxlsx2'); renv::snapshot()")
}
```

All other existing setup (renv bootstrap, paths, helpers) is unchanged.

#### `README.md`

-   Updated project structure diagram to include new scripts
-   Added "One-time setup" section with `openxlsx2` install instruction
-   Split workflow into "2026-focused pipeline" (fast) vs "Full historical pipeline"
-   Added "Customizing the query pipeline" section with parameter docs

#### `CLAUDE.md`

-   Updated current state from "no data downloaded" to reflect actual parquet files present
-   Listed actual FanGraphs column names (`xAVG`, `wRC_plus`, `team_name_abb`, etc.)
-   Listed BRef column names (`BA` not `AVG`, `season` lowercase, etc.)
-   Updated run order for 2026 analyses

------------------------------------------------------------------------

## What Still Needs to Run

### One-time (do once in RStudio):

``` r
renv::install("openxlsx2")
renv::snapshot()
```

### To generate xBA-BA gap results (FG data already downloaded):

``` r
source(here::here("code", "analysis", "06_xba_ba_gap.R"))
```

### To generate backwards K results:

``` r
# Step 1: pull strikeout events (~20 min, pulls ~40k rows for 2026 season)
source(here::here("code", "data_processing", "05_process_statcast_strikeouts.R"))

# Step 2: run analysis
source(here::here("code", "analysis", "07_backwards_k.R"))
```

### Ad-hoc queries (edit parameters first):

``` r
# Edit QUERY_* params at top of file, then:
source(here::here("code", "analysis", "05_query_pipeline.R"))
```

------------------------------------------------------------------------

## Git / GitHub

**Repo created:** <https://github.com/brockdaylor/mlb_predict>\
**Commit message:** "Add 2026 analysis pipeline: xBA-BA gap, backwards K, query tool"\
**Status:** Committed locally, remote configured. To push:

``` bash
# In the project root (Git Bash, RStudio Terminal, or Windows Terminal):
git push -u origin main

# Or double-click push_to_github.bat in the project directory
```

------------------------------------------------------------------------

## Key Technical Notes

-   **FanGraphs xBA column name** is `xAVG` (not `xBA` or `x_ba`) — confirmed from parquet schema
-   **FanGraphs batting average** is `AVG`; BRef uses `BA`
-   **FanGraphs season column** is `Season` (capital S); BRef uses `season` (lowercase)
-   **FanGraphs team abbreviation** is in `team_name_abb` column
-   **Statcast pitcher team**: derived as `home_team` when `inning_topbot == "Top"`, else `away_team`
-   **Twins filter**: `grepl("MIN", pitcher_team)` for Statcast, `grepl("MIN|Twins", team_name_abb)` for FG
-   **openxlsx2 vs openxlsx**: scripts use `openxlsx2` (modern successor, Java-free, better Excel Table support for pivot tables)
-   **No Statcast pitch-by-pitch data** currently in `data/processed/` — the existing `01_process_statcast_data.R` pulls this but hasn't been run; the new `05_process_statcast_strikeouts.R` is a much leaner alternative for the backwards K use case
