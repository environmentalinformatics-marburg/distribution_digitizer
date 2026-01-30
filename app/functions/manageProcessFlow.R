
####################
# FUNCTIONS       #----------------------------------------------------------------------#
####################

checkTesseractWindows <- function() {
  candidates <- c(
    "C:/Program Files/Tesseract-OCR/tesseract.exe",
    "C:/Program Files (x86)/Tesseract-OCR/tesseract.exe"
  )
  any(file.exists(candidates))
}


# Function to manage the processing
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
      mainmaskgeoreferencingMasks_PF(workingDir, current_out_dir)
      # processing rectifying
      
      fname=paste0(workingDir, "/", "src/polygonize/rectifying.py")
      print(" Process rectifying python script:")
      print(fname)
      source_python(fname)
      mainmaskgeoreferencingMaps(workingDir, current_out_dir)
      mainRectifying_Map_PF(workingDir, current_out_dir)
      mainRectifying(workingDir, current_out_dir)
      mainRectifying_CD(workingDir, current_out_dir)
      mainRectifying_PF(workingDir, current_out_dir)
      #current_out_dir = "D:/test/output_2024-08-05_15-38-45/"
      findTemplateResult = paste0(current_out_dir, "/georeferencing/maps/pointFiltering/")
      files <- list.files(findTemplateResult, full.names = TRUE, recursive = FALSE)
      countFiles <- paste0(length(files), "")
      message <- paste0("Georeferencing ended on: ", 
                        format(current_time(), "%H:%M:%S \n"), " The number georeferencing masks ", " are \n", 
                        countFiles, " and saved in directory \n", findTemplateResult)
      # convert the tif images to png and save this in /www directory
     
      #convertTifToPngSave(findTemplateResult, file.path(workingDir, "app", "www", "output", "georeferencing_png"))
      
    }, error = function(e) {
      cat("An error occurred during georeferencing processing:\n")
      print(e)
    })
  }
  
  if(processing == "georef_coords_from_csv"){
    # processing mathematical georeferencing of extracted coordinates stored in csv file
    tryCatch({
      
      fname=paste0(workingDir, "/", "src/georeferencing/centroid_georeferencing.py")
      print(" Process georef_coords_from_csv python script:")
      print(fname)
      source_python(fname)
      mainCentroidGeoref(workingDir, current_out_dir)
    }, error = function(e) {
      cat("An error occurred during pageReadRpecies processing:\n")
      print(e)
    })
  }
  
  if(processing == "polygonize"){
    tryCatch({
      
      # processing polygonize
      fname=paste0(workingDir, "/", "src/polygonize/polygonize.py")
      print(" Process polygonizing python script:")
      print(fname)
      source_python(fname)
      #mainPolygonize(workingDir, current_out_dir)
      #mainPolygonize_Map_PF(workingDir, current_out_dir)
      mainPolygonize_CD(workingDir, current_out_dir)
      mainPolygonize_PF(workingDir, current_out_dir)
      findTemplateResult = paste0(current_out_dir, "/polygonize/pointFiltering")
      files <- list.files(findTemplateResult, full.names = TRUE, recursive = FALSE)
      countFiles <- paste0(length(files), "")
      message <- paste0("Georeferencing ended on: ", 
                        format(current_time(), "%H:%M:%S \n"), " The number polygonized masks ", " are \n", 
                        countFiles, " and saved in directory \n", findTemplateResult)
      
      shFiles <- list.files(findTemplateResult, pattern = ".sh", recursive = TRUE, full.names = TRUE)
      dir.create(file.path(workingDir, "app", "www", "output", "polygonize"),
                 recursive = TRUE, showWarnings = FALSE)
      # copy the shape files into www directory
      for (f in shFiles) {
        # Source and destination file paths
        baseName = basename(f)
        destination_file <- file.path(workingDir, "app", "www", "output", "polygonize", baseName)
        

        #print(destination_file)
        # Copy the file
        file.copy(from = f, to = destination_file, overwrite = TRUE)
        
        # Check if the copy was successful
        if (file.exists(destination_file)) {
          cat("File copied successfully to:", destination_file)
        } else {
          cat("File copy failed.")
        }
      }
    }, error = function(e) {
      cat("An error occurred during pageReadRpecies processing:\n")
      print(e)
    })
  }
  
  if(processing == "spatial_data_computing"){
    
    tryCatch(
      # Processing spatial data computing
      
      expr = {
        #fname=paste0(workingDir, "/", "src/extract_coordinates/poly_to_point.py")
        #source_python(fname)
        #main_circle_detection(workingDir, current_out_dir)
        #main_point_filtering(workingDir, current_out_dir)
        
        #fname=paste0(workingDir, "/", "src/extract_coordinates/extract_coords.py")
        #source_python(fname)
        #main_circle_detection(workingDir, current_out_dir)
        #main_point_filtering(workingDir, current_out_dir)
        
        # prepare pages as png for the spatia view
        #convertTifToPngSave( file.path(workingDir, "output", "input",  "pages"),  file.path(workingDir, "app", "www", "output", "pages"))
        
      
        
        
        source(paste0(workingDir, "/src/spatial_view/merge_spatial_final_data.R"))
        mergeFinalData(workingDir, current_out_dir)
        spatialFinalData(current_out_dir)
        spatialRealCoordinats(current_out_dir)
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
  
  if(processing == "view_csv"){
    # Hier können Sie den Pfad zu Ihrer CSV-Datei angeben
    csv_path <- paste0(current_out_dir, "/spatial_final_data.csv")
    
    # Hier können Sie Daten für Ihre Tabelle oder Visualisierung laden
    # In diesem Beispiel lesen wir die CSV-Datei
    
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