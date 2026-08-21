# ============================================================
# File: run_pipeline.R
#
# Description:
# Runs the complete Distribution Digitizer processing pipeline.
#
# Arguments:
#   inputDir - directory containing the original book pages
#   config   - configuration list used for the current run
#
# Returns:
#   Path to the newly created full pipeline output directory.
# ============================================================


run_complete_pipeline <- function(
    inputDir,
    config
) {
  
  # ----------------------------------------------------------
  # Working directory
  # ----------------------------------------------------------
  
  workingDir <- config$workingDir
  
  if (is.null(workingDir) || !nzchar(workingDir)) {
    stop("workingDir is missing in pipeline configuration.")
  }
  
  
  # ----------------------------------------------------------
  # Input directory
  # ----------------------------------------------------------
  
  if (!dir.exists(inputDir)) {
    stop(
      "Pipeline input directory not found: ",
      inputDir
    )
  }
  
  # Use supplied input directory for this run only
  config$dataInputDir <- inputDir
  
  
  # ----------------------------------------------------------
  # Python environment
  # ----------------------------------------------------------
  
  reticulate::use_condaenv(
    "distribution_digitizer_env",
    required = TRUE,
    conda = "C:/ProgramData/miniconda3/condabin/conda.bat"
  )
  
  
  # ----------------------------------------------------------
  # Create new output directory
  # ----------------------------------------------------------
  
  book_title <- config$title
  
  book_title_safe <- gsub(
    "[^A-Za-z0-9_-]",
    "_",
    book_title
  )
  
  book_title_safe <- gsub(
    "_+",
    "_",
    book_title_safe
  )
  
  timestamp <- format(
    Sys.time(),
    "%Y-%m-%d_%H-%M-%S"
  )
  
  pipeline_out_dir <- file.path(
    dirname(config$dataOutputDir),
    paste0(
      "full_output_",
      book_title_safe,
      "_",
      timestamp
    )
  )
  
  dir.create(
    pipeline_out_dir,
    recursive = TRUE,
    showWarnings = FALSE
  )
  
  
  cat("\n=======================================\n")
  cat("FULL BOOK RUN\n")
  cat("=======================================\n")
  cat("Book:", config$title, "\n")
  cat("Input:", inputDir, "\n")
  cat("Output:", pipeline_out_dir, "\n")
  cat("Map types:", config$nMapTypes, "\n")
  cat("Species representation:",
      config$speciesRepresentation, "\n")
  cat("Species name source:",
      config$speciesNameSource, "\n")
  
  
  
  # ------------------------------------------------------------
  # 4. Python environment
  # ------------------------------------------------------------
  
  use_condaenv(
    "distribution_digitizer_env",
    required = TRUE,
    conda = "C:/ProgramData/miniconda3/condabin/conda.bat"
  )
  
  
  # ============================================================
  # STEP 1: MAP MATCHING
  # ============================================================
  
  cat("\n=======================================\n")
  cat("START MAP MATCHING\n")
  cat("=======================================\n")
  
  source_python(
    file.path(
      workingDir,
      "src",
      "matching",
      "map_matching.py"
    )
  )
  
  main_template_matching(
    workingDir       = workingDir,
    outDir           = pipeline_out_dir,
    threshold        = as.numeric(config$threshold_for_TM),
    page_position    = as.integer(config$sNumberPosition),
    matchingType     = as.integer(config$matchingType),
    pageSel          = "ALL",
    nMapTypes        = as.integer(config$nMapTypes)
  )
  
  cat("\n=======================================\n")
  cat("MAP MATCHING FINISHED\n")
  cat("Output:", pipeline_out_dir, "\n")
  cat("=======================================\n")
  
  # ============================================================
  # STEP 2: ALIGN MAPS
  # ============================================================
  
  cat("\n=======================================\n")
  cat("START ALIGN MAPS\n")
  cat("=======================================\n")
  
  source_python(
    file.path(
      workingDir,
      "src",
      "matching",
      "map_align.py"
    )
  )
  
  align_images_directory(
    workingDir,
    pipeline_out_dir,
    nMapTypes = as.integer(config$nMapTypes)
  )
  
  cat("\n=======================================\n")
  cat("ALIGN MAPS FINISHED\n")
  cat("=======================================\n")
  
  
  
  # ============================================================
  # STEP 3: CONTOUR MATCHING
  # ============================================================
  
  if (config$speciesRepresentation == "contour") {
    
    cat("\n=======================================\n")
    cat("START CONTOUR MATCHING\n")
    cat("=======================================\n")
    
    source_python(
      file.path(
        workingDir,
        "src",
        "matching",
        "species_area_detection.py"
      )
    )
    
    # ----------------------------------------------------------
    # Read contour colors from config
    #
    # Example:
    # 82,84,89|84,86,89
    # ----------------------------------------------------------
    color_strings <- strsplit(
      config$contourColors,
      "\\|"
    )[[1]]
    
    colors <- lapply(
      color_strings,
      function(x) {
        as.integer(
          strsplit(x, ",")[[1]]
        )
      }
    )
    
    cat("Colors:\n")
    print(colors)
    
    cat(
      "Tolerance:",
      config$contourColorTolerance,
      "\n"
    )
    
    cat(
      "Border margin:",
      config$contourBorderMargin,
      "\n"
    )
    
    # ----------------------------------------------------------
    # Process each map type
    # ----------------------------------------------------------
    for (map_type in seq_len(as.integer(config$nMapTypes))) {
      
      input_dir <- file.path(
        pipeline_out_dir,
        as.character(map_type),
        "maps",
        "align"
      )
      
      output_dir <- file.path(
        pipeline_out_dir,
        as.character(map_type),
        "masking_black",
        "pointFiltering"
      )
      
      os.makedirs <- NULL
      
      dir.create(
        output_dir,
        recursive = TRUE,
        showWarnings = FALSE
      )
      
      number_processed <- process_species_area_maps(
        input_dir     = input_dir,
        output_dir    = output_dir,
        colors        = colors,
        tolerance     = as.integer(config$contourColorTolerance),
        border_margin = as.integer(config$contourBorderMargin),
        debug         = TRUE
      )
      
      cat(
        "Map type", map_type, ":",
        number_processed,
        "maps processed\n"
      )
    }
    
    cat("\n=======================================\n")
    cat("CONTOUR MATCHING FINISHED\n")
    cat("=======================================\n")
  }
  
  
  # ============================================================
  # STEP 3: CONTOUR MATCHING
  # ============================================================
  
  if (config$speciesRepresentation == "contour") {
    
    cat("\n=======================================\n")
    cat("START CONTOUR MATCHING\n")
    cat("=======================================\n")
    
    source_python(
      file.path(
        workingDir,
        "src",
        "matching",
        "species_area_detection.py"
      )
    )
    
    # ----------------------------------------------------------
    # Read contour colors from config
    #
    # Example:
    # 82,84,89|84,86,89
    # ----------------------------------------------------------
    color_strings <- strsplit(
      config$contourColors,
      "\\|"
    )[[1]]
    
    colors <- lapply(
      color_strings,
      function(x) {
        as.integer(
          strsplit(x, ",")[[1]]
        )
      }
    )
    
    cat("Colors:\n")
    print(colors)
    
    cat(
      "Tolerance:",
      config$contourColorTolerance,
      "\n"
    )
    
    cat(
      "Border margin:",
      config$contourBorderMargin,
      "\n"
    )
    number_processed <- mainSpeciesAreaDetection(
      workingDir,
      pipeline_out_dir,
      colors,
      tolerance     = as.integer(config$contourColorTolerance),
      border_margin = as.integer(config$contourBorderMargin),
      nMapTypes     = as.integer(config$nMapTypes),
      debug         = TRUE
    )
    
    cat("\n=======================================\n")
    cat("CONTOUR MATCHING FINISHED\n")
    cat("=======================================\n")
  }
  
  # ============================================================
  # STEP 4: MASKING
  # ============================================================
  
  if (config$speciesRepresentation == "point") {
    
    cat("\n=======================================\n")
    cat("START MASKING\n")
    cat("=======================================\n")
    
    source_python(
      file.path(
        workingDir,
        "src",
        "masking",
        "masking.py"
      )
    )
    
    source_python(
      file.path(
        workingDir,
        "src",
        "masking",
        "creating_masks.py"
      )
    )
    
    mainGeomask(
      workingDir = workingDir,
      outDir = pipeline_out_dir,
      n = as.integer(config$morph_ellipse),
      nMapTypes = as.integer(config$nMapTypes)
    )
    
    mainGeomaskB(
      workingDir = workingDir,
      outDir = pipeline_out_dir,
      n = as.integer(config$morph_ellipse),
      nMapTypes = as.integer(config$nMapTypes)
    )
    
    cat("MASKING FINISHED\n")
    
  } else {
    
    cat("\n=======================================\n")
    cat("MASKING SKIPPED\n")
    cat("Species representation: contour\n")
    cat("Contour masks already available.\n")
    cat("=======================================\n")
  }
  
  
  # ============================================================
  # STEP 4: SPECIES PROCESSING
  # ============================================================
  
  cat("\n=======================================\n")
  cat("START SPECIES PROCESSING\n")
  cat("Species name source:", config$speciesNameSource, "\n")
  cat("=======================================\n")
  
  
  # ============================================================
  # A. SPECIES NAMES FROM MAP LEGEND
  # ============================================================
  
  if (config$speciesNameSource == "legend") {
    
    cat("\n--- LEGEND WORKFLOW ---\n")
    
    # ----------------------------------------------------------
    # 4.1 Read species names from map legends
    # ----------------------------------------------------------
    
    fname <- file.path(
      workingDir,
      "src",
      "species",
      "species_map_detection.R"
    )
    
    print("Reading species names from the map bottom R script:")
    print(fname)
    
    source(fname)
    
    legend_list <- strsplit(
      config$legendKeywords,
      ","
    )[[1]]
    
    legend_list <- trimws(legend_list)
    
    species <- read_legends(
      working_dir   = workingDir,
      out_dir       = pipeline_out_dir,
      legendKeywords = legend_list,
      nMapTypes     = as.integer(config$nMapTypes)
    )
    
    cat("\nSpecies names from legends processed.\n")
    
    
    # ----------------------------------------------------------
    # 4.2 Read complete species titles from pages
    # ----------------------------------------------------------
    
    tesseract_available <- checkTesseractWindows()
    
    if (!tesseract_available) {
      cat(
        "\n⚠️ OCR WARNING:\n",
        "Tesseract OCR was not found on this system.\n",
        "Species detection may be incomplete.\n\n"
      )
    }
    
    fname <- file.path(
      workingDir,
      "src",
      "species",
      "species_title_detection.R"
    )
    
    print(fname)
    source(fname)
    
    species <- readPageSpeciesTitleMulti(
      workingDir,
      pipeline_out_dir,
      ifelse(
        length(config$specieTitleKeyword) > 0 &&
          nzchar(config$specieTitleKeyword),
        config$specieTitleKeyword,
        "None"
      ),
      as.integer(config$specieTitleKeywordBefore),
      as.integer(config$specieTitleKeywordThen),
      as.integer(config$middle),
      config$legendKeywords,
      nMapTypes = as.integer(config$nMapTypes)
    )
    
    cat("\nSpecies titles processed.\n")
    # ============================================================
    # B. SPECIES NAMES DIRECTLY FROM PAGE REGIONS
    # ============================================================
    
    # ============================================================
    # B. SPECIES NAMES DIRECTLY FROM PAGE REGIONS
    # ============================================================
    
  } else if (config$speciesNameSource == "regions") {
    
    cat("\n--- REGIONS / TRAINING WORKFLOW ---\n")
    
    # ----------------------------------------------------------
    # Check training data
    # ----------------------------------------------------------
    
    training_file <- file.path(
      workingDir,
      "training",
      "species_title_training.csv"
    )
    
    if (!file.exists(training_file)) {
      stop(
        "Species training file not found: ",
        training_file
      )
    }
    
    cat("Training file:", training_file, "\n")
    
    
    # ----------------------------------------------------------
    # Load species processing
    # ----------------------------------------------------------
    
    species_script <- file.path(
      workingDir,
      "src",
      "species",
      "species_title_detection.R"
    )
    
    if (!file.exists(species_script)) {
      stop(
        "Species processing script not found: ",
        species_script
      )
    }
    
    source(species_script)
    
    
    # ----------------------------------------------------------
    # Process complete book
    # ----------------------------------------------------------
    
    readPageSpeciesDirectMulti(
      workingDir = workingDir,
      outDir     = pipeline_out_dir,
      nMapTypes  = as.integer(config$nMapTypes)
    )
    
    cat("\nSpecies titles processed from training regions.\n")
    
    
    # ============================================================
    # Unknown configuration
    # ============================================================
    
  } else {
    
    stop(
      "Unknown speciesNameSource in config: ",
      config$speciesNameSource
    )
  }
  
  
  cat("\n=======================================\n")
  cat("SPECIES PROCESSING FINISHED\n")
  cat("=======================================\n")
  
  
  # ============================================================
  # STEP 6: GEOREFERENCING + RECTIFYING
  # ============================================================
  
  cat("\n=======================================\n")
  cat("START GEOREFERENCING + RECTIFYING\n")
  cat("Species representation:",
      config$speciesRepresentation, "\n")
  cat("=======================================\n")
  
  
  # ------------------------------------------------------------
  # 6.1 GEOREFERENCING
  # Same processing for point and contour masks
  # ------------------------------------------------------------
  
  fname <- file.path(
    workingDir,
    "src",
    "georeferencing",
    "mask_georeferencing.py"
  )
  
  cat("Georeferencing script:\n")
  cat(fname, "\n")
  
  if (!file.exists(fname)) {
    stop("Georeferencing script not found: ", fname)
  }
  
  source_python(fname)
  
  mainmaskgeoreferencingMasks_PF(
    workingDir,
    pipeline_out_dir,
    nMapTypes = as.integer(config$nMapTypes)
  )
  
  cat("\nGeoreferencing finished.\n")
  
  
  # ------------------------------------------------------------
  # 6.2 RECTIFYING
  # ------------------------------------------------------------
  
  fname <- file.path(
    workingDir,
    "src",
    "polygonize",
    "rectifying.py"
  )
  
  cat("\nRectifying script:\n")
  cat(fname, "\n")
  
  if (!file.exists(fname)) {
    stop("Rectifying script not found: ", fname)
  }
  
  source_python(fname)
  
  
  # ------------------------------------------------------------
  # POINT DISTRIBUTION
  # ------------------------------------------------------------
  
  if (config$speciesRepresentation == "point") {
    
    cat("\nRectifying POINT distributions...\n")
    
    mainRectifying_PF(
      workingDir,
      pipeline_out_dir,
      nMapTypes = as.integer(config$nMapTypes)
    )
    
    
    # ------------------------------------------------------------
    # CONTOUR DISTRIBUTION
    # ------------------------------------------------------------
    
  } else if (config$speciesRepresentation == "contour") {
    
    cat("\nRectifying CONTOUR distributions...\n")
    
    mainRectifying_Contour(
      workingDir,
      pipeline_out_dir,
      nMapTypes = as.integer(config$nMapTypes)
    )
    
    
    # ------------------------------------------------------------
    # UNKNOWN REPRESENTATION
    # ------------------------------------------------------------
    
  } else {
    
    stop(
      "Unknown speciesRepresentation in config: ",
      config$speciesRepresentation
    )
  }
  
  
  cat("\n=======================================\n")
  cat("GEOREFERENCING + RECTIFYING FINISHED\n")
  cat("=======================================\n")
  
  
  # ============================================================
  # STEP 7: POLYGONIZE
  # ============================================================
  
  cat("\n=======================================\n")
  cat("START POLYGONIZE\n")
  cat(
    "Species representation:",
    config$speciesRepresentation,
    "\n"
  )
  cat("=======================================\n")
  
  
  # ------------------------------------------------------------
  # Load polygonize functions
  # ------------------------------------------------------------
  
  fname <- file.path(
    workingDir,
    "src",
    "polygonize",
    "polygonize.py"
  )
  
  cat("Polygonize script:\n")
  cat(fname, "\n")
  
  if (!file.exists(fname)) {
    stop("Polygonize script not found: ", fname)
  }
  
  source_python(fname)
  
  
  # ------------------------------------------------------------
  # POINT DISTRIBUTION
  # ------------------------------------------------------------
  
  if (config$speciesRepresentation == "point") {
    
    cat("\nPolygonizing POINT distributions...\n")
    
    mainPolygonize_PF(
      workingDir,
      pipeline_out_dir,
      nMapTypes = as.integer(config$nMapTypes)
    )
    
    
    # ------------------------------------------------------------
    # CONTOUR DISTRIBUTION
    # ------------------------------------------------------------
    
  } else if (config$speciesRepresentation == "contour") {
    
    cat("\nPolygonizing CONTOUR distributions...\n")
    
    mainPolygonize_Contour(
      workingDir,
      pipeline_out_dir,
      nMapTypes = as.integer(config$nMapTypes)
    )
    
    
    # ------------------------------------------------------------
    # UNKNOWN REPRESENTATION
    # ------------------------------------------------------------
    
  } else {
    
    stop(
      "Unknown speciesRepresentation in config: ",
      config$speciesRepresentation
    )
  }
  
  
  cat("\n=======================================\n")
  cat("POLYGONIZE FINISHED\n")
  cat("=======================================\n")
  
  # ============================================================
  # STEP 8: FINAL SPATIAL DATA INTEGRATION
  # ============================================================
  
  cat("\n=======================================\n")
  cat("START SPATIAL DATA INTEGRATION\n")
  cat(
    "Species representation:",
    config$speciesRepresentation,
    "\n"
  )
  cat("=======================================\n")
  
  
  # ------------------------------------------------------------
  # Load spatial data integration functions
  # ------------------------------------------------------------
  
  fname <- file.path(
    workingDir,
    "src",
    "spatial_view",
    "merge_spatial_final_data.R"
  )
  
  cat("Spatial data integration script:\n")
  cat(fname, "\n")
  
  if (!file.exists(fname)) {
    stop("Spatial data integration script not found: ", fname)
  }
  
  source(fname)
  
  
  # ------------------------------------------------------------
  # POINT DISTRIBUTION
  # ------------------------------------------------------------
  
  if (config$speciesRepresentation == "point") {
    
    cat("\nMerging POINT spatial data...\n")
    
    merge_all_maps(
      pipeline_out_dir,
      nMapTypes = as.integer(config$nMapTypes)
    )
    
    
    # ------------------------------------------------------------
    # CONTOUR DISTRIBUTION
    # ------------------------------------------------------------
    
  } else if (config$speciesRepresentation == "contour") {
    
    cat("\nMerging CONTOUR spatial data...\n")
    
    merge_all_contours(
      outDir = pipeline_out_dir,
      nMapTypes = as.integer(config$nMapTypes)
    )
    
    
    # ------------------------------------------------------------
    # UNKNOWN REPRESENTATION
    # ------------------------------------------------------------
    
  } else {
    
    stop(
      "Unknown speciesRepresentation in config: ",
      config$speciesRepresentation
    )
  }
  
  
  cat("\n=======================================\n")
  cat("SPATIAL DATA INTEGRATION FINISHED\n")
  cat("Final output:", pipeline_out_dir, "\n")
  cat("=======================================\n")
  
  
  # ============================================================
  # PIPELINE FINISHED
  # ============================================================
  
  cat("\n=======================================\n")
  cat("FULL BOOK PROCESSING FINISHED\n")
  cat("=======================================\n")
  cat("Book:", config$title, "\n")
  cat("Output:", pipeline_out_dir, "\n")
  cat("=======================================\n")
  
  
  # ----------------------------------------------------------
  # Return output directory
  # ----------------------------------------------------------
  
  return(pipeline_out_dir)
}
}
  