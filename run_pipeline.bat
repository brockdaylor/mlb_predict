@echo off
setlocal EnableDelayedExpansion

:: MLB Analysis Pipeline Runner
:: Logs all output to logs\ subfolder; creates pipeline_done.flag on finish.
cd /d "%~dp0"

set LOGDIR=%~dp0logs
if not exist "%LOGDIR%" mkdir "%LOGDIR%"

:: Find Rscript — try PATH first, then default install location
where Rscript >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    set RSCRIPT=Rscript
) else (
    set RSCRIPT="C:\Program Files\R\R-4.5.2\bin\Rscript.exe"
)

echo [%date% %time%] Pipeline started. Rscript=%RSCRIPT% > "%LOGDIR%\pipeline.log"
echo [%date% %time%] Working dir: %CD% >> "%LOGDIR%\pipeline.log"

:: ---- Step 1: Install openxlsx2 ----
echo [%date% %time%] STEP 1: Installing openxlsx2... >> "%LOGDIR%\pipeline.log"
echo STEP1_START > "%LOGDIR%\step1.flag"
%RSCRIPT% -e "renv::install('openxlsx2'); renv::snapshot()" > "%LOGDIR%\step1_install.log" 2>&1
if !ERRORLEVEL! NEQ 0 (
    echo [%date% %time%] ERROR: Step 1 failed (exit !ERRORLEVEL!) >> "%LOGDIR%\pipeline.log"
    echo STEP1_FAIL > "%LOGDIR%\step1.flag"
    echo PIPELINE_FAILED > "%LOGDIR%\pipeline_done.flag"
    goto :DONE
)
echo [%date% %time%] Step 1 complete. >> "%LOGDIR%\pipeline.log"
echo STEP1_DONE > "%LOGDIR%\step1.flag"

:: ---- Step 2: Statcast strikeout pull ----
echo [%date% %time%] STEP 2: Pulling Statcast strikeout data (~15-20 min)... >> "%LOGDIR%\pipeline.log"
echo STEP2_START > "%LOGDIR%\step2.flag"
%RSCRIPT% -e "source(here::here('code','data_processing','05_process_statcast_strikeouts.R'))" > "%LOGDIR%\step2_statcast.log" 2>&1
if !ERRORLEVEL! NEQ 0 (
    echo [%date% %time%] ERROR: Step 2 failed (exit !ERRORLEVEL!) >> "%LOGDIR%\pipeline.log"
    echo STEP2_FAIL > "%LOGDIR%\step2.flag"
    echo PIPELINE_FAILED > "%LOGDIR%\pipeline_done.flag"
    goto :DONE
)
echo [%date% %time%] Step 2 complete. >> "%LOGDIR%\pipeline.log"
echo STEP2_DONE > "%LOGDIR%\step2.flag"

:: ---- Step 3: xBA-BA gap analysis ----
echo [%date% %time%] STEP 3: xBA vs BA gap analysis... >> "%LOGDIR%\pipeline.log"
echo STEP3_START > "%LOGDIR%\step3.flag"
%RSCRIPT% -e "source(here::here('code','analysis','06_xba_ba_gap.R'))" > "%LOGDIR%\step3_xba.log" 2>&1
if !ERRORLEVEL! NEQ 0 (
    echo [%date% %time%] ERROR: Step 3 failed (exit !ERRORLEVEL!) >> "%LOGDIR%\pipeline.log"
    echo STEP3_FAIL > "%LOGDIR%\step3.flag"
    echo PIPELINE_FAILED > "%LOGDIR%\pipeline_done.flag"
    goto :DONE
)
echo [%date% %time%] Step 3 complete. >> "%LOGDIR%\pipeline.log"
echo STEP3_DONE > "%LOGDIR%\step3.flag"

:: ---- Step 4: Backwards K analysis ----
echo [%date% %time%] STEP 4: Backwards K analysis... >> "%LOGDIR%\pipeline.log"
echo STEP4_START > "%LOGDIR%\step4.flag"
%RSCRIPT% -e "source(here::here('code','analysis','07_backwards_k.R'))" > "%LOGDIR%\step4_backwards_k.log" 2>&1
if !ERRORLEVEL! NEQ 0 (
    echo [%date% %time%] ERROR: Step 4 failed (exit !ERRORLEVEL!) >> "%LOGDIR%\pipeline.log"
    echo STEP4_FAIL > "%LOGDIR%\step4.flag"
    echo PIPELINE_FAILED > "%LOGDIR%\pipeline_done.flag"
    goto :DONE
)
echo [%date% %time%] Step 4 complete. >> "%LOGDIR%\pipeline.log"
echo STEP4_DONE > "%LOGDIR%\step4.flag"

:: ---- Step 5: Git add + commit ----
echo [%date% %time%] STEP 5: Git commit... >> "%LOGDIR%\pipeline.log"
git add output/ code/ README.md CLAUDE.md renv.lock >> "%LOGDIR%\step5_git.log" 2>&1
git commit -m "Run 2026 analysis: xBA-BA gap, backwards K results" >> "%LOGDIR%\step5_git.log" 2>&1
git push -u origin main >> "%LOGDIR%\step5_git.log" 2>&1
if !ERRORLEVEL! NEQ 0 (
    echo [%date% %time%] WARNING: Git push may have failed — check step5_git.log >> "%LOGDIR%\pipeline.log"
) else (
    echo [%date% %time%] Step 5 (git) complete. >> "%LOGDIR%\pipeline.log"
)

echo [%date% %time%] ALL STEPS COMPLETE. >> "%LOGDIR%\pipeline.log"
echo PIPELINE_COMPLETE > "%LOGDIR%\pipeline_done.flag"

:DONE
echo.
echo Pipeline finished. See logs\ folder for details.
pause
