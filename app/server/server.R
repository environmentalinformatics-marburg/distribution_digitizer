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

py_config()
library(sf)

options(shiny.maxRequestSize = 500*1024^2)
processEventNumber <- 0
inputDir  <- file.path(workingDir, "data/input/")
tempImage <- "temp.png"
scale <- 20
rescale <- 100 / scale

source("server/book_structure_training_server.R")
source("server/map_matching_server.R", local = TRUE)
source("server/species_distribution_server.R", local = TRUE)
source("server/species_reading_server.R", local = TRUE)
source("server/georeferencing_server.R")
source("server/pipeline_server.R")
source("server/points_matching_server.R", local = TRUE)
source("server/masking_server.R", local = TRUE)

server <- shinyServer(function(input, output, session) {
  missingConfigFields <- reactive({
    required <- c(
      title = "Book Title", author = "Author", pYear = "Publication Year",
      tesserAct = "Tesseract Path",
      speciesRepresentation = "Points / symbols or Contours / areas",
      speciesNameSource = "Species name source (Read Species tab)",
      dataInputDir = "Input Directory", dataOutputDir = "Output Directory"
    )
    missing <- vapply(names(required), function(id) {
      value <- input[[id]]
      if (length(value) != 1L || is.na(value) || !nzchar(trimws(value))) return(TRUE)
      (id == "speciesRepresentation" && !value %in% c("point", "contour")) ||
        (id == "speciesNameSource" && !value %in% c("legend", "regions"))
    }, logical(1))
    unname(required[missing])
  })

  output$configRequiredWarning <- renderUI({
    missing <- missingConfigFields()
    if (!length(missing)) return(NULL)
    tags$div(
      class = "dd-config-required-warning", role = "status", `aria-live` = "polite",
      tags$strong("Please complete the required fields before saving:"),
      tags$ul(lapply(missing, tags$li))
    )
  })

  observe({
    shinyjs::toggleState("saveConfig", condition = length(missingConfigFields()) == 0L)
  })

  currentSpeciesRepresentation <- reactive({
    if (!is.null(input$speciesRepresentation) && nzchar(input$speciesRepresentation)) {
      input$speciesRepresentation
    } else {
      config$speciesRepresentation
    }
  })

  species_distribution_server(input = input, output = output, session = session, current_out_dir = outDir())
  cat("### species_distribution_server STARTED ###\n")
  restoredSpeciesNameSource <- reactiveVal(NULL)
  species_reading_server(input = input, output = output, session = session, workingDir = workingDir, current_out_dir = outDir(), restoredSpeciesNameSource = restoredSpeciesNameSource)
  cat("### read_species__server STARTED ###\n")
  options(shiny.autoreload = FALSE)
  current_tab <- reactiveVal("tab0")
  observeEvent(input$tablist, { current_tab(input$tablist) })

  observeEvent(input$dataInputDir_open, {
    dir_path <- input$dataInputDir
    if (nzchar(dir_path) && dir.exists(dir_path)) {
      shell(paste("start explorer /e,", shQuote(normalizePath(dir_path))), wait = FALSE)
    } else {
      showNotification("⚠️ Folder not found or invalid path.", type = "error")
    }
  })

  observeEvent(input$dataOutputDir_open, {
    dir_path <- input$dataOutputDir
    if (nzchar(dir_path) && dir.exists(dir_path)) {
      shell(paste("start explorer /e,", shQuote(normalizePath(dir_path))), wait = FALSE)
    } else {
      showNotification("⚠️ Folder not found or invalid path.", type = "error")
    }
  })

  pipeline_server(input = input, output = output, session = session, workingDir = workingDir, info = info, shinyfields2 = shinyfields2)

  shinyFileChoose(
    input, "pick_file",
    roots = roots,
    defaultRoot = "D",
    defaultPath = "distribution_digitizer/www/data",
    filetypes = c("", "tif", "tiff", "png", "jpg")
  )

  sel_files <- reactive({
    req(input$pick_file)
    parseFilePaths(roots, input$pick_file)$datapath
  })
  output$file_out <- renderPrint(sel_files())

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
    output_dir <- outDir()
    if (is.null(output_dir) || !nzchar(output_dir) || !dir.exists(output_dir)) {
      showNotification(paste("Ordner existiert nicht:", output_dir), type = "error", duration = 5)
      return()
    }
    open_dir(output_dir)
  })
  
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
      restored_source <- if (isTRUE(cfg$speciesNameSource %in% c("legend", "regions"))) cfg$speciesNameSource else ""
      restoredSpeciesNameSource(restored_source)
      updateRadioButtons(session, "speciesNameSource", selected = restored_source)
      # Restore the latest saved representation for every new browser session.
      if (isTRUE(cfg$speciesRepresentation %in% c("point", "contour"))) {
        updateRadioButtons(session, "speciesRepresentation", selected = cfg$speciesRepresentation)
      }
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
    # Also reject incomplete submissions on the server before any files are written.
    missing <- missingConfigFields()
    if (length(missing)) {
      showNotification(
        paste("Please complete the required fields:", paste(missing, collapse = ", ")),
        type = "warning", duration = 8
      )
      return()
    }
    
    tryCatch({
      # ---------- VORPRÜFUNGEN ----------
      if (is.null(input$speciesRepresentation) || !nzchar(input$speciesRepresentation)) {
        showNotification(
          "Please choose how species distributions are represented before saving.",
          type = "error",
          duration = 8
        )
        return()
      }
      if (is.null(input$dataInputDir) || !nzchar(input$dataInputDir) || !dir.exists(input$dataInputDir)) {
        showNotification(
          "Please provide a valid input folder.",
          type = "error",
          duration = 8
        )
        return()
      }
      required1 <- c("pages", "templates")
      folders1 <- list.dirs(input$dataInputDir, full.names = FALSE, recursive = FALSE)
      missing1 <- setdiff(required1, folders1)
      if (length(missing1) > 0) {
        showNotification(
          paste("The input folder is missing:", paste(missing1, collapse = ", ")),
          type = "error",
          duration = 8
        )
        return()
      }
      if (is.null(input$dataOutputDir) || !nzchar(input$dataOutputDir)) {
        showNotification(
          "Please provide an output folder before saving.",
          type = "error",
          duration = 8
        )
        return()
      }
      
      # optional: vorherige Meldungen leeren
      
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
        speciesRepresentation = to_chr(input$speciesRepresentation),
        speciesNameSource = to_chr(input$speciesNameSource),
        dataInputDir   = to_chr(input$dataInputDir),
        dataOutputDir  = run_out,
        pFormat        = to_chr(input$pFormat),
        pColor         = to_chr(input$pColor),
        specieTitleKeyword = to_chr(input$specieTitleKeyword),
        specieTitleKeywordBefore = to_chr(input$specieTitleKeywordBefore),
        specieTitleKeywordThen = to_chr(input$specieTitleKeywordThen),
        legendKeywords = to_chr(input$legendKeywords),
        middle = ifelse(isTRUE(input$middle), "TRUE", "FALSE")
      )
      
      # Calibration belongs to each map type and survives ordinary config saves.
      if (file.exists(cfg_path)) {
        previous <- read_config(cfg_path)
        calibration_keys <- grep("^georefCalibration_[0-9]+_", names(previous), value = TRUE)
        cfg[calibration_keys] <- previous[calibration_keys]
      }
      df <- data.frame(key = names(cfg), value = unname(unlist(cfg, use.names = FALSE)), stringsAsFactors = FALSE)
      write.table(df, cfg_path, sep = ";", row.names = FALSE, col.names = FALSE, quote = FALSE)
      if (!file.exists(cfg_path)) stop("Config file not found after write: ", cfg_path)
      
      outDir(run_out)
      isolate({
        freezeReactiveValue(input, "dataOutputDir")
        updateTextInput(session, "dataOutputDir", value = outDir())
      })
      Sys.sleep(0.5)
      
      showModal(
        modalDialog(
          title = span("✅ Configuration saved successfully"),
          tags$div(
            style = "font-size:15px; line-height:1.5;",
            "All configuration data were saved successfully.",
            tags$br(), tags$br(),
            tags$b("Test mode: "),
            "To keep the interactive workflow fast, only the first ",
            tags$b("10 pages"), " of the book are converted from ",
            tags$b(".tif"), " to ", tags$b(".png"), " and prepared for use in the app.",
            tags$br(), tags$br(),
            "The complete book will be processed later during the ",
            tags$b("full processing pipeline"), "."
          ),
          easyClose = TRUE,
          footer = modalButton("Close")
        )
      )
    })
    shinyjs::show("open_output")
  })
  
  ####################
  # 2. Maps matching
  ####################
  book_structure_training_server(
    input = input,
    output = output,
    session = session,
    workingDir = workingDir,
    tempImage = tempImage,
    speciesRepresentation = currentSpeciesRepresentation
  )

  map_matching_server(
    input = input,
    output = output,
    session = session,
    workingDir = workingDir,
    outDir = outDir 
  )
  ####################
  # 2.1 Maps align #----------------------------------------------------------------------#
  ####################

  
  ####################
  # 5. Georeferencing #----------------------------------------------------------------------#
  ####################
  georeferencing_server(
    input = input,
    output = output,
    session = session,
    workingDir = workingDir,
    current_out_dir = outDir,
    speciesRepresentation = currentSpeciesRepresentation
  )

  
  ####################
  # 6. Polygonize #----------------------------------------------------------------------#
  ####################
  
  observeEvent(input$polygonize, {
    req(currentSpeciesRepresentation() %in% c("point", "contour"), outDir())
    
    if (currentSpeciesRepresentation() == "point") {
      
      manageProcessFlow(
        processing = "polygonize",
        allertText1 = "polygonize",
        allertText2 = "polygonize",
        input = input,
        session = session,
        current_out_dir = outDir()
      )
      
    } else if (currentSpeciesRepresentation() == "contour") {
      
      manageProcessFlow(
        processing = "polygonize_contour",
        allertText1 = "polygonize",
        allertText2 = "polygonize",
        input = input,
        session = session,
        current_out_dir = outDir()
      )
      
    }
    
    polygon_revision(polygon_revision() + 1L)
  })
  
  
  # Browse vector results using the same controls and styles as Align.
  # Read the active run rather than the shared PNG preview folder.
  polygon_revision <- reactiveVal(0L)
  polygon_page <- reactiveVal(1L)
  polygon_selected <- reactiveVal(NULL)
  polygon_cache <- new.env(parent = emptyenv())
  polygon_files <- reactive({
    polygon_revision()
    root <- outDir()
    type <- input$map_type_Polygonize
    if (is.null(root) || !nzchar(root) || is.null(type) ||
        !grepl("^[0-9]+$", type)) return(character())
    files <- sort(list.files(file.path(root, type, "polygonize", "pointFiltering"),
      pattern = "\\.shp$", full.names = TRUE, ignore.case = TRUE))
    files[!grepl("filtered", basename(files), ignore.case = TRUE)]
  })
  polygon_filtered <- reactive({
    files <- polygon_files()
    query <- trimws(if (is.null(input$polygon_search)) "" else input$polygon_search)
    if (nzchar(query)) files <- files[grepl(tolower(query), tolower(basename(files)), fixed = TRUE)]
    files
  })
  observeEvent(list(outDir(), input$map_type_Polygonize, polygon_revision()), {
    polygon_selected(NULL)
    rm(list = ls(polygon_cache), envir = polygon_cache)
  }, ignoreNULL = FALSE)
  observeEvent(polygon_filtered(), { polygon_page(1L) }, ignoreNULL = FALSE)
  observeEvent(input$polygon_refresh, { polygon_revision(polygon_revision() + 1L) })
  polygon_page_count <- reactive(max(1L, ceiling(length(polygon_filtered()) / 12L)))
  observeEvent(input$polygon_previous, { polygon_page(max(1L, polygon_page() - 1L)) })
  observeEvent(input$polygon_next, { polygon_page(min(polygon_page_count(), polygon_page() + 1L)) })
  polygon_thumbnail <- function(path) {
    info <- file.info(path)
    key <- paste(path, info$size, as.numeric(info$mtime), sep = "|")
    if (exists(key, envir = polygon_cache, inherits = FALSE)) return(get(key, envir = polygon_cache))
    uri <- tryCatch({
      shape <- sf::st_read(path, quiet = TRUE)
      tmp <- tempfile(fileext = ".png")
      on.exit(unlink(tmp), add = TRUE)
      grDevices::png(tmp, width = 320, height = 220)
      device <- grDevices::dev.cur()
      tryCatch({
        par(mar = c(1, 1, 1, 1))
        plot(sf::st_geometry(shape), col = "#337ab7", border = "#245580")
      }, finally = grDevices::dev.off(device))
      base64enc::dataURI(file = tmp, mime = "image/png")
    }, error = function(e) NULL)
    assign(key, uri, envir = polygon_cache)
    uri
  }
  output$polygon_gallery <- renderUI({
    files <- polygon_filtered()
    if (!length(files)) return(p(
      if (length(polygon_files())) "No maps match your search." else
        "No polygonized maps in the current output folder. Run polygonization or choose another map type.",
      class = "dd-align-empty"))
    page <- min(polygon_page(), polygon_page_count())
    visible <- seq.int((page - 1L) * 12L + 1L, min(page * 12L, length(files)))
    all_files <- polygon_files()
    div(class = "dd-align-grid", lapply(visible, function(i) {
      path <- files[i]
      uri <- polygon_thumbnail(path)
      tags$button(type = "button",
        class = paste("dd-align-card", if (identical(path, polygon_selected())) "is-selected" else ""),
        onclick = sprintf("Shiny.setInputValue('polygon_pick', %d, {priority: 'event'});", match(path, all_files)),
        if (is.null(uri)) div(class = "dd-align-empty", "Preview unavailable") else
          tags$img(src = uri, alt = basename(path)),
        tags$span(basename(path))
      )
    }))
  })
  output$polygon_page_info <- renderText({
    sprintf("Page %d of %d - %d maps", min(polygon_page(), polygon_page_count()),
      polygon_page_count(), length(polygon_filtered()))
  })
  observeEvent(input$polygon_pick, {
    index <- suppressWarnings(as.integer(input$polygon_pick))
    files <- polygon_files()
    if (length(index) == 1L && !is.na(index) && index >= 1L && index <= length(files))
      polygon_selected(files[index])
  })
  polygon_selection <- reactive({
    path <- polygon_selected()
    req(length(path) == 1L, path %in% polygon_files(), file.exists(path))
    path
  })
  output$polygon_has_selection <- renderText({
    path <- polygon_selected()
    if (length(path) == 1L && path %in% polygon_files() && file.exists(path)) "true" else "false"
  })
  outputOptions(output, "polygon_has_selection", suspendWhenHidden = FALSE)
  output$polygon_selected_name <- renderText(basename(polygon_selection()))
  output$download_polygon_map <- downloadHandler(
    filename = function() paste0(tools::file_path_sans_ext(basename(polygon_selection())), ".zip"),
    contentType = "application/zip",
    content = function(file) {
      path <- polygon_selection()
      candidates <- list.files(dirname(path), full.names = TRUE)
      stem <- tools::file_path_sans_ext(basename(path))
      extensions <- tolower(tools::file_ext(candidates))
      companions <- candidates[
        tools::file_path_sans_ext(basename(candidates)) == stem &
        extensions %in% c("shp", "shx", "dbf", "prj", "cpg", "qix", "sbn", "sbx")]
      zip::zipr(file, files = companions, include_directories = FALSE)
    }
  )

  observeEvent(polygon_selection(), ignoreInit = TRUE, {
    
    tryCatch({
      
      # 1) outDir prüfen
      current_out_dir <- outDir()
      
      validate(
        need(nzchar(current_out_dir), "outDir() ist leer."),
        need(dir.exists(current_out_dir),
             paste("Ordner existiert nicht:", current_out_dir))
      )
      
      # 2) Alle Map-Ordner (1, 2, 3, ...)
      map_dirs <- list.dirs(current_out_dir, recursive = FALSE, full.names = TRUE)
      
      # Nur numerische Ordner behalten
      map_dirs <- map_dirs[grepl("[/\\\\][0-9]+$", map_dirs)]
      
      validate(
        need(length(map_dirs) > 0, "Keine Map-Ordner gefunden (1/, 2/, ...).")
      )
      
      # Optional: Nach bestimmtem Map-Typ filtern
      if (!is.null(input$map_type_Polygonize) &&
          nzchar(input$map_type_Polygonize)) {
        
        selected_map <- as.character(input$map_type_Polygonize)
        
        map_dirs <- map_dirs[
          basename(map_dirs) == selected_map
        ]
        
        validate(
          need(length(map_dirs) > 0,
               paste("Map-Ordner nicht gefunden:", selected_map))
        )
      }
      
      # The explorer selects one shapefile for the existing map/detail view.
      shp <- polygon_selection()

      validate(
        need(length(shp) > 0, "Keine Shapefiles gefunden.")
      )
      # -----------------------------
      # 🔥 RANGE FILTER (wie Spatial)
      # -----------------------------
      shp_base <- basename(shp)
      
      # optional sortieren (wichtig!)
      shp_base <- sort(shp_base)
      
      range_str <- input$range_list_Polygonize
      
      if (!is.null(range_str) && nzchar(range_str)) {
        
        sel <- parse_range_indices(range_str, length(shp_base))
        
        selected_files <- shp_base[sel]
        
        shp <- shp[
          basename(shp) %in% selected_files
        ]
      }
      
      # Falls leer → abbrechen
      validate(
        need(length(shp) > 0, "No shapefiles in selected range.")
      )
      # 4) Site-Filter (optional)
      site_pat <- if (!is.null(input$siteNumberPolygonize))
        as.character(input$siteNumberPolygonize) else ""
      
      if (nzchar(site_pat)) {
        shp <- shp[grepl(site_pat, basename(shp), fixed = TRUE)]
      }
      
      shp <- shp[!grepl("filtered", basename(shp), ignore.case = TRUE)]
      
      validate(
        need(length(shp) > 0, "Keine passenden Shapefiles gefunden.")
      )
      
      # 5) PNG-Verzeichnis (www)
      png_dir_disk <- file.path(
        workingDir,
        "www",
        "data",
        "align_png"
      )
      
      # Hilfsfunktion PNG passend zum SHP finden
      pick_png_for_shp <- function(shp_path) {
        
        # Dateiname ohne .shp
        base_name <- sub("\\.shp$", "", basename(shp_path))
        
        # Map-Ordner bestimmen (1, 2, 3, ...)
        # shp_path/.../output/1/polygonize/pointFiltering/file.shp
        map_folder <- basename(dirname(dirname(dirname(shp_path))))
        
        # PNG-Dateiname
        png_name <- paste0(base_name, ".png")
        
        # Disk-Pfad prüfen
        png_disk_path <- file.path(
          workingDir,
          "app",
          "www",
          "output",
          map_folder,
          "align_png",
          png_name
        )
        
        if (file.exists(png_disk_path)) {
          
          # Web-Pfad (wichtig: relativ zu www)
          return(file.path("output", map_folder, "align_png", png_name))
          
        } else {
          return(NA_character_)
        }
      }
      observeEvent(input$show_png_modal, {
        
        showModal(
          modalDialog(
            size = "l",
            easyClose = TRUE,
            footer = NULL,
            
            tags$img(
              src = paste0("/", input$show_png_modal),
              style = "width:100%;"
            )
          )
        )
        
      })
      # 6) Dynamische Leaflet UI
      output$leaflet_outputs_PL <- renderUI({
        
        tagList(lapply(seq_along(shp), function(i) {
          
          fluidRow(
            column(
              width = 7,
              leafletOutput(paste0("listPL", i), height = 400)
            ),
            column(
              width = 5,
              uiOutput(paste0("pngPL", i))
            ),
            hr()
          )
          
        }))
      })
      
      # 7) Karten erzeugen
      invisible(lapply(seq_along(shp), function(i) {
        
        local({
          
          shp_i <- shp[i]
          shp_name <- basename(shp_i)
          png_i <- pick_png_for_shp(shp_i)
          
          shape_data <- sf::st_read(shp_i, quiet = TRUE)
          # Leaflet requires geographic coordinates (WGS84)
          if (!is.na(sf::st_crs(shape_data))) {
            shape_data <- sf::st_transform(shape_data, 4326)
          }
          
          rgb_to_hex <- function(r, g, b) {
            grDevices::rgb(r/255, g/255, b/255)
          }
          
          if (!all(c("Red","Green","Blue") %in% names(shape_data))) {
            shape_data$Red   <- 30
            shape_data$Green <- 144
            shape_data$Blue  <- 255
          }
          
          info_br <- htmltools::div(htmltools::p(shp_name))
          
          info_bl <- if (!is.na(png_i)) {
            htmltools::div(
              tags$img(
                src = paste0("/", png_i),
                width = 200
              ),
              tags$a(
                href = paste0("/", png_i),
                target = "_blank",
                png_i
              )
            )
          } else {
            htmltools::div(htmltools::em(paste("PNG-Pfad:", png_i)))
          }
          
          output[[paste0("listPL", i)]] <- leaflet::renderLeaflet({
            
            map <- leaflet::leaflet() %>%
              leaflet::addProviderTiles(
                leaflet::providers$OpenStreetMap
              )
            
            if (currentSpeciesRepresentation() == "contour") {
              
              map <- map %>%
                leaflet::addPolygons(
                  data = shape_data,
                  color = "red",
                  weight = 2,
                  opacity = 1,
                  fillOpacity = 0.3
                )
              
            } else {
              
              map <- map %>%
                leaflet::addCircleMarkers(
                  data = shape_data,
                  color = ~rgb_to_hex(Red, Green, Blue),
                  weight = 1,
                  opacity = 0.9,
                  fillOpacity = 0.6,
                  radius = 5
                )
            }
            
            #map %>%
              #leaflet::addControl(info_br, position = "bottomright") %>%
              #leaflet::addControl(info_bl, position = "bottomleft")
            
          })
          output[[paste0("pngPL", i)]] <- renderUI({
            
            if (!is.na(png_i)) {
              
              tagList(
                
                tags$div(
                  style = "text-align:center;",
                  
                  tags$img(
                    src = paste0("/", png_i),
                    style = "max-width:100%; cursor:pointer; border:1px solid #ccc;",
                    onclick = sprintf(
                      "Shiny.setInputValue('show_png_modal', '%s', {priority: 'event'})",
                      png_i
                    )
                  ),
                  
                  tags$p(
                    style = "font-size:12px;",
                    basename(png_i)
                  )
                )
                
              )
              
            } else {
              
              tags$em("Kein PNG gefunden.")
              
            }
          })
          
        })
        
      }))
      
      showNotification(
        paste("Gefunden:", length(shp), "Shapefile(s)."),
        type = "message"
      )
      
    }, error = function(e) {
      
      shinyalert(
        text = paste("Polygonize Fehler:", conditionMessage(e)),
        type = "error"
      )
      
    })
    
  })
  


  # ============================================================
  # Species distribution search
  # ============================================================
  
  # 1. Species auswählen
  selectedSpeciesData <- eventReactive(
    input$showSpeciesDistribution,
    {
      
      req(input$speciesSpatialSearch)
      req(input$map_type_Spatial)
      
      csv_file <- file.path(
        outDir(),
        as.character(input$map_type_Spatial),
        "spatial_data_final.csv"
      )
      
      validate(
        need(
          file.exists(csv_file),
          "spatial_data_final.csv not found."
        )
      )
      
      df <- read.csv(
        csv_file,
        stringsAsFactors = FALSE
      )
      
      search_text <- trimws(input$speciesSpatialSearch)
      
      result <- df[
        grepl(
          search_text,
          df$species,
          ignore.case = TRUE,
          fixed = TRUE
        ),
      ]
      
      validate(
        need(nrow(result) > 0, "Species not found.")
      )
      
      result
    }
  )
  

  # 2. Titel anzeigen
  output$selectedSpeciesTitle <- renderUI({
    
    df <- selectedSpeciesData()
    
    h2(
      df$species[1],
      style = "
      color:black;
      text-align:center;
      font-weight:bold;
    "
    )
  })
  
  
  # 3. Karte anzeigen
  output$speciesDistributionMap <- leaflet::renderLeaflet({
    
    df <- selectedSpeciesData()
    
    shape_list <- lapply(
      df$shape_file,
      function(shp_file) {
        
        if (!file.exists(shp_file)) {
          return(NULL)
        }
        
        shape <- sf::st_read(
          shp_file,
          quiet = TRUE
        )
        
        if (!is.na(sf::st_crs(shape))) {
          shape <- sf::st_transform(shape, 4326)
        }
        
        shape
      }
    )
    
    shape_list <- Filter(
      Negate(is.null),
      shape_list
    )
    
    validate(
      need(
        length(shape_list) > 0,
        "No valid shapefile found for this species."
      )
    )
    
    shape_data <- do.call(
      rbind,
      shape_list
    )
    
    bbox <- sf::st_bbox(shape_data)
    
    leaflet::leaflet() %>%
      leaflet::addProviderTiles(
        leaflet::providers$OpenStreetMap
      ) %>%
      leaflet::addPolygons(
        data = shape_data,
        color = "red",
        weight = 2,
        opacity = 1,
        fillOpacity = 0.3
      ) %>%
      leaflet::fitBounds(
        lng1 = as.numeric(bbox["xmin"]),
        lat1 = as.numeric(bbox["ymin"]),
        lng2 = as.numeric(bbox["xmax"]),
        lat2 = as.numeric(bbox["ymax"])
      )
  })
  
  output$downloadFinalSpeciesCSV <- downloadHandler(
    
    filename = function() {
      paste0(
        "spatial_data_final_maptype_",
        input$map_type_Spatial,
        ".csv"
      )
    },
    
    content = function(file) {
      
      csv_file <- file.path(
        outDir(),
        as.character(input$map_type_Spatial),
        "spatial_data_final.csv"
      )
      
      req(file.exists(csv_file))
      
      file.copy(
        csv_file,
        file,
        overwrite = TRUE
      )
    }
  )
  
  
  finalSpeciesData <- eventReactive(
    input$showFinalSpeciesData,
    {
      
      req(input$map_type_Spatial)
      
      csv_file <- file.path(
        outDir(),
        as.character(input$map_type_Spatial),
        "spatial_data_final.csv"
      )
      
      validate(
        need(
          file.exists(csv_file),
          "Please run Spatial Data Computing first."
        )
      )
      
      read.csv(
        csv_file,
        stringsAsFactors = FALSE
      )
    }
  )
  
  
  output$finalSpeciesTable <- DT::renderDT({
    
    df <- finalSpeciesData()
    
    DT::datatable(
      df,
      options = list(
        pageLength = 5,
        scrollX = TRUE
      ),
      rownames = FALSE
    )
  })
  
  ####################
  # 7. Save the outputs #----------------------------------------------------------------------#
  ####################
  
  observeEvent(input$startSpatialDataComputing, {
    req(currentSpeciesRepresentation() %in% c("point", "contour"))
    
    if (currentSpeciesRepresentation() == "point") {
      
      manageProcessFlow(
        processing = "spatial_data_computing",
        allertText1 = "spatial",
        allertText2 = "spatial",
        input = input,
        session = session,
        current_out_dir = outDir()
      )
      
    } else if (currentSpeciesRepresentation() == "contour") {
      
      manageProcessFlow(
        processing = "spatial_data_computing_contour",
        allertText1 = "spatial",
        allertText2 = "spatial",
        input = input,
        session = session,
        current_out_dir = outDir()
      )
      
    }
    # ==========================================================
    # Save last successfully tested configuration
    # ==========================================================
    
    config_file <- file.path(
      workingDir,
      "config",
      "config.csv"
    )
    
    backup_file <- file.path(
      workingDir,
      "config",
      "config_backup.csv"
    )
    
    if (file.exists(config_file)) {
      
      file.copy(
        from = config_file,
        to = backup_file,
        overwrite = TRUE
      )
      
      cat(
        "\n✅ Configuration backup saved:\n",
        backup_file,
        "\n"
      )
    }
    
  })
  
  observeEvent(input$spatialViewPF, {
    
    tryCatch({

      current_out_dir <- outDir()
     # current_out_dir = "D:/test/output_2026-03-26_11-00-43"
      selected_type   <- input$map_type_Spatial
      selected_type <- trimws(as.character(input$map_type_Spatial))
      #selected_type=1
      if(is.null(selected_type) || selected_type == "") return()
    
      mapDir <- file.path(current_out_dir, selected_type)
      
      spatial_path <- file.path(
        mapDir,
        "spatial_data_final.csv"
      )
      
      cat("selected_type:", selected_type, "\n")
      cat("spatial_path:", spatial_path, "\n")
      cat("exists:", file.exists(mapDir), "\n")
      if(!file.exists(spatial_path)){
        showModal(modalDialog(
          title = "No data",
          paste("No spatial data found for map type", selected_type),
          easyClose = TRUE,
          footer = NULL
        ))
        return()
      }
      
      #marker_data <- read.csv2(spatial_path, sep = ",", stringsAsFactors = FALSE)
      marker_data <- read.csv(spatial_path, stringsAsFactors = FALSE)
      # -----------------------------
      # 🔥 FILTER NACH RANGE (UI)
      # -----------------------------
      marker_data$file_base <- basename(marker_data$File)
      files_unique <- unique(marker_data$file_base)
      files_unique <- sort(unique(marker_data$file_base))
      
      # Falls nichts eingegeben → alle anzeigen
      range_str <- input$range_list_Spatial
      
      if (!is.null(range_str) && nzchar(range_str)) {
        
        range_str <- trimws(range_str)
        
        # -------------------------------------------------
        # 👉 FALL 1: ALL
        # -------------------------------------------------
        if (toupper(range_str) == "ALL") {
          
          cat("🔍 Showing ALL data\n")
          
        } else if (grepl("\\.tiff?$", range_str, ignore.case = TRUE)) {
          
          # -------------------------------------------------
          # 👉 FALL 2: SEITE (nur wenn .tif/.tiff enthalten)
          # -------------------------------------------------
          
          # Zahl extrahieren (z.B. 0177 aus 0177.tif)
          page_num <- gsub("\\D", "", range_str)
          
          if (nchar(page_num) == 0) return()
          
          # auf 4-stellig bringen
          page_num <- sprintf("%04d", as.numeric(page_num))
          
          cat("🔍 Filtering by page:", page_num, "\n")
          
          marker_data <- marker_data[
            grepl(paste0("_", page_num, "_"), marker_data$file_base),
          ]
          
        } else if (grepl("-", range_str)) {
          
          # -------------------------------------------------
          # 👉 FALL 3: RANGE (z.B. 1-4)
          # -------------------------------------------------
          
          cat("🔍 Filtering by range:", range_str, "\n")
          
          sel <- parse_range_indices(range_str, length(files_unique))
          selected_files <- files_unique[sel]
          
          marker_data <- marker_data[
            marker_data$file_base %in% selected_files,
          ]
          
        }
      }

      
      if(nrow(marker_data) == 0) return()
      
      # Koordinaten numerisch
      marker_data$Real_X <- as.numeric(gsub(",", ".", marker_data$Real_X))
      marker_data$Real_Y <- as.numeric(gsub(",", ".", marker_data$Real_Y))
      marker_data$template_clean <- sub("_.*", "", marker_data$template)
      marker_data$file_base <- basename(marker_data$File)
      marker_data$page <- sub(".*_(\\d{4})_map_.*", "\\1.png", marker_data$file_base)
      # 🔥 HIER DER FIX
      marker_data$file_base <- gsub("\\.tiff?$", ".png", marker_data$file_base)
      
      color_map <- c(
        red = "#FF0000",
        green = "#00FF00",
        blue = "#0000FF",
        yellow = "#FFFF00",
        orange = "#FFA500",
        magenta = "#FF00FF"
      )
      
      marker_data$color <- color_map[marker_data$template_clean]
      
      print(unique(marker_data$template_clean))
      print(unique(marker_data$color))
      


      
      output$mapSpatialViewPF <- renderLeaflet({
        
        leaflet() %>%
          addTiles() %>%
          addCircleMarkers(
            data = marker_data,
            lat = ~Real_Y,
            lng = ~Real_X,
            color = ~color,
            fillColor = ~color,
            fillOpacity = 1,
            stroke = FALSE,   # 🔥 GANZ WICHTIG
            radius = 4,       # 🔥 etwas größer
            popup = ~paste0(
              "<p><b>Species: ", specie, "</b></p>",
              "<p><b>", title, "</b></p>",
              "<a href='/output/", selected_type,
              "/matching_png/", file_base,
              "' target='_blank'>",
              "<img src='/output/", selected_type,
              "/matching_png/", file_base,
              "' width='100'></a>",
              "<br>",
              "<a href='/pages/", page,
              "' target='_blank'>",
              "<img src='/pages/", page,
              "' width='100'></a>"
            ),
            label = ~specie
          )
        
      })
      
      cat("\n✅ Spatial view loaded for MapType", selected_type, "\n")
      
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
        # Seitenzahl (erste 4 Ziffern) extrahieren
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
  
  points_matching_server(
    input = input,
    output = output,
    session = session,
    outDir = outDir,
    manageProcessFlow = manageProcessFlow,
    prepareImageView = prepareImageView
  )

  masking_server(
    input = input,
    output = output,
    session = session,
    outDir = outDir,
    manageProcessFlow = manageProcessFlow,
    prepareImageView = prepareImageView,
    speciesRepresentation = currentSpeciesRepresentation
  )

  
 
  observe({
    isolate({
      if (!is.null(current_tab())) {
        updateTabItems(session, "tablist", selected = current_tab())
      }
    })
  })
  
   
})

  

