#!/bin/bash
# MLB Analysis Pipeline - runs from MSYS2/Rtools bash
set -e

PROJ="/c/bdaylor/Research/Projects/mlb_predict"
LOGDIR="$PROJ/logs"
mkdir -p "$LOGDIR"

cd "$PROJ"

# Find Rscript
RSCRIPT="/c/Program Files/R/R-4.5.2/bin/Rscript.exe"
if [ ! -f "$RSCRIPT" ]; then
  RSCRIPT=$(which Rscript 2>/dev/null || echo "")
fi
if [ -z "$RSCRIPT" ]; then
  echo "ERROR: Rscript not found" | tee -a "$LOGDIR/pipeline.log"
  exit 1
fi

echo "[$(date)] Pipeline started. Rscript=$RSCRIPT" | tee "$LOGDIR/pipeline.log"
echo "[$(date)] Working dir: $(pwd)" | tee -a "$LOGDIR/pipeline.log"

# Step 1: Install openxlsx2
echo "[$(date)] STEP 1: Installing openxlsx2..." | tee -a "$LOGDIR/pipeline.log"
echo "STEP1_START" > "$LOGDIR/step1.flag"
"$RSCRIPT" -e "renv::install('openxlsx2'); renv::snapshot()" > "$LOGDIR/step1_install.log" 2>&1
echo "[$(date)] Step 1 complete." | tee -a "$LOGDIR/pipeline.log"
echo "STEP1_DONE" > "$LOGDIR/step1.flag"

# Step 2: Statcast pull
echo "[$(date)] STEP 2: Statcast strikeout pull (~15-20 min)..." | tee -a "$LOGDIR/pipeline.log"
echo "STEP2_START" > "$LOGDIR/step2.flag"
"$RSCRIPT" -e "source(here::here('code','data_processing','05_process_statcast_strikeouts.R'))" > "$LOGDIR/step2_statcast.log" 2>&1
echo "[$(date)] Step 2 complete." | tee -a "$LOGDIR/pipeline.log"
echo "STEP2_DONE" > "$LOGDIR/step2.flag"

# Step 3: xBA-BA gap
echo "[$(date)] STEP 3: xBA vs BA gap analysis..." | tee -a "$LOGDIR/pipeline.log"
echo "STEP3_START" > "$LOGDIR/step3.flag"
"$RSCRIPT" -e "source(here::here('code','analysis','06_xba_ba_gap.R'))" > "$LOGDIR/step3_xba.log" 2>&1
echo "[$(date)] Step 3 complete." | tee -a "$LOGDIR/pipeline.log"
echo "STEP3_DONE" > "$LOGDIR/step3.flag"

# Step 4: Backwards K
echo "[$(date)] STEP 4: Backwards K analysis..." | tee -a "$LOGDIR/pipeline.log"
echo "STEP4_START" > "$LOGDIR/step4.flag"
"$RSCRIPT" -e "source(here::here('code','analysis','07_backwards_k.R'))" > "$LOGDIR/step4_backwards_k.log" 2>&1
echo "[$(date)] Step 4 complete." | tee -a "$LOGDIR/pipeline.log"
echo "STEP4_DONE" > "$LOGDIR/step4.flag"

# Step 5: Git commit + push
echo "[$(date)] STEP 5: Git commit and push..." | tee -a "$LOGDIR/pipeline.log"
git add output/ code/ README.md CLAUDE.md renv.lock >> "$LOGDIR/step5_git.log" 2>&1
git commit -m "Run 2026 analysis: xBA-BA gap, backwards K results" >> "$LOGDIR/step5_git.log" 2>&1
git push -u origin main >> "$LOGDIR/step5_git.log" 2>&1
echo "[$(date)] Step 5 complete." | tee -a "$LOGDIR/pipeline.log"

echo "[$(date)] ALL STEPS COMPLETE." | tee -a "$LOGDIR/pipeline.log"
echo "PIPELINE_COMPLETE" > "$LOGDIR/pipeline_done.flag"
