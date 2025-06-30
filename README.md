
# 📦 Installation Guide – Distribution Digitizer

This guide explains how to install and prepare the **Distribution Digitizer** project on a Windows system using R, Python, and Shiny.

---

## 📚 Citation

This software is currently under development.  
If you use it, please cite:

**Venkatesh M, Forteva S, Zeuss D (2021)**  
*Distribution digitizer: Software for digitizing species distributions from analogue maps.*  
Version 0.0.1  
[https://github.com/environmentalinformatics-marburg/distribution_digitizer_students](https://github.com/environmentalinformatics-marburg/distribution_digitizer_students)

---

## ✅ Prerequisites

Ensure the following software are installed:

- [R](https://cran.r-project.org/)
- [RStudio](https://posit.co/download/rstudio-desktop/)
- [Git](https://git-scm.com/download/win) *(optional, if cloning)*
- [Tesseract OCR](https://github.com/tesseract-ocr/tesseract)
- [Python](https://www.python.org/) or [Miniconda](https://docs.conda.io/en/latest/miniconda.html)

---

## 📥 Clone the Repository

You can clone the project from GitHub using:

```bash
git clone https://github.com/YourUsername/distribution_digitizer.git
```

> 💡 If you downloaded the ZIP archive instead of cloning, the folder will likely be named `distribution_digitizer-main`. In this case, make sure to adjust all folder paths accordingly in the instructions and scripts.

---

## 📁 Folder Structure After Cloning

Below is the expected structure of the project directory. This structure is **essential** for the correct functioning of the Distribution Digitizer:

````plaintext
distribution_digitizer/
├── app_start.R               # Main launcher script (R)
├── start_Digitizer.bat       # Batch file to start the program
├── shiny_apps/               # All Shiny-based GUI scripts
│   ├── app_mode_selector.R
│   ├── app_write_config.R
│   ├── app_main_dialog.R
├── src/                      # Python and helper R scripts
│   └── (template matching, alignment, point detection, etc.)
├── config/                   # Static configuration files (CSV format)
│   ├── config.csv
│   └── ...
├── data/
│   └── input/                # Book-specific input files
│       ├── pages/            # Scanned TIFF images of the book pages (e.g., 0066.tif)
│       └── templates/        # Template-related resources
│           ├── maps/         # Cropped map templates (*.tif)
│           ├── geopoints/    # Coordinate files (*.points)
│           ├── symbols/      # Templates for different species point markers
│           └── align_ref/    # Reference maps for alignment/orientation
````

> ⚠️ Make sure that your templates and point files reflect the actual structure and content of the scanned book. For reliable matching, file names must correspond to the map and symbol types actually used.

---

## 📦 R Package Installation

Open **RStudio as Administrator** and run:

```r
install.packages(c(
  "shiny", "shinydashboard", "magick", "grid", "shinyFiles", 
  "reticulate", "tesseract", "leaflet", "raster", "sf", 
  "shinyalert", "shinyjs", "rdrop2"
))
```

> ⚠️ `rdrop2` is optional. If it fails, you can comment it out in the script.

These packages are used in the app and expected to be preinstalled:


---

## 🐍 Python Package Installation

In RStudio, run (only once):

```r
# Load reticulate first
library(reticulate)

# Install Python packages (Miniconda recommended)
reticulate::py_install(packages = c(
  "opencv-python", "pillow", "pandas", "GDAL", 
  "imutils", "rasterio", "geopandas"
), pip = TRUE)
```

If you do not use Miniconda, specify the system Python path manually:

```r
use_python("C:/Path/To/python.exe")
```

Use `Sys.which("python")` to find your path.

---

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

## ℹ️ More Information

[https://environmentalinformatics-marburg.github.io/distribution_digitizer_webpage](https://environmentalinformatics-marburg.github.io/distribution_digitizer_webpage)
