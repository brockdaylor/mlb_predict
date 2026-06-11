############################################################
# 02_league_trends.R
# Purpose: exploratory descriptives — league-wide trends over time
# Data: Lahman team-season (run 04_process_lahman_data.R first)
############################################################

source(here::here("code", "00_setup.R"))

# ---- 1. Load processed data ----
tm_file <- file.path(DATA_PROCESSED, "lahman_teams_season.parquet")
if (!file.exists(tm_file)) {
  stop("Missing ", tm_file, " — run code/data_processing/04_process_lahman_data.R first.")
}
tm <- arrow::read_parquet(tm_file) |> as.data.table()

# Modern era only (1901+), league-season aggregates per game
lg <- tm[yearID >= 1901, .(
  rpg  = sum(R)  / sum(G),
  hrpg = sum(HR) / sum(G),
  kpg  = sum(SO, na.rm = TRUE) / sum(G),
  bbpg = sum(BB) / sum(G),
  avg  = sum(H)  / sum(AB)
), by = yearID][order(yearID)]

# ---- 2. Summary statistics ----
print(df_summary(lg))
fwrite(lg, file.path(OUTPUT_TABLES, "league_trends_by_year.csv"))

# ---- 3. Trend figures ----
p_runs <- ggplot(lg, aes(yearID, rpg)) +
  geom_line(color = "grey60") +
  geom_smooth(se = FALSE, span = 0.25, color = "steelblue") +
  labs(title = "Run scoring per team-game, 1901–present",
       x = NULL, y = "Runs per game")
save_plot(p_runs, "league_runs_per_game.png")

p_tto <- lg |>
  melt(id.vars = "yearID", measure.vars = c("hrpg", "kpg", "bbpg"),
       variable.name = "stat") |>
  ggplot(aes(yearID, value, color = stat)) +
  geom_line() +
  scale_color_manual(
    values = c(hrpg = "firebrick", kpg = "steelblue", bbpg = "darkgreen"),
    labels = c(hrpg = "HR/G", kpg = "K/G", bbpg = "BB/G")
  ) +
  labs(title = "Three true outcomes per team-game, 1901–present",
       x = NULL, y = "Per team-game", color = NULL)
save_plot(p_tto, "league_three_true_outcomes.png")

p_avg <- ggplot(lg, aes(yearID, avg)) +
  geom_line(color = "grey60") +
  geom_smooth(se = FALSE, span = 0.25, color = "firebrick") +
  labs(title = "League batting average, 1901–present",
       x = NULL, y = "AVG")
save_plot(p_avg, "league_batting_avg.png")

cat("02_league_trends.R complete.\n")
