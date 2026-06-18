#!/bin/bash
# Run steps 3-5 only (statcast pull already done)

PROJ="/c/bdaylor/Research/Projects/mlb_predict"
LOGDIR="$PROJ/logs"
RSCRIPT="/c/Program Files/R/R-4.5.2/bin/Rscript.exe"

cd "$PROJ"

echo "[$(date)] STEP 3: xBA vs BA gap analysis..." | tee -a "$LOGDIR/pipeline.log"
echo "STEP3_START" > "$LOGDIR/step3.flag"
"$RSCRIPT" -e "source(here::here('code','analysis','06_xba_ba_gap.R'))" > "$LOGDIR/step3_xba.log" 2>&1
STEP3_EXIT=$?
echo "[$(date)] Step 3 done (exit $STEP3_EXIT)." | tee -a "$LOGDIR/pipeline.log"
echo "STEP3_DONE:$STEP3_EXIT" > "$LOGDIR/step3.flag"

echo "[$(date)] STEP 4: Backwards K analysis..." | tee -a "$LOGDIR/pipeline.log"
echo "STEP4_START" > "$LOGDIR/step4.flag"
"$RSCRIPT" -e "source(here::here('code','analysis','07_backwards_k.R'))" > "$LOGDIR/step4_backwards_k.log" 2>&1
STEP4_EXIT=$?
echo "[$(date)] Step 4 done (exit $STEP4_EXIT)." | tee -a "$LOGDIR/pipeline.log"
echo "STEP4_DONE:$STEP4_EXIT" > "$LOGDIR/step4.flag"

echo "[$(date)] STEP 5: Git commit and push..." | tee -a "$LOGDIR/pipeline.log"
git -C "$PROJ" add output/ code/ README.md CLAUDE.md renv.lock logs/ > "$LOGDIR/step5_git.log" 2>&1
git -C "$PROJ" commit -m "Run 2026 analysis: xBA-BA gap, backwards K results" >> "$LOGDIR/step5_git.log" 2>&1
git -C "$PROJ" push -u origin main >> "$LOGDIR/step5_git.log" 2>&1
GIT_EXIT=$?
echo "[$(date)] Step 5 done (exit $GIT_EXIT)." | tee -a "$LOGDIR/pipeline.log"

echo "[$(date)] ALL REMAINING STEPS COMPLETE." | tee -a "$LOGDIR/pipeline.log"
echo "PIPELINE_COMPLETE" > "$LOGDIR/pipeline_done.flag"
