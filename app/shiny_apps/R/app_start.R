
# ============================================================
# Distribution Digitizer – Launch Script (dynamic paths)
# Author: Adapted for portable usage
# ============================================================

# -------------------------
# Helper: Get base directory dynamically
# -------------------------
get_base_dir <- function() {
  # 1) From environment variable (set by batch)
  env_dir <- Sys.getenv("APP_WORKING_DIR", unset = "")
  if (nzchar(env_dir)) return(normalizePath(env_dir, winslash = "/", mustWork = TRUE))
  
  # 2) From script path if run with Rscript
  all_args <- commandArgs(trailingOnly = FALSE)
  file_arg  <- "--file="
  file_path <- sub(file_arg, "", all_args[grepl(file_arg, all_args)])
  if (length(file_path) > 0) {
    return(normalizePath(dirname(file_path[1]), winslash = "/", mustWork = TRUE))
  }
  
  # 3) Fallback: current working directory
  return(normalizePath(getwd(), winslash = "/", mustWork = TRUE))
}

base_dir <- get_base_dir()
setwd(base_dir)

# Define all paths relative to base_dir
config_dir        <- file.path(base_dir, "config")
config_csv_path   <- file.path(config_dir, "config.csv")
start_config_path <- file.path(base_dir, "start_config.csv")
shiny_dir         <- file.path(base_dir, "shiny_apps")

# --------------------------------------------------------------------------------------------------
# OPTIONAL: Manual installation of Python packages (use only for initial setup if needed)
# --------------------------------------------------------------------------------------------------
# py_install(packages = "opencv", pip = FALSE)
# py_install(packages = "pillow", pip = FALSE)
# py_install(packages = "tesseract", pip = FALSE)
# py_install(packages = "pandas", pip = FALSE)
# py_install(packages = "GDAL", pip = FALSE)
# py_install(packages = "imutils", pip = FALSE)
# py_install(packages = "rasterio", pip = FALSE)
# py_install(packages = "geopandas", pip = FALSE)

# --------------------------------------------------------------------------------------------------
# 1. Get Python interpreter from args or fallback
# --------------------------------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
python_path <- if (length(args) >= 1 && file.exists(args[1])) args[1] else Sys.which("python")

if (!file.exists(python_path)) {
  stop("❌ Python path not found. Please check your batch file or installation.")
}

# --------------------------------------------------------------------------------------------------
# 2. Update config.csv with new Tesseract path if provided
# --------------------------------------------------------------------------------------------------
if (file.exists(config_csv_path)) {
  cfg <- read.csv(config_csv_path, sep = ";", stringsAsFactors = FALSE)
  if ("tesserAct" %in% names(cfg) && length(args) >= 3) {
    tess_path <- normalizePath(args[3], winslash = "/", mustWork = TRUE)
    cfg$tesserAct[1] <- tess_path
    write.table(cfg, file = config_csv_path, sep = ";", row.names = FALSE, quote = FALSE)
    cat("✅ Updated 'tesserAct' path in config.csv.
")
  }
} else {
  warning("⚠️ config.csv not found in /config directory.")
}

# --------------------------------------------------------------------------------------------------
# 3. Ensure start_config.csv exists and update 'input'
# --------------------------------------------------------------------------------------------------
if (file.exists(start_config_path)) {
  lines  <- readLines(start_config_path, warn = FALSE)
  kv     <- setNames(sub(".*=", "", lines), sub("=.*", "", lines))
  kv["input"] <- base_dir
  writeLines(paste0(names(kv), "=", kv), start_config_path)
  cat("✅ Set 'input' in start_config.csv to:", base_dir, "\n")
} else {
  warning("⚠️ start_config.csv not found. Cannot update 'input'.")
}

# --------------------------------------------------------------------------------------------------
# 4. Load R packages
# --------------------------------------------------------------------------------------------------
required_r_packages <- c(
  "shiny", "shinydashboard", "magick", "grid", "shinyFiles",
  "reticulate", "tesseract", "leaflet", "raster", "sf",
  "shinyalert", "shinyjs", "rdrop2"
)
missing_r_packages <- required_r_packages[!(required_r_packages %in% installed.packages()[, "Package"])]
if (length(missing_r_packages) > 0) {
  stop(paste("❌ Missing R packages:", paste(missing_r_packages, collapse = ", ")))
}
invisible(lapply(required_r_packages, require, character.only = TRUE))

# --------------------------------------------------------------------------------------------------
# 5. Configure Python and check modules
# --------------------------------------------------------------------------------------------------
library(reticulate)
use_python(python_path, required = TRUE)
cat("\n✅ Python interpreter:\n")
print(py_config())

required_py_modules <- c("cv2", "PIL", "pandas", "osgeo", "imutils", "geopandas",
                         "functools", "string", "os", "glob", "shutil")
missing <- required_py_modules[!sapply(required_py_modules, py_module_available)]
if (length(missing) > 0) {
  stop(paste("❌ Missing Python modules:", paste(missing, collapse = ", ")))
}

# --------------------------------------------------------------------------------------------------
# 6. Launch Shiny application
# --------------------------------------------------------------------------------------------------
# ---------------------------
# 6. Launch Shiny application
# ---------------------------
required_files <- c("app_mode_selector.R", "app_write_config.R", "app_main_dialog.R")
missing <- required_files[!file.exists(file.path(shiny_dir, required_files))]
if (length(missing) > 0) {
  stop(paste("❌ Missing required files in 'shiny_apps':", paste(missing, collapse = ", ")))
}

Sys.setenv(APP_WORKING_DIR = base_dir)

# Schritt 1: Mode-Selector starten und Output-Ordner erhalten
selected_output_path <- runApp(
  file.path(shiny_dir, "app_mode_selector.R"),
  port = 8888,
  launch.browser = TRUE
)

# Schritt 2: Wenn Auswahl getroffen wurde → start_config.csv aktualisieren
if (!is.null(selected_output_path) && dir.exists(selected_output_path)) {
  
  start_config_path <- file.path(base_dir, "start_config.csv")
  
  if (file.exists(start_config_path)) {
    lines <- readLines(start_config_path, warn = FALSE)
    config_map <- setNames(sub(".*=", "", lines), sub("=.*", "", lines))
  } else {
    config_map <- c(input = base_dir, output = selected_output_path, actualscript = "2")
  }
  
  config_map["input"] <- base_dir
  config_map["output"] <- selected_output_path
  config_map["actualscript"] <- "2"
  
  writeLines(paste0(names(config_map), "=", config_map), start_config_path)
  cat("✅ Updated start_config.csv\n")
  

  
} else {
  cat("❌ No output folder selected or folder does not exist.\n")
}

install.packages("shiny")
install.packages("shinydashboard")
install.packages("shinyjs")
install.packages("DT", dependencies = TRUE)
install.packages("remotes")
install.packages("rdrop2", dependencies = TRUE)
remotes::install_github("karthik/rdrop2")

install.packages("RInno")
remotes::install_github("ficonsulting/RInno")
install.packages("shinyalert")
#einfach 3 geben
install.packages(c("rmarkdown", "tinytex"))
tinytex::install_tinytex()

options(shiny.autoreload = TRUE)
shiny::runApp("D:/distribution_digitizer/app/app.R")
options(shiny.launch.browser = TRUE)
shiny::runApp()
library(RInno)
create_app(
  app_name = "DistributionDigitizer",
  app_dir  = "D:/distribution_digitizer"
)
tinytex::install_tinytex(force = TRUE)
install.packages("devtools")
library(devtools)
install_github("shinyworks/shinydesktop", dependencies = TRUE)

setwd("D:/distribution_digitizer/app")
list.files("www", recursive=TRUE, full.names=TRUE)
list.files(".", pattern="\\.Rprofile$", recursive=TRUE, full.names=TRUE)
list.files(".", pattern="global.R", recursive=TRUE, full.names=TRUE)

grep("addResourcePath", list.files(".", recursive = TRUE, full.names = TRUE), value = TRUE)
grep("www/data", list.files(".", recursive = TRUE, full.names = TRUE), value = TRUE)
grep("data/", list.files(".", recursive = TRUE, full.names = TRUE), value = TRUE)
setwd("D:/distribution_digitizer/app")
grep("addResourcePath", list.files(".", recursive = TRUE, full.names = TRUE), value = TRUE)
grep("www/data", list.files(".", recursive = TRUE, full.names = TRUE), value = TRUE)
grep("data/", list.files(".", recursive = TRUE, full.names = TRUE), value = TRUE)
setwd("D:/distribution_digitizer")
#system("grep -Rni \"prepareImage\" .")
system("grep -Rni \"prepareImage\" .", intern = TRUE)
system("findstr /S /I /N View *", intern = TRUE)


setwd("D:/distribution_digitizer")
options(shiny.port = 8888, shiny.host = "127.0.0.1")
shiny::runApp("app", launch.browser = TRUE, display.mode = "normal", test.mode = FALSE)
#rmarkdown::render("d:/distribution_digitizer/README.Rmd")
