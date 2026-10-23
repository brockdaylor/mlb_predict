# NOTES — mlb_predict

Running log of data provenance, environment changes, and cleaning decisions.

## 2026-10-23 — R 4.5.2 → 4.6.1 upgrade (renv.lock re-snapshotted)

- **Why:** R 4.5.2 is no longer installed on the dev machine, and the old lockfile can't be restored on R 4.6.1. The old pinned versions have no R 4.6 Windows binaries, so they build from source, and some no longer compile (e.g. cli 3.6.5 calls `Rf_findVar`, which R 4.6 removed). The alternative, keeping R 4.5.2 installed alongside for this project, was rejected because it means maintaining two R installs.
- **What:** installed current Posit Package Manager binaries for every lockfile package, then `renv::snapshot()`. 54 of 132 packages changed version, including arrow 23→25, fixest 0.13→0.14, curl 7→8, fs 1→2 and RcppParallel 5→6. `otel` was added (new httr2 dependency). `lattice` and `nlme` use the versions bundled with R 4.6.1.
- **Exception:** baseballr kept at 1.6.0 rather than 2.0.0, because the scraping pipelines were fixed against 1.6.0 (commit 1555453).
- **Verification:** reran `06_xba_ba_gap.R` and `07_backwards_k.R` on unchanged inputs (`fg_batters_all.parquet`, `statcast_strikeouts_2026.parquet`; both predate the 2026-06-18 outputs). All six Excel sheets match the committed outputs cell for cell, and all five PNG figures are byte-identical. `05_process_statcast_strikeouts.R` (network pull) was not rerun.
- **Known issue:** R exits with code -1073741569 (0xC00000FF) after loading arrow. This reproduces with arrow 24 and 25 and with `--vanilla` outside renv, and no arrow setting avoids it (memory pool, SIMD level, thread counts). The likely cause is x64 R running under ARM emulation. Scripts finish their work first. `run_pipeline.bat` now judges success by each script's final `complete.` line instead of the exit code.
- **Install tip:** set `RENV_CONFIG_INSTALL_STAGED=FALSE` before renv installs. Staged installs write into `renv/staging` inside the OneDrive folder, and OneDrive locks make the final rename fail with "Access is denied".
