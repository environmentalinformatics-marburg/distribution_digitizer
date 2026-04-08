# ============================================================
# Distribution Digitizer - Clean Pipeline Execution Script
# ============================================================
# Purpose:
# Executes the full processing pipeline step-by-step without GUI.
# Designed for testing, reproducibility, and batch processing.
# ============================================================

library(reticulate)
library(dplyr)
library(stringr)
library(readr)
library(parallel)
# ------------------------------------------------------------
# 🔧 USER SETTINGS
# ------------------------------------------------------------

workingDir <- "D:/distribution_digitizer"
outDir     <- "D:/test/output_2026-04-06_08-03-59/"

nMapTypes  <- 2


# ------------------------------------------------------------
# 🔗 Python Environment
# ------------------------------------------------------------

use_condaenv(
  "distribution_digitizer_env",
  required = TRUE,
  conda = "C:/ProgramData/miniconda3/condabin/conda.bat"
)

# ------------------------------------------------------------
# CONFIG READER
# ------------------------------------------------------------
read_config <- function(config_path) {
  
  df <- read.csv2(config_path, stringsAsFactors = FALSE)
  
  config <- as.list(df[1, ])
  
  # automatische Typ-Konvertierung
  convert_value <- function(x) {
    if (grepl("^[0-9.]+$", x)) return(as.numeric(x))
    if (tolower(x) %in% c("true", "false")) return(as.logical(x))
    return(x)
  }
  
  config <- lapply(config, convert_value)
  
  return(config)
}

config_path <- file.path(workingDir, "config", "config.csv")

config <- read_config(config_path)

time_step <- function(step_name, expr) {
  cat("\n====================================\n")
  cat("⏱ START:", step_name, "\n")
  start_time <- Sys.time()
  
  result <- eval(expr)
  
  end_time <- Sys.time()
  duration <- round(as.numeric(difftime(end_time, start_time, units = "secs")), 2)
  
  cat("⏱ END:", step_name, "\n")
  cat("⏱ Duration:", duration, "seconds\n")
  cat("====================================\n")
  
  return(duration)
}
pipeline_start <- Sys.time()
# ------------------------------------------------------------
# 1️⃣ MAP MATCHING
# ------------------------------------------------------------

t1 <- time_step("MAP MATCHING", quote({
  source_python(file.path(workingDir, "src/matching/map_matching.py"))
  
  main_template_matching(
    workingDir,
    outDir,
    threshold = 0.18,
    page_position = 1,
    matchingType = 1,
    pageSel = "ALL",
    nMapTypes = nMapTypes
  )
}))
# ------------------------------------------------------------
# 2️⃣ ALIGN MAPS
# ------------------------------------------------------------

t2 <- time_step("ALIGN MAPS", quote({
  source_python(file.path(workingDir, "src/matching/map_align.py"))
  
  align_images_directory(
    workingDir,
    outDir,
    nMapTypes = nMapTypes
  )
}))
# ------------------------------------------------------------
# 3️⃣ POINT MATCHING
# ------------------------------------------------------------

t3 <- time_step("POINT MATCHING", quote({
  source_python(file.path(workingDir, "src/matching/point_matching.py"))
  
  map_points_matching(
    workingDir = workingDir,
    outDir = outDir,
    threshold = 0.75,
    nMapTypes = nMapTypes
  )
}))

# ------------------------------------------------------------
# 4️⃣ POINT FILTERING
# ------------------------------------------------------------

t4 <- time_step("POINT FILTERING", quote({
  source_python(file.path(workingDir, "src/matching/point_filtering.py"))
  
  main_point_filtering(
    working_dir = workingDir,
    output_dir = outDir,
    kernel_size = 5,
    blur_radius = 9,
    nMapTypes = nMapTypes
  )
}))

# ------------------------------------------------------------
# 6️⃣ MASK CENTROIDS
# ------------------------------------------------------------

t5 <- time_step("MASK CENTROIDS", quote({
  source_python(file.path(workingDir, "src/masking/mask_centroids.py"))
  
  MainMaskCentroids(
    workingDir = workingDir,
    outDir = outDir,
    nMapTypes = 1
  )
}))
# ------------------------------------------------------------
# 7️⃣ READ SPECIES FROM MAP
# ------------------------------------------------------------

t6 <- time_step("READ SPECIES FROM MAP", quote({
  source(file.path(workingDir, "src/read_species/map_read_species.R"))
  
  read_legends(
    working_dir = workingDir,
    out_dir = outDir,
    nMapTypes = nMapTypes
  )
}))
# ------------------------------------------------------------
# 8️⃣ READ SPECIES FROM PAGES
# ------------------------------------------------------------
#previous_page_path: None
#next_page_path: None
#keyword_page_Specie: None
#keyword_top: None
#keyword_bottom: None
#middle: None
t7 <- time_step("READ SPECIES FROM PAGES", quote({
  source(file.path(workingDir, "src/read_species/page_read_species.R"))
  
  readPageSpeciesMulti(
    workingDir,
    outDir,
    keywordReadSpecies = "Range",
    keywordBefore = 0,
    keywordThen   = 2,
    middle        = 1,
    nMapTypes     = as.integer(nMapTypes)
  )
}))
#species = readPageSpecies("D:/distribution_digitizer/", "D:/test/output_2024-08-07_15-46-48/", "Range", 0, 2, 1)
# Call the function with specified arguments
# coordinates
# ------------------------------------------------------------
# 9️⃣ GEOREFERENCING + RECTIFYING
# ------------------------------------------------------------

t8 <- time_step("GEOREFERENCING + RECTIFYING", quote({
  source_python(file.path(workingDir, "src/georeferencing/mask_georeferencing.py"))
  source_python(file.path(workingDir, "src/polygonize/rectifying.py"))
  
  mainmaskgeoreferencingMasks_PF(
    workingDir,
    outDir,
    nMapTypes = as.integer(nMapTypes)
  )
  
  mainRectifying_PF(
    workingDir,
    outDir,
    nMapTypes = as.integer(nMapTypes)
  )
}))

# ------------------------------------------------------------
# 🔟 POLYGONIZE
# ------------------------------------------------------------

t9 <- time_step("POLYGONIZE", quote({
  source_python(file.path(workingDir, "src/polygonize/polygonize.py"))
  
  mainPolygonize_PF(
    workingDir,
    outDir,
    nMapTypes = as.integer(nMapTypes)
  )
}))
# ------------------------------------------------------------
# 1️⃣1️⃣ MERGE FINAL DATA
# ------------------------------------------------------------
t10 <- time_step("MERGE FINAL DATA", quote({
  source(file.path(workingDir, "src/spatial_view/merge_spatial_final_data.R"))
  
  merge_all_maps(
    outDir,
    nMapTypes = nMapTypes
  )
}))

pipeline_end <- Sys.time()

total_time <- round(as.numeric(difftime(pipeline_end, pipeline_start, units = "secs")), 2)

cat("\n====================================\n")
cat("📊 PIPELINE SUMMARY\n")
cat("====================================\n")

cat(sprintf("MAP MATCHING:            %6.2f sec\n", t1))
cat(sprintf("ALIGN:                   %6.2f sec\n", t2))
cat(sprintf("POINT MATCHING:          %6.2f sec\n", t3))
cat(sprintf("POINT FILTERING:         %6.2f sec\n", t4))
cat(sprintf("MASK CENTROIDS:          %6.2f sec\n", t5))
cat(sprintf("MAP SPECIES:             %6.2f sec\n", t6))
cat(sprintf("PAGE SPECIES:            %6.2f sec\n", t7))
cat(sprintf("GEOREFERENCING:          %6.2f sec\n", t8))
cat(sprintf("POLYGONIZE:              %6.2f sec\n", t9))
cat(sprintf("MERGE:                   %6.2f sec\n", t10))

cat("------------------------------------\n")
cat(sprintf("TOTAL TIME:              %6.2f sec\n", total_time))
cat("====================================\n")