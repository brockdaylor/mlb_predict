# Project Title — Brock Daylor

## Overview

Brief description of the project, research question, and goals.

## Project Structure

``` text
data/
├── raw/                # original data (immutable)
└── processed/          # cleaned datasets

code/
├── 00_setup.R          # global setup (paths, packages, helpers)
├── data_processing/
│   └── 01_data_processing.R
├── analysis/
│   └── 01_analysis.R
└── models/
    └── 01_modeling.R

output/
├── figures/            # plots and visualizations
└── tables/             # regression tables and results

docs/                   # notes, drafts, and writeups
```

## Reproducibility

This project uses `renv` for package management.

To reproduce the environment:

``` r
renv::restore()
```

## Workflow

1.  Place raw data in `data/raw/`
2.  Run:
    -   `code/data_processing/01_data_processing.R`
    -   `code/analysis/01_analysis.R`
    -   `code/models/01_modeling.R` (if applicable)
3.  Outputs will be saved in `output/`

## Conventions

-   All scripts source `code/00_setup.R`
-   File paths are defined using `here::here()`
-   Processed data should be saved in `data/processed/`
-   No hard-coded paths

## Data

Raw data is not included in this repository unless otherwise noted.

If needed, document: - data sources - access instructions - any preprocessing requirements

## Notes

Add any important assumptions, data sources, or caveats here.
