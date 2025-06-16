@echo off
REM ===================================================
REM Distribution Digitizer Setup with Defaults
REM ===================================================

REM Open the README.pdf with the default PDF viewer
start "" "README.pdf"

REM Display the setup menu
echo.
echo ===================================================
echo     Welcome to the Distribution Digitizer Setup
echo ===================================================
echo.
echo The user guide has been opened in README.pdf.
echo Please read it carefully before continuing.
echo.
echo Default values are suggested below.
echo Press ENTER to accept the default, or type your custom path.
echo.

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

echo.
echo Launching Distribution Digitizer with:
echo   Python: %PYTHON_PATH%
echo   Tesseract: %TESS_PATH%
echo   Directory: %SCRIPT_DIR%
echo.

REM Launch the R script with arguments
Rscript app_start.R "%PYTHON_PATH%" "%SCRIPT_DIR%" "%TESS_PATH%"

pause
exit