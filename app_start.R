#-------------------------------------------------------------------------------------------------

# Installation of needed packages (python) ####
# deactivate using comment after first installation
#py_install(packages = "opencv", pip = FALSE) #used for map matching
#py_install(packages = "pillow", pip = FALSE)
#py_install(packages = "tesseract", pip = FALSE)
#py_install(packages = "pandas", pip = FALSE)
#py_install(packages = "GDAL", pip = FALSE)
#py_install(packages = "imutils", pip = FALSE)
#py_install(packages = "rasterio", pip = FALSE)
#py_install(packages = "geopandas", pip = FALSE)

#use_python(Sys.which("python")) # Set the path to a local python installation.
# use this row if you not use Anaconda or miniconda. the best way is to set the python system (environment)variables (Windows->system,...) 

#use_python("C:/ProgramData/miniconda3/python.exe")
# os <- import("os") # python module needed for managing files, folders and their paths

#py_install(packages = "osgeo", pip = FALSE)
#py_install(packages = "opencv-python", pip = TRUE)
#setwd("C:/ProgramData/Miniconda3/")

#py_install(packages = "pillow", pip = FALSE)
#py_install(packages = "pandas", pip = FALSE)
#py_install(packages = "GDAL", pip = FALSE)


#---------------------------------------------------------------------------------------------------
# Distribution Digitizer – Start-Skript
#---------------------------------------------------------------------------------------------------

library(reticulate)
library(shiny)


# Set working directory to script location
args <- commandArgs(trailingOnly = FALSE)
script_path <- normalizePath(sub("--file=", "", args[grep("--file=", args)]))
setwd(dirname(script_path))  # Setzt Arbeitsverzeichnis auf Projektordner

print(getwd())

# Logging function
log_message <- function(msg) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  cat(paste0("[", timestamp, "] ", msg, "\n"), file = "start_log.txt", append = TRUE)
}

log_message("🚀 Starting Distribution Digitizer...")

# Define subfolder for shiny apps
shiny_dir <- "shiny_apps"

# Check required files
required_files <- c("app_mode_selector.R", "app_write_config.R", "app_main_dialog.R")
missing <- required_files[!file.exists(file.path(shiny_dir, required_files))]
if (length(missing) > 0) {
  log_message(paste("❌ Missing required files:", paste(missing, collapse = ", ")))
  stop("Required R scripts are missing in 'shiny_apps/'. Please check the folder.")
}

# Run dialogs
log_message("▶ Running mode selector...")
config_path <- runApp(file.path(shiny_dir, "app_mode_selector.R"))

#log_message("▶ Running configuration dialog...")
#config_path <- runApp(file.path(shiny_dir, "app_write_config.R"))

#log_message("💾 Saving configuration result...")
#saveRDS(config_path, file = "config_path.rds")

# Start main dialog
#log_message("▶ Starting main app...")
#system(paste("Rscript", file.path(shiny_dir, "app_main_dialog.R"), "8889"), wait = FALSE)

log_message("✅ Main app launched.")
