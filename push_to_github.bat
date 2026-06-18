@echo off
:: Quick helper to push the committed changes to GitHub.
:: Run this from Git Bash or Windows Terminal in the project root,
:: or just double-click it if you have git credentials cached.
cd /d "%~dp0"
git push -u origin main
echo.
echo Done. Check https://github.com/brockdaylor/mlb_predict
pause
