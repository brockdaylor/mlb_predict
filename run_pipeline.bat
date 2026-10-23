@echo off
setlocal EnableDelayedExpansion

:: MLB Analysis Pipeline Runner
:: Runs the 2026 pipeline in order. Logs all output to logs\ subfolder;
:: creates pipeline_done.flag on finish. Does NOT commit or push: review
:: outputs and commit by hand.
::
:: Success check: a step passes only if its log contains the script's final
:: "<script>.R complete." line. Exit codes are not trusted: on ARM64 Windows
:: (x64 R under emulation) R crashes during shutdown (0xC00000FF) after the
:: script has finished, unless the env var CLI_NO_THREAD=1 is set. See docs\NOTES.md.
cd /d "%~dp0"

set LOGDIR=%~dp0logs
if not exist "%LOGDIR%" mkdir "%LOGDIR%"

:: Find Rscript on PATH; stop with a clear message rather than guess a version
where Rscript >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Rscript not found on PATH. Add R's bin\x64 folder to PATH and retry.
    echo PIPELINE_FAILED > "%LOGDIR%\pipeline_done.flag"
    goto :DONE
)
set RSCRIPT=Rscript

echo [%date% %time%] Pipeline started. Rscript=%RSCRIPT% > "%LOGDIR%\pipeline.log"
echo [%date% %time%] Working dir: %CD% >> "%LOGDIR%\pipeline.log"

:: ---- Step 1: Check installed packages match renv.lock ----
:: Read-only check; if it fails, run renv::restore() and inspect before rerunning.
echo [%date% %time%] STEP 1: Checking packages against renv.lock... >> "%LOGDIR%\pipeline.log"
echo STEP1_START > "%LOGDIR%\step1.flag"
%RSCRIPT% -e "s <- renv::status(); if (isTRUE(s$synchronized)) cat('renv check complete.\n')" > "%LOGDIR%\step1_renv.log" 2>&1
findstr /L /C:"renv check complete." "%LOGDIR%\step1_renv.log" >nul
if !ERRORLEVEL! NEQ 0 (
    echo [%date% %time%] ERROR: Step 1 failed - packages out of sync with renv.lock, see step1_renv.log >> "%LOGDIR%\pipeline.log"
    echo STEP1_FAIL > "%LOGDIR%\step1.flag"
    echo PIPELINE_FAILED > "%LOGDIR%\pipeline_done.flag"
    goto :DONE
)
echo [%date% %time%] Step 1 complete. >> "%LOGDIR%\pipeline.log"
echo STEP1_DONE > "%LOGDIR%\step1.flag"

:: ---- Steps 2-4: R scripts ----
call :RUN_STEP 2 "Pulling Statcast strikeout data (~15-20 min)" code/data_processing/05_process_statcast_strikeouts.R 05_process_statcast_strikeouts.R step2_statcast.log
if !ERRORLEVEL! NEQ 0 goto :DONE
call :RUN_STEP 3 "xBA vs BA gap analysis" code/analysis/06_xba_ba_gap.R 06_xba_ba_gap.R step3_xba.log
if !ERRORLEVEL! NEQ 0 goto :DONE
call :RUN_STEP 4 "Backwards K analysis" code/analysis/07_backwards_k.R 07_backwards_k.R step4_backwards_k.log
if !ERRORLEVEL! NEQ 0 goto :DONE

echo [%date% %time%] ALL STEPS COMPLETE. Review outputs, then commit manually. >> "%LOGDIR%\pipeline.log"
echo PIPELINE_COMPLETE > "%LOGDIR%\pipeline_done.flag"
goto :DONE

:: ---- RUN_STEP <n> <label> <script path> <script name> <log file> ----
:: Sources one script; passes if the log contains "<script name> complete."
:RUN_STEP
echo [%date% %time%] STEP %1: %~2... >> "%LOGDIR%\pipeline.log"
echo STEP%1_START > "%LOGDIR%\step%1.flag"
%RSCRIPT% -e "source(here::here('%3'))" > "%LOGDIR%\%5" 2>&1
set RC=!ERRORLEVEL!
findstr /L /C:"%4 complete." "%LOGDIR%\%5" >nul
if !ERRORLEVEL! NEQ 0 (
    echo [%date% %time%] ERROR: Step %1 failed - no completion line, see %5 ^(exit !RC!^) >> "%LOGDIR%\pipeline.log"
    echo STEP%1_FAIL > "%LOGDIR%\step%1.flag"
    echo PIPELINE_FAILED > "%LOGDIR%\pipeline_done.flag"
    exit /b 1
)
echo [%date% %time%] Step %1 complete ^(R exit !RC!^). >> "%LOGDIR%\pipeline.log"
echo STEP%1_DONE > "%LOGDIR%\step%1.flag"
exit /b 0

:DONE
echo.
echo Pipeline finished. See logs\ folder for details.
pause
