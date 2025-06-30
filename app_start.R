# --------------------------------------------------------------------------------------------------
# OPTIONAL: Manual installation of Python packages (use only for initial setup if needed)
# Uncomment to install via reticulate/conda or pip
# --------------------------------------------------------------------------------------------------

# py_install(packages = "opencv", pip = FALSE)        # used for map matching
# py_install(packages = "pillow", pip = FALSE)
# py_install(packages = "tesseract", pip = FALSE)
# py_install(packages = "pandas", pip = FALSE)
# py_install(packages = "GDAL", pip = FALSE)
# py_install(packages = "imutils", pip = FALSE)
# py_install(packages = "rasterio", pip = FALSE)
# py_install(packages = "geopandas", pip = FALSE)

# Use this only if you don't use Anaconda or Miniconda. Otherwise, it's recommended to set system environment variables.
# use_python("C:/ProgramData/miniconda3/python.exe")

# --------------------------------------------------------------------------------------------------
# Distribution Digitizer – Launch Script
# --------------------------------------------------------------------------------------------------

# ===============================
# 1. Get Python interpreter and working directory from batch file
# ===============================

args <- commandArgs(trailingOnly = TRUE)


if (length(args) < 3 || !file.exists(args[1]) || !dir.exists(args[3])) {
  stop("❌ Python path, working directory, or Tesseract path is missing or invalid. Please check your input.")
}

python_path <- args[1]
script_folder <- normalizePath(gsub("\\\\", "/", args[2]), winslash = "/", mustWork = TRUE)
tess_path    <- normalizePath(gsub("\\\\", "/", args[3]), winslash = "/", mustWork = TRUE)


# Set working directory to where the batch file is located
setwd(script_folder)

# Update config.csv with new Tesseract path
config_path <- file.path("config", "config.csv")

if (file.exists(config_path)) {
  config <- read.csv(config_path, sep = ";", stringsAsFactors = FALSE)
  if ("tesserAct" %in% names(config)) {
    config$tesserAct[1] <- tess_path
    write.table(config, file = config_path, sep = ";", row.names = FALSE, quote = FALSE)
    cat("✅ Updated 'tesserAct' path in config.csv.\n")
  } else {
    warning("⚠️ Column 'tesserAct' not found in config.csv.")
  }
} else {
  warning("⚠️ config.csv not found in /config directory.")
}

cat("📁 Working directory set to:", getwd(), "\n")
cat("📌 Tesseract folder path set to:", tess_path, "\n")

# ===============================
# 2. Check R package dependencies (report only, do not install automatically)
# ===============================

required_r_packages <- c(
  "shiny", "shinydashboard", "magick", "grid", "shinyFiles", 
  "reticulate", "tesseract", "leaflet", "raster", "sf", 
  "shinyalert", "shinyjs", "rdrop2"
)

missing_r_packages <- required_r_packages[!(required_r_packages %in% installed.packages()[, "Package"])]
if (length(missing_r_packages) > 0) {
  stop(paste(
    "❌ The following required R packages are missing:\n", paste(missing_r_packages, collapse = ", "),
    "\n\nPlease install them manually in RStudio or via the console, for example:\n  install.packages(\"package_name\")",
    "\n\n📄 For detailed setup instructions, please refer to the README.pdf file located in the project folder."
  ))
}

invisible(lapply(required_r_packages, require, character.only = TRUE))

# ===============================
# 3. Configure Python interpreter and check required modules
# ===============================

library(reticulate)
use_python(python_path, required = TRUE)

cat("\n✅ Python interpreter:\n")
print(py_config())

required_py_modules <- c("cv2", "PIL", "pandas", "osgeo", "imutils", "geopandas", 
                         "functools", "string", "os", "glob", "shutil") # test with no module, "superfakepy999")

missing <- required_py_modules[!sapply(required_py_modules, py_module_available)]

if (length(missing) > 0) {
  stop(paste(
    "❌ The following required Python modules are missing:\n", paste(missing, collapse = ", "),
    "\n\nPlease install them manually using:\n  conda install -c conda-forge", 
    paste(missing, collapse = " "),
    "\n\n📄 For detailed setup instructions, please refer to the README.pdf file included in the project folder."
  ))
}

cat("\n✅ All required R and Python dependencies are fulfilled. Launching app...\n\n")

# ===============================
# 4. Launch the Shiny application
# ===============================

library(shiny)

# Set working directory again (optional safety)
setwd(script_folder)
workingDir <- script_folder
cat("📁 Working directory:", workingDir, "\n")

# Fix: Set or update 'input' in start_config.csv
start_config_path <- file.path(script_folder, "start_config.csv")
if (file.exists(start_config_path)) {
  lines <- readLines(start_config_path)
  config <- setNames(sub(".*=", "", lines), sub("=.*", "", lines))
  config["input"] <- script_folder  # set input = working dir
  new_lines <- paste0(names(config), "=", config)
  writeLines(new_lines, start_config_path)
  cat("✅ Set 'input' in start_config.csv to:", script_folder, "\n")
} else {
  warning("⚠️ start_config.csv not found. Cannot update 'input'.")
}

# Logging function for easier debugging
log_message <- function(msg) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  cat(paste0("[", timestamp, "] ", msg, "\n"), file = "start_log.txt", append = TRUE)
}

log_message("🚀 Starting Distribution Digitizer...")

# Define subfolder that contains all Shiny apps
shiny_dir <- "shiny_apps"

# Check if required R scripts exist
required_files <- c("app_mode_selector.R", "app_write_config.R", "app_main_dialog.R")
missing <- required_files[!file.exists(file.path(shiny_dir, required_files))]
if (length(missing) > 0) {
  log_message(paste("❌ Missing required files:", paste(missing, collapse = ", ")))
  stop("Required R scripts are missing in 'shiny_apps/'. Please check the folder.")
}

# Run the mode selector dialog
log_message("▶ Running mode selector...")
shiny_port <- 8888
Sys.setenv(APP_WORKING_DIR = script_folder)

# ... (dein bestehender Code bleibt gleich bis hier)
Sys.setenv(APP_WORKING_DIR = script_folder)

library(readr)

# Pfad zur Steuerdatei
configFile <- file.path(script_folder, "start_config.csv")

if (!file.exists(configFile)) {
  stop("❌ start_config.csv not found. Aborting.")
}

repeat {
  Sys.sleep(1)
  raw_lines <- readLines(configFile, warn = FALSE)
  if (length(raw_lines) == 0) next
  
  # key=value Format parsen
  config <- setNames(
    sub(".*=", "", raw_lines),
    sub("=.*", "", raw_lines)
  )
  
  if (config[["actualscript"]] == "1") {
    log_message("▶ Running app_mode_selector...")
    output_path <- runApp(file.path(shiny_dir, "app_mode_selector.R"), port = shiny_port, launch.browser = TRUE)
    
    if (!is.null(output_path)) {
      config[["output"]] <- output_path
      config[["actualscript"]] <- "2"
      writeLines(paste0(names(config), "=", config), configFile)
      log_message(paste("ℹ️ Switching to app_main_dialog with output:", output_path))
    } else {
      log_message("ℹ️ User exited app_mode_selector without output.")
      break
    }
    
  } else if (config[["actualscript"]] == "2") {
    log_message("▶ Running app_main_dialog...")
    output_path <- config[["output"]]
    system(paste("Rscript", file.path(shiny_dir, "app_main_dialog.R"),
                 shQuote(output_path), shQuote(script_folder)), wait = FALSE)
    break
  } else {
    log_message("⚠️ Unknown actualscript value in config.")
    break
  }
}






config_path <- "D:/distribution_digitizer/start_config.csv"
lines <- readLines(config_path)
config <- setNames(sub(".*=", "", lines), sub("=.*", "", lines))
workingDir <- normalizePath(config["input"], winslash = "/", mustWork = TRUE)
outDir <- normalizePath(config["output"], winslash = "/", mustWork = TRUE)
setwd(workingDir)
runApp("shiny_apps/app_main_dialog.R", launch.browser = TRUE)
