############################################################
# 01_data_processing.R
# Purpose: import, clean, merge, and save processed data
############################################################

source(here::here("code", "00_setup.R"))

# ---- 1. Load raw data ----
# Example:
# df_raw <- read_csv_fast(file.path(DATA_RAW, "your_raw_file.csv"))

# ---- 2. Clean variable names / basic cleaning ----
# Example:
# df <- df_raw |>
#   janitor::clean_names()

# ---- 3. Recode / transform variables ----
# Example:
# df <- df |>
#   mutate(
#     log_y = log(y),
#     treated = if_else(group == "treated", 1, 0)
#   )

# ---- 4. Merge in other sources if needed ----
# Example:
# other_df <- read_csv_fast(file.path(DATA_RAW, "other_file.csv"))
# df <- df |>
#   left_join(other_df, by = "id")

# ---- 5. Quick checks ----
# Example:
# print(df_summary(df))
# print(tab_vars(df, "treated"))

# ---- 6. Save processed data ----
# Example CSV:
# fwrite(df, file.path(DATA_PROCESSED, "analysis_data.csv"))

# Example fst:
# fst::write_fst(df, file.path(DATA_PROCESSED, "analysis_data.fst"))

# Example parquet:
# arrow::write_parquet(df, file.path(DATA_PROCESSED, "analysis_data.parquet"))

cat("01_data_processing.R complete.\n")