@echo off
REM ===============================================
REM Start Main Dialog for Distribution Digitizer
REM ===============================================

REM === Default paths (customize if needed) ===
set DEFAULT_PYTHON=C:/ProgramData/miniconda3/python.exe
set DEFAULT_TESSERACT=C:/Program Files/Tesseract-OCR

REM === Prompt for Python ===
echo Python path [Default: %DEFAULT_PYTHON%]:
set /p PYTHON_PATH=Path to python.exe:
if "%PYTHON_PATH%"=="" set PYTHON_PATH=%DEFAULT_PYTHON%

REM === Prompt for Tesseract ===
echo Tesseract folder path [Default: %DEFAULT_TESSERACT%]:
set /p TESS_PATH=Path to Tesseract folder:
if "%TESS_PATH%"=="" set TESS_PATH=%DEFAULT_TESSERACT%

REM === Clean up potential quotes or trailing spaces ===
for /f "tokens=* delims=" %%a in ("%PYTHON_PATH%") do set PYTHON_PATH=%%~a
for /f "tokens=* delims=" %%a in ("%TESS_PATH%") do set TESS_PATH=%%~a

REM Determine this batch file's directory
set SCRIPT_DIR=%~dp0
if "%SCRIPT_DIR:~-1%"=="\" set SCRIPT_DIR=%SCRIPT_DIR:~0,-1%

REM === Set R-Script options ===
set R_HOST=127.0.0.1
set R_PORT=8888


echo.
echo Launching Distribution Digitizer with:
echo   Python: %PYTHON_PATH%
echo   Tesseract: %TESS_PATH%
echo   Directory: %SCRIPT_DIR%

echo Starting Main Dialog from:
echo   %SCRIPT_DIR%
echo.


REM Start R script for main dialog mit Fehlermeldungen
Rscript --vanilla "%SCRIPT_DIR%\shiny_apps\app_main_dialog.R" %R_HOST%  "%PYTHON_PATH%" "%TESS_PATH%" "%SCRIPT_DIR%"

pause
