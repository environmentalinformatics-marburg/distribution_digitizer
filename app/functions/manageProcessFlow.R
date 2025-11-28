
####################
# FUNCTIONS       #----------------------------------------------------------------------#
####################

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
      
      cat("\nSuccessfully executed")
      message <- computeNumberResult(
        base_output_dir = current_out_dir,
        working_dir = workingDir,
        nMapTypes = as.integer(input$nMapTypes),
        subfolder = "maps/align",
        png_subdir = "output/align_png"
      )
      
    }, error = function(e) {
      cat("An error occurred during alignMaps processing:\n")
      print(e)
    })
  }
  
  
  
  if(processing == "pointMatching") {
    tryCatch({
      # Processing points matching
      fname=paste0(workingDir, "/", "src/matching/point_matching.py")
      print(" Processing point python script:")
      print(fname)
      source_python(fname)
      
      map_points_matching(workingDir, current_out_dir, input$threshold_for_PM)
      
      #map_type_dirs <- list.dirs(current_out_dir, recursive = FALSE, full.names = TRUE)
     # map_type_dirs <- map_type_dirs[grepl("/[0-9]+$", map_type_dirs)]
      
     # all_files <- c()
      
     # for (map_dir in map_type_dirs) {
     #   pm_dir <- file.path(map_dir, "maps", "pointMatching")
     #   if (dir.exists(pm_dir)) {
     #     png_target <- file.path(workingDir, "app", "www", "output", "pointMatching_png", basename(map_dir))
     #     dir.create(png_target, recursive = TRUE, showWarnings = FALSE)
          
     #     convertTifToPngSave(pm_dir, png_target)
     #     all_files <- c(all_files, list.files(pm_dir, full.names = TRUE))
     #   }
     # }
      
     # countFiles <- length(all_files)
     # print(paste("Total matched point images:", countFiles))
      
      #current_out_dir = "D:/test/output_2024-07-12_08-18-21/"
      #workingDir = "D:/distribution_digitizer/"
      
      # convert the tif images to png and save in www
     # convertTifToPngSave(findTemplateResult, file.path(workingDir, "app", "www", "output", "pointMatching_png"))
      
    }, error = function(e) {
      cat("An error occurred during pointMatching processing:\n")
      print(e)
    })
  }
  
  
  if(processing == "mapReadRpecies" ){
    tryCatch({
      
      # Croping
      fname <- paste0(workingDir, "/", "src/read_species/map_read_species.R")
      print("Croping the species names from the map botton R script:")
      print(fname)
      source(fname)
      species <- read_legends(workingDir, current_out_dir)
      cat("\nSuccessfully executed")
      findTemplateResult <- paste0(current_out_dir, "/maps/readSpecies/")
      files <- list.files(findTemplateResult, full.names = TRUE, recursive = FALSE)
      
      countFiles <- paste0(length(files), "")
      # convert the tif images to png and save in www
      convertTifToPngSave(
        findTemplateResult, 
        #file.path(workingDir, "app", "www", "data", "matching_png")
        file.path(workingDir, "app", "www", "output", "readSpecies_png")
      )
      
      message <- paste0("Ended on: ", 
                        format(current_time(), "%H:%M:%S \n"), " The number maps ", " are \n", 
                        countFiles, " and saved in directory \n", findTemplateResult)
    }, error = function(e) {
      cat("An error occurred during mapReadRpecies processing:\n")
      print(e)
    })
  }
  
  if(processing == "pageReadRpecies" ){
    tryCatch({
      # Read page species
      fname=paste0(workingDir, "/", "src/read_species/page_read_species.R")
      print(paste0("Reading page species data and saving the results to a 'pageSpeciesData.csv' file in the ", current_out_dir," directory"))
      source(fname)
      if(length(config$keywordReadSpecies) > 0) {
        species <- readPageSpecies(workingDir, current_out_dir, config$keywordReadSpecies, config$keywordBefore, config$keywordThen, config$middle)
      } else {
        species <- readPageSpecies(workingDir, current_out_dir, 'None', config$keywordBefore, config$keywordThen, config$middle)
      }
      
      cat("\nSuccessfully executed")
      findTemplateResult <- paste0(current_out_dir, "/maps/align/")
      files <- list.files(findTemplateResult, full.names = TRUE, recursive = FALSE)
      countFiles <- paste0(length(files), "")
      message <- paste0("Ended on: ", 
                        format(current_time(), "%H:%M:%S \n"), " The number maps ", " are \n", 
                        countFiles, " and saved in directory \n", findTemplateResult)
      # convert the tif images to png and save in www
      #convertTifToPngSave(findTemplateResult, paste0(workingDir, "/www/data/cropped_png/"))
    }, error = function(e) {
      cat("An error occurred during pageReadRpecies processing:\n")
      print(e)
    })
  }
  

  
  if(processing == "pointFiltering") {
    tryCatch({
      
      fname=paste0(workingDir, "/", "src/matching/point_filtering.py")
      fname2 = paste0(workingDir, "/", "src/matching/coords_to_csv.py")
      print(" Process pixel filtering  python script:")
      print(fname)
      source_python(fname)
      source_python(fname2)
      main_point_filtering(workingDir, current_out_dir, input$filterK, input$filterG)
      
      cat("\nSuccessfully executed")
      # convert the tif images to png and save in www
      findTemplateResult = paste0(current_out_dir, "/maps/pointFiltering/")
      files <- list.files(findTemplateResult, full.names = TRUE, recursive = FALSE)
      countFiles <- paste0(length(files), "")
      message <- paste0("Ended on: ", 
                        format(current_time(), "%H:%M:%S \n"), " The number PF maps ", " are \n", 
                        countFiles, " and saved in directory \n", findTemplateResult)
      convertTifToPngSave(findTemplateResult, file.path(workingDir, "app", "www", "output", "pointFiltering_png"))
      
    }, error = function(e) {
      cat("An error occurred during pointFiltering processing:\n")
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
      
      convertTifToPngSave(findTemplateResult, file.path(workingDir, "app", "www", "output", "CircleDetection_png"))
    }, error = function(e) {
      cat("An error occurred during pointCircleDetection processing:\n")
      print(e)
    })
  }
  
  if(processing == "masking"){
    tryCatch({
      
      fname=paste0(workingDir, "/", "src/masking/masking.py")
      print(" Process masking normale python script:")
      print(fname)
      source_python(fname)
      mainGeomask(workingDir, current_out_dir, input$morph_ellipse)
      
      fname=paste0(workingDir, "/", "src/masking/creating_masks.py")
      print(" Process masking black python script:")
      print(fname)
      source_python(fname)
      mainGeomaskB(workingDir, current_out_dir, input$morph_ellipse)
      
      findTemplateResult = paste0(current_out_dir, "/masking/")
      files <- list.files(findTemplateResult, full.names = TRUE, recursive = FALSE)
      countFiles <- paste0(length(files), "")
      message <- paste0("Ended on: ", 
                        format(current_time(), "%H:%M:%S \n"), " The number masks ", " are \n", 
                        countFiles, " and saved in directory \n", findTemplateResult)
      
    
      convertTifToPngSave(findTemplateResult, file.path(workingDir, "app", "www", "output", "masking_png"))
      findTemplateResult = paste0(current_out_dir, "/masking_black/")
      convertTifToPngSave(findTemplateResult, file.path(workingDir, "app", "www", "output", "masking_black_png"))
      
    }, error = function(e) {
      cat("An error occurred during masking processing:\n")
      print(e)
    })
  }
  
  if(processing == "maskingCentroids"){
    tryCatch({
      
      fname=paste0(workingDir, "/", "src/masking/mask_centroids.py")
      print(" Process masking Centroids python script:")
      print(fname)
      source_python(fname)
      MainMaskCentroids(workingDir, current_out_dir)
      
      findTemplateResult = paste0(current_out_dir, "/masking_black/pointFiltering/")
      files <- list.files(findTemplateResult, full.names = TRUE, recursive = FALSE)
      countFiles <- paste0(length(files), "")
      message <- paste0("Ended on: ", 
                        format(current_time(), "%H:%M:%S \n"), " The number centroids masks ", " are \n", 
                        countFiles, " and saved in directory \n", findTemplateResult)
      
      convertTifToPngSave(findTemplateResult, file.path(workingDir, "app", "www", "output", "maskingCentroids_png"))
    }, error = function(e) {
      cat("An error occurred during masking Centroids processing:\n")
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
     
      convertTifToPngSave(findTemplateResult, file.path(workingDir, "app", "www", "output", "georeferencing_png"))
      
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
        convertTifToPngSave( file.path(workingDir, "output", "input",  "pages"),  file.path(workingDir, "app", "www", "output", "pages"))
        
      
        
        
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