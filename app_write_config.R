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


# Global variables
processEventNumber = 0

# Input variables
# host
options(shiny.host = '127.0.0.1')
# port
options(shiny.port = 8888)

# Change the max uploaf size
options(shiny.maxRequestSize=100*1024^2)

workingDir <- getwd()
print("Working directory 1:")
print(workingDir)
outDir <- ""
inputDir = paste0(workingDir,"/data/input/")

#read config fields from config.csv in .../distribution_digitizer/config directory
fileFullPath = (paste0(workingDir,'/config/config.csv'))
if (file.exists(fileFullPath)){
  config <- read.csv(fileFullPath,header = TRUE, sep = ';')
} else{
  stop(paste0("file:", fileFullPath, "not found, please create them and start the app"))
}

fileFullPath = (paste0(workingDir,'/config/configStartDialog.csv'))
if (file.exists(fileFullPath)){
  configStartDialog <- read.csv(fileFullPath, header = TRUE, sep = ';')
} else{
  stop("The file configStartDialog.csv was not found, please create them and start the app")
}


#2 shinyfields_detect_maps.csv
fileFullPath = (paste0(workingDir,'/config/shinyfields_detect_maps.csv'))
if (file.exists(fileFullPath)){
  shinyfields2 <- read.csv(fileFullPath,header = TRUE, sep = ';')
} else{
  stop(paste0("file:", fileFullPath, "not found, please create them and start the app"))
}

header <- dashboardHeader(
  tags$li(
    class = "dropdown",
    tags$style(HTML("
          .navbar-custom-menu{float:left !important;}
          .sidebar-menu{display:flex;align-items:baseline;}
          /* layout of the map images */
          .shiny-map-image{margin:7px;}
          #message {color: red;}
          "))
  ),
  tags$li(
    class = "dropdown",
    sidebarMenu(
      id = "tablist",
      menuItem("Environment DD", tabName = "tab0")
    )
  )
)
body <- dashboardBody(
  # Top Information
  # Working directory
  titlePanel("Distribution Digitizer"),
  
  p(paste0(config$workingDirInformation,": ",workingDir) , style = "color:black"),
  tabItems(
    # Tab 0 Config Dialog --------------------------------------------------------------------------------------------------------------
    tabItem(
      tabName = "tab0",
      p("In ", strong("Distribution Digitizer"), " 1.0, certain lines are skipped during species name search. Lines containing special characters like",
        strong("doublequotes\""), ",",strong(" point ."),", ", strong("colons :"),", or the word", strong(" \"distribution\"")," are excluded.",
        br(),
        "The tool also searches for species names in the legend map and uses a specified regular expression for matching the year.",
        br(),
        "If you've added an extra ",strong("additional keyword"),", indicate if it appears before, after,  the species name."
      ),
      fluidRow(
        # Linke Spalte
        column(
          width = 6, # Zum Beispiel die Hälfte der Breite des Containers
          wellPanel(
            h3(strong("General configuration fields", style = "color:black")),
            # Title: Provide the name of the book's author.
            fluidRow(textInput("title", label = "Please write the title of the book.", value = config$title)),
            # Author: Provide the name of the book's author.
            fluidRow(textInput("author", label = "Please write the author of the book.", value = config$autor)),
            # Publication Year: Specify the year the book was published.
            fluidRow(textInput("pYear", label = "Publication Year", value = config$pYear)),
            # Directory Tesseract
            fluidRow(textInput("tesserAct", label = "Please write the path to the Tesseract", value = config$tesserAct)),
            # Data input directory
            fluidRow(textInput("dataInputDir", p("Please write the path to the inputs.",br(),
                                                 "This input directory should contain two folders:",br(),
                                                 "- 'pages', where the scanned images are stored,",br(),
                                                 "- 'templates', which includes four additional folders.",br(),br(),
                                                 "-- 'maps' ",br(),
                                                 "--- 'map_1.tif' use the next Tab: Create Templates to create this",br(),
                                                 "-- 'symbols' ",br(),
                                                 "--- 'symbol_1.tif' 'symbol_2.tif' use the next Tab: Create Templates to create this",br(),
                                                 "-- 'align_ref'  ",br(),
                                                 "--- 'map_1_align.tif' make one template map properly aligned (Gimp) and save it here.",br(),
                                                 "-- 'geopoints'",br(),
                                                 "--- 'gcp_point_map1.points'  geopoints data for the georeferens. you can user the program QGIS to extract this",br(),br(),
                                                 "To ensure proper functionality of the application,",
                                                 "please ensure that the provided path adheres to the aforementioned structure."), 
                               value = config$dataInputDir),   verbatimTextOutput("message"),),
            # Data output directory
            fluidRow(textInput("dataOutputDir", label = "Please write the path to the output environment of the distribution digitizer", value = config$dataOutputDir)),
            # format
            fluidRow(selectInput("pFormat", label = "Image iiFormat of the Scanned Sites", c("tif" = 1, "png" = 2, "jpg" = 3), selected = config$pFormat)),
            # Page color
            fluidRow(selectInput("pColor", label = "Page Color", c("black white" = 1, "color" = 2), selected = config$pColor)),
            # allprintedPages
            fluidRow(textInput("allPrintedPages", label = "Please provide the number of scanned images:", value = config$allPrintedPages)),
           )
        ),
        # Rechte Spalte
        column(
          width = 6, # Zum Beispiel die Hälfte der Breite des Containers
          wellPanel(
            h3(strong(" Additional specific configuration input fields", style = "color:black")),
            
            # mapCaptureType
            fluidRow(selectInput("mapCaptureType", label = "Select map capture type: points or contours.",  c("points" = 1, "countors" = 2), selected = config$mapCaptureType)),
            
            # site number position
            fluidRow(selectInput("sNumberPosition", label = "Indicate whether the page number is positioned at the top or bottom of the page.", c("top" = 1, "botom" = 2), selected = config$sNumberPosition)),
            
            # Is the term "species name" listed on the map (bottom)?
            fluidRow(selectInput("speciesOnMap", label = "Is there a species name listed on the map?", c( "No" = 0, "Yes" = 1 ), selected = config$speciesOnMap)),
            
            # Select which is the type of matching: template or contours
            fluidRow(column(8, selectInput("matchingType", label = shinyfields2$matchingType,  c("Template matching" = 1, "Countor matching" = 2), selected = config$matchingType))),
            
            # Select species is approximately at the same level in the book as the map
            fluidRow(column(8, selectInput("approximatelySpecieMap", label = "Could you check if the title/term of the species is approximately at the same level in the book as the map?",  c("Yes" = 1, "No" = 2), selected = config$approximatelySpecieMap))),
            
            
            # Is the term "species name" on the page inclusive of special patterns such as year, parentheses, or symbols?
            fluidRow(selectInput("middle", label = "Is the term-species shifted to the middle, indented?", c( "No" = 0, "Yes" = 1 ), selected = config$middle)),
            
            fluidRow(selectInput("regExYear", label = "Does the term contain a regular expression like a year?", c( "No" = 0, "Yes" = 1), selected = config$regExYear)),# keayword to read species data
            
            fluidRow(textInput("keywordReadSpecies", label = "If there is a keyword related to the term 'species', please write it here. Please note that the word should almost always appear a few lines before, after, or directly on the same line as the species term.", value = config$keywordReadSpecies)),
            
            fluidRow(selectInput("keywordBefore", label = "Is the keyword located a few lines before the species name? If so, how many lines?", c("0" = 0, "1" = 1, "2" = 2, "3" = 3), selected = config$keywordBefore)),
            
            fluidRow(selectInput("keywordThen", label = "Is the keyword located a few lines after the species name? If yes, please specify how many.", c("0" = 0, "1" = 1, "2" = 2, "3" = 3), selected = config$keywordThen)),
            
            #Is the keyword a few lines before the species name? If yes, how many? 
            #Is the keyword exactly on the line with the species name? 
            #Is the keyword a few lines after the species name? If yes, please specify how many."
            # Save button
            fluidRow(actionButton("saveConfig", label = "Save", style = "color:#FFFFFF;background:#999999"))
          )
        )
      )
    )
  ) # END tabItems
) # END BODY


sidebar <-
  ui <- dashboardPage(
    header = header,
    sidebar = dashboardSidebar(disable = TRUE),
    body = body,
    title = NULL,
    skin = "black"
  )



################################################################################
# Shiny SERVER CODE
################################################################################
################################################################################

server <- shinyServer(function(input, output, session) {
  
  dataInputDir = ""
  # Update the clock every second using a reactiveTimer
  current_time <- reactiveTimer(1000)
  
  # SAVE the config
  observeEvent(input$saveConfig, {
    dataInputDir = input$dataInputDir
    tryCatch({
      
      # Check if the directory exists
      if (file.exists(dataInputDir) ){#&& file.info(dataInputDir)$isdir) {
        output$message <- NULL
        # List of subdirectories in the "input" directory
        subdirectories <- list.dirs(dataInputDir, full.names = FALSE, recursive = FALSE)
        
        # Required subdirectories
        required_subdirectories <- c("pages", "templates")
        #required_subdirectories <- c("maps", "symbols", "align", "points")
        
        # Check if all required subdirectories are present
        if (all(required_subdirectories %in% subdirectories)) {
          print("All required subdirectories of input are present.")      
          
          templates <- paste0(dataInputDir,"/templates/")
          # List of subdirectories in the "input" directory
          subdirectories <- list.dirs(templates, full.names = FALSE, recursive = FALSE)
          
          # Required subdirectories
          required_subdirectories <- c("align_ref", "maps","symbols", "geopoints")
          
          #required_subdirectories <- c("maps", "symbols", "align", "points")
          if (all(required_subdirectories %in% subdirectories)) {
            print("All required subdirectories of templates are present.")
          } else {
            missing_subdirectories <- required_subdirectories[!required_subdirectories %in% subdirectories]
            output$message <- renderPrint(paste("The following subdirectories in templates are missing:", paste(missing_subdirectories, collapse = ", ")))
            break
          }
        } else {
          missing_subdirectories <- required_subdirectories[!required_subdirectories %in% subdirectories]
          output$message <- renderPrint(paste("The following subdirectories are missing:", paste(missing_subdirectories, collapse = ", ")))
          break
        }
      } else {
        #rv$message <- "The 'templates' directory does not exist."
        output$message <- renderPrint("The 'templates' directory does not exist.")
        break
      }
      # Generate current date-time string
      current_datetime <- format(Sys.time(), "%Y-%m-%d_%H-%M-%S")
      # Directory name with current date-time
      out_directory_name <- paste("output_", current_datetime, sep = "")
      
      # Concatenate base path with directory name
      outDir <- file.path(input$dataOutputDir, out_directory_name)
      
      prepare_base_output(outDir)
      
      webViewMap = paste0(workingDir,"/www/data/")
      prepare_www_output(webViewMap)
      
      x <- data.frame(workingDir= workingDir, 
                      workingDirInformation = "Your working directory is the local digitizer repository!",
                      title = input$title,
                      autor = input$author,
                      pYear = input$pYear,
                      tesserAct = input$tesserAct,
                      dataInputDir= input$dataInputDir,
                      dataOutputDir = outDir,
                      allPrintedPages = input$allPrintedPages,
                      sNumberPosition = input$sNumberPosition,
                      # special config data, in relation with the book Moths of Europe
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
                      pColor = input$pColor)
      
      tf <- tempfile(fileext = ".csv")
      
      ## To write a CSV file for input to Excel one might use
      write.table(x, file = paste0(workingDir,"/config/config.csv"), sep = ";", row.names = FALSE,
                  quote=FALSE)
      
      shinyalert::shinyalert(title = "Success", text = "Configuration successfully saved!", type = "success")
      
    },  
    error = function(e) {
      errorMessage <- paste("Ein Fehler ist aufgetreten:", e$message)
      stackTrace <- paste("Stapelrückverfolgung:", traceback())
      shinyalert::shinyalert(title = "Fehler", text = c(errorMessage, stackTrace), type = "error")
    })
    
  })
  
  ####################
  # FUNCTIONS       #----------------------------------------------------------------------#
  ####################
  
  
  # Function to create a new folder and move data
  prepare_www_output  <- function(www_output  ) {
    tryCatch({
      file_list <- list.files(www_output , full.names = TRUE)
      # Lösche das Verzeichnis und alle seine Inhalte
      unlink(www_output , recursive = TRUE)
      # Überprüfe, ob der eingegebene Verzeichnispfad für die Eingabedaten gültig ist
      if (nchar(www_output  ) > 0) {
        if(!dir.exists(www_output)){
          dir.create(www_output  , recursive = TRUE)
        }
        
        directory_names <- c("align_png", "CircleDetection_png", "readSpecies_png", "georeferencing_png", 
                             "masking_black_png", "masking_circleDetection", "masking_png", "maskingCentroids","matching_png", "pages",
                             "pointFiltering_png", "pointMatching_png", "polygonize", "symbol_templates_png",
                             "map_templates_png")
        
        for (sub_dir_name in directory_names) {
          sub_dir_path <- file.path(www_output, sub_dir_name) 
          print(sub_dir_path)# Path for subdirectory
          dir.create(sub_dir_path, recursive = TRUE, showWarnings = FALSE)  # Create subdirectory
        }
        
      } else {
        # Zeige eine Fehlermeldung an, wenn der Verzeichnispfad ungültig ist
        showModal(modalDialog(
          title = "Error",
          "Please provide a valid input directory path."
        ))
        return()  # Stoppe die Funktion, falls der Verzeichnispfad ungültig ist
      }
    }, error = function(e) {
      cat("An error occurred during prepare_www_output processing:\n")
      print(e)
    })
  }
  
  # Function to create a new folder and move data
  prepare_base_output  <- function(base_path ) {
    tryCatch({
      # Überprüfe, ob der eingegebene Verzeichnispfad für die Eingabedaten gültig ist
      if (nchar(base_path ) > 0) {
        if(!dir.exists(base_path)){
          dir.create(base_path , recursive = TRUE)
        }
        
        directory_names <- c("final_output", "georeferencing",  "maps", "masking", 
                             "masking_black", "output_shape", "pagerecords", "polygonize",
                             "rectifying")
        
        # Iteriere über den Vektor und erstelle die Verzeichnisse
        for (dir_name in directory_names) {
          dir_path <- file.path(base_path, dir_name)  # Passe den Pfad entsprechend an
          dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)  # Erstelle das Verzeichnis
          # Check if the current directory is "maps"
          if (dir_name == "maps") {
            # Define subdirectory names for "maps"
            sub_directory_names <- c("align", "csvFiles", "matching", "readSpecies", "pointMatching")  # Add your subdirectory names here
            
            # Iterate over subdirectory names and create them within "maps"
            for (sub_dir_name in sub_directory_names) {
              sub_dir_path <- file.path(dir_path, sub_dir_name) 
              dir.create(sub_dir_path, recursive = TRUE, showWarnings = FALSE)  # Create subdirectory
            }
          }
          # Check if the current directory is "georeferencing"
          if (dir_name == "georeferencing") {
            # Define subdirectory names for "maps"
            sub_directory_names <- c("maps", "masks")  # Add your subdirectory names here
            
            # Iterate over subdirectory names and create them within "georeferencing"
            for (sub_dir_name in sub_directory_names) {
              sub_dir_path <- file.path(dir_path, sub_dir_name) 
              dir.create(sub_dir_path, recursive = TRUE, showWarnings = FALSE)  # Create subdirectory
            }
          }
          if (dir_name == "final_output" || dir_name == "maps" || dir_name == "masking_black"|| dir_name == "polygonize" || dir_name == "rectifying") {
            # Define subdirectory names"
            sub_directory_names <- c("circleDetection", "pointFiltering")  # Add your subdirectory names here
            
            # Iterate over subdirectory names and create them within 
            for (sub_dir_name in sub_directory_names) {
              sub_dir_path <- file.path(dir_path, sub_dir_name) 
              dir.create(sub_dir_path, recursive = TRUE, showWarnings = FALSE)  # Create subdirectory
            }
          }
        }
        
        
      } else {
        # Zeige eine Fehlermeldung an, wenn der Verzeichnispfad ungültig ist
        showModal(modalDialog(
          title = "Error",
          "Please provide a valid input directory path."
        ))
        return()  # Stoppe die Funktion, falls der Verzeichnispfad ungültig ist
      }
    }, error = function(e) {
      cat("An error occurred during prepare_base_output processing:\n")
      print(e)
    })
    # Letzte Zeile im try-Block – nach erfolgreichem Speichern
    stopApp(paste0(workingDir,"/config/config.csv"))
  }
  

})

shinyApp(ui, server)