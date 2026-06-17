############################################################
# Project Setup Script
# Purpose: Load packages, define paths, set global options
############################################################

# ---- 0. Bootstrap renv (runs before anything else) ----
# Directly adds the renv library to .libPaths() by constructing the path from
# the R version and platform. Avoids sourcing activate.R mid-session, which is
# designed for session startup and does not reliably set .libPaths() when called
# from inside a script.
local({
  # Walk up to find the project root (contains renv.lock)
  path <- getwd()
  while (nchar(path) > 3) {
    if (file.exists(file.path(path, "renv.lock"))) break
    path <- dirname(path)
  }
  if (!file.exists(file.path(path, "renv.lock"))) return()

  # Build the renv library path for this R version and platform
  r_ver <- paste0("R-", R.Version()$major, ".",
                  strsplit(R.Version()$minor, "\\.")[[1]][1])
  os    <- if (.Platform$OS.type == "windows") "windows" else "unix"
  lib   <- file.path(path, "renv", "library", os, r_ver, R.version[["platform"]])

  if (!dir.exists(lib)) return()

  # Always correct RENV_PROJECT — a prior failed activation may have set it
  # to the wrong directory (e.g. code/ instead of the project root)
  Sys.setenv(RENV_PROJECT = path)

  if (!lib %in% .libPaths()) {
    .libPaths(c(lib, .libPaths()))
  }
})

# ---- 1. Load core packages ----
library(here)
here::i_am("code/00_setup.R")   # anchor project root to mlb_predict/, not code/
library(data.table)
library(tidyverse)

# MLB data
library(baseballr)

# Modeling / econometrics
library(fixest)
library(modelsummary)
library(broom)

# Visualization
library(ggrepel)

# Data utilities
library(janitor)
library(readxl)
library(arrow)
library(fst)

# Excel export — run once if missing:
#   renv::install("openxlsx2"); renv::snapshot()
if (requireNamespace("openxlsx2", quietly = TRUE)) {
  library(openxlsx2)
} else {
  message(
    "openxlsx2 not installed. Excel output will be skipped.\n",
    "Fix with: renv::install('openxlsx2'); renv::snapshot()"
  )
}

# ---- 2. Define project paths ----
# Using here() ensures portability across machines

DATA_RAW        <- here("data", "raw")
DATA_PROCESSED  <- here("data", "processed")
OUTPUT_FIGURES  <- here("output", "figures")
OUTPUT_TABLES   <- here("output", "tables")
DOCS            <- here("docs")

# ---- 3. Global options ----

# Print settings
options(
  scipen = 999,          # Turn off scientific notation
  digits = 4
)

# Data.table threads (optional)
data.table::setDTthreads(parallel::detectCores() - 1)

# Fixest options (nice defaults)
fixest::setFixest_nthreads(parallel::detectCores() - 1)

# ---- 4. Plot theme (ggplot) ----
theme_set(
  theme_minimal(base_size = 12)
)

# ---- 5. Helper functions ----

# Safe fread wrapper
read_csv_fast <- function(path) {
  data.table::fread(path) |> janitor::clean_names()
}

# Save table helper
save_table <- function(model, filename) {
  modelsummary::modelsummary(
    model,
    output = file.path(OUTPUT_TABLES, filename)
  )
}

# Save plot helper
save_plot <- function(plot, filename, width = 8, height = 5, dpi = 300) {
  ggsave(
    filename = file.path(OUTPUT_FIGURES, filename),
    plot     = plot,
    width    = width,
    height   = height,
    dpi      = dpi
  )
}

# Codebook equivalent 
df_summary <- function(df) {
  
  # Ensure data.table for speed
  dt <- data.table::as.data.table(df)
  
  # Helper function for numeric summaries
  num_summary <- function(x) {
    c(
      mean = mean(x, na.rm = TRUE),
      sd   = sd(x, na.rm = TRUE),
      min  = min(x, na.rm = TRUE),
      p25  = quantile(x, 0.25, na.rm = TRUE),
      median = median(x, na.rm = TRUE),
      p75  = quantile(x, 0.75, na.rm = TRUE),
      max  = max(x, na.rm = TRUE)
    )
  }
  
  results <- lapply(names(dt), function(var) {
    
    x <- dt[[var]]
    
    out <- list(
      variable      = var,
      class         = class(x)[1],
      n_obs         = length(x),
      n_missing     = sum(is.na(x)),
      n_unique      = data.table::uniqueN(x)
    )
    
    if (is.numeric(x)) {
      stats <- num_summary(x)
      out <- c(out, as.list(stats))
    } else {
      # For non-numeric: show top values
      top_vals <- sort(table(x), decreasing = TRUE)
      top_vals <- head(top_vals, 3)
      out$top_values <- paste(names(top_vals), collapse = ", ")
    }
    
    return(out)
  })
  
  summary_dt <- data.table::rbindlist(results, fill = TRUE)
  
  return(summary_dt)
}

# Tab variables
tab_vars <- function(df, var1, var2 = NULL, prop = FALSE) {
  
  dt <- data.table::as.data.table(df)
  
  # One-way table
  if (is.null(var2)) {
    
    tab <- dt[, .N, by = var1][order(-N)]
    
    if (prop) {
      tab[, prop := N / sum(N)]
    }
    
    return(tab)
  }
  
  # Two-way table
  tab <- dt[, .N, by = c(var1, var2)]
  
  tab_wide <- data.table::dcast(
    tab,
    formula = paste(var1, "~", var2),
    value.var = "N",
    fill = 0
  )
  
  if (prop) {
    # Row proportions
    mat <- as.matrix(tab_wide[, -1, with = FALSE])
    mat <- mat / rowSums(mat)
    tab_wide[, (names(tab_wide)[-1]) := as.data.table(mat)]
  }
  
  return(tab_wide)
}

# ---- 6. Startup message ----
cat("Setup complete.\n")
cat("Project root:", here(), "\n")