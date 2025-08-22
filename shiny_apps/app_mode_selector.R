# ============================================================
# Script Author: Spaska Forteva
# Updated On: 2025-06-17
# Description: Unified configuration and output folder creation 
# for Distribution Digitizer (integrated in app_mode_selector.R)
# ============================================================

library(shiny)
library(shinydashboard)
library(magick)
library(grid)
library(rdrop2)
library(shinyFiles)
library(reticulate)
library(shinyalert)
library(tesseract)
library(leaflet)
library(raster)
library(sf)

options(shiny.host = '127.0.0.1')
options(shiny.port = 8888)
options(shiny.maxRequestSize = 100 * 1024^2)


workingDir <- Sys.getenv("APP_WORKING_DIR")
if (workingDir == "") {
  workingDir <- getwd()  # fallback
}
setwd(workingDir)

inputDir <- file.path(workingDir, "data/input/")

# Read config
readConfigFile <- function(filename) {
  path <- file.path(workingDir, "config", filename)
  if (!file.exists(path)) stop(paste("Missing:", filename))
  read.csv(path, header = TRUE, sep = ";")
}

config <- tryCatch({
  readConfigFile("config.csv")
}, error = function(e) {
  warning("config.csv not found, using empty defaults")
  data.frame(
    workingDirInformation = "Your working directory is the local digitizer repository!",
    title = "", autor = "", pYear = "", tesserAct = "", dataInputDir = "",
    dataOutputDir = "", allPrintedPages = "", sNumberPosition = 1, mapCaptureType = 1,
    speciesOnMap = 0, matchingType = 1, approximatelySpecieMap = 1, middle = 0,
    regExYear = 0, keywordReadSpecies = "", keywordBefore = 0, keywordThen = 0,
    pFormat = 1, pColor = 1,
    stringsAsFactors = FALSE
  )
})

configStartDialog <- readConfigFile("configStartDialog.csv")
shinyfields2 <- readConfigFile("shinyfields_detect_maps.csv")

# UI
header <- dashboardHeader(
  tags$li(class = "dropdown", tags$style(HTML(".navbar-custom-menu{float:left !important;}.sidebar-menu{display:flex;align-items:baseline;}#message {color: red;}"))),
  tags$li(class = "dropdown", sidebarMenu(id = "tablist", menuItem("Environment DD", tabName = "tab0")))
)

body <- dashboardBody(
  titlePanel("Distribution Digitizer"),
  p(paste0(config$workingDirInformation, ": ", workingDir), style = "color:black"),
  tags$a(href = "README.pdf", target = "_blank", "📘 Open README.pdf"),
  br(),
  actionButton("showDialog", "New Book Configurator", class = "btn-primary"),
  br(),
  br(),
  conditionalPanel(
    condition = "input.showDialog % 2 == 0",
    fluidRow(
      column(6,
             selectInput("existingOutput", "Select existing output directory", choices = NULL),
             actionButton("continueApp", "Continue with selected output", class = "btn-success"),
             br()
      )
    )
  ),
  conditionalPanel(
    condition = "input.showDialog % 2 == 1",
    tabItems(
      tabItem(
        tabName = "tab0",
        fluidRow(
          column(6, wellPanel(
            h3("General configuration fields"),
            textInput("title", "Book Title", config$title),
            textInput("author", "Author", config$autor),
            textInput("pYear", "Publication Year", config$pYear),
            textInput("tesserAct", "Tesseract Path", config$tesserAct),
            textInput("dataInputDir", "Input Directory", config$dataInputDir),
            verbatimTextOutput("message"),
            textInput("dataOutputDir", "Output Directory", config$dataOutputDir),
            selectInput("pFormat", "Image Format", c("tif" = 1, "png" = 2, "jpg" = 3), selected = config$pFormat),
            selectInput("pColor", "Page Color", c("black white" = 1, "color" = 2), selected = config$pColor),
            textInput("allPrintedPages", "Number of Scanned Images", config$allPrintedPages)
          )),
          column(6, wellPanel(
            h3("Additional specific configuration fields"),
            selectInput("mapCaptureType", "Map Capture Type", c("points" = 1, "contours" = 2), selected = config$mapCaptureType),
            selectInput("sNumberPosition", "Page Number Position", c("top" = 1, "bottom" = 2), selected = config$sNumberPosition),
            selectInput("speciesOnMap", "Species on Map?", c("No" = 0, "Yes" = 1), selected = config$speciesOnMap),
            selectInput("matchingType", shinyfields2$matchingType, c("Template matching" = 1, "Contour matching" = 2), selected = config$matchingType),
            selectInput("approximatelySpecieMap", "Species Near Map Level?", c("Yes" = 1, "No" = 2), selected = config$approximatelySpecieMap),
            selectInput("middle", "Indented Species Term?", c("No" = 0, "Yes" = 1), selected = config$middle),
            selectInput("regExYear", "Contains Year Regex?", c("No" = 0, "Yes" = 1), selected = config$regExYear),
            textInput("keywordReadSpecies", "Keyword Related to 'Species'", config$keywordReadSpecies),
            selectInput("keywordBefore", "Keyword Lines Before?", 0:3, selected = config$keywordBefore),
            selectInput("keywordThen", "Keyword Lines After?", 0:3, selected = config$keywordThen),
            actionButton("saveConfig", "Save", style = "color:#FFFFFF;background:#999999")
          ))
        )
      )
    )
  )
  
)

ui <- dashboardPage(header = header, sidebar = dashboardSidebar(disable = TRUE), body = body)

prepare_base_output <- function(base_path) {
  tryCatch({
    if (nchar(base_path) > 0) {
      if (!dir.exists(base_path)) {
        dir.create(base_path, recursive = TRUE)
      }
      directory_names <- c("final_output", "georeferencing", "maps", "masking", 
                           "masking_black", "output_shape", "pagerecords", "polygonize", "rectifying")
      for (dir_name in directory_names) {
        dir_path <- file.path(base_path, dir_name)
        dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
        if (dir_name == "maps") {
          sub_directory_names <- c("align", "csvFiles", "matching", "readSpecies", "pointMatching")
          for (sub_dir_name in sub_directory_names) {
            dir.create(file.path(dir_path, sub_dir_name), recursive = TRUE, showWarnings = FALSE)
          }
        }
        if (dir_name == "georeferencing") {
          sub_directory_names <- c("maps", "masks")
          for (sub_dir_name in sub_directory_names) {
            dir.create(file.path(dir_path, sub_dir_name), recursive = TRUE, showWarnings = FALSE)
          }
        }
        if (dir_name %in% c("final_output", "maps", "masking_black", "polygonize", "rectifying")) {
          sub_directory_names <- c("circleDetection", "pointFiltering")
          for (sub_dir_name in sub_directory_names) {
            dir.create(file.path(dir_path, sub_dir_name), recursive = TRUE, showWarnings = FALSE)
          }
        }
      }
    } else {
      showModal(modalDialog(title = "Error", "Please provide a valid input directory path."))
      return()
    }
  }, error = function(e) {
    cat("An error occurred during prepare_base_output processing:\n")
    print(e)
  })
}

prepare_www_output <- function(www_output) {
  tryCatch({
    unlink(www_output, recursive = TRUE)
    if (nchar(www_output) > 0) {
      if (!dir.exists(www_output)) {
        dir.create(www_output, recursive = TRUE)
      }
      directory_names <- c("align_png", "CircleDetection_png", "readSpecies_png", "georeferencing_png", 
                           "masking_black_png", "masking_circleDetection", "masking_png", "maskingCentroids",
                           "matching_png", "pages", "pointFiltering_png", "pointMatching_png", "polygonize",
                           "symbol_templates_png", "map_templates_png")
      for (sub_dir_name in directory_names) {
        sub_dir_path <- file.path(www_output, sub_dir_name)
        dir.create(sub_dir_path, recursive = TRUE, showWarnings = FALSE)
      }
    } else {
      showModal(modalDialog(title = "Error", "Please provide a valid input directory path."))
      return()
    }
  }, error = function(e) {
    cat("An error occurred during prepare_www_output processing:\n")
    print(e)
  })
}

server <- function(input, output, session) {
  addResourcePath("README.pdf", file.path(workingDir, "www/README.pdf"))
  
  observe({
    config_path <- file.path(workingDir, "config/config.csv")
    if (file.exists(config_path)) {
      cfg <- read.csv(config_path, sep = ";", stringsAsFactors = FALSE)
      base_output <- dirname(cfg$dataOutputDir[1])
      if (dir.exists(base_output)) {
        output_dirs <- list.dirs(base_output, full.names = FALSE, recursive = FALSE)
        output_dirs <- output_dirs[grepl("^output_", output_dirs)]
        updateSelectInput(session, "existingOutput", choices = output_dirs)
        # Speicher den Basis-Pfad für später
        output$baseOutputDir <- renderText({ base_output })
      }
    }
  })
  
  observeEvent(input$continueApp, {
    # Pfade
    config_path <- file.path(workingDir, "config/config.csv")
    if (!file.exists(config_path)) {
      shinyalert("Error", "No config.csv found.", type = "error")
      return()
    }
    
    # Auswahl prüfen
    selected_output <- input$existingOutput
    if (!nzchar(selected_output)) {
      shinyalert("Error", "Please select an output folder.", type = "error")
      return()
    }
    
    # Basisordner aus aktueller config lesen
    cfg <- read.csv(config_path, sep = ";", stringsAsFactors = FALSE)
    base_output <- dirname(cfg$dataOutputDir[1])
    
    # Vollständigen Pfad bilden und prüfen
    full_path <- file.path(base_output, selected_output)
    if (!dir.exists(full_path)) {
      shinyalert("Error", sprintf("Folder does not exist:\n%s", full_path), type = "error")
      return()
    }
    
    # In config.csv NUR dataOutputDir aktualisieren
    cfg$dataOutputDir[1] <- full_path
    write.table(cfg, file = config_path, sep = ";", row.names = FALSE, quote = FALSE)
    
    batch_file <- file.path(workingDir, "start_main_dialog.bat")
    shinyalert(
      "Success",
      sprintf(
        "Output folder saved:\n%s\n\nYou can now start the main batch:\n%s",
        full_path, batch_file
      ),
      type = "success"
    )
    stopApp()
  })
  

  observeEvent(input$saveConfig, {
    req(file.exists(input$dataInputDir))
    required1 <- c("pages", "templates")
    folders1 <- list.dirs(input$dataInputDir, full.names = FALSE, recursive = FALSE)
    if (!all(required1 %in% folders1)) {
      output$message <- renderPrint(paste("Missing folders:", paste(setdiff(required1, folders1), collapse = ", ")))
      return()
    }
    required2 <- c("align_ref", "maps", "symbols", "geopoints")
    folders2 <- list.dirs(file.path(input$dataInputDir, "templates"), full.names = FALSE, recursive = FALSE)
    if (!all(required2 %in% folders2)) {
      output$message <- renderPrint(paste("Missing template folders:", paste(setdiff(required2, folders2), collapse = ", ")))
      return()
    }
    timestamp <- format(Sys.time(), "%Y-%m-%d_%H-%M-%S")
    outDir <- file.path(input$dataOutputDir, paste0("output_", timestamp))
    prepare_base_output(outDir)
    prepare_www_output(file.path(workingDir, "www/data"))
    x <- data.frame(
      workingDir = workingDir,
      workingDirInformation = "Your working directory is the local digitizer repository!",
      title = input$title,
      autor = input$author,
      pYear = input$pYear,
      tesserAct = input$tesserAct,
      dataInputDir = input$dataInputDir,
      dataOutputDir = outDir,
      allPrintedPages = input$allPrintedPages,
      sNumberPosition = input$sNumberPosition,
      mapCaptureType = input$mapCaptureType,
      speciesOnMap = input$speciesOnMap,
      matchingType = input$matchingType,
      approximatelySpecieMap = input$approximatelySpecieMap,
      middle = input$middle,
      regExYear = input$regExYear,
      keywordReadSpecies = input$keywordReadSpecies,
      keywordBefore = input$keywordBefore,
      keywordThen = input$keywordThen,
      pFormat = input$pFormat,
      pColor = input$pColor
    )
    write.table(x, file = file.path(workingDir, "config/config.csv"), sep = ";", row.names = FALSE, quote = FALSE)
    shinyalert("Success", "Configuration successfully saved!", type = "success")
  })
}

shinyApp(ui, server)
