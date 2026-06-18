############################################################
# 01_analysis.R
# Purpose: descriptive statistics, tables, and regressions
############################################################

source(here::here("code", "00_setup.R"))

# ---- 1. Load processed data ----
# Example CSV:
# df <- fread(file.path(DATA_PROCESSED, "analysis_data.csv"))

# Example fst:
# df <- fst::read_fst(file.path(DATA_PROCESSED, "analysis_data.fst"), as.data.table = TRUE)

# Example parquet:
# df <- arrow::read_parquet(file.path(DATA_PROCESSED, "analysis_data.parquet")) |>
#   as.data.table()

# ---- 2. Quick summary statistics ----
# Example:
# print(df_summary(df))
# print(tab_vars(df, "treated"))
# print(tab_vars(df, "treated", "post"))

# ---- 3. Descriptive plots ----
# Example:
# p1 <- ggplot(df, aes(x = x_var, y = y_var)) +
#   geom_point(alpha = 0.5) +
#   labs(title = "Scatterplot of X and Y")
#
# ggsave(
#   filename = file.path(OUTPUT_FIGURES, "scatter_xy.png"),
#   plot = p1,
#   width = 7,
#   height = 5
# )

# ---- 4. Regression analysis ----
# Example:
# m1 <- feols(y ~ x1 + x2, data = df)
# m2 <- feols(y ~ x1 + x2 | fe_group, cluster = ~cluster_id, data = df)

# ---- 5. Export regression tables ----
# Example:
# modelsummary(
#   list("OLS" = m1, "FE" = m2),
#   output = file.path(OUTPUT_TABLES, "regression_results.html")
# )

# ---- 6. Save any derived analysis outputs ----
# Example:
# summary_dt <- df_summary(df)
# fwrite(summary_dt, file.path(OUTPUT_TABLES, "summary_stats.csv"))

cat("01_analysis.R complete.\n")