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

# NOTHING related to workingDir here!
# NOTHING related to loading config or shinyfields!
# NOTHING related to get_app_dir()

options(shiny.maxRequestSize = 500*1024^2)
Sys.setenv(TESSDATA_PREFIX = "C:/Program Files/Tesseract-OCR/tessdata")

processEventNumber <- 0

# These depend on workingDir → OK, because global.R created it
inputDir  <- file.path(workingDir, "data/input/")
tempImage <- "temp.png"
scale <- 20
rescale <- 100 / scale

# Setzt TESSDATA_PREFIX einmalig aus einem Pfad (aus Config),
# egal ob dieser auf .../Tesseract-OCR oder .../tessdata zeigt.
set_tessdata_prefix_once <- function(tess_path) {
  if (nzchar(Sys.getenv("TESSDATA_PREFIX"))) {
    message("TESSDATA_PREFIX already set to: ", Sys.getenv("TESSDATA_PREFIX"))
    return(invisible(FALSE))
  }
  if (is.null(tess_path) || !nzchar(tess_path)) {
    warning("No Tesseract path provided.")
    return(invisible(FALSE))
  }
  p <- normalizePath(tess_path, winslash = "/", mustWork = FALSE)
  # Wenn Pfad direkt auf 'tessdata' zeigt → eine Ebene hoch
  if (basename(p) %in% c("tessdata", "tessdata/")) {
    p <- dirname(p)
  }
  # Prüfen, ob unter p tatsächlich ein 'tessdata' Ordner existiert
  if (!dir.exists(file.path(p, "tessdata"))) {
    warning("No 'tessdata' directory found under: ", p)
    return(invisible(FALSE))
  }
  Sys.setenv(TESSDATA_PREFIX = p)
  message("TESSDATA_PREFIX set to: ", p)
  invisible(TRUE)
}


server <- shinyServer(function(input, output, session) {
  #addResourcePath("root", "D:/distribution_digitizer/www")
  
  options(shiny.autoreload = FALSE)
  current_tab <- reactiveVal("tab0")
  
  observeEvent(input$tablist, {
    current_tab(input$tablist)
  })
 

  # Erlaube Navigieren auf bestimmten Laufwerken/Roots
  #roots <- c(Home = "~", D = "D:/")  # passe an: C="C:/", Netzlaufwerke etc.
  # --- Input Directory ---
  # --- Input Directory ---
  observeEvent(input$dataInputDir_open, {
    dir_path <- input$dataInputDir
    if (nzchar(dir_path) && dir.exists(dir_path)) {
      # Variante mit system2 (bringt Explorer ins Vordergrund)
      shell(paste("start explorer /e,", shQuote(normalizePath(dir_path))), wait = FALSE)
    } else {
      showNotification("⚠️ Folder not found or invalid path.", type = "error")
    }
  })
  
  # --- Output Directory ---
  observeEvent(input$dataOutputDir_open, {
    dir_path <- input$dataOutputDir
    if (nzchar(dir_path) && dir.exists(dir_path)) {
      # Variante mit system2 (bringt Explorer ins Vordergrund)
      shell(paste("start explorer /e,", shQuote(normalizePath(dir_path))), wait = FALSE)
    } else {
      showNotification("⚠️ Folder not found or invalid path.", type = "error")
    }
  })
  
  
  
  # Dateiauswahl mit Startordner
  shinyFileChoose(
    input, "pick_file",
    roots = roots,
    defaultRoot = "D",
    defaultPath = "distribution_digitizer/www/data",
    filetypes = c("", "tif", "tiff", "png", "jpg")  # Filter optional
  )
  
  sel_files <- reactive({
    req(input$pick_file)
    parseFilePaths(roots, input$pick_file)$datapath
  })
  
  output$file_out <- renderPrint(sel_files())
  
  
  open_dir <- function(path) {
    p <- normalizePath(path, winslash = "/", mustWork = FALSE)
    if (.Platform$OS.type == "windows") {
      shell.exec(p)                # Windows: Explorer
    } else if (Sys.info()[["sysname"]] == "Darwin") {
      system2("open", p)           # macOS: Finder
    } else {
      system2("xdg-open", p)       # Linux: Dateimanager
    }
  }
  
  open_dir <- function(path) {
    p <- normalizePath(path, winslash = "/", mustWork = FALSE)
    
    if (.Platform$OS.type == "windows") {
      shell.exec(p)
    } else if (Sys.info()[["sysname"]] == "Darwin") {
      system2("open", p)
    } else {
      system2("xdg-open", p)
    }
  }

  observeEvent(input$open_output, {
    
    # Template-Ordner bestimmen (z. B. 1 oder 2)
    template_dir <- file.path(outDir(), input$map_type)
    
    # Falls nicht existiert → Meldung
    if (!dir.exists(template_dir)) {
      showNotification(
        paste("Ordner existiert nicht:", template_dir),
        type = "error", duration = 5
      )
      return()
    }
    
    open_dir(template_dir)
  })
  
  
  set_tessdata_prefix_once(config$tesseract_path)
  # prüfen:
  Sys.getenv("TESSDATA_PREFIX")
  
  # ganz oben im server:
  outDir <- reactiveVal(NULL)
  # Restore output directory from config.csv
  if (!is.null(config$dataOutputDir) && nzchar(config$dataOutputDir)) {
    restored <- normalizePath(config$dataOutputDir, winslash = "/", mustWork = FALSE)
    outDir(restored)
    message("RESTORED outDir() = ", restored)
  }
  
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
 
  # Hilfsfunktion
  to_chr <- function(x) if (is.null(x) || is.na(x)) "" else as.character(x)
  
  observeEvent(input$saveConfig, ignoreInit = TRUE, {
    
    tryCatch({
      # ---------- VORPRÜFUNGEN ----------
      req(nzchar(input$dataInputDir), dir.exists(input$dataInputDir))
      req(nzchar(input$dataOutputDir))
      
      # optional: vorherige Meldungen leeren
      output$message <- renderPrint(NULL)
      
      required1 <- c("pages", "templates")
      folders1  <- list.dirs(input$dataInputDir, full.names = FALSE, recursive = FALSE)
      if (!all(required1 %in% folders1)) {
        stop(sprintf("Missing folders in dataInputDir: %s", paste(setdiff(required1, folders1), collapse = ", ")))
      }
      
      #required2 <- c("align_ref", "maps", "symbols", "geopoints")
      #folders2  <- list.dirs(file.path(input$dataInputDir, "templates"), full.names = FALSE, recursive = FALSE)
      #if (!all(required2 %in% folders2)) {
      #  stop(sprintf("Missing template folders: %s", paste(setdiff(required2, folders2), collapse = ", ")))
      #}
      
      # ---------- AUSGABEORDNER & CONFIG-PFAD ----------
      timestamp <- format(Sys.time(), "%Y-%m-%d_%H-%M-%S")
      run_out <- file.path(input$dataOutputDir, paste0("output_", timestamp))
      run_out <- strip_trailing(run_out)
      run_out <- pretty_path(run_out)
      prepare_base_output(run_out,  nMapTypes = as.integer(input$nMapTypes))
      prepare_www_output(
        workingDir,
        file.path(workingDir, "app", "www", "output"),
        nMapTypes = as.integer(input$nMapTypes)
      )
      
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
        nMapTypes      = to_chr(input$nMapTypes),
        dataInputDir   = to_chr(input$dataInputDir),
        dataOutputDir  = run_out,
        pFormat        = to_chr(input$pFormat),
        pColor         = to_chr(input$pColor)
      )
      
      df <- data.frame(key = names(cfg), value = unname(unlist(cfg, use.names = FALSE)), stringsAsFactors = FALSE)
      
      # ---------- SCHREIBEN ----------
      write.table(df, cfg_path, sep = ";", row.names = FALSE, col.names = FALSE, quote = FALSE)
      if (!file.exists(cfg_path)) stop("Config file not found after write: ", cfg_path)
      
      # ---------- REAKTIVEN STATE SETZEN ----------
      outDir(run_out)
      isolate({
        freezeReactiveValue(input, "dataOutputDir")
        updateTextInput(session, "dataOutputDir", value = outDir())
      })
      Sys.sleep(0.5)
      # ---------- ERFOLGSMODAL ----------
      showModal(modalDialog(
        title = span("✅ Configuration saved successfully"),
        tags$div(
          style = "font-size:15px; line-height:1.5;",
          "All configuration data were saved successfully.",
          tags$br(),
          tags$br(),
          "If this is your first setup, please make sure that all ",
          tags$b(".tif"), " pages were converted into ", tags$b(".png"),
          " and copied into the ", tags$code("www/pages"), " directory.",
          tags$br(),
          "This ensures all pages will be accessible later in the app."
        ),
        easyClose = TRUE,
        footer = modalButton("Close")
      ))
      
    })
    shinyjs::show("open_output")
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
    plot_png(input$plot_brush)
  })
  
  # Show hint only when cropped preview (plot1) is visible
  output$showCropHint <- reactive({
    # show only if brush exists and image loaded
    !is.null(input$plot_brush) && !is.null(input$image)
  })
  outputOptions(output, "showCropHint", suspendWhenHidden = FALSE)
  
  # Function to save the cropped tepmlate map image
  output$saveTemplate <- downloadHandler(
    
    # ✔ Nur der Dateiname, ohne Pfad!
    filename = function() {
      paste0("map_", input$imgIndexTemplate, ".tif")
    },
    
    content = function(file) {
      
      # ---- Crop Koordinaten ----
      x1 <- input$plot_brush$xmin
      x2 <- input$plot_brush$xmax
      y2 <- input$plot_brush$ymin
      y1 <- input$plot_brush$ymax
      
      tempI <- image_read(input$image$datapath)
      
      width  <- (x2*rescale - x1*rescale)
      height <- (y1*rescale - y2*rescale)
      
      geometrie <- paste0(width, "x", height, "+", x1*rescale, "+", y2*rescale)
      
      tempI <- image_crop(tempI, geometrie)
      
      # ---- Speicherort definieren ----
      save_dir <- file.path(workingDir, "output", "templates", "maps")
      
      if (!dir.exists(save_dir)) {
        dir.create(save_dir, recursive = TRUE)
      }
      
      # finaler Dateipfad
      save_path <- file.path(save_dir, paste0("map_", input$imgIndexTemplate, ".tif"))
      
      # ---- Speichern ----
      image_write(tempI, save_path, format = "tif")
      
      # ---- zurück an den Download-Handler ----
      file.copy(save_path, file)
      
      # ---- Index hochzählen ----
      updateNumericInput(session, "imgIndexTemplate", value = input$imgIndexTemplate + 1)
    }
  )
  
  
  observeEvent(input$listMTemplates, {
    output$listMapTemplates = renderUI({
      # Check if the directory already exists
      findTemplateResult = paste0(workingDir, "/data/input/templates/maps/")
      convertTifToPngSave(
        findTemplateResult, 
        file.path(workingDir, "app", "www", "output", "map_templates_png")
      )
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
      convertTifToPngSave(
        findTemplateResult, 
        file.path(workingDir, "app", "www", "output", "symbol_templates_png")
      )
      prepareImageView("/symbol_templates_png/", '.png')
    })
  })
  
  ####################
  # 2. Maps matching #----------------------------------------------------------------------#
  ####################
  
  # START th template matching 
  observeEvent(input$templateMatching, {
    current_out_dir <- outDir()
    # Falls leer → rotes Feld + Meldung + Abbruch
    if (is.null(input$range_matching) || trimws(input$range_matching) == "") {
      
      shinyjs::runjs("$('#range_matching').css('border-color', 'red')")
      output$range_warning <- renderText("⚠️ Please fill in 'range matching' before starting.")
      
      return()  # ❌ stoppe hier – kein Matching!
    }
    
    # Wenn alles OK → Standardfarbe + Hinweis entfernen
    shinyjs::runjs("$('#range_matching').css('border-color', '')")
    output$range_warning <- renderText("")
    # call the function for map matching 
    manageProcessFlow(
      processing    = "mapMatching",
      allertText1   = "map matching",
      allertText2   = "matching",
      input         = input,
      session       = session,
      current_out_dir = current_out_dir     # << HIER!
    )
  })
  
  observeEvent(input$listMatchingButton, {
    output$listMaps <- renderUI({
      prepareImageView(
        dirName   = "matching_png",
        map_type  = input$map_type,
        range_str = input$range_list
      )
    })
  })
  
  observeEvent(input$showRecords, {
    wd <- if (is.function(workingDir)) workingDir() else workingDir
    csv <- file.path(wd, "www", "records.csv")
    
    output$records_tbl <- DT::renderDataTable({
      validate(need(file.exists(csv), "records.csv not found yet."))
      # Trenner automatisch erkennen (, oder ;)
      first <- readLines(csv, n = 1, warn = FALSE)
      sep <- if (grepl(";", first, fixed = TRUE)) ";" else ","
      df <- utils::read.table(csv, header = TRUE, sep = sep, quote = "",
                              stringsAsFactors = FALSE, check.names = FALSE, comment.char = "")
      DT::datatable(df, options = list(pageLength = 25, scrollX = TRUE), rownames = FALSE)
    })
  })
  
  ####################
  # 2.1 Maps align #----------------------------------------------------------------------#
  ####################
  
  # Start Align maps 
  observeEvent(input$alignMaps, {
     current_out_dir <- outDir()
    # Falls leer → rotes Feld + Meldung + Abbruch
    if (is.null(input$range_matching) || trimws(input$range_matching) == "") {
      
      shinyjs::runjs("$('#range_matching').css('border-color', 'red')")
      output$range_warning <- renderText("⚠️ Please fill in 'range matching' before starting.")
      
      return()  # ❌ stoppe hier – kein Matching!
    }
    
    # Wenn alles OK → Standardfarbe + Hinweis entfernen
    shinyjs::runjs("$('#range_matching').css('border-color', '')")
    output$range_warning <- renderText("")
    # call the function for align maps 
    manageProcessFlow(
      processing    = "alignMaps",
      allertText1   = "align maps",
      allertText2   = "allign",
      input         = input,
      session       = session,
      current_out_dir = current_out_dir     # << HIER!
    ) 
  })
  
  # List align maps
  observeEvent(input$listAlignButton, {
    output$listMaps <- renderUI({
      prepareImageView(
        dirName   = "align_png",
        map_type  = input$map_type,
        range_str = input$range_list
      )
    })
  })
  

  
  ####################
  # 2. Points Matching  #----------------------------------------------------------------------#
  ####################
  
  # Start points detection with matching 
  observeEvent(input$pointMatching, {
    current_out_dir <- outDir()
    # call the function for cropping
    manageProcessFlow(
      processing    = "pointMatching",
      allertText1   = "points matching",
      allertText2   = "pointMatching",
      input         = input,
      session       = session,
      current_out_dir = current_out_dir     # << HIER!
    ) 
  })
  
  observeEvent(input$listPointsM, {
    if(input$siteNumberPointsMatching != ''){
      #print(input$siteNumberPointsMatching)
      output$listPM = renderUI({
        prepareImageView("/output/pointMatching_png/", input$siteNumberPointsMatching)
      })
    }
    else{
      output$listPM = renderUI({
        prepareImageView("/output/pointMatching_png/", '.png')
      })
    }
  })
  
  
  
  ####################
  # 2.1 Points Filtering  #----------------------------------------------------------------------#
  ####################
  # Start Process point filtering 
  
  observeEvent(input$pointFiltering, {
    # call the function for filtering
    #manageProcessFlow("pointFiltering", "points filtering", "pointFiltering")
    current_out_dir <- outDir()
    # call the function for cropping
    manageProcessFlow(
      processing    = "pointFiltering",
      allertText1   = "points filtering",
      allertText2   = "pointFiltering",
      input         = input,
      session       = session,
      current_out_dir = current_out_dir     # << HIER!
    )
  })
  
  observeEvent(input$listPointsF, {
    if(input$siteNumberPointsMatching != ''){
      #print(input$siteNumberPointsMatching)
      output$listPF = renderUI({
        prepareImageView("/output/pointFiltering_png/", input$siteNumberPointsMatching)
      })
    }
    else{
      output$listPF = renderUI({
        prepareImageView("/output/pointFiltering_png/", '.png')
      })
    }
  })
  
  # List matching maps
  observeEvent(input$listMapsMatching2, {
    if(input$siteNumberPointsMatching != ''){
      output$listMapsMatching2 = renderUI({
        prepareImageView("/output/matching_png/", input$siteNumberPointsMatching)
      })
    }
    else{
      output$listMapsMatching2 = renderUI({
        prepareImageView("/output/matching_png/", '.png')
      })
    }
  })
  
  
  ####################
  # 4. Masking #----------------------------------------------------------------------#
  ####################
  
  observeEvent(input$masking, {
    # call the function for filtering
    manageProcessFlow(
      processing = "masking",
      allertText1 = "masking white background",
      allertText2 = "masking",
      input = input,  # ✅ input muss übergeben werden
      session = session,
      current_out_dir = outDir()
    )
  })
  
  ####################
  # 4.1 Masking centroids #----------------------------------------------------------------------#
  ####################
  
  
  observeEvent(input$maskingCentroids, {
    # call the function for filtering
    manageProcessFlow(
      processing = "maskingCentroids",
      allertText1 = "masking centroids",
      allertText2 = "maskingCentroids",
      input = input,  # ✅ input muss übergeben werden
      session = session,
      current_out_dir = outDir()
    )
  })
  
  observeEvent(input$listMasks, {
    if(input$siteNumberMasks!= ''){
      output$listMS = renderUI({
        prepareImageView("/output/masking_png/", input$siteNumberMasks)
      })
    }
    else{
      output$listMS = renderUI({
        prepareImageView("/output/masking_png/", '.png')
      })
    }
  })
  
  observeEvent(input$listMasksB, {
    if(input$siteNumberMasks!= ''){
      output$listMSB = renderUI({
        prepareImageView("/output/masking_png/", input$siteNumberMasks)
      })
    }
    else{
      output$listMSB = renderUI({
        prepareImageView("/output/masking_black_png/", '.png')
      })
    }
  })
  
  observeEvent(input$listMasksCD, {
    if(input$siteNumberMasks!= ''){
      output$listMCD = renderUI({
        prepareImageView("/output/maskingCentroids/", input$siteNumberMasks)
      })
    }
    else{
      output$listMCD = renderUI({
        prepareImageView("/output/maskingCentroids/", '.png')
      })
    }
  })
  
  ####################
  # 2.2 Circle Detection  #----------------------------------------------------------------------#
  ####################
  # Process circle detection
  
  observeEvent(input$pointCircleDetection, {
    # call the function for circle detection
    manageProcessFlow("pointCircleDetection", "points circle detection", "pointCircleDetection")
    
  })
  
  observeEvent(input$listPointsCD, {
    if(input$siteNumberPointsMatching != ''){
      output$listPCD = renderUI({
        prepareImageView("/output/CircleDetection_png/", input$siteNumberPointsMatching)
      })
    }
    else{
      output$listPCD = renderUI({
        prepareImageView("/output/CircleDetection_png/", '.png')
      })
    }
    
  })
  
  ####################
  # 3.2 Crop map legend species#----------------------------------------------------------------------#
  ####################
  
  # Start read  legend species
  observeEvent(input$mapReadRpecies, {
    # call the function for filtering
    manageProcessFlow(
      processing = "mapReadRpecies",
      allertText1 = "cropping map species",
      allertText2 = "align",
      input = input,  # ✅ input muss übergeben werden
      session = session,
      current_out_dir = outDir()
    )
  })
  
  # List map legend species
  observeEvent(input$listCropped, {
    if(input$siteNumberMapsMatching != ''){
      #print(input$siteNumberMapsMatching)
      output$listCropped = renderUI({
        prepareImageView("/output/cropped_png/", input$siteNumberMapsMatching)
      })
    }
    else{
      output$listCropped = renderUI({
        prepareImageView("/output/cropped_png/", '.png')
      })
    }
  })
  
  
  ####################
  # 3.3 Crop species name of the page content #----------------------------------------------------------------------#
  ####################
  
  # Start Crop page species
  observeEvent(input$pageReadRpecies, {
    # call the function for cropping
    manageProcessFlow("pageReadRpecies", "read page species", "output")
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
    shinyalert(text = paste(message, format(Sys.time(), "%H:%M:%S")), type = "info", showConfirmButton = FALSE, closeOnEsc = TRUE,
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
    shinyalert(text = paste("Georeferencing successfully executed!", format(Sys.time(), "%H:%M:%S")), 
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
  plot_png <- function(plot_brush) {
    require('png')
    fname <- tempImage
    if (!file.exists(fname)) return()
    
    img <- as.raster(png::readPNG(fname))
    res <- dim(img)[2:1]
    
    if (is.null(plot_brush) ||
        any(is.na(c(plot_brush$xmin, plot_brush$xmax, plot_brush$ymin, plot_brush$ymax)))) {
      plot(1, 1, type = "n", xlim = c(1, res[1]), ylim = c(1, res[2]),
           xlab = "", ylab = "", asp = 1, axes = FALSE)
      text(mean(res[1]), mean(res[2]), "Draw a crop area in the left image", col = "gray40")
      return()
    }
    
    x1 <- round(plot_brush$xmin)
    x2 <- round(plot_brush$xmax)
    y1 <- round(plot_brush$ymax)
    y2 <- round(plot_brush$ymin)
    
    x1 <- max(1, min(x1, res[1]))
    x2 <- max(1, min(x2, res[1]))
    y1 <- max(1, min(y1, res[2]))
    y2 <- max(1, min(y2, res[2]))
    
    if (x2 - x1 < 2 || y1 - y2 < 2) {
      plot(1, 1, type = "n", xlim = c(1, res[1]), ylim = c(1, res[2]),
           xlab = "", ylab = "", asp = 1, axes = FALSE)
      text(mean(res[1]), mean(res[2]), "Selection too small", col = "gray40")
      return()
    }
    
    plot(1, 1, xlim = c(1, x2 - x1), ylim = c(1, y1 - y2),
         asp = 1, type = "n", xaxs = "i", yaxs = "i",
         xaxt = "n", yaxt = "n", xlab = "", ylab = "", bty = "n")
    
    grid::grid.raster(img[y2:y1, x1:x2, ])
  }
  
  
  
  # Render the image in the plot with given dynamical 10%
  output$plot <- renderImage({
    
    req(input$image)
    
    # Lade und skaliere das Bild
    img <- image_read(input$image$datapath)
    img <- image_convert(img, "png")
    img <- image_scale(img, paste0(scale, "%"))
    
    # Speichere IMMER in app/temp.png
    temp_path <- file.path(getwd(), tempImage)
    image_write(img, path = temp_path, format = "png")
    
    list(src = temp_path, alt = "uploaded image")
    
  }, deleteFile = FALSE)
    #only if input$image is given
    
  
  
  ######
  # -----------------------------------------# Other functions #---------------------------------------------------------------------#
  ######
  
  # --- Helper ---------------------------------------------------------------
  
  sanitize_dirname <- function(dirName, default = "data/matching_png") {
    dn <- if (is.null(dirName)) "" else trimws(dirName)
    dn <- gsub("^/+","", dn)
    dn <- gsub("/+$","", dn)
    if (dn == "") default else dn
  }
  
  # "1", "1-5", "3-", "-4" -> Indizes (1-basiert, automatisch begrenzt)
  parse_range_indices <- function(range_str, n_max) {
    s <- if (is.null(range_str)) "" else trimws(range_str)
    if (!nzchar(s)) return(seq_len(n_max))                 # leer -> alle
    is_int <- function(x) grepl("^-?\\d+$", x)
    
    if (is_int(s)) {
      a <- max(1, min(as.integer(s), n_max)); return(a)
    }
    if (grepl("^\\d+\\s*-\\s*\\d+$", s)) {
      ab <- as.integer(unlist(strsplit(gsub("\\s*", "", s), "-")))
      a <- max(1, min(ab[1], n_max)); b <- max(1, min(ab[2], n_max))
      return(if (a <= b) seq(a,b) else seq(b,a))
    }
    if (grepl("^\\d+\\s*-$", s)) {
      a <- as.integer(gsub("\\D", "", s)); a <- max(1, min(a, n_max))
      return(seq(a, n_max))
    }
    if (grepl("^-\\s*\\d+$", s)) {
      b <- as.integer(gsub("\\D", "", s)); b <- max(1, min(b, n_max))
      return(seq(1, b))
    }
    seq_len(n_max)  # Fallback
  }
  
  prepareImageView <- function(dirName = "matching_png",
                               map_type = "1",
                               range_str = "") {
    tryCatch({
      
      cat("\n====== prepareImageView ======\n")
      cat("INPUT  dirName   =", dirName, "\n")
      cat("INPUT  map_type  =", map_type, "\n")
      cat("INPUT  range_str =", range_str, "\n")
      
      # -----------------------------
      # Normalize parameters
      # -----------------------------
      dirName_clean  <- sanitize_dirname(dirName)
      map_type_clean <- sanitize_dirname(map_type)
      
      cat("CLEAN  dirName   =", dirName_clean, "\n")
      cat("CLEAN  map_type  =", map_type_clean, "\n")
      
      # -----------------------------
      # Build full filesystem path
      # www/data/<map_type>/<dirName>/
      # -----------------------------
      fs_dir <- file.path(workingDir, "app", "www", "output",
                          map_type_clean, dirName_clean)
      
      cat("FS DIR =", fs_dir, "\n")
      
      if (!dir.exists(fs_dir)) {
        return(HTML(
          paste0("<p><i>Directory not found: ", fs_dir, "</i></p>")
        ))
      }
      
      # -----------------------------
      # Read PNG files
      # -----------------------------
      files <- sort(list.files(fs_dir,
                               pattern = "\\.png$",
                               full.names = FALSE))
      
      if (length(files) == 0) {
        return(HTML("<p><i>No images found.</i></p>"))
      }
      
      # -----------------------------
      # Determine selection range
      # -----------------------------
      sel <- parse_range_indices(range_str, length(files))
      
      # -----------------------------
      # Build image preview HTML
      # -----------------------------
      lapply(sel, function(i) {
        
        # Shiny-relative paths (served via addResourcePath)
        rel_img  <- file.path("output", map_type_clean,
                              dirName_clean, files[i])
        
        # Extract page number from filename
        # Example: 0039_map_1_... → take chars 8–11
        # 🔥 Seitenzahl (erste 4 Ziffern) extrahieren
        # 0043_map_1_xxx → 0043
        # --- Extract correct 4-digit page number (e.g., 0039) ---
        page_number <- regmatches(files[i], regexpr("[0-9]{4}", files[i]))
        
        # --- Build correct link to the corresponding page PNG ---
        page_png <- file.path( "pages", paste0(page_number, ".png"))
        
        HTML(paste0(
          '<div class="shiny-map-image">',
          '  <a href="', rel_img, '" target="_blank">',
          '    <img src="', rel_img,
          '" style="width:100%;">',
          '  </a>',
          '  <p><a href="', page_png,
          '" target="_blank">see original page</a></p>',
          '</div>'
        ))
      })
      
    }, error = function(e) {
      print(e)
      HTML("<p><i>Error while preparing image view.</i></p>")
    })
  }
  
  
 
  observe({
    isolate({
      if (!is.null(current_tab())) {
        updateTabItems(session, "tablist", selected = current_tab())
      }
    })
  })
  
   
})

  

