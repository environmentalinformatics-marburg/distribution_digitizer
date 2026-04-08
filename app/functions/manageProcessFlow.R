
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
manageProcessFlow <- function(processing, allertText1, allertText2, input, session, current_out_dir) {

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
      # processing template matching
      #workingDir = "D:/distribution_digitizer"
      #current_out_dir="D:/test/output_2025-09-26_13-16-11/"
      fname=paste0(workingDir, "/", "src/matching/map_matching.py")
      print(workingDir)
      print("The processing template matching python script:")
      print(fname)
      source_python(fname)
      print("Threshold:")
      print(input$threshold_for_TM)
      pattern <- "^(ALL|[0-9]+[0-9]+)$"
      #if (grep(pattern,input$range_matching)){
      main_template_matching(workingDir, current_out_dir, input$threshold_for_TM, input$sNumberPosition, input$matchingType, as.character(input$range_matching), nMapTypes = as.integer(input$nMapTypes) )
      #}else{
      #  stop("🚨 The input range is not correct, please write like 1-5 or ALL")
      #}
      #main_template_matching(workingDir, current_out_dir, 0.18, 1, 1, "1-2")
      
      
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
  if(processing == "mapReadRpecies"){
    tryCatch({
      
      # --- 1. Read species ---
      fname <- paste0(workingDir, "/", "src/read_species/map_read_species.R")
      print("Reading species names from the map bottom R script:")
      print(fname)
      source(fname)
      
      # --- 2. Für jeden Map-Typ (1, 2, ...) ---
      species <- read_legends(
        working_dir = workingDir,
        out_dir = current_out_dir,
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
      cat("An error occurred during mapReadRpecies processing:\n")
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
  if (processing == "pageReadRpecies") {
    
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
      
      fname <- paste0(workingDir, "/src/read_species/page_read_species.R")
      print(paste0(
        "Reading page species data and saving the results to a 'pageSpeciesData.csv' file in the ",
        current_out_dir, " directory"
      ))
      print(fname)
      
      source(fname)
      
      species <- readPageSpeciesMulti(
        workingDir,
        current_out_dir,
        ifelse(length(config$keywordReadSpecies) > 0, config$keywordReadSpecies, "None"),
        config$keywordBefore,
        config$keywordThen,
        config$middle,
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
      cat("An error occurred during pageReadRpecies processing:\n")
      print(e)
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