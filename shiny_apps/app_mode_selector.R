# app_mode_selector.R

library(shiny)
library(shinyjs)

setwd(file.path(getwd(), ".."))

workingDir <- getwd()
config_path <- file.path(workingDir, "/config/config.csv")

print(config_path)

if (!file.exists(config_path)) stop("❌ Config file not found at: ", config_path)

config <- read.csv(config_path, header = TRUE, sep = ";")


# Helper: Read config
readConfig <- function(filePath) {
  if (file.exists(filePath)) {
    read.csv(filePath, header = TRUE, sep = ";", stringsAsFactors = FALSE)
  } else {
    stop(paste("Missing config file:", filePath))
  }
}

# Get initial config values
config <- readConfig(config_path)
shinyfields2 <- readConfig(file.path(workingDir, "config/shinyfields_detect_maps.csv"))

# Default output directory
get_last_output_dir <- function() {
  if ("dataOutputDir" %in% names(config)) {
    return(tail(config$dataOutputDir[config$dataOutputDir != ""], 1))
  }
  return("")
}

default_output <- get_last_output_dir()

ui <- fluidPage(
  useShinyjs(),
  titlePanel("Distribution Digitizer – Mode Selection"),
  fluidRow(
    column(6,
           h4("➊ Configure settings first"),
           p("If you want to start a new book or test, please configure the settings first."),
           actionButton("toggle_config", "Show Configuration Fields")
    ),
    column(6,
           h4("➋ Use existing configuration"),
           selectInput("output_dir", "Choose existing output folder:", choices = config$dataOutputDir, selected = NULL),
           textInput("new_output_dir", "Or specify new folder:", value = default_output),
           actionButton("start_main", "Launch Main App")
    )
  ),
  br(),
  hidden(
    div(id = "config_panel",
        fluidRow(
          column(6, wellPanel(
            h3(strong("General Configuration Fields")),
            textInput("title", "Book Title", config$title),
            textInput("author", "Author", config$autor),
            textInput("pYear", "Publication Year", config$pYear),
            textInput("tesserAct", "Tesseract Path", config$tesserAct),
            textInput("dataInputDir", "Input Data Directory", config$dataInputDir),
            verbatimTextOutput("message"),
            textInput("dataOutputDir", "Output Directory", config$dataOutputDir),
            selectInput("pFormat", "Image Format", c("tif" = 1, "png" = 2, "jpg" = 3), selected = config$pFormat),
            selectInput("pColor", "Page Color", c("black white" = 1, "color" = 2), selected = config$pColor),
            textInput("allPrintedPages", "Number of Scanned Images", config$allPrintedPages)
          )),
          column(6, wellPanel(
            h3(strong("Specific Configuration")),
            selectInput("mapCaptureType", "Map Capture Type", c("points" = 1, "contours" = 2), selected = config$mapCaptureType),
            selectInput("sNumberPosition", "Page Number Position", c("top" = 1, "bottom" = 2), selected = config$sNumberPosition),
            selectInput("speciesOnMap", "Is Species on Map?", c("No" = 0, "Yes" = 1), selected = config$speciesOnMap),
            selectInput("matchingType", shinyfields2$matchingType, c("Template matching" = 1, "Contour matching" = 2), selected = config$matchingType),
            selectInput("approximatelySpecieMap", "Species Near Map Level?", c("Yes" = 1, "No" = 2), selected = config$approximatelySpecieMap),
            selectInput("middle", "Is Species Term Indented?", c("No" = 0, "Yes" = 1), selected = config$middle),
            selectInput("regExYear", "Contains Year Regex?", c("No" = 0, "Yes" = 1), selected = config$regExYear),
            textInput("keywordReadSpecies", "Keyword Related to 'Species'", config$keywordReadSpecies),
            selectInput("keywordBefore", "Keyword Lines Before?", c("0" = 0, "1" = 1, "2" = 2, "3" = 3), selected = config$keywordBefore),
            selectInput("keywordThen", "Keyword Lines After?", c("0" = 0, "1" = 1, "2" = 2, "3" = 3), selected = config$keywordThen),
            actionButton("saveConfig", "Save Configuration")
          ))
        )
    )
  )
)

server <- function(input, output, session) {
  
  config_visible <- reactiveVal(FALSE)
  
  observeEvent(input$toggle_config, {
    if (config_visible()) {
      shinyjs::hide("config_panel")
      shinyjs::enable("start_main")
      config_visible(FALSE)
    } else {
      shinyjs::show("config_panel")
      shinyjs::disable("start_main")
      config_visible(TRUE)
    }
  })
  
  observeEvent(input$saveConfig, {
    if (!file.exists(input$dataInputDir)) {
      output$message <- renderPrint("Directory does not exist.")
      return()
    }
    
    config_df <- data.frame(
      workingDir = workingDir,
      workingDirInformation = "Your working directory is the local digitizer repository!",
      title = input$title,
      autor = input$author,
      pYear = input$pYear,
      tesserAct = input$tesserAct,
      dataInputDir = input$dataInputDir,
      dataOutputDir = input$dataOutputDir,
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
    
    write.table(config_df, file = config_path, sep = ";", row.names = FALSE, quote = FALSE)
    output$message <- renderPrint("Configuration saved successfully.")
    shinyjs::enable("start_main")
  })
  
  observeEvent(input$start_main, {
    chosen_dir <- if (nzchar(input$new_output_dir)) input$new_output_dir else input$output_dir
    if (nzchar(chosen_dir)) {
      system(paste("Rscript app.R", shQuote(chosen_dir)), wait = FALSE)
      showModal(modalDialog(
        title = "Main App Started",
        HTML("The main application is now running at:<br><br>
             <a href='http://127.0.0.1:8888' target='_blank'>http://127.0.0.1:8888</a>"),
        easyClose = TRUE
      ))
    } else {
      showModal(modalDialog(
        title = "Missing Folder",
        "Please select or enter a valid output directory.",
        easyClose = TRUE
      ))
    }
  })
}

shinyApp(ui, server)
