
####################
# FUNCTIONS       #----------------------------------------------------------------------#
####################

# ------------------------------------------------------------
# Function: checkTesseractWindows
# ------------------------------------------------------------
# Purpose:
# Checks whether a valid Tesseract OCR installation is available
# on a Windows system by testing common installation paths.
#
# Description:
# This function verifies if the Tesseract executable exists in
# standard directories ("Program Files" and "Program Files (x86)").
# It is used as a prerequisite check before OCR-based processing.
#
# Returns:
# Logical value (TRUE/FALSE) indicating whether Tesseract is available.
# ------------------------------------------------------------
checkTesseractWindows <- function() {
  candidates <- c(
    "C:/Program Files/Tesseract-OCR/tesseract.exe",
    "C:/Program Files (x86)/Tesseract-OCR/tesseract.exe"
  )
  any(file.exists(candidates))
}


# ------------------------------------------------------------
# Function: manageProcessFlow
# ------------------------------------------------------------
# Purpose:
# Central control function that manages and executes the full
# processing pipeline of the Distribution Digitizer.
#
# Description:
# This function orchestrates all processing steps depending on
# the selected workflow stage ("processing"). It dynamically
# triggers Python and R scripts using reticulate and source(),
# and ensures correct execution order across multiple map types.
#
# The function integrates:
# - Image processing (template matching, filtering, masking)
# - OCR-based species extraction
# - Geospatial processing (georeferencing, rectifying, polygonization)
# - Spatial data integration and visualization
#
# Key Features:
# - Modular execution of pipeline steps (if-block per stage)
# - Dynamic handling of multiple map types (nMapTypes)
# - Integration of Python scripts via source_python()
# - Error handling using tryCatch()
# - User feedback via Shiny alerts
#
# Parameters:
# - processing: Character string defining the current pipeline step
# - allertText1 / allertText2: Messages for UI notifications
# - input: Shiny input object (user-defined parameters)
# - session: Shiny session object
# - current_out_dir: Output directory for all generated results
#
# Notes:
# - This function represents the core workflow engine of the software
# - All major modules (matching, OCR, georeferencing, polygonize)
#   are triggered from here
# - Designed for extensibility and integration of additional steps
#
# Returns:
# No explicit return value; results are written to output directories
# and communicated via Shiny UI
# ------------------------------------------------------------
manageProcessFlow <- function(processing, allertText1, allertText2, input, session, current_out_dir, contour_colors) {

  print(paste("DEBUG nMapTypes =", input$nMapTypes))
  print(paste("DEBUG current_out_dir =", current_out_dir))
  #current_out_dir <- outDir()
  # END IMPORTANT
  
  message=""
  message <- paste0("The process ", allertText1, " is started on: ")
  shinyalert(
    text = paste(message, format(Sys.time(), "%H:%M:%S")), 
    type = "info", 
    showConfirmButton = FALSE, 
    closeOnEsc = TRUE,
    closeOnClickOutside = FALSE, 
    animation = TRUE
  )
  
  #  MATCHING
  # ------------------------------------------------------------
  # Step: Map Matching (Template Matching on Book Pages)
  # ------------------------------------------------------------
  # Purpose:
  # Detects map regions within scanned book pages using template matching.
  #
  # Description:
  # This step applies OpenCV-based template matching to identify map
  # locations on full page images. Detected regions are stored and
  # used for further processing (alignment and extraction).
  #
  # Output:
  # - Detected map regions (maps/matching)
  # - Visualization PNGs for validation
  # ------------------------------------------------------------
  if(processing == "mapMatching"){
    tryCatch({
      
      fname <- paste0(
        workingDir,
        "/",
        "src/matching/map_matching.py"
      )
      
      print(workingDir)
      print("The processing template matching python script:")
      print(fname)
      
      source_python(fname)
      
      print("Threshold:")
      print(input$threshold_for_TM)
      
      
      # ------------------------------------------------------------
      # Page selection
      # In Shiny, ALL is limited to the first 10 pages for testing.
      # Full-book processing is performed by the pipeline script.
      # ------------------------------------------------------------
      
      page_selection <- as.character(input$range_matching)
      
      if (toupper(trimws(page_selection)) == "ALL") {
        page_selection <- "1-10"
        cat("\nTEST MODE: ALL limited to first 10 pages.\n")
      } else if (grepl("^[0-9]+-[0-9]+$", page_selection)) {
        
        range_parts <- as.integer(
          strsplit(page_selection, "-")[[1]]
        )
        
        start_page <- range_parts[1]
        end_page   <- range_parts[2]
        
        # Maximum 10 pages
        if ((end_page - start_page + 1) > 10) {
          end_page <- start_page + 9
          
          page_selection <- paste0(
            start_page,
            "-",
            end_page
          )
        }
      }
      
      cat("Pages used for test:", page_selection, "\n")
      
      # ------------------------------------------------------------
      # Template matching
      # ------------------------------------------------------------
      
      main_template_matching(
        workingDir,
        current_out_dir,
        input$threshold_for_TM,
        input$sNumberPosition,
        input$matchingType,
        page_selection,
        nMapTypes = as.integer(input$nMapTypes)
      )
      
      
      # ------------------------------------------------------------
      # Prepare results for Shiny
      # ------------------------------------------------------------
      
      message <- computeNumberResult(
        base_output_dir = current_out_dir,
        working_dir = workingDir,
        nMapTypes = as.integer(input$nMapTypes),
        subfolder = "maps/matching",
        png_subdir = "output/matching_png"
      )
      
    }, error = function(e) {
      
      cat("An error occurred during mapMatching processing:\n")
      print(e)
    })
  }
  
  # ALIGN
  # ------------------------------------------------------------
  # Step: Map Alignment
  # ------------------------------------------------------------
  # Purpose:
  # Aligns detected map regions to a consistent reference position.
  #
  # Description:
  # This step normalizes map positioning (primarily along the Y-axis)
  # to ensure consistent downstream processing such as symbol detection
  # and OCR-based analysis.
  #
  # Output:
  # - Aligned map images (maps/align)
  # - Visualization PNGs for quality control
  # ------------------------------------------------------------
  if(processing == "alignMaps" ){
    tryCatch({
      
      # align
      fname=paste0(workingDir, "/", "src/matching/map_align.py")
      print("Processing align python script:")
      print(fname)
      source_python(fname)
      align_images_directory(
        workingDir,
        current_out_dir,
        nMapTypes = as.integer(input$nMapTypes)
      )
      
      message <- computeNumberResult(
        base_output_dir = current_out_dir,
        working_dir = workingDir,
        nMapTypes = as.integer(input$nMapTypes),
        subfolder = "maps/align",
        png_subdir = "output/align_png"
      )
      cat("\nSuccessfully executed align")
    }, error = function(e) {
      cat("An error occurred during alignMaps processing:\n")
      print(e)
    })
  }
  
  
  # ------------------------------------------------------------
  # Step: Point Matching (Symbol Detection)
  # ------------------------------------------------------------
  # Purpose:
  # Detects map symbols (e.g. colored points) using template matching.
  #
  # Description:
  # Symbol templates are matched across aligned map images using
  # normalized cross-correlation. Candidate point locations are
  # identified and stored for further filtering.
  #
  # Output:
  # - Raw detected points (maps/pointMatching)
  # - Coordinates stored in CSV
  # ------------------------------------------------------------
  if(processing == "pointMatching") {
    tryCatch({
      # Processing points matching
      fname <- paste0(workingDir, "/", "src/matching/point_matching.py")
      print("Processing point matching Python script:")
      print(fname)
      source_python(fname)
      
      # Pass nMapTypes to the Python function
      map_points_matching(
        workingDir = workingDir,
        outDir = current_out_dir,
        threshold = input$threshold_for_PM,
        nMapTypes = as.integer(input$nMapTypes)  # <-- Hinzugefügt
      )
      
      message <- computeNumberResult(
        base_output_dir = current_out_dir,
        working_dir = workingDir,
        nMapTypes = as.integer(input$nMapTypes),
        subfolder = "maps/pointMatching",
        png_subdir = "output/pointMatching_png"
      )
    }, error = function(e) {
      cat("An error occurred during pointMatching processing:\n")
      print(e)
    })
  }
  
  # ------------------------------------------------------------
  # Step: Point Filtering
  # ------------------------------------------------------------
  # Purpose:
  # Refines detected symbol points by removing noise and false positives.
  #
  # Description:
  # Morphological operations and spatial filtering are applied to
  # eliminate duplicate detections, merged contours, and irrelevant
  # artifacts. This step ensures clean and reliable point datasets.
  #
  # Output:
  # - Filtered points (maps/pointFiltering)
  # - Cleaned coordinate datasets
  # ------------------------------------------------------------
  if(processing == "pointFiltering") {
    tryCatch({
      
      fname=paste0(workingDir, "/", "src/matching/point_filtering.py")
      #fname2 = paste0(workingDir, "/", "src/matching/coords_to_csv.py")
      print(" Process pixel filtering  python script:")
      print(fname)
      source_python(fname)
      #source_python(fname2)
      main_point_filtering(
        working_dir = workingDir,
        output_dir = current_out_dir,
        kernel_size = 5, #input$filterK,
        blur_radius = 9, #input$filterG,
        nMapTypes = 2#as.integer(input$nMapTypes)
      )
      
      cat("\nSuccessfully executed")
      message <- computeNumberResult(
        base_output_dir = current_out_dir,
        working_dir = workingDir,
        nMapTypes = as.integer(input$nMapTypes),
        subfolder = "maps/pointFiltering",
        png_subdir = "output/pointFiltering_png"
      )
    }, error = function(e) {
      cat("An error occurred during pointFiltering processing:\n")
      print(e)
    })
  }
  

  # ------------------------------------------------------------
  # Step: Species Area Detection (Contour Matching)
  # ------------------------------------------------------------
  if (processing == "contourMatching") {
    tryCatch({
      
      # ----------------------------------------------------------
      # Load Python contour processing
      # ----------------------------------------------------------
      fname <- file.path(
        workingDir,
        "src",
        "matching",
        "species_area_detection.py"
      )
      
      print("Processing species area detection Python script:")
      print(fname)
      
      source_python(fname)
      
      # ----------------------------------------------------------
      # Check selected colors
      # ----------------------------------------------------------
      if (is.null(contour_colors) || nrow(contour_colors) == 0) {
        stop("No contour colors available.")
      }
      
      # ----------------------------------------------------------
      # Convert R RGB data.frame to Python-friendly list
      # ----------------------------------------------------------
      colors_python <- lapply(
        seq_len(nrow(contour_colors)),
        function(i) {
          as.integer(c(
            contour_colors$red[i],
            contour_colors$green[i],
            contour_colors$blue[i]
          ))
        }
      )
      
      # ----------------------------------------------------------
      # Debug information
      # ----------------------------------------------------------
      cat("\n=== PROCESS ALL SPECIES AREA MAPS ===\n")
      cat("Output:", current_out_dir, "\n")
      cat("Map types:", input$nMapTypes, "\n")
      cat("Tolerance:", input$contourColorTolerance, "\n")
      cat("Border margin:", input$contourBorderMargin, "\n")
      cat("Colors:\n")
      print(contour_colors)
      
      # ----------------------------------------------------------
      # Process all map types and all aligned contour maps
      # ----------------------------------------------------------
      number_processed <- mainSpeciesAreaDetection(
        workingDir,
        current_out_dir,
        colors_python,
        tolerance     = as.integer(input$contourColorTolerance),
        border_margin = as.integer(input$contourBorderMargin),
        nMapTypes     = as.integer(input$nMapTypes),
        debug         = TRUE
      )
      
      # ----------------------------------------------------------
      # Create PNG versions for Shiny result display
      # ----------------------------------------------------------
      message <- computeNumberResult(
        base_output_dir = current_out_dir,
        working_dir     = workingDir,
        nMapTypes       = as.integer(input$nMapTypes),
        subfolder       = file.path(
          "masking_black",
          "pointFiltering"
        ),
        png_subdir      = "output/contourMatching_png"
      )
      
      cat("Total processed maps:", number_processed, "\n")
      cat("=======================================\n")
      
    }, error = function(e) {
      
      cat("An error occurred during contourMatching processing:\n")
      print(e)
      
    })
  }
  # ------------------------------------------------------------
  # Step: Masking (Image Cleaning)
  # ------------------------------------------------------------
  # Purpose:
  # Removes irrelevant map regions to improve OCR and detection accuracy.
  #
  # Description:
  # Two masking strategies are applied:
  # - Standard masking to isolate relevant regions
  # - Black masking to suppress background noise
  #
  # These masks are used to enhance OCR performance and symbol detection.
  #
  # Output:
  # - Masked images (masking / masking_black)
  # - PNG previews for validation
  # ------------------------------------------------------------
  if(processing == "masking") {
    tryCatch({
      
      # --- 1. Masking (normale) ---
      fname <- paste0(workingDir, "/", "src/masking/masking.py")
      print("Processing normal masking Python script:")
      print(fname)
      source_python(fname)
      
      # --- 2. Masking (schwarz) ---
      fname2 <- paste0(workingDir, "/", "src/masking/creating_masks.py")
      print("Processing black masking Python script:")
      print(fname2)
      source_python(fname2)
      
      # --- 3. Für jeden Map-Typ (1, 2, ...) ---
      # mainGeomask und mainGeomaskB werden in den Python-Dateien mit nMapTypes aufgerufen
      mainGeomask(
        workingDir = workingDir,
        outDir = current_out_dir,
        n = input$morph_ellipse,
        nMapTypes = as.integer(input$nMapTypes)
      )
      
      mainGeomaskB(
        workingDir = workingDir,
        outDir = current_out_dir,
        n = input$morph_ellipse,
        nMapTypes = as.integer(input$nMapTypes)
      )
      
      # --- 4. Zähle Masken und kopiere PNGs ---
      message <- computeNumberResult(
        base_output_dir = current_out_dir,
        working_dir = workingDir,
        nMapTypes = as.integer(input$nMapTypes),
        subfolder = "masking",
        png_subdir = "output/masking_png"
      )
      
      # --- 5. Black Masking ---
      message_black <- computeNumberResult(
        base_output_dir = current_out_dir,
        working_dir = workingDir,
        nMapTypes = as.integer(input$nMapTypes),
        subfolder = "masking_black",
        png_subdir = "output/masking_black_png"
      )
      
    }, error = function(e) {
      cat("An error occurred during masking processing:\n")
      print(e)
    })
  }
  
  # ------------------------------------------------------------
  # Step: Masking Centroids
  # ------------------------------------------------------------
  # Purpose:
  # Applies masking specifically to centroid-based detections.
  #
  # Description:
  # This step isolates detected centroid regions after point filtering
  # and prepares them for spatial processing and polygonization.
  #
  # Output:
  # - Masked centroid images
  # - Refined centroid-based datasets
  # ------------------------------------------------------------
  if(processing == "maskingCentroids"){
    tryCatch({
      
      # --- 1. Masking Centroids ---
      fname <- paste0(workingDir, "/", "src/masking/mask_centroids.py")
      print("Processing masking centroids Python script:")
      print(fname)
      source_python(fname)
      
      # --- 2. Für jeden Map-Typ (1, 2, ...) ---
      MainMaskCentroids(
        workingDir = workingDir,
        outDir = current_out_dir,
        nMapTypes = as.integer(input$nMapTypes)
      )
      
      # --- 3. Zähle Masken und kopiere PNGs ---
      message <- computeNumberResult(
        base_output_dir = current_out_dir,
        working_dir = workingDir,
        nMapTypes = as.integer(input$nMapTypes),
        subfolder = "masking_black/pointFiltering",
        png_subdir = "output/maskingCentroids_png"
      )
      
    }, error = function(e) {
      cat("An error occurred during masking Centroids processing:\n")
      print(e)
    })
  }
  
  # ------------------------------------------------------------
  # Step: Species Extraction from Map Legends
  # ------------------------------------------------------------
  # Purpose:
  # Extracts species names directly from map legends.
  #
  # Description:
  # This step analyzes legend areas of maps using OCR and template
  # matching. Species names are linked to symbol colors and stored
  # in structured format.
  #
  # Output:
  # - Species annotations on maps (maps/readSpecies)
  # - Updated coordinate datasets with species information
  # ------------------------------------------------------------
  if(processing == "mapReadSpecies"){ # alter Workflow: Species aus Legende
    tryCatch({
      
      # --- 1. Read species ---
      fname <- paste0(workingDir, "/", "src/species/species_map_detection.R")
      print("Reading species names from the map bottom R script:")
      print(fname)
      source(fname)
      
      # --- 2. Für jeden Map-Typ (1, 2, ...) ---
      legend_list <- strsplit(config$legendKeywords, ",")[[1]]
      legend_list <- trimws(legend_list)
      
      species <- read_legends(
        working_dir = workingDir,
        out_dir = current_out_dir,
        legendKeywords = legend_list,
        nMapTypes = as.integer(input$nMapTypes)
      )
      
      cat("\nSuccessfully executed")
      
      # --- 3. Zähle Bilder und kopiere PNGs ---
      message <- computeNumberResult(
        base_output_dir = current_out_dir,
        working_dir = workingDir,
        nMapTypes = as.integer(input$nMapTypes),
        subfolder = "maps/readSpecies",
        png_subdir = "output/readSpecies_png"
      )
      
    }, error = function(e) {
      cat("An error occurred during species_map_processing:\n")
      print(e)
    })
  }
  
  # ------------------------------------------------------------
  # Step: Species Extraction from Book Pages
  # ------------------------------------------------------------
  # Purpose:
  # Extracts species titles and contextual information from book text.
  #
  # Description:
  # OCR is applied to full book pages to identify species names and
  # associated descriptions. Keyword-based filtering and multi-page
  # fallback strategies are used to improve robustness.
  #
  # Output:
  # - pageSpeciesData.csv (species + titles)
  # - Enriched species information for integration
  # ------------------------------------------------------------
  if (processing == "pageReadRpecies") { # alter Workflow: vollständige Titel zu den
    # bereits aus der Legende erkannten Species
    
    tryCatch({
      
      # 🔍 OCR-Status einmal prüfen
      tesseract_available <- checkTesseractWindows()
      
      if (!tesseract_available) {
        cat(
          "\n⚠️  OCR WARNING:\n",
          "   Tesseract OCR was not found on this system.\n",
          "   Species detection may be incomplete.\n",
          "   Install Tesseract or set 'tesserAct' in config/config.csv\n\n"
        )
      }
      
      fname <- file.path(
        workingDir,
        "src",
        "species",
        "species_title_detection.R"
      )
      print(paste0(
        "Reading page species data and saving the results to a 'pageSpeciesData.csv' file in the ",
        current_out_dir, " directory"
      ))
      print(fname)
      
      source(fname)
      
      # ------------------------------------------------------------
      # Read species information for multiple map types
      #
      # This function call loads and processes species data based on
      # parameters defined in the configuration file (config.csv),
      # which is populated through the Shiny GUI.
      #
      # Key aspects:
      # - All keyword parameters (e.g., speciesTitleKeywords, speciesTitleBefore,
      #   speciesTitleThen, middle) are dynamically read from the user-defined
      #   configuration.
      # - If no speciesTitleKeywords is provided, a fallback value "None" is used.
      # - The function is specifically designed to handle workflows with
      #   multiple map types (nMapTypes), ensuring flexible and scalable
      #   species extraction across different map categories.
      # - workingDir and current_out_dir define the input/output context
      #   for the current processing run.
      #
      # This allows a fully configurable and GUI-driven species extraction
      # workflow without hardcoding parameters in the script.
      # ------------------------------------------------------------
      species <- readPageSpeciesTitleMulti(
        workingDir,
        current_out_dir,
        ifelse(length(config$specieTitleKeyword) > 0, config$specieTitleKeyword, "None"),
        as.integer(config$specieTitleKeywordBefore),   # FIX
        as.integer(config$specieTitleKeywordThen),     # FIX
        as.integer(config$middle),                     # optional, aber gut
        config$legendKeywords,
        nMapTypes = as.integer(input$nMapTypes)
      )
      
      cat("\nSuccessfully executed\n")
      
      # 📊 Zusammenfassung + OCR-Hinweis
      message <- computeNumberResult(
        base_output_dir = current_out_dir,
        working_dir = workingDir,
        nMapTypes = as.integer(input$nMapTypes),
        subfolder = "maps/readSpecies",
        png_subdir = "output/readSpecies_png",
        tesseract_available = tesseract_available
      )
      
    }, error = function(e) {
      cat("An error occurred during species_title_processing processing:\n")
      print(e)
    })
  }
  

  # ============================================================
  # Step: Direct species-title processing
  # ============================================================
  # Starts automatic species-title detection after the
  # user-confirmed training examples have been saved.
  #
  # The detailed page and map-type processing is implemented
  # in species_title_processing.R.
  # ============================================================
  
  if (processing == "pageReadSpeciesDirect") { # neuer Workflow ohne Legende:
    # Titel anhand Trainingsdaten erkennen
    
    cat("\n=======================================\n")
    cat("START SPECIES TITLE PROCESSING\n")
    cat("=======================================\n")
    
    # ----------------------------------------------------------
    # Check current output directory
    # ----------------------------------------------------------
    
    if (
      is.null(current_out_dir) ||
      !nzchar(current_out_dir)
    ) {
      
      showNotification(
        "No output directory available.",
        type = "error"
      )
      
      return(invisible(FALSE))
    }
    
    cat(
      "Output directory:",
      current_out_dir,
      "\n"
    )
    
    
    # ----------------------------------------------------------
    # Check species-title training data
    # ----------------------------------------------------------
    
    training_file <- file.path(
      workingDir,
      "training",
      "species_title_training.csv"
    )
    
    if (!file.exists(training_file)) {
      
      showNotification(
        "Please save training examples first.",
        type = "warning"
      )
      
      return(invisible(FALSE))
    }
    
    cat(
      "Training file:",
      training_file,
      "\n"
    )
    
    
    # ----------------------------------------------------------
    # Load species-title processing functions
    # ----------------------------------------------------------
    
    species_script <- file.path(
      workingDir,
      "src",
      "species",
      "species_title_detection.R"
    )
    
    if (!file.exists(species_script)) {
      
      showNotification(
        "Species processing script not found.",
        type = "error"
      )
      
      return(invisible(FALSE))
    }
    
    source(species_script)
    
    
    # ----------------------------------------------------------
    # Start processing
    # ----------------------------------------------------------
    
    tryCatch({
      
      readPageSpeciesDirectMulti(
        workingDir = workingDir,
        outDir = current_out_dir,
        nMapTypes = as.integer(input$nMapTypes)
      )
      
      cat("\n=======================================\n")
      cat("SPECIES TITLE PROCESSING FINISHED\n")
      cat("=======================================\n")
      
      showNotification(
        "Species titles processed successfully.",
        type = "message",
        duration = 5
      )
      
    }, error = function(e) {
      
      cat("\nERROR DURING SPECIES TITLE PROCESSING:\n")
      print(e)
      
      showNotification(
        "Species title processing failed.",
        type = "error",
        duration = 8
      )
    })
  }
  
  # ------------------------------------------------------------
  # Step: Circle Detection (Alternative Point Detection)
  # ------------------------------------------------------------
  # Purpose:
  # Detects circular symbols using Hough Circle Transform.
  #
  # Description:
  # This optional step applies circle detection as an alternative to
  # template matching for identifying symbol locations.
  #
  # Output:
  # - Detected circles (maps/circleDetection)
  # - Coordinates stored in CSV
  # ------------------------------------------------------------
  if(processing == "pointCircleDetection") {
    tryCatch({
      
      fname=paste0(workingDir, "/", "src/matching/circle_detection.py")
      fname2 = paste0(workingDir, "/", "src/matching/coords_to_csv.py")
      print("Processing circle detection python script:")
      print(fname)
      source_python(fname)
      source_python(fname2)
      print(current_out_dir)
      mainCircleDetection(workingDir, current_out_dir, input$Gaussian, input$minDist, 
                          input$thresholdEdge, input$thresholdCircles, input$minRadius, input$maxRadius)
      
      # convert the tif images to png and save in www
      findTemplateResult = paste0(current_out_dir, "/maps/circleDetection/")
      files <- list.files(findTemplateResult, full.names = TRUE, recursive = FALSE)
      countFiles <- paste0(length(files), "")
      message <- paste0("Ended on: ", 
                        format(current_time(), "%H:%M:%S \n"), " The number CD maps", " are \n", 
                        countFiles, " and saved in directory \n", findTemplateResult)
      
      #convertTifToPngSave(findTemplateResult, file.path(workingDir, "app", "www", "output", "CircleDetection_png"))
    }, error = function(e) {
      cat("An error occurred during pointCircleDetection processing:\n")
      print(e)
    })
  }
  
  # ------------------------------------------------------------
  # Step: Georeferencing and Rectifying
  # ------------------------------------------------------------
  # Purpose:
  # Transforms map images into geographic coordinate space.
  #
  # Description:
  # Georeferencing assigns real-world coordinates to detected points.
  # Rectifying corrects spatial distortions and prepares data for
  # spatial analysis.
  #
  # Output:
  # - Georeferenced images
  # - Rectified spatial datasets
  # ------------------------------------------------------------
  if(processing == "georeferencing"){
    tryCatch({
      
      # processing georeferencing
      fname=paste0(workingDir, "/", "src/georeferencing/mask_georeferencing.py")
      print(" Process georeferencing python script:")
      print(fname)
      source_python(fname)
      #mainmaskgeoreferencingMaps(workingDir, current_out_dir)
      #mainmaskgeoreferencingMaps_CD(workingDir, current_out_dir)
      #mainmaskgeoreferencingMasks(workingDir, current_out_dir)
      #mainmaskgeoreferencingMasks_CD(workingDir, current_out_dir)
      mainmaskgeoreferencingMasks_PF(workingDir, current_out_dir,  nMapTypes = as.integer(input$nMapTypes)
      )
      print(" Process rectifying python script:")
      # processing rectifying
      fname <- paste0(workingDir, "/", "src/polygonize/rectifying.py")
      print(" Process rectifying python script:")
      print(fname)
      source_python(fname)
      
      mainRectifying_PF(
        workingDir,
        current_out_dir,
        nMapTypes = as.integer(input$nMapTypes)
      )
      # --- 3. Zähle Masken und kopiere PNGs ---
      message <- computeNumberResult(
        base_output_dir = current_out_dir,
        working_dir = workingDir,
        nMapTypes = as.integer(input$nMapTypes),
        subfolder = "rectifying/pointFiltering",
        png_subdir = "output/georeferencing_png"
      )
      
    }, error = function(e) {
      cat("An error occurred during georeferencing processing:\n")
      print(e)
    })
  }
  
  if (processing == "georeferencing_contour") {
    tryCatch({
      
      # --------------------------------------------------
      # 1. Georeferencing contour masks
      # Contour masks are already stored in
      # masking_black/pointFiltering, therefore the
      # existing georeferencing function can be reused.
      # --------------------------------------------------
      fname <- paste0(
        workingDir,
        "/src/georeferencing/mask_georeferencing.py"
      )
      
      print("Process georeferencing contour masks:")
      print(fname)
      
      source_python(fname)
      
      mainmaskgeoreferencingMasks_PF(
        workingDir,
        current_out_dir,
        nMapTypes = as.integer(input$nMapTypes)
      )
      
      
      # --------------------------------------------------
      # 2. Rectifying contours
      # Separate function because no point extraction
      # is required for contour masks.
      # --------------------------------------------------
      fname <- paste0(
        workingDir,
        "/src/polygonize/rectifying.py"
      )
      
      print("Process rectifying contour masks:")
      print(fname)
      
      source_python(fname)
      
      mainRectifying_Contour(
        workingDir,
        current_out_dir,
        nMapTypes = as.integer(input$nMapTypes)
      )
      
      
      # --------------------------------------------------
      # 3. Count results and create PNG previews
      # --------------------------------------------------
      message <- computeNumberResult(
        base_output_dir = current_out_dir,
        working_dir = workingDir,
        nMapTypes = as.integer(input$nMapTypes),
        subfolder = "rectifying/pointFiltering",
        png_subdir = "output/georeferencing_png"
      )
      
    }, error = function(e) {
      cat("An error occurred during contour georeferencing:\n")
      print(e)
    })
  }
  
  # ------------------------------------------------------------
  # Step: Polygonization
  # ------------------------------------------------------------
  # Purpose:
  # Converts detected point data into spatial polygon representations.
  #
  # Description:
  # Filtered and georeferenced points are transformed into polygons
  # using GDAL-based processing. This enables spatial analysis and
  # visualization.
  #
  # Output:
  # - polygonize.csv
  # - Spatial polygon datasets
  # ------------------------------------------------------------
  if(processing == "polygonize"){
    tryCatch({
      
      # processing polygonize
      fname=paste0(workingDir, "/", "src/polygonize/polygonize.py")
      print(" Process polygonizing python script:")
      print(fname)
      source_python(fname)
      # mainPolygonize_CD(workingDir, current_out_dir)
      # mainPolygonize_PF(workingDir, current_out_dir)
      mainPolygonize_PF(workingDir, current_out_dir, nMapTypes = as.integer(input$nMapTypes))
      # --- 3. Zähle Masken und kopiere PNGs ---
      message <- computeNumberResult(
        base_output_dir = current_out_dir,
        working_dir = workingDir,
        nMapTypes = as.integer(input$nMapTypes),
        subfolder = "polygonize/pointFiltering",
        png_subdir = "output/polygonize"
      )
    }, error = function(e) {
      cat("An error occurred during pageReadRpecies processing:\n")
      print(e)
    })
  }   
  
  if (processing == "polygonize_contour") {
    tryCatch({
      
      fname <- paste0(
        workingDir,
        "/src/polygonize/polygonize.py"
      )
      
      print("Process contour polygonizing python script:")
      print(fname)
      
      source_python(fname)
      
      mainPolygonize_Contour(
        workingDir,
        current_out_dir,
        nMapTypes = as.integer(input$nMapTypes)
      )
      
      message <- computeNumberResult(
        base_output_dir = current_out_dir,
        working_dir = workingDir,
        nMapTypes = as.integer(input$nMapTypes),
        subfolder = "polygonize/pointFiltering",
        png_subdir = "output/polygonize"
      )
      
    }, error = function(e) {
      cat("An error occurred during contour polygonizing:\n")
      print(e)
    })
  }
  # ------------------------------------------------------------
  # Step: Spatial Data Integration
  # ------------------------------------------------------------
  # Purpose:
  # Merges all processed data into a final spatial dataset.
  #
  # Description:
  # Combines coordinates, species information, and titles into a
  # unified dataset (spatial_final_data.csv), ready for visualization
  # and analysis.
  #
  # Output:
  # - spatial_final_data.csv
  # ------------------------------------------------------------
  if(processing == "spatial_data_computing"){
    
    tryCatch(
      # Processing spatial data computing
      
      expr = {
        source(paste0(workingDir, "/src/spatial_view/merge_spatial_final_data.R"))
        merge_all_maps(current_out_dir, nMapTypes = as.integer(input$nMapTypes))
        
      },
      error = function(e) {
        messageOnClose = e$message
        # Hier steht der Code, der ausgeführt wird, wenn ein Fehler auftritt
        showModal(
          modalDialog(
            title = "Error",
            paste("Error in startSpatialDataComputing:", e$message),
            easyClose = TRUE,
            footer = NULL
          )
        )
      },
      finally = {
        cat("\nSuccessfully executed")
        # show end action message if no errors
        closeAlert(num = 0, id = NULL)
        message = "End of processing spatial on " 
        message = paste(message, format(current_time(), "%H:%M:%S."), 
                        " The data spatial_final_data.csv in: " , current_out_dir)
      }
    )
  }
  
  if (processing == "spatial_data_computing_contour") {
    
    fname <- paste0(
      workingDir,
      "/src/spatial_view/merge_spatial_final_data.R"
    )
    
    print("Process final contour spatial data:")
    print(fname)
    
    source(fname)
    
    merge_all_contours(
      outDir = current_out_dir,
      nMapTypes = as.integer(input$nMapTypes)
    )
  }
  # ------------------------------------------------------------
  # Step: Data Visualization (CSV Viewer)
  # ------------------------------------------------------------
  # Purpose:
  # Displays the final dataset within the Shiny interface.
  #
  # Description:
  # Loads the final CSV file and renders it as an interactive table
  # for inspection and validation.
  #
  # Output:
  # - Interactive table in Shiny UI
  # ------------------------------------------------------------
  if(processing == "view_csv"){
    # Hier können Sie den Pfad zu Ihrer CSV-Datei angeben
    csv_path <- paste0(current_out_dir, "/spatial_final_data.csv")
    
    data <- reactive({
      dd_data <- read.table(csv_path, sep = ";", header = TRUE, check.names = FALSE)
      
      #print(colnames(my_data))
      return(dd_data)
    })
    
    output$view_csv <- renderDataTable({
      data()
    })
    
  }
  
  cat("\nSuccessfully executed")
  
  closeAlert(num = 0, id = NULL)
  shinyalert(text = paste(message, format(Sys.time(), "%H:%M:%S"), "!\n Results are located at: " , current_out_dir ), type = "info", showConfirmButton = TRUE, closeOnEsc = TRUE,
             closeOnClickOutside = TRUE, animation = TRUE)
  
}