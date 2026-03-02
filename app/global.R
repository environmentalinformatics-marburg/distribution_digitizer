###############################################################
# global.R – Distribution Digitizer
# Wird automatisch vor ui.R und server.R geladen
###############################################################

# ---- WORKING DIRECTORY -------------------------------------

# app/-Ordner (wo global.R liegt)
appDir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)

# Hauptprojekt-Verzeichnis = eine Ebene höher
workingDir <- normalizePath(
  file.path(appDir, ".."),
  winslash = "/",
  mustWork = TRUE
)

# global clock (dummy before server starts)
current_time <- function() Sys.time()

message("GLOBAL:: workingDir = ", workingDir)

# global reactive values
outDir <- shiny::reactiveVal(NULL)

# ---- PYTHON / RETICULATE SETUP -----------------------------

# ---- PYTHON / RETICULATE SETUP -----------------------------

Sys.unsetenv("RETICULATE_PYTHON")
Sys.unsetenv("RETICULATE_PYTHON_ENV")

library(reticulate)

use_condaenv(
  "distribution_digitizer_env",
  conda = "C:/ProgramData/miniconda3/Scripts/conda.exe",
  required = TRUE
)

message("GLOBAL:: Python initialized successfully")

# conda_path <- "C:/ProgramData/miniconda3/Scripts/conda.exe"
# conda_env_name <- "distribution_digitizer_env"
# 
# # Prüfen ob conda existiert
# if (!file.exists(conda_path)) {
#   stop("Conda not found at: ", conda_path)
# }
# 
# # Verfügbare Environments abfragen
# available_envs <- tryCatch(
#   reticulate::conda_list(conda = conda_path)$name,
#   error = function(e) NULL
# )
# 
# if (is.null(available_envs) || !(conda_env_name %in% available_envs)) {
#   stop(
#     paste0(
#       "Python environment '", conda_env_name,
#       "' not found.\n",
#       "Please create it first using:\n",
#       "conda create -n distribution_digitizer_env python=3.11\n",
#       "conda activate distribution_digitizer_env\n",
#       "pip install opencv-python numpy gdal"
#     )
#   )
# }
# 
# # Environment aktivieren
# use_condaenv(
#   conda_env_name,
#   conda = conda_path,
#   required = TRUE
# )
# 
# # Prüfen ob wichtige Module vorhanden sind
# required_modules <- c("cv2", "numpy", "osgeo")
# 
# missing_modules <- required_modules[
#   !sapply(required_modules, py_module_available)
# ]
# 
# if (length(missing_modules) > 0) {
#   stop(
#     paste(
#       "Missing Python modules:",
#       paste(missing_modules, collapse = ", "),
#       "\nInstall inside the conda environment using:",
#       "\npip install opencv-python numpy gdal"
#     )
#   )
# }
# 
# message("GLOBAL:: Python environment loaded successfully.")
# 
# ---- CONFIG DIRECTORY --------------------------------------

configDir <- normalizePath(
  file.path(workingDir, "config"),
  winslash = "/",
  mustWork = FALSE
)

if (!dir.exists(configDir)) {
  dir.create(configDir, recursive = TRUE, showWarnings = FALSE)
}

message("GLOBAL:: configDir = ", configDir)

# ---- FUNCTION LOADER ---------------------------------------

load_folder <- function(path) {
  if (dir.exists(path)) {
    files <- list.files(path, pattern = "\\.R$", full.names = TRUE)
    sapply(files, source)
  }
}

load_folder(file.path(workingDir, "app", "functions"))

# ---- CONFIG LOADER -----------------------------------------

load_key_value_config <- function(path) {
  if (!file.exists(path)) {
    warning("Config file missing: ", path)
    return(list())
  }

  df <- read.csv2(path, header = FALSE, sep = ";", stringsAsFactors = FALSE)
  if (ncol(df) >= 2) colnames(df) <- c("key", "value")
  as.list(setNames(df$value, df$key))
}

# Globale config.csv laden
config <- load_key_value_config(file.path(configDir, "config.csv"))

# Anzahl der Map-Typen aus config
numMapTypes <- as.integer(config$nMapTypes %||% 1)

# Dropdown-Liste
mapTypes <- as.character(seq_len(numMapTypes))
# 
# # ---- SHINYFIELDS LOADER ------------------------------------
# 
# load_shinyfields <- function(name) {
#   file <- file.path(configDir, name)
#   if (!file.exists(file)) stop("Missing config file: ", file)
#   read.csv(file, header = TRUE, sep = ";", stringsAsFactors = FALSE)
# }
# 
# shinyfields1   <- load_shinyfields("shinyfields_create_templates.csv")
# shinyfields2   <- load_shinyfields("shinyfields_detect_maps.csv")
# shinyfields3   <- load_shinyfields("shinyfields_detect_points.csv")
# shinyfields4   <- load_shinyfields("shinyfields_detect_points_using_filtering.csv")
# shinyfields4.1 <- load_shinyfields("shinyfields_detect_points_using_circle_detection.csv")
# shinyfields5   <- load_shinyfields("shinyfields_masking.csv")
# shinyfields5.1 <- load_shinyfields("shinyfields_mask_centroids.csv")
# shinyfields6   <- load_shinyfields("shinyfields_georeferensing.csv")
# shinyfields7   <- load_shinyfields("shinyfields_polygonize.csv")
# shinyfields8   <- load_shinyfields("shinyfields_georef_coords_from_csv_file.csv")
# 
# # ---- GLOBAL PATHS USED IN SERVER.R --------------------------
# 
# inputDir  <- file.path(workingDir, "data/input/")
# dataDir   <- file.path(workingDir, "data/")
# tempImage <- "temp.png"
# 
# scale     <- 20
# rescale   <- 100 / scale
# 
# ###############################################################
# # ENDE global.R
# ###############################################################