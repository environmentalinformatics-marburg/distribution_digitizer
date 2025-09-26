# ============================================================
# Script Author: [Spaska Forteva]
# Created On: 2021-06-10c
# ============================================================

# ============================================================
# Main Shiny App Distribution Digitization
# ============================================================
# 
# 
# ============================================================
# # Tab 1 Config Dialog for Book Distribution Digitization
# ============================================================
# This configuration dialog is designed to gather essential 
# information about a book before the digitization process. 
# Users can input details to create a comprehensive summary 
# for proper documentation. The dialog includes the following fields:
# 
# 1. Title: Enter the title of the book.
# 2. Author: Provide the name of the book's author.
# 3. Publication Year: Specify the year the book was published.
# 4. Data Input Directory: Specify the directory where the raw 
#    data for the book digitization is stored.
# 5. Data Output Directory: Specify the directory where the 
#    digitized output for the book will be stored.
# 6. Number of Book Sites per One Print: Define the number of 
#    book pages to be included in one printed output.
# 7. All Printed Pages: Indicate whether all pages of the book 
#     will be included in the digitization process.
# 8. Site Number Position: Specify the placement of the site 
#     number on each printed page (e.g., top-right, bottom-left).
# 9. Image Format of the Scanned Sites: Choose the format 
#     (e.g., JPEG, PNG) for the digitized pages.
# 10. Page Color: Indicate the color of the book pages 
#     (e.g., black and white, color).
# 
# This dialog aims to streamline the digitization process by 
# ensuring that all relevant information is captured accurately. 
# Once the user completes the form, the gathered details can 
# be used for cataloging and organizing the digital version of 
# the book, preserving its content for future reference.
# ============================================================

library(shiny)
library(shinydashboard)
library(shinyjs)
if(!require(magick)){
  install.packages("magick", dependencies = T)
  library(magick)
}
if(!require(grid)){
  install.packages("grid", dependencies = T)
  library(grid)
}

if(!require(rdrop2)){
  install.packages("rdrop2", dependencies = T)
  library(rdrop2)
}

if(!require(shiny)){
  install.packages("shiny",dependencies = T)
  library(shiny)
}

if(!require(shinyFiles)){
  install.packages("shinyFiles",dependencies = T)
  library(shinyFiles)
}

if(!require(reticulate)){
  install.packages("reticulate",dependencies = T)
  library(reticulate)
}
library(shinyalert)

if(!require(tesseract)){
  install.packages("tesseract",dependencies = T)
  library(tesseract)
}
if(!require(leaflet)){
  install.packages("leaflet",dependencies = T)
  library(leaflet)
}

if(!require(raster)){
  install.packages("raster",dependencies = T)
  library(raster)
}

library(sf)
Sys.setenv(TESSDATA_PREFIX = "C:/Program Files/Tesseract-OCR/tessdata")

# Global variables
processEventNumber = 0
# ==========================
# Read start_config.csv instead of using commandArgs
# ==========================


workingDir <- "D:/distribution_digitizer"

cat("📁 Received working directory:", workingDir, "\n")


# ==========================
# Weitere Initialisierung
# ==========================
setwd(workingDir)  # falls du auf relative Pfade angewiesen bist
inputDir <- file.path(workingDir, "data/input/")
tempImage <- "temp.png"
scale <- 20
rescale <- 100 / scale


#read config fields from config.csv in .../distribution_digitizer/config directory
fileFullPath = (paste0(workingDir,'/config/config.csv'))
if (file.exists(fileFullPath)){
  #config <- read.csv(fileFullPath,header = TRUE, sep = ';')
  # Reading configuration files
  config_list<- read.csv2(paste0(workingDir,'/config/config.csv'), header = FALSE, sep = ';',stringsAsFactors = FALSE)
  colnames(config_list) <- c("key", "value")
  # Als Liste umwandeln
  config<- as.list(setNames(config_list$value, config_list$key))
  
} else{
  stop(paste0("file:", fileFullPath, "not found, please create them and start the app"))
}


server <- shinyServer(function(input, output, session) {
  # ganz oben im server:
  outDir <- reactiveVal(NULL)
  
  # kleiner Helper: Basis-Pfad säubern (Trailing Slashes entfernen)
  strip_trailing <- function(p) sub("[/\\]+$", "", toString(p))          # .../foo/  -> .../foo
  pretty_path    <- function(p) normalizePath(p, winslash = "/", mustWork = FALSE)
  

  dataInputDir = ""
  # Update the clock every second using a reactiveTimer
  current_time <- reactiveTimer(1000)
  
  # Hilfsfunktion zum Lesen
  read_config <- function(file) {
    df <- read.csv2(file, header = FALSE, stringsAsFactors = FALSE)
    names(df) <- c("key","value")
    as.list(stats::setNames(df$value, df$key))
  }
  
  # Einmal nach dem ersten Flush (UI steht), dann Inputs gefahrlos updaten
  session$onFlushed(function() {
    cfg_path <- file.path(workingDir, "config", "config.csv")
    if (file.exists(cfg_path)) {
      cfg <- read_config(cfg_path)
      # Run-Ordner aus der Config in die Reactive übernehmen
      if (!is.null(cfg$dataOutputDir) && nzchar(cfg$dataOutputDir)) {
        outDir(cfg$dataOutputDir)
      }
      # Optional: ins UI spiegeln, ohne Event-Lawine
      isolate({
        if (!is.null(input$dataOutputDir)) {
          shiny::freezeReactiveValue(input, "dataOutputDir")
          updateTextInput(session, "dataOutputDir", value = pretty_path(cfg$dataOutputDir) %||% "")
        }
      })
    }
  }, once = TRUE)
  
  # CSS hover-Event, um zusätzliche Info anzuzeigen
  observe({
    session$sendCustomMessage("showHoverInfo", list(id = "title"))
  })
  
  # CSS hover-Event, um zusätzliche Info anzuzeigen
  observe({
    session$sendCustomMessage("showHoverInfo", list(id = "author"))
  })
  
  # CSS hover-Event, um zusätzliche Info anzuzeigen
  observe({
    session$sendCustomMessage("showHoverInfo", list(id = "pYear"))
  })
  # CSS hover-Event, um zusätzliche Info anzuzeigen
  observe({
    session$sendCustomMessage("showHoverInfo", list(id = "tesserAct"))
  })
  # CSS hover-Event, um zusätzliche Info anzuzeigen
  observe({
    session$sendCustomMessage("showHoverInfo", list(id = "dataInputDir"))
  })
  # CSS hover-Event, um zusätzliche Info anzuzeigen
  observe({
    session$sendCustomMessage("showHoverInfo", list(id = "dataOutputDir"))
  })

  # CSS hover-Event, um zusätzliche Info anzuzeigen
  observe({
    session$sendCustomMessage("showHoverInfo", list(id = "pColor"))
  })
  
  # CSS hover-Event, um zusätzliche Info anzuzeigen
  observe({
    session$sendCustomMessage("showHoverInfo", list(id = "pFormat"))
  })
  
  # -----------------------------------------# 1. Step - Create templates #---------------------------------------------------------------------
  #Function to show the ccrop process in the app 
  plot_png <- function(path, plot_brush, index, add=FALSE)
  {
    require('png')
    #fname=paste0(workingDir, "/", tempImage)
    fname=tempImage
    png = png::readPNG(fname, native=T) # read the file
    # this for tests png <- image_read('DD_shiny/0045.png')
    
    # get the resolution, [x, y]
    res = dim(png)[2:1] 
    # initialize an empty plot area if add==FALSE
    if (!add) 
      plot(1,1,xlim=c(1,res[1]),ylim=c(1,res[2]),asp=1,type='n',xaxs='i',yaxs='i',xaxt='n',yaxt='n',
           xlab='',ylab='',bty='n')
    img <- as.raster(readPNG(fname))
    # rasterImage(img,1,1,res[1],res[2])
    #grid.raster(img[1:600,1:500,]) wichtig img[y1:y2,x2:y2]
    x1 = plot_brush$xmin
    x2 = plot_brush$xmax
    y2 = plot_brush$ymin
    y1 = plot_brush$ymax
    grid.raster(img[y2:y1,x1:x2,])
  }
  

  # Hilfsfunktion
  to_chr <- function(x) if (is.null(x) || is.na(x)) "" else as.character(x)
  
  observeEvent(input$saveConfig, ignoreInit = TRUE, {
    # optional: vorherige Meldungen leeren
    output$message <- renderPrint(NULL)
    
    tryCatch({
      # ---------- VORPRÜFUNGEN ----------
      req(nzchar(input$dataInputDir), dir.exists(input$dataInputDir))
      req(nzchar(input$dataOutputDir))
      
      required1 <- c("pages", "templates")
      folders1  <- list.dirs(input$dataInputDir, full.names = FALSE, recursive = FALSE)
      if (!all(required1 %in% folders1)) {
        stop(sprintf("Missing folders in dataInputDir: %s", paste(setdiff(required1, folders1), collapse=", ")))
      }
      
      required2 <- c("align_ref", "maps", "symbols", "geopoints")
      folders2  <- list.dirs(file.path(input$dataInputDir, "templates"), full.names = FALSE, recursive = FALSE)
      if (!all(required2 %in% folders2)) {
        stop(sprintf("Missing template folders: %s", paste(setdiff(required2, folders2), collapse=", ")))
      }
      
      # ---------- AUSGABEORDNER & CONFIG-PFAD ----------
      timestamp <- format(Sys.time(), "%Y-%m-%d_%H-%M-%S")
      run_out <- file.path(input$dataOutputDir, paste0("output_", timestamp))
      run_out  <- strip_trailing(run_out)
      run_out <- pretty_path(run_out)
      prepare_base_output(run_out)
      prepare_www_output(file.path(workingDir, "www", "data"))
      
      cfg_dir  <- file.path(workingDir, "config")
      if (!dir.exists(cfg_dir)) dir.create(cfg_dir, recursive = TRUE, showWarnings = FALSE)
      cfg_path <- file.path(cfg_dir, "config.csv")
     
      # ---------- CONFIG ALS KEY→VALUE ----------
      to_chr <- function(x) if (is.null(x) || is.na(x)) "" else as.character(x)
      cfg <- list(
        workingDir     = to_chr(workingDir),
        title          = to_chr(input$title),
        author         = to_chr(input$author),
        pYear          = to_chr(input$pYear),
        tesserAct      = to_chr(input$tesserAct),
        dataInputDir   = to_chr(input$dataInputDir),
        dataOutputDir  = run_out,           # <-- WICHTIG: mit Zeitstempel!
        pFormat        = to_chr(input$pFormat),
        pColor         = to_chr(input$pColor)
      )

      
      df <- data.frame(key = names(cfg), value = unname(unlist(cfg, use.names = FALSE)), stringsAsFactors = FALSE)
      
      # ---------- SCHREIBEN ----------
      write.table(df, cfg_path, sep = ";", row.names = FALSE, col.names = FALSE, quote = FALSE)
      if (!file.exists(cfg_path)) stop("Config file not found after write: ", cfg_path)
      
      # ---------- REAKTIVEN STATE SETZEN ----------
      # WICHTIG: benutze eine reactiveVal, z.B. outDir
      outDir(run_out)
      
      # UI nicht mit neuem Zeitstempel überschreiben, wenn du das nicht willst.
      # Falls du im Dialog den aktuellen Run-Ordner anzeigen willst:
      #output$currentRunDir <- renderText(outDir())
      
      # ---------- ERFOLG (ganz zum Schluss) ----------
      shinyalert("Success", "Configuration successfully saved!", type = "success")
      output$message <- renderPrint(paste("Saved to:", cfg_path, "\nRun output:", run_out_dir))
      # Wrapper um das textInput, damit wir das Style anwenden können
      isolate({
        # verhindert Event-Kaskaden
        freezeReactiveValue(input, "dataOutputDir")
        updateTextInput(session, "dataOutputDir", value = outDir())  # oder value = run_out
      })
    }, error = function(e) {
      # EIN Fehlerpfad: kein Success mehr anzeigen
      msg <- conditionMessage(e)
      if (!nzchar(msg)) msg <- "Unknown error (possibly from validate/need)."
      shinyalert("Error", paste("Config save failed:", msg), type = "error")
      output$message <- renderPrint(paste("Config save failed:", msg))
    })
  })
  
  
  # Render the image in the plot with given dynamical 10%
  output$plot <- renderImage({
    
    #only if input$image is given
    req(input$image)
    temp <- image_read(input$image$datapath)
    file <- image_convert(temp, "png")
    temp_scale <- image_scale(file, paste0(scale,"%"))
    fname = paste0(workingDir, "/", tempImage)
    workingDir = workingDir
    image_write(temp_scale, path = fname, format = "png", )
    req(file)
    list(src = fname, alt="alternative text")
    
    shinyalert::shinyalert(title = "Success", text = "Configuration successfully saved!", type = "success")
  }, deleteFile = FALSE)
  
  
  #plot1
  output$plot1 <- renderPlot({
    req(input$image)
    req(input$plot_brush)
    d <- data()
    if(!is.null(input$image$datapath) && input$image$datapath!=""){
      plot_png(input$image$datapath, input$plot_brush, input$imgIndexTemplate)
    }
  })
  
  # Function to save the cropped tepmlate map image
  output$saveTemplate <- downloadHandler(
    filename = function() {
      paste(workingDir, '/data/templates/maps/map', '_',input$imgIndexTemplate,'.tif', sep='')
    },
    content = function(file) {
      
      x1 = input$plot_brush$xmin
      x2 = input$plot_brush$xmax
      y2 = input$plot_brush$ymin
      y1 = input$plot_brush$ymax
      
      tempI <- image_read(input$image$datapath)
      
      widht=(x2*rescale-x1*rescale)
      height=(y1*rescale-y2*rescale)
      
      geometrie <- paste0(widht, "x", height, "+",x1*rescale,"+", y2*rescale)
      #"100x150+0+0")
      tempI <- image_crop(tempI, geometrie)
      image_write(tempI, file, format = "tif")
      #writePNG(tempImage, target = file)
      # unlink(paste0(workingDir,"/", tempImage))
      i = input$imgIndexTemplate +1
      updateNumericInput(session, "imgIndexTemplate", value = i)
      
      
    }) 
  
  observeEvent(input$listMTemplates, {
    output$listMapTemplates = renderUI({
      # Check if the directory already exists
      findTemplateResult = paste0(workingDir, "/data/input/templates/maps/")
      convertTifToPngSave(findTemplateResult, paste0(workingDir, "/www/data/map_templates_png/"))
      prepareImageView("/map_templates_png/", '.png')
    })
  })
  
  # Function to save the cropped template symbol image
  output$saveSymbol <- downloadHandler(
    filename = function() {
      paste(workingDir, '/data/templates/maps/symbols', '_',input$imgIndexSymbol,'.tif', sep='')
    },
    content = function(file) {
      
      x1 = input$plot_brush$xmin
      x2 = input$plot_brush$xmax
      y2 = input$plot_brush$ymin
      y1 = input$plot_brush$ymax
      
      tempI <- image_read(input$image$datapath)
      widht=(x2*rescale-x1*rescale)
      height=(y1*rescale-y2*rescale)
      
      geometrie <- paste0(widht, "x", height, "+",x1*rescale,"+", y2*rescale)
      #"100x150+0+0")
      tempI <- image_crop(tempI, geometrie)
      image_write(tempI, file, format = "tif")
      #writePNG(tempImage, target = file)
      # unlink(paste0(workingDir,"/", tempImage))
      i = input$imgIndexSymbol +1
      updateNumericInput(session, "imgIndexSymbol", value = i)
      
    }) 
  
  observeEvent(input$listSTemplates, {
    output$listSymbolTemplates = renderUI({
      
      findTemplateResult = paste0(workingDir, "/data/input/templates/symbols/")
      convertTifToPngSave(findTemplateResult, paste0(workingDir, "/www/data/symbol_templates_png/"))
      prepareImageView("/symbol_templates_png/", '.png')
    })
  })
  
  ####################
  # 2. Maps matching #----------------------------------------------------------------------#
  ####################
  
  # START th template matching 
  observeEvent(input$templateMatching, {
    # call the function for map matching 
    manageProcessFlow("mapMatching", "map matching", "matching")
  })
  
  observeEvent(input$listMapsMatching, {
    # optional: leere Eingaben zu "" normalisieren
    idx <- if (isTruthy(input$siteNumberMapsMatchingR)) trimws(input$siteNumberMapsMatchingR) else ""
    rng <- if (isTruthy(input$mapsRange))               trimws(input$mapsRange)               else ""
    
    output$listMaps <- renderUI({
      # KEIN führender Slash, weil prepareImageView intern "www" ergänzt
      prepareImageView("data/matching_png", index = idx, range_str = rng)
    })
  })
  
  
  
  ####################
  # 2.1 Maps align #----------------------------------------------------------------------#
  ####################
  
  # Start Align maps 
  observeEvent(input$alignMaps, {
    # call the function for align maps 
    manageProcessFlow("alignMaps", "align maps", "allign")
  })
  
  # List align maps
  observeEvent(input$listAlign, {
    if(input$siteNumberMapsMatching != ''){
      #print(input$siteNumberMapsMatching)
      output$listAlign = renderUI({
        prepareImageView("/data/align_png/", input$siteNumberMapsMatching)
      })
    }
    else{
      output$listAlign = renderUI({
        prepareImageView("/data/align_png/", '.png')
      })
    }
  })
  
  
  ####################
  # 2.2 Crop map legend species#----------------------------------------------------------------------#
  ####################
  
  # Start read  legend species
  observeEvent(input$mapReadRpecies, {
    # call the function for cropping
    manageProcessFlow("mapReadRpecies", "cropping map species", "align")
  })
  
  # List map legend species
  observeEvent(input$listCropped, {
    if(input$siteNumberMapsMatching != ''){
      #print(input$siteNumberMapsMatching)
      output$listCropped = renderUI({
        prepareImageView("/cropped_png/", input$siteNumberMapsMatching)
      })
    }
    else{
      output$listCropped = renderUI({
        prepareImageView("/cropped_png/", '.png')
      })
    }
  })
  
  
  ####################
  # 2.3 Crop species name of the page content #----------------------------------------------------------------------#
  ####################
  
  # Start Crop page species
  observeEvent(input$pageReadRpecies, {
    # call the function for cropping
    manageProcessFlow("pageReadRpecies", "read page species", "output")
  })
  
  
  ####################
  # 3. Points Matching  #----------------------------------------------------------------------#
  ####################
  
  # Start points detection with matching 
  observeEvent(input$pointMatching, {
    # call the function for cropping
    manageProcessFlow("pointMatching", "points matching", "pointMatching")
  })
  
  observeEvent(input$listPointsM, {
    if(input$siteNumberPointsMatching != ''){
      #print(input$siteNumberPointsMatching)
      output$listPM = renderUI({
        prepareImageView("/pointMatching_png/", input$siteNumberPointsMatching)
      })
    }
    else{
      output$listPM = renderUI({
        prepareImageView("/pointMatching_png/", '.png')
      })
    }
  })
  
  
  ####################
  # 3.1 Points Filtering  #----------------------------------------------------------------------#
  ####################
  # Start Process point filtering 
  
  observeEvent(input$pointFiltering, {
    # call the function for filtering
    manageProcessFlow("pointFiltering", "points filtering", "pointFiltering")
  })
  
  observeEvent(input$listPointsF, {
    if(input$siteNumberPointsMatching != ''){
      #print(input$siteNumberPointsMatching)
      output$listPF = renderUI({
        prepareImageView("/pointFiltering_png/", input$siteNumberPointsMatching)
      })
    }
    else{
      output$listPF = renderUI({
        prepareImageView("/pointFiltering_png/", '.png')
      })
    }
  })
  
  # List matching maps
  observeEvent(input$listMapsMatching2, {
    if(input$siteNumberPointsMatching != ''){
      output$listMapsMatching2 = renderUI({
        prepareImageView("/data/matching_png/", input$siteNumberPointsMatching)
      })
    }
    else{
      output$listMapsMatching2 = renderUI({
        prepareImageView("/data/matching_png/", '.png')
      })
    }
  })
  
  ####################
  # 3.2 Circle Detection  #----------------------------------------------------------------------#
  ####################
  # Process circle detection
  
  observeEvent(input$pointCircleDetection, {
    # call the function for circle detection
    manageProcessFlow("pointCircleDetection", "points circle detection", "pointCircleDetection")
    
  })
  
  observeEvent(input$listPointsCD, {
    if(input$siteNumberPointsMatching != ''){
      output$listPCD = renderUI({
        prepareImageView("/CircleDetection_png/", input$siteNumberPointsMatching)
      })
    }
    else{
      output$listPCD = renderUI({
        prepareImageView("/CircleDetection_png/", '.png')
      })
    }
    
  })
  
  
  ####################
  # 4. Masking #----------------------------------------------------------------------#
  ####################
  
  observeEvent(input$masking, {
    # call the function for filtering
    manageProcessFlow("masking", "masking white background", "masking")
    
  })
  
  
  ####################
  # 4.1 Masking centroids #----------------------------------------------------------------------#
  ####################
  
  observeEvent(input$maskingCentroids, {
    # call the function for filtering
    manageProcessFlow("maskingCentroids", "masking centroids", "maskingCentroids")
  })
  
  observeEvent(input$listMasks, {
    if(input$siteNumberMasks!= ''){
      output$listMS = renderUI({
        prepareImageView("/masking_png/", input$siteNumberMasks)
      })
    }
    else{
      output$listMS = renderUI({
        prepareImageView("/masking_png/", '.png')
      })
    }
  })
  
  observeEvent(input$listMasksB, {
    if(input$siteNumberMasks!= ''){
      output$listMSB = renderUI({
        prepareImageView("/masking_png/", input$siteNumberMasks)
      })
    }
    else{
      output$listMSB = renderUI({
        prepareImageView("/masking_black_png/", '.png')
      })
    }
  })
  
  observeEvent(input$listMasksCD, {
    if(input$siteNumberMasks!= ''){
      output$listMCD = renderUI({
        prepareImageView("/maskingCentroids/", input$siteNumberMasks)
      })
    }
    else{
      output$listMCD = renderUI({
        prepareImageView("/maskingCentroids/", '.png')
      })
    }
  })
  
  
  ####################
  # 5. Georeferencing #----------------------------------------------------------------------#
  ####################
  
  # Start
  # GCP points extraction
  observeEvent(input$pointextract, {
    current_out_dir <- outDir()
    #Processing georeferencing
    fname=paste0(workingDir, "/", "src/georeferencing/geo_points_extraction.py")
    source_python(fname)
    maingeopointextract(workingDir,current_out_dir, input$filterm)
    cat("\nSuccessfully executed")
  })
  
  observeEvent(input$georeferencing, {
    # call the function for filtering
    manageProcessFlow("georeferencing", "georeferencing", "georeferencing")
  })
  
  
  # Georeferencing list maps
  observeEvent(input$listGeoreferencing, {
    current_out_dir <- outDir()
    # Anzahl der Leaflet-Elemente, die Sie hinzufügen möchten
    # show start action message
    message=paste0("Process ", "Georeferencing", " is started on: ")
    shinyalert(text = paste(message, format(current_time(), "%H:%M:%S")), type = "info", showConfirmButton = FALSE, closeOnEsc = TRUE,
               closeOnClickOutside = FALSE, animation = TRUE)
    #current_out_dir <- "D:/test/output_2025-03-27_12-30-59/"
    listgeoTiffiles = list.files(paste0(current_out_dir, "/rectifying/maps"), full.names = T, pattern = paste0('.tif',input$siteNumberGeoreferencing))
    if( length(listgeoTiffiles) == 0) {
      listgeoTiffiles = list.files(paste0(current_out_dir, "/rectifying/maps"), full.names = T, pattern = '.tif')
    }
    num_leaflet_outputs_GEO <- length(listgeoTiffiles)
    
    # Liste der ursprunlichen map Files zum Vergleich mit den polygonizierten Maps
    listPng = list.files(paste0(workingDir, "/www/data/georeferencing_png/"), full.names = F, pattern = paste0('.png', input$siteNumberGeoreferencing))  #print(listPng)
    
    output$leaflet_outputs_GEO <- renderUI({
      #print( paste('00',input$siteNumberGeoreferencing,'map'))
      # Erstellen Sie eine Liste von Leaflet-Elementen
      leaflet_outputs_list <- lapply(1:num_leaflet_outputs_GEO, function(i) {
        leafletOutput(outputId = paste0("map_geo_", i))
      })
      
      # Verwenden Sie do.call, um die Liste der Leaflet-Elemente in UI auszugeben
      do.call(tagList, leaflet_outputs_list)
    })
    
    # Liste von Leaflet-Objektenlapply(seq_along(my_list), function(i) {
    leaflet_list_GEO <- lapply(seq_along(listgeoTiffiles), function(i) {
      #print(listgeoTiffiles[i])
      leaflet() %>%
        addTiles("Georeferencing") %>%
        addProviderTiles("OpenStreetMap.Mapnik") %>%
        addRasterImage(raster(listgeoTiffiles[i]), opacity = 0.7) %>%
        addControl(
          htmltools::div(
            p(listgeoTiffiles[i]),
          ),
          position = "bottomright"
        ) %>%
        addControl(
          htmltools::div(
            img(src = paste0("/data/georeferencing_png/",listPng[i]), width = 200, height = 200),
            tags$a(href = paste0("/data/georeferencing_png/",listPng[i]), listPng[i], target="_blank"),
          ),
          position = "bottomleft"
        )
    })
    
    # Ergebnisse in den Output-Variablen speichern
    
    leaflet_lists <- lapply(1:length(leaflet_list_GEO), function(i) {
      output[[paste0('map_geo_', i)]] <- renderLeaflet({ leaflet_list_GEO[[i]] })
    })
    
    cat("\nSuccessfully executed")
    # show end action message
    
    closeAlert(num = 0, id = NULL)
    shinyalert(text = paste("Georeferencing successfully executed!", format(current_time(), "%H:%M:%S")), 
               type = "info", showConfirmButton = TRUE, closeOnEsc = TRUE,
               closeOnClickOutside = TRUE, animation = TRUE)
  })
  
  observeEvent(input$georef_coords_from_csv, {
    # call the function for georeference extracted csv files mathematically
    manageProcessFlow("georef_coords_from_csv", "georeferencing", "georef_coords_from_csv")
  })
  
  
  
  ####################
  # 6. Polygonize #----------------------------------------------------------------------#
  ####################
  
  # Start
  observeEvent(input$polygonize, {
    # call the function for filtering
    manageProcessFlow("polygonize", "polygonize", "polygonize")
    
  }) 
  
  
  observeEvent(input$listPolygonize, ignoreInit = TRUE, {
    tryCatch({
      # 1) outDir holen und prüfen
      current_out_dir <- outDir()
      validate(
        need(nzchar(current_out_dir), "outDir() ist leer."),
        need(dir.exists(current_out_dir), paste("Ordner existiert nicht:", current_out_dir))
      )
      
      # 2) Basisordner für Shapefiles
      shp_dir <- file.path(current_out_dir, "polygonize", "pointFiltering")
      validate(need(dir.exists(shp_dir), paste("Shapefile-Ordner fehlt:", shp_dir)))
      
      # 3) Alle .shp einsammeln
      shp <- list.files(shp_dir, pattern = "\\.shp$", full.names = TRUE, recursive = FALSE)
      
      # 4) Nach Site-Nummer filtern (falls gesetzt) – auf Dateiname (basename) matchen
      site_pat <- if (!is.null(input$siteNumberPolygonize)) as.character(input$siteNumberPolygonize) else ""
      if (nzchar(site_pat)) {
        shp <- shp[grepl(site_pat, basename(shp), fixed = TRUE)]
      }
      
      # 5) "filtered" ausschließen (einfach & stabil)
      shp <- shp[!grepl("filtered", basename(shp), ignore.case = TRUE)]
      
      # 6) Ergebnis prüfen
      validate(need(length(shp) > 0, "Keine passenden Shapefiles gefunden."))
      
      # 7) PNG-Verzeichnis (statische Auslieferung unter www/data/…)
      png_dir_disk <- file.path(workingDir, "www", "data", "pointFiltering_png")
      validate(need(dir.exists(png_dir_disk), paste("PNG-Ordner fehlt:", png_dir_disk)))
      
      # Hilfsfunktion: für jedes Shapefile ein passendes PNG finden (gleicher Basename)
      pick_png_for_shp <- function(shp_path) {
        stem <- sub("\\.shp$", "", basename(shp_path))
        # Erlaube z. B. .png oder .PNG
        cand <- list.files(png_dir_disk, pattern = paste0("^", gsub("([.^$|()\\[\\]{}+*?\\\\])", "\\\\\\1", stem), "\\.(?i:png)$"),
                           full.names = FALSE)
        if (length(cand) > 0) cand[[1]] else NA_character_
      }
      
      # 8) Leaflet-Outputs dynamisch anlegen
      num_leaflet_outputs <- length(shp)
      
      output$leaflet_outputs_PL <- renderUI({
        leaflet_outputs_list <- lapply(seq_len(num_leaflet_outputs), function(i) {
          leafletOutput(outputId = paste0("listPL", i))
        })
        do.call(tagList, leaflet_outputs_list)
      })
      
      # 9) Karten erstellen
      leaflet_list_PL <- lapply(seq_along(shp), function(i) {
        shp_i <- shp[i]
        shp_name <- basename(shp_i)
        png_i <- pick_png_for_shp(shp_i)
        
        # Shapefile einlesen
        shape_data <- sf::st_read(shp_i, quiet = TRUE)
        
        # RGB→HEX (erwartet Spalten Red/Green/Blue in 0..255)
        rgb_to_hex <- function(r, g, b) {
          grDevices::rgb(r/255, g/255, b/255)  # default maxColorValue = 1 → Werte 0..1
        }
        
        # Optional: Falls Red/Green/Blue fehlen, fallback auf eine Farbe
        if (!all(c("Red","Green","Blue") %in% names(shape_data))) {
          shape_data$Red   <- 30
          shape_data$Green <- 144
          shape_data$Blue  <- 255
        }
        
        # UI-Schnipsel unten rechts (Dateiname)
        info_br <- htmltools::div(htmltools::p(shp_name))
        
        # UI-Schnipsel unten links (PNG-Vorschau + Link), nur wenn PNG vorhanden
        info_bl <- if (!is.na(png_i)) {
          htmltools::div(
            tags$img(src = file.path("/data/pointFiltering_png", png_i), width = 200, height = 200),
            tags$a(href = file.path("/data/pointFiltering_png", png_i), target = "_blank", png_i)
          )
        } else {
          htmltools::div(htmltools::em("Kein PNG gefunden."))
        }
        
        leaflet::leaflet() %>%
          leaflet::addTiles() %>%
          leaflet::addCircleMarkers(
            data = shape_data,
            color = ~rgb_to_hex(Red, Green, Blue),
            weight = 1,
            opacity = 0.9,
            fillOpacity = 0.5,
            radius = 5
          ) %>%
          leaflet::addControl(info_br, position = "bottomright") %>%
          leaflet::addControl(info_bl, position = "bottomleft")
      })
      
      # 10) Rendern
      invisible(lapply(seq_along(leaflet_list_PL), function(i) {
        output[[paste0("listPL", i)]] <- leaflet::renderLeaflet(leaflet_list_PL[[i]])
      }))
      
      # Optional: kurze Rückmeldung
      showNotification(paste("Gefunden:", num_leaflet_outputs, "Shapefile(s)."), type = "message")
      
    }, error = function(e) {
      message <- paste("Error in observeEvent(input$listPolygonize):", conditionMessage(e))
      shinyalert(text = message, type = "error")
    })
  })
  
  
  ####################
  # 7. Save the outputs #----------------------------------------------------------------------#
  ####################
  
  # Start
  observeEvent(input$startSpatialDataComputing, {
    # call the function for filteringg
    manageProcessFlow("spatial_data_computing", "spatial", "spatial")
  })
  
  observeEvent(input$spatialViewPF, {
    tryCatch({
      current_out_dir <- outDir()
      customMouseover <- JS(
        "function(event) { var layer = event.target;
      layer.bindPopup('Dies ist ein benutzerdefinierter Mouseover-Text').openPopup();}"
      )
      marker_data <- read.csv(paste0(current_out_dir, "/spatial_final_data_with_realXY.csv"), sep = ";", header = TRUE)
      #filtered_data <- marker_data[marker_data$Detectionmethod == "point_filtering", ]
      name_on_top = paste0(marker_data$species)#,": ", filtered_data$File,".png")
      name <- gsub("\\.tiff?$", ".png", marker_data$File)
      page <- sub(".*_(\\d{4})map_.*", "\\1.tif", name)
      page <- sub("\\.tiff?$", ".png", page)
      
      # Umwandeln der X_WGS84 und Y_WGS84 Spalten in numerische Werte
      marker_data$Real_X <- as.numeric(gsub(",", ".", marker_data$Real_X))
      marker_data$Real_Y <- as.numeric(gsub(",", ".", marker_data$Real_Y))
      
      # OpenStreetMap show
      output$mapSpatialViewPF <- renderLeaflet({
        leaflet() %>%
          addTiles() %>%
          addMarkers(
            data = marker_data,
            lat = ~Real_Y,
            lng = ~Real_X,
            label = name_on_top,
            labelOptions = labelOptions(
              direction = "auto",
              noHide = TRUE,
              onEachFeature = customMouseover  # Hier fügen Sie die benutzerdefinierte Mouseover-Funktion hinzu
            ),
            popup = ~paste0("<p><b>specie keyword on the map: ", marker_data$species, "</b></p><p><b>", marker_data$Title, "</b></p><a href='/data/matching_png/", name, "' target='_blank'>",
                            "<img src='/data/matching_png/", name, "' width='100' height='100'></a>",
                            "<a href='/data/pages/", page, "' target='_blank'>",
                            "<img src='/data/pages/", page, "' width='100' height='100'></a>")
          )
      })
      cat("\nSuccessfully executed")
    }, error = function(e) {
      showModal(
        modalDialog(
          title = "Error",
          paste("An error occurred:", e$message),
          easyClose = TRUE,
          footer = NULL
        )
      )
    })
  })
  
  
  observeEvent(input$spatialViewCD, {
    # IMPORTANT not remove!
    current_out_dir <- outDir()
    
    customMouseover <- JS(
      "function(event) {
        var layer = event.target;
        layer.bindPopup('Dies ist ein benutzerdefinierter Mouseover-Text').openPopup();
      }"
    )
    
    # Einlesen der Daten
    filtered_data <- read.csv(paste0(current_out_dir, "/spatial_final_data.csv"), sep = ";", header = TRUE)
    
    # Filtern der Daten
    #filtered_data <- marker_data[filtered_data$Detection.method == "circle_detection", ]
    
    # Anpassung der Daten für die Anzeige
    name_on_top <- paste0(filtered_data$species)
    name <- gsub("\\.tiff?$", ".png", filtered_data$File)
    page <- sub(".*_(\\d{4})map_.*", "\\1.tif", name)
    page <- sub("\\.tiff?$", ".png", page)
    
    # Umwandeln der X_WGS84 und Y_WGS84 Spalten in numerische Werte
    filtered_data$Real_X <- as.numeric(gsub(",", ".", filtered_data$Real_X))
    filtered_data$Real_Y <- as.numeric(gsub(",", ".", filtered_data$Real_Y))
    
    # Erstellen der Farben aus den RGB-Werten
    filtered_data$color <- rgb(filtered_data$Red, filtered_data$Green, filtered_data$Blue, maxColorValue = 255)
    # Debugging-Ausgabe
    print(head(filtered_data))
    print(sapply(filtered_data, class))
    output$mapSpatialViewCD <- renderLeaflet({
      leaflet() %>%
        addTiles() %>%
        addCircleMarkers(
          data = filtered_data,
          lat = ~Real_Y,
          lng = ~Real_X,
          color = ~color,
          radius = 2,  # Setzen Sie den Radius hier auf eine kleinere Zahl
          label = ~name_on_top,
          labelOptions = labelOptions(
            direction = "auto",
            noHide = TRUE
          ),
          popup = ~paste0(
            "<p><b>Specie keyword on the map: ", filtered_data$species, "</b></p>",
            "<p><b>", filtered_data$Title, "</b></p>",
            "<a href='/data/matching_png/", name, "' target='_blank'>",
            "<img src='/data/matching_png/", name, "' width='100' height='100'></a>",
            "<a href='/data/pages/", page, "' target='_blank'>",
            "<img src='/data/pages/", page, "' width='100' height='100'></a>"
          )
        )
    })
    cat("\nSuccessfully executed")
  })
  
  
  ####################
  # 8. Download the outputs #----------------------------------------------------------------------#
  ####################
  
  output$download_csv<- downloadHandler(
    
    filename = function() {
      "spatial_final_data.csv"
    },
    content = function(file) {
      current_out_dir <- outDir()
      csv_path <- paste0(current_out_dir, "/spatial_final_data.csv")
      if (file.exists(csv_path)) {
        file.copy(csv_path, file)
      } else {
        stop("Die Datei spatial_final_data.csv existiert nicht.")
      }
    }
    
  )
  
  ####################
  # 9. View CSV Data #----------------------------------------------------------------------#
  ####################
  observeEvent(input$viewCSV, {
    
    # call the function for filtering
    manageProcessFlow("view_csv", "view_csv", "view_csv")
    
  })
  
  
  
  ####################
  # FUNCTIONS       #----------------------------------------------------------------------#
  ####################
  
  # Function to manage the processing
  manageProcessFlow <- function(processing, allertText1, allertText2){
    
    current_out_dir <- outDir()
    # END IMPORTANT
    
    message=""
    message <- paste0("The process ", allertText1, " is started on: ")
    shinyalert(
      text = paste(message, format(current_time(), "%H:%M:%S")), 
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
        #outDir="D:/test/output_2025-09-18_13-08-43/"
        fname=paste0(workingDir, "/", "src/matching/map_matching.py")
        
        print("The processing template matching python script:")
        print(fname)
        source_python(fname)
        print("Threshold:")
        print(input$threshold_for_TM)
        print(outDir)
        
        print(input$sNumberPosition)
        print(input$matchingType)
        print(input$siteNumberMapsMatching)
        
        main_template_matching(workingDir, outDir, input$threshold_for_TM, input$sNumberPosition, input$matchingType, as.character(input$siteNumberMapsMatching))
        #main_template_matching(workingDir, outDir, 0.18, 1, 1, "0088.tif")
        
        findTemplateResult = paste0(outDir, "/maps/matching/")
        
        files<- list.files(findTemplateResult, full.names = TRUE, recursive = FALSE)
        convertTifToPngSave(paste0(outDir, "/maps/matching/"), paste0(workingDir, "/www/data/matching_png/"))
        
        countFiles = paste0(length(files),"")
        message=paste0("Ended on: ", 
                       format(current_time(), "%H:%M:%S \n"), " The number extracted outputs with threshold = ",
                       input$threshold_for_TM , " are \n", countFiles ," and saved in directory \n",findTemplateResult, 
                       "! \n High threshold values lead to few matchings, low values to many matchings.")
        
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
        align_images_directory(workingDir, current_out_dir)
        
        cat("\nSuccessfully executed")
        findTemplateResult = paste0(current_out_dir, "/maps/align/")
        files<- list.files(findTemplateResult, full.names = TRUE, recursive = FALSE)
        countFiles = paste0(length(files),"")
        
        # convert the tif images to png and show this on the plot
        convertTifToPngSave(paste0(current_out_dir, "/maps/align/"), paste0(workingDir, "/www/data/align_png/"))
        
        message=paste0("Ended on: ", 
                       format(current_time(), "%H:%M:%S \n"), " The number align maps ", " are \n", 
                       countFiles ," and saved in directory \n",findTemplateResult)
        
      }, error = function(e) {
        cat("An error occurred during alignMaps processing:\n")
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
        convertTifToPngSave(findTemplateResult, paste0(workingDir, "/www/data/readSpecies_png/"))
        
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
    
    
    if(processing == "pointMatching") {
      tryCatch({
        # Processing points matching
        fname=paste0(workingDir, "/", "src/matching/point_matching.py")
        print(" Processing point python script:")
        print(fname)
        source_python(fname)
        map_points_matching(workingDir, current_out_dir, input$threshold_for_PM)
        findTemplateResult = paste0(current_out_dir, "/maps/pointMatching/")
        print(findTemplateResult)
        cat("\nSuccessfully executed")
        files <- list.files(findTemplateResult, full.names = TRUE, recursive = FALSE)
        countFiles <- paste0(length(files), "")
        #current_out_dir = "D:/test/output_2024-07-12_08-18-21/"
        #workingDir = "D:/distribution_digitizer/"
        
        # convert the tif images to png and save in www
        convertTifToPngSave(findTemplateResult, paste0(workingDir, "/www/data/pointMatching_png/"))
      }, error = function(e) {
        cat("An error occurred during pointMatching processing:\n")
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
        convertTifToPngSave(findTemplateResult, paste0(workingDir, "/www/data/pointFiltering_png/"))
        
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
        
        convertTifToPngSave(findTemplateResult, paste0(workingDir, "/www/data/CircleDetection_png/"))
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
        
        convertTifToPngSave(findTemplateResult, paste0(workingDir, "/www/data/masking_png/"))
        
        findTemplateResult = paste0(current_out_dir, "/masking_black/")
        convertTifToPngSave(findTemplateResult, paste0(workingDir, "/www/data/masking_black_png/"))
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
        convertTifToPngSave(findTemplateResult, paste0(workingDir, "/www/data/maskingCentroids/"))
        
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
        convertTifToPngSave(findTemplateResult, paste0(workingDir, "/www/data/georeferencing_png/"))
        
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
        
        # copy the shape files into www directory
        for (f in shFiles) {
          # Source and destination file paths
          baseName = basename(f)
          destination_file <- paste0(workingDir, "/www/data/polygonize/", baseName)
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
          convertTifToPngSave(paste0(workingDir, "/data/input/pages/"),paste0(workingDir, "/www/data/pages/"))
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
    shinyalert(text = paste(message, format(current_time(), "%H:%M:%S"), "!\n Results are located at: " , current_out_dir ), type = "info", showConfirmButton = TRUE, closeOnEsc = TRUE,
               closeOnClickOutside = TRUE, animation = TRUE)
    
  }
  
  
  # save the last working directory
  onStop(function() {
    cat(workingDir)
    # fields<-c ("working_dir=")
    # text<-c(workingDir)
    # write.csv(text, file = "lastwd.csv" , col.names = F, row.names = fields, quote = F, append=T)
    # write.table(x, file = paste0(workingDir,"/lastwd.txt") ,sep = ",", col.names = NA)
  })
  
  # -----------------------------------------# 1. Step - Create templates #---------------------------------------------------------------------#
  #Function to show the ccrop process in the app 
  plot_png <- function(path, plot_brush, index, add=FALSE)
  {
    require('png')
    #fname=paste0(workingDir, "/", tempImage)
    fname=tempImage
    png = png::readPNG(fname, native=T) # read the file
    # this for tests png <- image_read('DD_shiny/0045.png')
    
    # get the resolution, [x, y]
    res = dim(png)[2:1] 
    # initialize an empty plot area if add==FALSE
    if (!add) 
      plot(1,1,xlim=c(1,res[1]),ylim=c(1,res[2]),asp=1,type='n',xaxs='i',yaxs='i',xaxt='n',yaxt='n',
           xlab='',ylab='',bty='n')
    img <- as.raster(readPNG(fname))
    # rasterImage(img,1,1,res[1],res[2])
    #grid.raster(img[1:600,1:500,]) wichtig img[y1:y2,x2:y2]
    x1 = plot_brush$xmin
    x2 = plot_brush$xmax
    y2 = plot_brush$ymin
    y1 = plot_brush$ymax
    grid.raster(img[y2:y1,x1:x2,])
  }
  
  # Render the image in the plot with given dynamical 10%
  output$plot <- renderImage({
    req(input$image)
    if (file.exists(input$image$datapath)) {
      temp <- image_read(input$image$datapath)
      file <- image_convert(temp, "png")
      temp_scale <- image_scale(file, paste0(scale,"%"))
      fname = paste0(workingDir, "/", tempImage)
      workingDir = workingDir
      image_write(temp_scale, path = fname, format = "png", )
      req(file)
      list(src = fname, alt="alternative text")
      
    } else {
      NULL
    }
    #only if input$image is given
    
    
  }, deleteFile = FALSE)
  
  
  ######
  # -----------------------------------------# Other functions #---------------------------------------------------------------------#
  ######
  
  prepareImageView <- function(dirName, index = "", range_str = "") {
    tryCatch({
      cat("📁 WorkingDir:", workingDir, "\n")
      cat("DEBUG raw dirName:", paste0("[", dirName, "]"), "\n")
      
      # 1) dirName säubern
      dirName <- trimws(dirName)
      dirName <- gsub("^/+","", dirName)
      dirName <- gsub("/+$","", dirName)
      if (dirName == "") dirName <- "data/matching_png"
      cat("DEBUG clean dirName:", dirName, "\n")
      
      # 2) FS-Pfad (mit www)
      pathToMatchingImages <- file.path(workingDir, "www", dirName)
      cat("DEBUG pathToMatchingImages:", pathToMatchingImages, "\n")
      if (!dir.exists(pathToMatchingImages)) {
        cat("WARN: directory does not exist\n")
        return(HTML("<p><i>Directory not found.</i></p>"))
      }
      
      # 3) Pattern
      if (is.null(index) || is.na(index) || index == "" || index == ".png") {
        pattern <- "\\.png$"
      } else {
        index_esc <- gsub("([\\.^$|()\\[\\]{}+*?\\\\])", "\\\\\\1", index)
        pattern <- paste0("^", index_esc, ".*\\.png$")
      }
      cat("DEBUG pattern:", pattern, "\n")
      
      # 4) Dateien holen (alphabetisch sortiert)
# 1) Alle PNGs holen
    files <- sort(list.files(pathToMatchingImages,
                             full.names = FALSE,
                             pattern = "\\.png$",
                             ignore.case = TRUE))
    n <- length(files)
    if (n == 0) return(HTML("<p><i>No images found.</i></p>"))

    # 2) Falls im index versehentlich ein Range steht → als range_str nutzen
    idx_raw <- trimws(index %||% "")
    if (idx_raw != "" && grepl("^\\d+\\s*-\\s*\\d*$|^\\d+\\s*$|^-\\s*\\d+$", idx_raw)) {
      range_str <- if (range_str == "") idx_raw else range_str
      index <- ""  # Index-Filter deaktivieren
    }

    # 3) Index-Filter OHNE Regex (Prefix-Match)
    if (!is.null(index) && nzchar(index) && index != ".png") {
      files <- files[startsWith(tolower(files), tolower(index))]
      n <- length(files)
      if (n == 0) return(HTML("<p><i>No images found.</i></p>"))
    }

    # 4) Range anwenden
    parse_range <- function(s, n_max) {
      s <- trimws(s %||% "")
      if (s == "") return(seq_len(n_max))
      if (grepl("^-?\\d+$", s)) {
        a <- max(1, min(as.integer(s), n_max)); return(a)
      }
      if (grepl("^\\d+\\s*-\\s*\\d+$", s)) {
        ab <- as.integer(unlist(strsplit(gsub("\\s*", "", s), "-")))
        a <- max(1, min(ab[1], n_max)); b <- max(1, min(ab[2], n_max))
        return(if (a<=b) seq(a,b) else seq(b,a))
      }
      if (grepl("^\\d+\\s*-$", s)) { a <- as.integer(gsub("\\D","",s)); a <- max(1,min(a,n_max)); return(seq(a,n_max)) }
      if (grepl("^-\\s*\\d+$", s)) { b <- as.integer(gsub("\\D","",s)); b <- max(1,min(b,n_max)); return(seq(1,b)) }
      seq_len(n_max)
    }
    `%||%` <- function(x,y) if (is.null(x)) y else x
    sel <- parse_range(range_str, n)

    # 5) Render
    lapply(sel, function(i){
      relPath <- file.path(dirName, files[i])
      HTML(paste0(
        '<div class="shiny-map-image">',
        '<img src="', relPath, '" style="width:100%;">',
        '<a href="', relPath, '" style="width:27%;" target="_blank">', files[i], '</a>',
        '</div>'
      ))
    })
  }, error=function(e){ cat("prepareImageView error:\n"); print(e); HTML("<p><i>Error while preparing image view.</i></p>") })
}
  
  
  # Function to list CSV files as links
  prepareCSVLinks <- function(dirName, index) {
    tryCatch({
      #pathToCSVFiles = paste0(workingDir, "/www", dirName)
      listCSVFiles = list.files(paste0(workingDir, "/data/output"), full.names = FALSE, pattern = index)
      
      display_link = function(i) {
        HTML(paste0('<div class="csv-link" > 
                  <a href="', paste0(dirName, listCSVFiles[i]), '" target="_blank">', listCSVFiles[i], '</a></div>'))
      }
      
      lapply(1:length(listCSVFiles), display_link)
    }, error = function(e) {
      cat("An error occurred during prepareCSVLinks processing:\n")
      print(e)
    })
  }
  
  
  # Function to convert tif images to png and save in /www directory
  convertTifToPngSave <- function(pathToTiffImages, pathToPngImages) {
    #print(pathToTiffImages)
    tryCatch({
      # Get list of tif files
      tifFiles <- list.files(pathToTiffImages, pattern = ".tif", recursive = FALSE)
      
      # Convert tif to png and save in the given path
      for (f in tifFiles) {
        tifFile <- paste0(pathToTiffImages, f)
        
        # Check if tif file exists
        if (file.exists(tifFile)) {
          #print(tifFile)
          tifImage <- image_read(tifFile)
          pngFile <- image_convert(tifImage, "png")
          pngName <- tools::file_path_sans_ext(f)
          fname <- paste0(pathToPngImages, pngName, ".png")
          image_write(pngFile, path = fname, format = "png")
        } else {
          cat("Error in convert tif to png: The file", tifFile, "does not exist.\n")
        }
      }
    }, error = function(e) {
      cat("An error occurred during convertTifToPngSave processing:\n")
      print(e)
    })
  }
  
  # -------------------------------------------------------------------
  # Function: prepare_base_output
  # -------------------------------------------------------------------
  # This function prepares the main "output" directory structure 
  # for storing processing results. It ensures that all required 
  # subdirectories exist before the workflow starts, so that 
  # intermediate and final results can be organized consistently.
  #
  # Arguments:
  #   base_path - the path to the base output directory
  #
  # Behavior:
  #   1. Validates the provided base_path (must not be empty).
  #   2. Creates the base output directory if it does not exist.
  #   3. Creates a predefined set of subdirectories for various 
  #      processing steps (e.g., final_output, georeferencing, maps).
  #   4. Creates additional nested subdirectories for specific folders:
  #        - "maps" → subfolders: align, csvFiles, matching, readSpecies, pointMatching
  #        - "georeferencing" → subfolders: maps, masks
  #        - "final_output", "maps", "masking_black", "polygonize", "rectifying" 
  #            → subfolders: circleDetection, pointFiltering
  #   5. If the provided base_path is empty, an error dialog is shown in the app.
  #   6. Any errors are caught and printed to the console for debugging.
  #
  # Usage:
  #   prepare_base_output(file.path(workingDir, "data/output"))
  # -------------------------------------------------------------------
  prepare_base_output <- function(base_path) {
    tryCatch({
      if (nchar(base_path) > 0) {
        
        # Create the main output directory if it does not exist
        if (!dir.exists(base_path)) {
          dir.create(base_path, recursive = TRUE)
        }
        
        # Define top-level directories
        directory_names <- c(
          "final_output", "georeferencing", "maps", "masking", 
          "masking_black", "output_shape", "pagerecords", 
          "polygonize", "rectifying"
        )
        
        for (dir_name in directory_names) {
          dir_path <- file.path(base_path, dir_name)
          dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
          
          # Special case: subfolders for "maps"
          if (dir_name == "maps") {
            sub_directory_names <- c("align", "csvFiles", "matching", "readSpecies", "pointMatching")
            for (sub_dir_name in sub_directory_names) {
              dir.create(file.path(dir_path, sub_dir_name), recursive = TRUE, showWarnings = FALSE)
            }
          }
          
          # Special case: subfolders for "georeferencing"
          if (dir_name == "georeferencing") {
            sub_directory_names <- c("maps", "masks")
            for (sub_dir_name in sub_directory_names) {
              dir.create(file.path(dir_path, sub_dir_name), recursive = TRUE, showWarnings = FALSE)
            }
          }
          
          # Common subfolders for selected directories
          if (dir_name %in% c("final_output", "maps", "masking_black", "polygonize", "rectifying")) {
            sub_directory_names <- c("circleDetection", "pointFiltering")
            for (sub_dir_name in sub_directory_names) {
              dir.create(file.path(dir_path, sub_dir_name), recursive = TRUE, showWarnings = FALSE)
            }
          }
        }
        
      } else {
        # Show error if no valid path was provided
        showModal(modalDialog(title = "Error", "Please provide a valid input directory path."))
        return()
      }
    }, error = function(e) {
      # Handle and report any errors
      cat("An error occurred during prepare_base_output processing:\n")
      print(e)
    })
  }
  
  
  
  # -------------------------------------------------------------------
  # Function: prepare_www_output
  # -------------------------------------------------------------------
  # This function prepares the "www" output directory that is used to 
  # store intermediate and final results of the processing steps. 
  # The created subdirectories organize images and data so that the user 
  # can easily navigate and view them inside the Shiny app.
  #
  # Arguments:
  #   www_output - the path to the "www/data" output directory
  #
  # Behavior:
  #   1. Removes any existing content of the www_output directory 
  #      (using unlink with recursive = TRUE).
  #   2. Creates the main www_output directory if it does not exist.
  #   3. Creates a predefined set of subdirectories for different 
  #      processing outputs (e.g., align_png, matching_png, polygonize).
  #   4. If the provided path is empty, shows an error dialog in the app.
  #   5. Any errors encountered are caught and printed to the console.
  #
  # Usage:
  #   prepare_www_output(file.path(workingDir, "www/data"))
  # -------------------------------------------------------------------
  prepare_www_output <- function(www_output) {
    tryCatch({
      # Remove existing folder and its contents
      unlink(www_output, recursive = TRUE)
      
      if (nchar(www_output) > 0) {
        # Create the main output folder if it does not exist
        if (!dir.exists(www_output)) {
          dir.create(www_output, recursive = TRUE)
        }
        
        # Predefined subdirectory names for organizing outputs
        directory_names <- c(
          "align_png", "CircleDetection_png", "readSpecies_png", "georeferencing_png", 
          "masking_black_png", "masking_circleDetection", "masking_png", "maskingCentroids",
          "matching_png", "pages", "pointFiltering_png", "pointMatching_png", "polygonize",
          "symbol_templates_png", "map_templates_png"
        )
        
        # Create each subdirectory inside the www_output folder
        for (sub_dir_name in directory_names) {
          sub_dir_path <- file.path(www_output, sub_dir_name)
          dir.create(sub_dir_path, recursive = TRUE, showWarnings = FALSE)
        }
      } else {
        # Show error if no valid directory path was provided
        showModal(modalDialog(title = "Error", "Please provide a valid input directory path."))
        return()
      }
    }, error = function(e) {
      # Handle and report any errors
      cat("An error occurred during prepare_www_output processing:\n")
      print(e)
    })
  }
  
})

  

