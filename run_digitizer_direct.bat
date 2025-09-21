@echo off
echo ==============================================
echo Distribution Digitizer - Direct Mode (no UI)
echo ==============================================

REM === Default paths ===
set DEFAULT_INPUT=D:/distribution_digitizer
set DEFAULT_OUTPUT=D:/test/
set DEFAULT_PYTHON=C:/ProgramData/miniconda3/python.exe
set DEFAULT_TESSERACT=C:/Program Files/Tesseract-OCR

REM === Prompt for Input ===
echo -----------------------------------------
echo Please enter input folder
echo [Enter] = Use default (%DEFAULT_INPUT%)
echo Example: D:/distribution_digitizer
echo -----------------------------------------
set /p INPUTDIR=Input folder: 
if "%INPUTDIR%"=="" set INPUTDIR=%DEFAULT_INPUT%

REM === Prompt for Output ===
echo -----------------------------------------
echo Please enter output folder
echo [Enter] = Use default (%DEFAULT_OUTPUT%)
echo Example: D:/test/output_2025-08-13_12-41-21
echo -----------------------------------------
set /p OUTPUTDIR=Output folder: 
if "%OUTPUTDIR%"=="" set OUTPUTDIR=%DEFAULT_OUTPUT%

REM === Page selection ===
echo -----------------------------------------
echo Page selection:
echo   - Enter exact filename, e.g. 0088.tif
echo   - Enter a number, e.g. 10 (first 10 pages)
echo   - Press Enter for ALL pages
echo -----------------------------------------
set /p PAGESEL=Page / Number / Enter for ALL: 
if "%PAGESEL%"=="" set PAGESEL=ALL

REM === Python path ===
echo -----------------------------------------
echo Please enter path to Python.exe
echo [Enter] = Use default (%DEFAULT_PYTHON%)
echo Example: C:/ProgramData/miniconda3/python.exe
echo -----------------------------------------
set /p PYTHON_PATH=Python path: 
if "%PYTHON_PATH%"=="" set PYTHON_PATH=%DEFAULT_PYTHON%

REM === Tesseract path ===
echo -----------------------------------------
echo Please enter Tesseract installation path
echo [Enter] = Use default (%DEFAULT_TESSERACT%)
echo Example: C:/Program Files/Tesseract-OCR
echo -----------------------------------------
set /p TESS_PATH=Tesseract path: 
if "%TESS_PATH%"=="" set TESS_PATH=%DEFAULT_TESSERACT%

REM === Env vars ===
set RETICULATE_PYTHON=%PYTHON_PATH%
set TESSDATA_PREFIX=%TESS_PATH%\tessdata
set PATH=%TESS_PATH%;%PATH%

REM === Show chosen settings ===
echo -----------------------------------------
echo        SETTINGS
echo -----------------------------------------
echo Input:     %INPUTDIR%
echo Output:    %OUTPUTDIR%
echo PageSel:   %PAGESEL%
echo Python:    %PYTHON_PATH%
echo Tesseract: %TESS_PATH%
echo -----------------------------------------
echo.

REM === Check Output Folder ===
if not exist "%OUTPUTDIR%" (
    echo The output folder "%OUTPUTDIR%" does not exist.
    echo.
    echo Please start the Digitizer with the batch script "start_dialog.bat".
    echo Read the PDF instructions carefully and fill in the configuration fields
    echo in the dialog to create the necessary folder structure.
    echo.
    pause
    exit /b
)

REM === Optional: Minimum structure check (e.g. maps/) ===
if not exist "%OUTPUTDIR%\maps" (
    echo The output folder "%OUTPUTDIR%" does not have a valid structure.
    echo Please start the Digitizer with the batch script "start_dialog.bat".
    echo Read the PDF instructions carefully and fill in the configuration fields
    echo in the dialog to create the necessary folder structure.
    echo.
    pause
    exit /b
)

REM === Launch R script ===
set SCRIPT_DIR=%~dp0
Rscript "%SCRIPT_DIR%\digitizer_run_direct.R" "%INPUTDIR%" "%OUTPUTDIR%" "%PAGESEL%"

echo.
echo Script finished. Press any key to exit.
pause
