#!/bin/bash
cd /c/bdaylor/Research/Projects/mlb_predict
rm -f .git/HEAD.lock
git add -A
git commit -m "Run 2026 analysis: xBA-BA gap, backwards K results"
git push
echo "Git done, exit: $?"
