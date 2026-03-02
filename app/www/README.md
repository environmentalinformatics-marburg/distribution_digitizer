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

------------------------------------------------------------------------

# 🐍 2. Create Python Environment (IMPORTANT)

Open **Anaconda Prompt**.

Create dedicated environment:

conda create -n distgeo python=3.11\
conda activate distgeo

Install required geospatial libraries:

conda install -c conda-forge gdal\
conda install -c conda-forge pandas numpy rasterio geopandas shapely
fiona

Optional (if needed):

conda install -c conda-forge opencv pillow pytesseract

Verify installation:

conda list gdal

Should show GDAL version (e.g., 3.11.x).

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

use_condaenv( "distgeo", required = TRUE, conda =
"C:/ProgramData/miniconda3/condabin/conda.bat" )

Restart RStudio.

Test connection:

library(reticulate) py_config() py_run_string("from osgeo import gdal;
print(gdal.VersionInfo())")

If a number (e.g., 3110400) is printed → setup is correct.

------------------------------------------------------------------------

# ▶️ 5. Start the Application

setwd("D:/distribution_digitizer")\
options(shiny.port = 8888, shiny.host = "127.0.0.1")\
shiny::runApp("app")

------------------------------------------------------------------------

# 🐛 Troubleshooting

### ❌ ModuleNotFoundError: pandas

conda install -c conda-forge pandas

### ❌ PROJ error: Cannot find proj.db

Make sure you are using the `distgeo` environment via `use_condaenv()`.

### ❌ reticulate cannot find conda

Ensure Miniconda is installed in:\
C:/ProgramData/miniconda3

------------------------------------------------------------------------

# 🎯 Important Notes

-   Do NOT use system Python.
-   Do NOT install GDAL via pip.
-   Do NOT mix QGIS Python with this setup.
-   Always use the isolated `distgeo` environment.

------------------------------------------------------------------------

End of README.
