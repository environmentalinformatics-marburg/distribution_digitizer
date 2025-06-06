This software is currently under development.
If you use it, please cite it as

Venkatesh M, Forteva S and Zeuss D (2021) Distribution digitizer: Software for digitizing species distributions from analogue maps. Version 0.0.1 https://github.com/environmentalinformatics-marburg/distribution_digitizer_students



# 📦 Installation Guide – Distribution Digitizer

This guide explains how to install and prepare the **Distribution Digitizer** project on a Windows system using R, Python, and Shiny.

---

## ✅ Prerequisites

Ensure the following software is installed:

- [R](https://cran.r-project.org/)
- [RStudio](https://posit.co/download/rstudio-desktop/)
- [Git](https://git-scm.com/download/win) *(optional, if cloning)*
- [Tesseract OCR](https://github.com/tesseract-ocr/tesseract)
- [Python](https://www.python.org/) or [Miniconda](https://docs.conda.io/en/latest/miniconda.html)

---

## Clone the Repository
git clone https://github.com/YourUsername/distribution_digitizer.git
Note: If you downloaded the ZIP, your folder may be called distribution_digitizer-main. Adjust paths accordingly.


## 📁 Folder Structure (after extraction or cloning)

```plaintext
distribution_digitizer/
├── app_start.R               # Main launcher script (R)
├── start_Digitizer.bat       # Batch file for launching the app
├── shiny_apps/               # All Shiny GUI scripts
│   ├── app_mode_selector.R
│   ├── app_write_config.R
│   ├── app_main_dialog.R
├── src/                      # Python and utility R scripts
│   └── (image matching, alignment, etc.)
├── config/                   # Static configuration files (CSV)
│   └── config.csv
├── data/
│   └── input/                # Book scans, points, templates
│       └── templates/
│           ├── *.tif
│           ├── *.points
│           └── ...
```

---

## 📦 R Package Installation

Open **RStudio as Administrator** and run:

```r
install.packages(c(
  "shiny", "shinydashboard", "magick", "grid", "shinyFiles", 
  "reticulate", "tesseract", "leaflet", "raster", "sf", "shinyalert", "shinyjs"
))
```

> ⚠️ If `rdrop2` is missing or fails, it is not required and can be commented out in the script.

---

## 🐍 Python Package Installation

In RStudio, run (only once):

```r
# Load reticulate first
library(reticulate)

# Install Python packages (only needed once)
# If you are using Miniconda (recommended):
reticulate::py_install(packages = c(
  "opencv-python", "pillow", "pandas", "GDAL", 
  "imutils", "rasterio", "geopandas"
), pip = TRUE)

```

If you do not use Miniconda, specify the system Python path:

# Point to your system-installed Python manually if needed
```r
use_python("C:/Path/To/python.exe")
```
Use Sys.which("python") to get the exact path.

## ▶️ Starting the Application

To start the app, **double-click** the file:

```
start_digitizer.bat
```

This will run all configuration dialogs and launch the main app.

---

## 🧭 Next Steps

> The instructions for working with the configuration dialogs will be provided in a **separate guide**.

---


# More installation and usage

https://environmentalinformatics-marburg.github.io/distribution_digitizer_webpage



