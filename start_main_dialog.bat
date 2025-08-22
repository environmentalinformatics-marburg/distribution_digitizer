@echo off
REM ===============================================
REM Start Main Dialog for Distribution Digitizer
REM ===============================================

REM Set working directory to this batch's folder
set SCRIPT_DIR=%~dp0
if "%SCRIPT_DIR:~-1%"=="\" set SCRIPT_DIR=%SCRIPT_DIR:~0,-1%

REM Optional: Zeige Info
echo Starting Main Dialog from:
echo   %SCRIPT_DIR%
echo.

REM Start R script for main dialog
Rscript "%SCRIPT_DIR%\shiny_apps\app_main_dialog.R"

exit
