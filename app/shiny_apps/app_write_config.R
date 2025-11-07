
# ============================================================
# Script Author: Spaska Forteva
# Updated On: 2025-05-20
# ============================================================

# Shiny App: Configuration Dialog for Book Distribution Digitization

# ============================================================
# Load Required Libraries
# ============================================================
library(shinyjs)  # ganz oben laden

# ============================================================
# Global Settings and Configuration
# ============================================================

options(shiny.host = '127.0.0.1')
options(shiny.port = 8888)
options(shiny.maxRequestSize=100*1024^2)

workingDir <- getwd()
inputDir <- file.path(workingDir, "data/input/")

readConfig <- function(filePath) {
  if (file.exists(filePath)) {
    read.csv(filePath, header = TRUE, sep = ";")
  } else {
    stop(paste("Missing config file:", filePath))
  }
}

config <- readConfig(file.path(workingDir, "config/config.csv"))
configStartDialog <- readConfig(file.path(workingDir, "config/configStartDialog.csv"))
shinyfields2 <- readConfig(file.path(workingDir, "config/shinyfields_detect_maps.csv"))

# ============================================================
# UI Definition
# ============================================================

header <- dashboardHeader(
  tags$li(class = "dropdown", tags$style(HTML("
    .navbar-custom-menu{float:left !important;}
    .sidebar-menu{display:flex;align-items:baseline;}
    .shiny-map-image{margin:7px;}
    #message {color: red;}
  "))),
  tags$li(class = "dropdown", sidebarMenu(id = "tablist", menuItem("Environment DD", tabName = "tab0")))
)

body <- dashboardBody(
  titlePanel("Distribution Digitizer"),
  p(paste0(config$workingDirInformation, ": ", workingDir), style = "color:black"),
  tabItems(
    tabItem(tabName = "tab0",
            p("This configuration dialog gathers information before digitization."),
            fluidRow(
              column(6, wellPanel(
                h3(strong("General configuration fields", style = "color:black")),
                textInput("title", "Book Title", config$title),
                textInput("author", "Author", config$autor),
                textInput("pYear", "Publication Year", config$pYear),
                textInput("tesserAct", 
                          "Tesseract Path (use forward slashes, e.g. C:/Program Files/Tesseract-OCR)", 
                          config$tesserAct),
                textInput("dataInputDir", "Input Data Directory", config$dataInputDir),
                verbatimTextOutput("message"),
                textInput("dataOutputDir", "Output Directory", config$dataOutputDir),
                selectInput("pFormat", "Image Format", c("tif" = 1, "png" = 2, "jpg" = 3), selected = config$pFormat),
                selectInput("pColor", "Page Color", c("black white" = 1, "color" = 2), selected = config$pColor),
                textInput("allPrintedPages", "Number of Scanned Images", config$allPrintedPages)
              )),
              column(6, wellPanel(
                h3(strong("Specific configuration", style = "color:black")),
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
                actionButton("saveConfig", "Save", style = "color:#FFFFFF;background:#999999")
              ))
            )
    )
  ),
  
  fluidRow(
    uiOutput("startMainAppUI")  # Dynamisch erzeugter Button
  )
)

ui <- dashboardPage(
  header = header,
  sidebar = dashboardSidebar(disable = TRUE),
  body = dashboardBody(
    useShinyjs(),  # <- Aktiviert shinyjs
    body  # <- dein vorhandener body-Block
  )
)

# ============================================================
# Server Definition
# ============================================================

server <- function(input, output, session) {
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
    
    write.table(config_df, file = file.path(workingDir, "config/config.csv"), sep = ";", row.names = FALSE, quote = FALSE)
    shinyalert("Success", "Configuration successfully saved!", type = "success")
    
    # Felder deaktivieren
    
    fields_to_disable <- c("title", "author", "pYear", "tesserAct", "dataInputDir",
                           "dataOutputDir", "allPrintedPages", "sNumberPosition", "mapCaptureType",
                           "speciesOnMap", "matchingType", "approximatelySpecieMap", "middle",
                           "regExYear", "keywordReadSpecies", "keywordBefore", "keywordThen",
                           "pFormat", "pColor")
    
    lapply(fields_to_disable, function(id) {
      shinyjs::disable(id)
    })
    
    # „Start Main App“-Button anzeigen
    output$startMainAppUI <- renderUI({
      tagList(
        actionButton("startMainApp", "Start Main App", class = "btn-success"),
        br(), br(),
        p("After clicking, open this URL manually in your browser:"),
        tags$code("http://127.0.0.1:8889")
      )
    })
  })
  
  observeEvent(input$startMainApp, {
    shinyalert("Launching", "Starting the main app on port 8889...", type = "info")
    system("Rscript app.R 8889", wait = FALSE)  # oder übergib Port in app.R
    #stopApp()
  })
}

shinyApp(ui = ui, server = server)
