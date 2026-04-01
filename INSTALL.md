# Distribution Digitizer -- Installation Guide (2026)

This document provides complete installation instructions for **Windows
10/11**.

This version uses a **dedicated Miniconda environment** for GDAL/PROJ to
ensure stable geospatial processing.

------------------------------------------------------------------------

# 📚 Citation

If you use this program, please cite:

**Venkatesh M, Forteva S, Zeuss D (2021)**\
*Distribution digitizer: Software for digitizing species distributions
from analogue maps.*\
Version 0.0.1\
https://github.com/environmentalinformatics-marburg/distribution_digitizer_students

------------------------------------------------------------------------

# ✅ 1. Install Required Software

Install the following:

## ✔ R (recommended: 4.4.x or higher)

https://cran.r-project.org/

## ✔ RStudio Desktop

https://posit.co/download/rstudio-desktop/

## ✔ Git (optional)

https://git-scm.com/download/win

## ✔ Miniconda (required for GDAL)

https://docs.conda.io/en/latest/miniconda.html

⚠ Install for **All Users**\
⚠ Default settings are fine

## ✔ Tesseract OCR


https://github.com/UB-Mannheim/tesseract/wiki

Install English + German language packs.

After installation, ensure that:
C:\Program Files\Tesseract-OCR\ is added to your system PATH

Or configure TESSDATA_PREFIX accordingly.
------------------------------------------------------------------------

# 🐍 2. Create Python Environment (IMPORTANT)

Open **Anaconda Prompt**.

Create dedicated environment:

conda create -n distribution_digitizer_env python=3.11\
conda activate distribution_digitizer_env

Install required geospatial and OCR libraries:

conda install -c conda-forge gdal
conda install -c conda-forge pandas numpy rasterio geopandas shapely fiona
conda install -c conda-forge opencv pillow pytesseract
conda install -c conda-forge imutils


Verify installation:

conda list gdal

Should show GDAL version (e.g., 3.11.x).

python -c "import pytesseract; print('pytesseract OK')"
tesseract --version

------------------------------------------------------------------------

# 📦 3. Install Required R Packages

Run RStudio.

install.packages(c( "shiny", "shinydashboard", "shinyFiles",
"shinyalert", "shinyjs", "DT", "magick", "grid", "reticulate",
"tesseract", "leaflet", "raster", "sf", "jsonlite", "stringr", "dplyr",
"tidyr", "remotes" ))

Optional:

remotes::install_github("karthik/rdrop2")

------------------------------------------------------------------------

# 🔗 4. Configure R--Python Connection

In `server.R` (at the very top, before anything else):

library(reticulate)

use_condaenv( "distribution_digitizer_env", required = TRUE, conda =
"C:/ProgramData/miniconda3/condabin/conda.bat" )

Restart RStudio.

Test connection:

library(reticulate) py_config() py_run_string("from osgeo import gdal;
print(gdal.VersionInfo())")

If a number (e.g., 3110400) is printed → setup is correct.

------------------------------------------------------------------------

Template Symbol Preparation for Point Matching

For reliable point detection, the symbol templates must be prepared carefully.
The quality and consistency of the templates strongly influence the detection results.

Please follow these guidelines when creating templates:

1. Crop the Symbol Tightly

Templates should contain only the symbol itself, without unnecessary background.

Good example:
[●]
Bad example (too much background):
[     ●     ]
Large background areas can lead to inaccurate template matching and incorrect point sizes.

2. Use Consistent Template Sizes

All templates for one map type should have approximately the same width and height (w, h).

For example:
Template 1: 12 × 12 px
Template 2: 12 × 12 px
Template 3: 12 × 12 px

Avoid situations like:
Template 1: 8 × 8 px
Template 2: 20 × 20 px
Template 3: 35 × 35 px

Different template sizes may cause inconsistent circle sizes during point visualization.

3. Avoid Background Borders
Do not include white or map background borders around the symbol.

Incorrect:
□□□□□□
□□●□□□
□□□□□□

Correct:
●

Background borders may lead to:

inaccurate template matching

oversized detected points

overlapping contour detection
# ▶️ 5. Start the Application

setwd("D:/distribution_digitizer")\
options(shiny.port = 8888, shiny.host = "127.0.0.1")\
shiny::runApp("app")


------------------------------------------------------------------------

# 🗺 Multi-Map Processing (New in 2026)

The processing pipeline now supports **multiple map types per book**.

All major modules have been refactored to operate per map directory:

- Template Matching
- Point Matching
- Rectifying
- Georeferencing
- Polygonize
- Spatial Data Merge

Each detected map type is processed in its own subfolder:

output/
  ├── 1/
  ├── 2/
  ├── 3/
  └── ...

This enables automated handling of books containing multiple
distribution map layouts without manual reconfiguration.

All spatial results (CSV, shapefiles, PNG overlays) are generated
per map folder.

------------------------------------------------------------------------

------------------------------------------------------------------------

# 🐛 Troubleshooting

### ❌ ModuleNotFoundError: pandas

conda install -c conda-forge pandas

### ❌ PROJ error: Cannot find proj.db

Make sure you are using the `distribution_digitizer_env` environment via `use_condaenv()`.

### ❌ reticulate cannot find conda

Ensure Miniconda is installed in:\
C:/ProgramData/miniconda3

### ❌ ModuleNotFoundError: pytesseract

conda activate distribution_digitizer_env
conda install -c conda-forge pytesseract
------------------------------------------------------------------------

# 🎯 Important Notes

-   Do NOT use system Python.
-   Do NOT install GDAL via pip.
-   Do NOT mix QGIS Python with this setup.
-   Always use the isolated `distribution_digitizer_env` environment.

------------------------------------------------------------------------

End of README.
