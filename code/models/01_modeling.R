############################################################
# 01_modeling.R
# Purpose: predictive modeling workflow
############################################################

source(here::here("code", "00_setup.R"))

# ---- 1. Load processed data ----
# Example:
# df <- fst::read_fst(file.path(DATA_PROCESSED, "model_data.fst"), as.data.table = TRUE)

# ---- 2. Define outcome and features ----
# Example:
# outcome_var <- "y"
# feature_vars <- c("x1", "x2", "x3")

# ---- 3. Train / test split ----
# Example:
# set.seed(123)
# train_idx <- sample(seq_len(nrow(df)), size = 0.8 * nrow(df))
# train_df <- df[train_idx]
# test_df  <- df[-train_idx]

# ---- 4. Baseline model ----
# Example:
# model_lm <- lm(y ~ x1 + x2 + x3, data = train_df)

# ---- 5. Generate predictions ----
# Example:
# test_df[, pred_lm := predict(model_lm, newdata = test_df)]

# ---- 6. Evaluate performance ----
# Example:
# rmse <- sqrt(mean((test_df$y - test_df$pred_lm)^2, na.rm = TRUE))
# mae  <- mean(abs(test_df$y - test_df$pred_lm), na.rm = TRUE)
#
# metrics <- data.table(
#   model = "lm",
#   rmse = rmse,
#   mae = mae
# )
#
# print(metrics)

# ---- 7. Save model outputs ----
# Example:
# fwrite(metrics, file.path(OUTPUT_TABLES, "model_metrics.csv"))
# saveRDS(model_lm, file.path(OUTPUT_TABLES, "model_lm.rds"))

cat("01_modeling.R complete.\n")