############################################################
# 02_team_wins_model.R
# Purpose: simple baseline models — team wins from run differential,
#          Pythagorean expectation, out-of-sample evaluation
# Data: Lahman team-season (run 04_process_lahman_data.R first)
############################################################

source(here::here("code", "00_setup.R"))

# ---- 1. Load processed data ----
tm_file <- file.path(DATA_PROCESSED, "lahman_teams_season.parquet")
if (!file.exists(tm_file)) {
  stop("Missing ", tm_file, " — run code/data_processing/04_process_lahman_data.R first.")
}
tm <- arrow::read_parquet(tm_file) |> as.data.table()

# Modern era, per-game scale (handles strike-shortened/COVID seasons)
df <- tm[yearID >= 1901]
df[, `:=`(wpg = W / G, rdpg = run_diff / G)]

# ---- 2. Train / test split (by season, not random rows) ----
test_years  <- df[, sort(unique(yearID))]
test_years  <- test_years[test_years >= max(test_years) - 9]   # last 10 seasons
train_df    <- df[!yearID %in% test_years]
test_df     <- df[yearID %in% test_years]
message("Train seasons: ", min(train_df$yearID), "–", max(train_df$yearID),
        " | Test seasons: ", min(test_df$yearID), "–", max(test_df$yearID))

# ---- 3. Models ----
# (a) OLS: win pct on run differential per game
m_ols <- feols(wpg ~ rdpg, data = train_df)

# (b) OLS with year FE (era-adjusted intercept)
m_fe  <- feols(wpg ~ rdpg | yearID, cluster = ~yearID, data = train_df)

# (c) Pythagorean: estimate the exponent k in W% = R^k / (R^k + RA^k)
#     log(W/L) = k * log(R/RA)
pyth_df <- train_df[W > 0 & L > 0 & RA > 0]
m_pyth  <- feols(log(W / L) ~ 0 + log(R / RA), data = pyth_df)
k_hat   <- coef(m_pyth)[[1]]
message("Estimated Pythagorean exponent: ", round(k_hat, 3))

# ---- 4. Out-of-sample predictions (wins over a full season) ----
test_df[, `:=`(
  pred_ols  = predict(m_ols,  newdata = test_df) * G,
  pred_pyth = (R^k_hat / (R^k_hat + RA^k_hat)) * G,
  pred_pyth2 = pyth_wpct * G                       # classic exponent = 2
)]

# ---- 5. Evaluate ----
eval_model <- function(actual, pred, label) {
  data.table(
    model = label,
    rmse  = sqrt(mean((actual - pred)^2, na.rm = TRUE)),
    mae   = mean(abs(actual - pred), na.rm = TRUE)
  )
}
metrics <- rbindlist(list(
  eval_model(test_df$W, test_df$pred_ols,   "OLS (run diff/G)"),
  eval_model(test_df$W, test_df$pred_pyth,  sprintf("Pythagorean (k = %.2f)", k_hat)),
  eval_model(test_df$W, test_df$pred_pyth2, "Pythagorean (k = 2)")
))
print(metrics)
fwrite(metrics, file.path(OUTPUT_TABLES, "team_wins_model_metrics.csv"))

# ---- 6. Export regression table and fit figure ----
modelsummary(
  list("OLS" = m_ols, "OLS + year FE" = m_fe, "Pythagorean (log)" = m_pyth),
  output = file.path(OUTPUT_TABLES, "team_wins_models.html")
)

p_fit <- ggplot(test_df, aes(pred_pyth, W)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "grey50") +
  geom_point(alpha = 0.6) +
  labs(title = sprintf("Out-of-sample: Pythagorean (k = %.2f) predicted vs. actual wins", k_hat),
       subtitle = sprintf("Test seasons %d–%d", min(test_df$yearID), max(test_df$yearID)),
       x = "Predicted wins", y = "Actual wins")
save_plot(p_fit, "team_wins_pyth_oos_fit.png")

cat("02_team_wins_model.R complete.\n")
