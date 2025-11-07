# ============================================================
# Script Author: [Spaska Forteva]
# Created On: 2021-06-10
# Updated On: 2025-09-18
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

# ============================================================
# DEBUG: Show all arguments passed from the batch script
# ============================================================
print("=== DEBUG ARGS ===")
print(commandArgs(trailingOnly = TRUE))  # Print all trailing arguments
print("===================")

# ============================================================
# Read arguments safely with fallbacks
# ============================================================
args <- commandArgs(trailingOnly = TRUE)

# Host address for Shiny (default: localhost)
R_HOST <- ifelse(length(args) >= 1, args[[1]], "127.0.0.1")

# Port for Shiny (default: 8888)
# We must check for NA because invalid input (e.g. text instead of number)
# would otherwise produce NA and break Shiny ("Listening on NA").
R_PORT <- 8888
if (length(args) >= 2) {
  val <- suppressWarnings(as.integer(args[[2]]))
  if (!is.na(val)) {
    R_PORT <- val
  }
}

# Maximum request size (for file uploads) in bytes.
# Here fixed to 100 MB. 
# No need to read from arguments, this avoids parsing issues.
R_MAX_REQUEST_SIZE <- 100 * 1024^2

# Path to Python (used by reticulate)
PYTHON_PATH <- ifelse(length(args) >= 4, args[[4]], "C:/ProgramData/miniconda3/python.exe")

# Path to Tesseract installation folder
# Note: We do not add "tessdata" here, it will be appended below.
TESS_PATH <- ifelse(length(args) >= 5, args[[5]], "C:/Program Files/Tesseract-OCR")

# Script working directory (default: current working directory)
SCRIPT_DIR <- ifelse(length(args) >= 6, args[[6]], "D:/distribution_digitizer")

# ============================================================
# Apply Shiny options
# ============================================================
options(shiny.host = R_HOST)
options(shiny.port = as.integer(R_PORT))
options(shiny.maxRequestSize = R_MAX_REQUEST_SIZE)

# ============================================================
# Set the working directory for the app
# ============================================================
workingDir <- SCRIPT_DIR
if (workingDir == "") {
  workingDir <- getwd()  # fallback if empty
}
setwd(workingDir)

# ============================================================
# Set environment variable for Tesseract
# ============================================================
Sys.setenv(TESSDATA_PREFIX = file.path(TESS_PATH, "tessdata"))

# ============================================================
# Global variables
# ============================================================
processEventNumber = 0


# ==========================
# Initialization
# ==========================
setwd(workingDir)  # falls du auf relative Pfade angewiesen bist
inputDir <- file.path(workingDir, "data/input/")

tempImage <- "temp.png"
scale <- 20
rescale <- 100 / scale


#read config fields from config.csv in .../distribution_digitizer/config directory
fileFullPath = (paste0(workingDir,'/config/config.csv'))
if (file.exists(fileFullPath)){
  config <- read.csv(fileFullPath,header = TRUE, sep = ';')
} else{
  stop(paste0("file:", fileFullPath, "not found, please create them and start the app"))
}

if (file.exists(config$dataOutputDir)) {
  outDir <-  config$dataOutputDir
}

# read the shiny text fields
#1 shinyfields_create_templates.csv
fileFullPath = (paste0(workingDir,'/config/shinyfields_create_templates.csv'))
if (file.exists(fileFullPath)){
  shinyfields1 <- read.csv(fileFullPath, header = TRUE, sep = ';')
} else{
  stop("file shinyfields_create_templates.csv not found, please create them and start the app")
}
#2 shinyfields_detect_maps.csv
fileFullPath = (paste0(workingDir,'/config/shinyfields_detect_maps.csv'))
if (file.exists(fileFullPath)){
  shinyfields2 <- read.csv(fileFullPath,header = TRUE, sep = ';')
} else{
  stop(paste0("file:", fileFullPath, "not found, please create them and start the app"))
}

#3 shinyfields_detect_points.csv
fileFullPath = (paste0(workingDir,'/config/shinyfields_detect_points.csv'))
if (file.exists(fileFullPath)){
  shinyfields3 <- read.csv(fileFullPath,header = TRUE, sep = ';')
} else{
  stop(paste0("file:", fileFullPath, "not found, please create them and start the app"))
}

#4 shinyfields_detect_points_using_filtering
fileFullPath = (paste0(workingDir,'/config/shinyfields_detect_points_using_filtering.csv'))
if (file.exists(fileFullPath)){
  shinyfields4 <- read.csv(fileFullPath,header = TRUE, sep = ';')
} else{
  stop(paste0("file:", fileFullPath, "not found, please create them and start the app"))
}

#4.1 shinyfields_detect_points_using_circle_detection
fileFullPath = (paste0(workingDir,'/config/shinyfields_detect_points_using_circle_detection.csv'))
if (file.exists(fileFullPath)){
  shinyfields4.1 <- read.csv(fileFullPath,header = TRUE, sep = ';')
} else{
  stop(paste0("file:", fileFullPath, "not found, please create them and start the app"))
}

#5 shinyfields_masking
fileFullPath = (paste0(workingDir,'/config/shinyfields_masking.csv'))
if (file.exists(fileFullPath)){
  shinyfields5 <- read.csv(fileFullPath,header = TRUE, sep = ';')
} else{
  stop(paste0("file:", fileFullPath, "not found, please create them and start the app"))
}

#5.1 shinyfields_mask_centroids
fileFullPath = (paste0(workingDir,'/config/shinyfields_mask_centroids.csv'))
if (file.exists(fileFullPath)){
  shinyfields5.1 <- read.csv(fileFullPath,header = TRUE, sep = ';')
} else{
  stop(paste0("file:", fileFullPath, "not found, please create them and start the app"))
}

#6 shinyfields_georeferensing
fileFullPath = (paste0(workingDir,'/config/shinyfields_georeferensing.csv'))
if (file.exists(fileFullPath)){
  shinyfields6 <- read.csv(fileFullPath,header = TRUE, sep = ';')
} else{
  stop(paste0("file:", fileFullPath, "not found, please create them and start the app"))
}

#7 shinyfields_polygonize
fileFullPath = (paste0(workingDir,'/config/shinyfields_polygonize.csv'))
if (file.exists(fileFullPath)){
  shinyfields7 <- read.csv(fileFullPath,header = TRUE, sep = ';')
} else{
  stop(paste0("file:", fileFullPath, "not found, please create them and start the app"))
}

# 8 shinyfields_georef_coords_from_csv_file
fileFullPath = (paste0(workingDir,'/config/shinyfields_georef_coords_from_csv_file.csv'))
if (file.exists(fileFullPath)){
  shinyfields8 <- read.csv(fileFullPath,header = TRUE, sep = ';')
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
      menuItem("General Config", tabName = "tab0"),
      menuItem("Create Templates", tabName = "tab1"),
      menuItem("Maps Matching", tabName = "tab2"),
      menuItem("Points Matching", tabName = "tab3"),
      menuItem("Masking", tabName = "tab4" ),
      menuItem("Read Spacies", tabName = "tab5" ),
      menuItem("Georeferencing", tabName = "tab6" ),
      menuItem("Polygonize", tabName = "tab7" ),
      menuItem("Spatial View", tabName = "tab8" ),
      menuItem("Download", tabName = "tab9" )
    )
  )
)

body <- dashboardBody(
  # Top Information
  # Working directory
  
  # Add a title panel for the app and a link to the README.pdf file.  
  # The PDF contains program documentation and instructions.  
  # Users can click on the link (📘 Open README.pdf) to read more details 
  # about how the "Distribution Digitizer" works.  
  # The label/tooltip informs the user about the purpose of the link.
  titlePanel("Distribution Digitizer"),
  
  # Second title panel for the README link
  tags$h4(
    tags$a(
      href = "README.pdf",
      target = "_blank",
      "📘 Read the program description and usage instructions - README.pdf",
      title = "Read the program description and usage instructions"
    )
  ),
  br(),
  p(paste0(config$workingDirInformation, ": ", workingDir), style = "color:black"),
  
  br(),
  
  tabItems(
    # =============================
    # Tab 0 General Configuration
    # =============================
    tabItem(
      tabName = "tab0",
      wellPanel(
        h3("General configuration fields"),
        fluidRow(
          # Left column
          column(6,
                 fluidRow(
                   column(10, textInput("title", "Book Title", config$title)),
                   column(2, actionButton("showTitleInfo", "", icon = icon("question-circle")))
                 ),
                 conditionalPanel("input.showTitleInfo % 2 == 1", textOutput("titleInfo")),
                 
                 fluidRow(
                   column(10, textInput("author", "Author", config$autor)),
                   column(2, actionButton("showAuthorInfo", "", icon = icon("question-circle")))
                 ),
                 conditionalPanel("input.showAuthorInfo % 2 == 1", textOutput("authorInfo")),
                 
                 fluidRow(
                   column(10, textInput("pYear", "Publication Year", config$pYear)),
                   column(2, actionButton("showPYearInfo", "", icon = icon("question-circle")))
                 ),
                 conditionalPanel("input.showPYearInfo % 2 == 1", textOutput("pYearInfo")),
                 
                 fluidRow(
                   column(10, textInput("tesserAct", "Tesseract Path", config$tesserAct)),
                   column(2, actionButton("showTesseractInfo", "", icon = icon("question-circle")))
                 ),
                 conditionalPanel("input.showTesseractInfo % 2 == 1", textOutput("tesseractInfo"))
          ),
          
          # Right column
          column(6,
                 fluidRow(
                   column(10, textInput("dataInputDir", "Input Directory", config$dataInputDir)),
                   column(2, actionButton("showInputDirInfo", "", icon = icon("question-circle")))
                 ),
                 conditionalPanel("input.showInputDirInfo % 2 == 1", textOutput("inputDirInfo")),
                 
                 fluidRow(
                   column(10, textInput("dataOutputDir", "Output Directory", config$dataOutputDir)),
                   column(2, actionButton("showOutputDirInfo", "", icon = icon("question-circle")))
                 ),
                 conditionalPanel("input.showOutputDirInfo % 2 == 1", textOutput("outputDirInfo")),
                 
                 fluidRow(
                   column(10, selectInput("pFormat", "Image Format", 
                                          choices = c("tif" = 1, "png" = 2, "jpg" = 3),
                                          selected = config$pFormat)),
                   column(2, actionButton("showPFormatInfo", "", icon = icon("question-circle")))
                 ),
                 conditionalPanel("input.showPFormatInfo % 2 == 1", textOutput("pFormatInfo")),
                 
                 fluidRow(
                   column(10, selectInput("pColor", "Page Color", 
                                          choices = c("black white" = 1, "color" = 2),
                                          selected = config$pColor)),
                   column(2, actionButton("showPColorInfo", "", icon = icon("question-circle")))
                 ),
                 conditionalPanel("input.showPColorInfo % 2 == 1", textOutput("pColorInfo")),
                 
                 fluidRow(
                   column(10, textInput("allPrintedPages", "Number of Scanned Images", config$allPrintedPages)),
                   column(2, actionButton("showAllPagesInfo", "", icon = icon("question-circle")))
                 ),
                 conditionalPanel("input.showAllPagesInfo % 2 == 1", textOutput("allPagesInfo"))
          )
        ),actionButton("saveConfig", "Save", style = "color:#FFFFFF;background:#999999")
      )
    ),
    
    # =============================
    # Tab 1 Create Templates
    # =============================
    tabItem(
      tabName = "tab1",
      actionButton("listMTemplates",  label = "List saved map templates"),
      actionButton("listSTemplates",  label = "List saved symbol templates"),
      
      fluidRow(
        column(4,
               wellPanel(
                 h3(strong(shinyfields1$head, style = "color:black")),
                 p(shinyfields1$inf4, style = "color:black"),
                 # Choose the file 
                 fileInput("image",  label = h5(shinyfields1$lab1), buttonLabel = "Browse...",
                           placeholder = "No file selected"),
               ),
               
               wellPanel(
                 
                 p(HTML(shinyfields1$inf), style = "color:red"),
                 p(strong(paste0(workingDir, "/data/templates/maps/"))),
                 # Add number to the file name of the created template file
                 fluidRow(column(8, numericInput("imgIndexTemplate", label = h5(shinyfields1$lab2),value = 1),    
                                 # Save the template map image with the given index
                                 downloadButton('saveTemplate', '💾 Save Map Template', 
                                                style="color:#FFFFFF;background:#0073e6"))),
                 p(shinyfields1$inf1, style = "color:black"),
               ),
               wellPanel(
                 
                 p(HTML(shinyfields1$inf), style = "color:red"),
                 p(strong(paste0(workingDir, "/data/templates/symbols/"))),
                 # Add number to the file name of the created template file
                 fluidRow(column(8, numericInput("imgIndexTemplate", label = h5(shinyfields1$lab2),value = 1),
                                 # Save the template map image with the given index
                                 downloadButton('saveSymbol', '💾 Save Symbol Template', 
                                                style="color:#FFFFFF;background:#28a745"))),
                 p(shinyfields1$inf2, style = "color:black"),
                 
               )
        ), # col 4
        column(8,
               uiOutput('listMapTemplates', style="width:35%;float:left"),
               uiOutput('listSymbolTemplates', style="width:35%;float:left"),
               plotOutput("plot", click = "plot_click",  # Equiv, to click=clickOpts(id="plot_click")
                          hover = hoverOpts(id = "plot_hover", delayType = "throttle"),
                          brush = brushOpts(id = "plot_brush")),
        )
      ) # END fluid Row
    ),  # END tabItem 1
    
    
    # =============================
    # Tab 2 Maps Matching
    # =============================
    tabItem(
      fluidRow(column(8,wellPanel(
        textInput("siteNumberMapsMatching", label=HTML(shinyfields2$inf6), value = ''),
        selectInput("matchingType", label = HTML(shinyfields2$matchingType), c("Template matching" = 1, "Contour matching" = 2), 1),
        selectInput("sNumberPosition", "Page Number Position", c("top" = 1, "bottom" = 2), selected = 1),))),
      tabName = "tab2",
      # actionButton("listCropped",  label = "List cropped maps"),
      fluidRow(
        column(4,
               wellPanel(
                 # submit action button
                 h3(strong(shinyfields2$head, style = "color:black")),
                 p(shinyfields2$inf1, style = "color:black"),
                 fluidRow(column(8, numericInput("threshold_for_TM", label = shinyfields2$threshold, value = 0.18, min = 0, max = 1, step = 0.05))),
                 # Start map matchings
                 fluidRow(column(3,actionButton("templateMatching",  
                                                label = shinyfields2$start1, 
                                                style="color:#FFFFFF;background:#28a745"))),
                 p(shinyfields2$inf2, style = "color:black"), 
                 
               ),
               wellPanel(
                 # maps align 
                 h4(shinyfields2$head_sub, style = "color:black"),
                 p(shinyfields2$inf3, style = "color:black"),
                 fluidRow(column(3,  actionButton("alignMaps",
                                                  label = shinyfields2$start2,
                                                  style = "color:#FFFFFF;background:#007bff"
                 ))),
                 
               )
        ), # col 4
        column(8,actionButton("listMapsMatching",  label = "List maps"),
               actionButton("listAlign",  label = "List aligned maps"),
               uiOutput('listMaps', style="width:30%;float:left"),
               uiOutput('listAlign', style="width:30%;float:left"),
               #uiOutput('listCropped', style="width:30%;float:left")
        )
      ) # END fluid Row
    ),  # END tabItem 2
    
    
    # =============================
    # Tab 3 Points Matching
    # =============================
    tabItem(
      tabName = "tab3",
      fluidRow(column(3,textInput("siteNumberPointsMatching", label=shinyfields6$input, value = ''))),
      actionButton("listMapsMatching2",  label = "List maps"),
      actionButton("listPointsM",  label = "List points matching"),
      actionButton("listPointsF",  label = "List points filterng"),
      actionButton("listPointsCD", label = "List points circle detection"),
      fluidRow(
        column(4,
               wellPanel(
                 h3(strong(shinyfields3$head, style = "color:black")),
                 p(shinyfields3$inf1, style = "color:black"),
                 p(shinyfields3$inf2, style = "color:black"),
               ),
               wellPanel(
                 # ----------------------------------------# 3.1 Points detection Using template  FILE=shinyfields_detect_points #---------------------------------------------------------------------
                 h4(shinyfields3$head_sub, style = "color:black"),
                 p(shinyfields3$inf3, style = "color:black"),
                 # Threshold for point matching
                 fluidRow(column(8,numericInput("threshold_for_PM", label = shinyfields3$threshold, value = 0.75, min = 0, max = 1, step = 0.05))),
                 p(shinyfields3$inf4, style = "color:black"),
                 fluidRow(column(3, actionButton("pointMatching",  label = shinyfields3$lab, style="color:#FFFFFF;background:#999999"))),
               ),
               wellPanel(
                 # ----------------------------------------# 3.2 Points detection Using filtering  FILE=shinyfields_detect_points_using_filtering #---------------------------------------------------
                 h4(shinyfields4$head, style = "color:black"),
                 fluidRow(column(8,numericInput("filterK", label = shinyfields4$lab1, value = 5))),#, width = NULL, placeholder = NULL)
                 p(shinyfields4$inf1, style = "color:black"),
                 fluidRow(column(8,numericInput("filterG", label = shinyfields4$lab2, value = 9))),#, width = NULL, placeholder = NULL)
                 p(shinyfields4$inf2, style = "color:black"),
                 fluidRow(column(3, actionButton("pointFiltering",  label = shinyfields4$lab3, style="color:#FFFFFF;background:#999999"))),
               ),
               wellPanel(
                 # ----------------------------------------# 3.3 Points detection Using circle detection  FILE=shinyfields_detect_points_using_circle_detection #------------------------------------
                 h4(shinyfields4.1$head, style = "color:black"),
                 fluidRow(column(8,numericInput("Gaussian", label = shinyfields4.1$lab1, value = 5, min = 0))),
                 p(shinyfields4.1$inf1, style = "color:black"),
                 fluidRow(column(8,numericInput("minDist", label = shinyfields4.1$lab2, value = 1, min = 0))),
                 p(shinyfields4.1$inf2, style = "color:black"),
                 fluidRow(column(8,numericInput("thresholdEdge", label = shinyfields4.1$lab3, value = 100, min = 0))),
                 p(shinyfields4.1$inf3, style = "color:black"),
                 fluidRow(column(8,numericInput("thresholdCircles", label = shinyfields4.1$lab4, value = 21, min = 0))),
                 p(shinyfields4.1$inf4, style = "color:black"),
                 fluidRow(column(8,numericInput("minRadius", label = shinyfields4.1$lab5, value = 3, min = 0))),
                 p(shinyfields4.1$inf5, style = "color:black"),
                 fluidRow(column(8,numericInput("maxRadius", label = shinyfields4.1$lab6, value = 12, min = 0))),
                 p(shinyfields4.1$inf6, style = "color:black"),
                 p(shinyfields4.1$inf7, style = "color:black"),
                 fluidRow(column(3, actionButton("pointCircleDetection",  label = shinyfields4.1$lab7, style="color:#FFFFFF;background:#999999"))),
               )
        ), # col 4
        column(8,
               uiOutput('listMapsMatching2', style="width:25%;float:left"),
               uiOutput('listPM', style="width:25%;float:left"),
               uiOutput('listPF', style="width:25%;float:left"),
               uiOutput('listPCD', style="width:25%;float:left")
        )
      ) # END fluid Row
    ),  # END tabItem 3
    
    
    # =============================
    # Tab 4 Masking
    # =============================
    tabItem(
      tabName = "tab4",  
      fluidRow(column(3,textInput("siteNumberMasks", label=shinyfields6$input, value = ''))),
      actionButton("listMasks",  label = "List masks"),
      actionButton("listMasksB",  label = "List black masks"),
      actionButton("listMasksCD",  label = "List CD masks"),
      # actionButton("listMPointsF",  label = "List points filterng"),
      fluidRow(
        column(4,
               wellPanel(
                 h3(strong(shinyfields5$head, style = "color:black"))
               ),
               wellPanel(
                 # ----------------------------------------# 4. 1 Masking (white)#----------------------------------------------------------------------
                 h3(shinyfields5$head_sub, style = "color:black"),
                 h4("You can extract masks with white background", style = "color:black"),
                 p(shinyfields5$inf1, style = "color:black"),
                 # p(shinyfields7$inf2, style = "color:black"),
                 fluidRow(column(8,numericInput("morph_ellipse", label = shinyfields5$lab1, value = 5))),#, width = NULL, placeholder = NULL)
                 fluidRow(column(3, actionButton("masking",  label = shinyfields5$lab2, style="color:#FFFFFF;background:#999999"))),
               ), 
               #wellPanel(
               # ----------------------------------------# Masking (black)#----------------------------------------------------------------------
               #   h4("Or you can extract masks with black background", style = "color:black"),
               #   p(shinyfields5$inf2, style = "color:black"),
               #   fluidRow(column(8,numericInput("morph_ellipse", label = shinyfields5$lab1, value = 5))),#, width = NULL, placeholder = NULL)
               #   fluidRow(column(3, actionButton("maskingBlack",  label = shinyfields5$lab2, style="color:#FFFFFF;background:#999999"))),
               # ),
               # ---------------------------------------- # 4.2 Masking centroids -----------------------------------------------------------------
               wellPanel(
                 h3(shinyfields5.1$head_sub, style = "color:black"),
                 h4("You can mask the centroids of the points detected by Point Filtering and Circle Detection.", style = "color:black"),
                 p(shinyfields5.1$inf1, style = "color:black"),
                 fluidRow(column(3, actionButton("maskingCentroids",  label = shinyfields5.1$lab1, style="color:#FFFFFF;background:#999999")))
               )
        ), # col 4
        column(8,
               uiOutput('listMS', style="float:left"),
               uiOutput('listMSB', style="float:left"),
               uiOutput('listMCD', style="float:left")
        )
      ) # END fluid Row
    ),  # END tabItem 4
    
    
    # =============================
    # Tab 5 Read Spezies
    # =============================
    tabItem(
      tabName = "tab5",
      # which site become overview
      fluidRow(column(3,textInput("siteNumberMapsMatching", label=shinyfields6$input, value = ''))),
      actionButton("listCropped",  label = "List cropped maps"),
      fluidRow(
        column(4,
               # speciesOnMap
               wellPanel(  
                 # maps species 
                 h3(shinyfields2$head_species, style = "color:black"),
                 p(shinyfields2$inf4, style = "color:black"),
                 fluidRow(column(3, actionButton("mapReadRpecies",  label = shinyfields2$start3, style="color:#FFFFFF;background:#999999"))),
               ),
               wellPanel(  
                 # page species
                 h3(shinyfields2$head_page_species, style = "color:black"),
                 p(shinyfields2$inf5, style = "color:black"),
                 fluidRow(column(3, actionButton("pageReadRpecies",  label = shinyfields2$start4, style="color:#FFFFFF;background:#999999"))),
               )
        ), # col 4v
        #column(8,
        #       uiOutput('listCropped', style="width:30%;float:left")
        # )
      ) # END fluid Row
    ),  # END tabItem 5
    
    
    # Tab 6 Georeferencing  FILES=shinyfields_georeferensing & shinyfields_georef_coords_from_csv_file.csv #-------------------------------------------------
    tabItem(
      tabName = "tab6",  
      wellPanel(
        h3(strong(shinyfields6$head, style = "color:black")),
        p(shinyfields6$inf1, style = "color:black"),
        p(shinyfields6$inf2, style = "color:black"),
        # start georeferencing
        actionButton("georeferencing",  label = shinyfields6$lab1, style="color:#FFFFFF;background:#999999")
      ),
      wellPanel(
        # which site become overview
        fluidRow(column(3,textInput("siteNumberGeoreferencing", label=shinyfields6$input, value = ''))),
        # start overview 
        actionButton("listGeoreferencing",  label = "List georeferenced files"),
      ),
      wellPanel(
        uiOutput('leaflet_outputs_GEO')
      ),
      wellPanel(
        h4(shinyfields8$head_sub, style = "color:red"),
        p(shinyfields8$info1, style = "color:black"),
        p(shinyfields8$info2, style = "color:black"),
        actionButton("georef_coords_from_csv", label = shinyfields8$lab1, style="color:#FFFFFF;background:#999999")
      )
      # END fluid Row
    ),# END tabItem 6
    
    
    # =============================
    # Tab 7 Polygonize  FILE=shinyfields_polygonize
    # =============================
    tabItem(
      tabName = "tab7", 
      wellPanel(
        h3(strong(shinyfields7$head, style = "color:black")),
        p(shinyfields7$inf1, style = "color:black"),
        p(shinyfields7$inf2, style = "color:black"),
        actionButton("polygonize",  label = shinyfields7$lab1, style="color:#FFFFFF;background:#999999")
      ),
      wellPanel(
        # which site become overview
        fluidRow(column(3,textInput("siteNumberPolygonize", label=shinyfields6$input, value = ''))),
        actionButton("listPolygonize",  label = "Listf polygonized files",),
      ),
      wellPanel( 
        uiOutput("leaflet_outputs_PL")
      )
    ),  # END tabItem 7
    
    # Tab 8 Spatial data view #----------------------------------------------------------------------
    tabItem(
      tabName = "tab8", 
      # wellPanel(
      #  h3(strong("Save the outputs in csv file", style = "color:black")),
      #  p("hier kommt noch mehr Text", style = "color:black"),
      #  p("hier kommt noch mehr Text", style = "color:black"),
      actionButton("startSpatialDataComputing",  label ="Spatial Data Computing", style="color:#FFFFFF;background:#999999"),
      #),
      wellPanel(
        # which site become overview
        #fluidRow(column(3,textInput("siteNumberSave", label="Test", value = ''))),
        
        actionButton("spatialViewPF",  label = "Start View point detection",),
        leafletOutput("mapSpatialViewPF"),
        verbatimTextOutput("hoverInfo3")
      ),
      # wellPanel(
      # which site become overview
      #fluidRow(column(3,textInput("siteNumberSave", label="Test", value = ''))),
      
      #actionButton("spatialViewCD",  label = "Start View circle detection",),
      #leafletOutput("mapSpatialViewCD"),
      #verbatimTextOutput("hoverInfo")
      #)
      
    ),  # END tabItem 8
    
    tabItem(
      tabName = "tab9",
      actionButton("viewCSV",  label ="Overview spatial final data", style="color:#FFFFFF;background:#999999"),
      
      wellPanel( 
        #downloadButton("downloadCSV", label = "Download CSV", style="color:#FFFFFF;background:#999999"),
        downloadButton("download_csv", label = "Download CSV", style="color:#FFFFFF;background:#999999"),
        
        dataTableOutput("view_csv")
      ),
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
#                         SERVER CODE
################################################################################
################################################################################

server <- shinyServer(function(input, output, session) {
  
  # Register a resource path for the README.pdf file.  
  # This maps the URL path "README.pdf" to the actual file location  
  # inside the app directory (workingDir/www/README.pdf).  
  # It ensures the file can be accessed via a browser link like /README.pdf.
  addResourcePath("README.pdf", file.path(workingDir, "www/README.pdf"))
  
  
  # Render help text for the "Author" field. 
  # This text is displayed when the user clicks the "Info" button 
  # in Tab 0 (General Config). It explains what should be entered 
  # in the "Author" text input.
  observeEvent(input$showAuthorInfo, {
    shinyalert(
      "Author-Informations",
      "Here you can enter the author's full name as it appears in the book.",
      type = "info",
      showConfirmButton = TRUE, closeOnEsc = TRUE,
      closeOnClickOutside = TRUE, animation = TRUE
      
      
    )
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
      pFormat = input$pFormat,
      pColor = input$pColor,
      allPrintedPages = input$allPrintedPages
    )
    write.table(x, file = file.path(workingDir, "config/config.csv"), sep = ";", row.names = FALSE, quote = FALSE)
    shinyalert("Success", "Configuration successfully saved!", type = "success")
  })
  
  # Render help text for the "Title" field.
  # Opens an info dialog when the user clicks the "?" button.
  observeEvent(input$showTitleInfo, {
    shinyalert(
      "Book Title",
      "Enter the full book title as it appears on the cover or title page.",
      type = "info",
      showConfirmButton = TRUE, closeOnEsc = TRUE,
      closeOnClickOutside = TRUE, animation = TRUE
    )
  })
  
  # Render help text for the "Author" field.
  observeEvent(input$showAuthorInfo, {
    shinyalert(
      "Author Information",
      "Here you can enter the author's full name as it appears in the book.",
      type = "info",
      showConfirmButton = TRUE, closeOnEsc = TRUE,
      closeOnClickOutside = TRUE, animation = TRUE
    )
  })
  
  # Render help text for the "Publication Year" field.
  observeEvent(input$showPYearInfo, {
    shinyalert(
      "Publication Year",
      "Provide the year in which the book was published.",
      type = "info",
      showConfirmButton = TRUE, closeOnEsc = TRUE,
      closeOnClickOutside = TRUE, animation = TRUE
    )
  })
  
  # Render help text for the "Tesseract Path" field.
  observeEvent(input$showTesseractInfo, {
    shinyalert(
      "Tesseract Path",
      "Specify the installation path of Tesseract OCR (e.g., C:/Program Files/Tesseract-OCR).",
      type = "info",
      showConfirmButton = TRUE, closeOnEsc = TRUE,
      closeOnClickOutside = TRUE, animation = TRUE
    )
  })
  
  # Render help text for the "Input Directory" field.
  observeEvent(input$showInputDirInfo, {
    shinyalert(
      "Input Directory",
      "Select or enter the folder where your scanned input files are stored.",
      type = "info",
      showConfirmButton = TRUE, closeOnEsc = TRUE,
      closeOnClickOutside = TRUE, animation = TRUE
    )
  })
  
  # Render help text for the "Output Directory" field.
  observeEvent(input$showOutputDirInfo, {
    shinyalert(
      "Output Directory",
      "Choose the folder where the processed and digitized output will be saved.",
      type = "info",
      showConfirmButton = TRUE, closeOnEsc = TRUE,
      closeOnClickOutside = TRUE, animation = TRUE
    )
  })
  
  # Render help text for the "Image Format" field.
  observeEvent(input$showPFormatInfo, {
    shinyalert(
      "Image Format",
      "Select the desired image format (e.g., tif, png, jpg) for your digitized pages.",
      type = "info",
      showConfirmButton = TRUE, closeOnEsc = TRUE,
      closeOnClickOutside = TRUE, animation = TRUE
    )
  })
  
  # Render help text for the "Page Color" field.
  observeEvent(input$showPColorInfo, {
    shinyalert(
      "Page Color",
      "Choose whether the scanned pages are black & white or in color.",
      type = "info",
      showConfirmButton = TRUE, closeOnEsc = TRUE,
      closeOnClickOutside = TRUE, animation = TRUE
    )
  })
  
  # Render help text for the "Number of Scanned Images" field.
  observeEvent(input$showAllPagesInfo, {
    shinyalert(
      "Number of Scanned Images",
      "Enter the total number of scanned images to be processed.",
      type = "info",
      showConfirmButton = TRUE, closeOnEsc = TRUE,
      closeOnClickOutside = TRUE, animation = TRUE
    )
  })
  
  dataInputDir = ""
  # Update the clock every second using a reactiveTimer
  current_time <- reactiveTimer(1000)
  
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
  
  # ============================================================
  # Observe button/listener: input$listMapsMatching
  # ------------------------------------------------------------
  # This function reacts when the user presses the "List Maps" button
  # (or triggers the event bound to input$listMapsMatching).
  #
  # Based on the text entered in input$siteNumberMapsMatching,
  # it decides which pages should be prepared and shown:
  #
  # - Single number (e.g. "5"): Show exactly ONE page.
  # - Range (e.g. "5-10"): Show all pages in the range (here: 6 pages).
  # - "all" or empty input: Show ALL pages.
  #
  # The logic then calls prepareImageView(), which:
  #   1. Copies the selected images from /data/matching_png/
  #      into the Shiny www/ folder (so they can be displayed in the browser).
  #   2. Returns <img> UI tags for the images.
  # ============================================================
  observeEvent(input$listMapsMatching, {
    output$listMaps <- renderUI({
      # Default behavior = show all pages
      prepareImageView("matching_png", ".png")
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
        prepareImageView("/align_png/", input$siteNumberMapsMatching)
      })
    }
    else{
      output$listAlign = renderUI({
        prepareImageView("/align_png/", '.png')
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
    #Processing georeferencing
    fname=paste0(workingDir, "/", "src/georeferencing/geo_points_extraction.py")
    source_python(fname)
    maingeopointextract(workingDir,outDir, input$filterm)
    cat("\nSuccessfully executed")
  })
  
  observeEvent(input$georeferencing, {
    # call the function for filtering
    manageProcessFlow("georeferencing", "georeferencing", "georeferencing")
  })
  
  
  # Georeferencing list maps
  observeEvent(input$listGeoreferencing, {
    
    # Anzahl der Leaflet-Elemente, die Sie hinzufügen möchten
    # show start action message
    message=paste0("Process ", "Georeferencing", " is started on: ")
    shinyalert(text = paste(message, format(current_time(), "%H:%M:%S")), type = "info", showConfirmButton = FALSE, closeOnEsc = TRUE,
               closeOnClickOutside = FALSE, animation = TRUE)
    #outDir <- "D:/test/output_2025-03-27_12-30-59/"
    listgeoTiffiles = list.files(paste0(outDir, "/rectifying/maps"), full.names = T, pattern = paste0('.tif',input$siteNumberGeoreferencing))
    if( length(listgeoTiffiles) == 0) {
      listgeoTiffiles = list.files(paste0(outDir, "/rectifying/maps"), full.names = T, pattern = '.tif')
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
  
  
  observeEvent(input$listPolygonize, {
    tryCatch({
      config <- read.csv(paste0(workingDir,"/config/config.csv"), header = TRUE, sep = ';')
      outDir <- config$dataOutputDir
      listShapefiles = list.files(paste0(outDir, "/polygonize/pointFiltering/"), full.names = T, pattern = '.shp')
      listShapefiles = grep(input$siteNumberPolygonize, listShapefiles, value= TRUE)
      muster <- "filtered"
      listShapefiles <- grep(paste0("^((?!(", muster, ")).)*$"), listShapefiles, value = TRUE, perl = TRUE)
      print(listShapefiles)
      num_leaflet_outputs <- length(listShapefiles)
      print(num_leaflet_outputs)
      listPng = list.files(paste0(workingDir, "/www/data/pointFiltering_png/"), full.names = F, pattern = input$siteNumberPolygonize)
      
      output$leaflet_outputs_PL <- renderUI({
        leaflet_outputs_list <- lapply(1:num_leaflet_outputs, function(i) {
          leafletOutput(outputId = paste0("listPL", i))
        })
        do.call(tagList, leaflet_outputs_list)
      })
      
      leaflet_list_PL <- lapply(seq_along(listShapefiles), function(i) {
        # Read shapefile
        shape_data <- st_read(listShapefiles[i])
        
        # Function to convert RGB to HEX
        rgb_to_hex <- function(r, g, b) {
          rgb(r / 255, g / 255, b / 255, maxColorValue = 1)
        }
        
        leaflet() %>%
          addTiles() %>%
          addCircleMarkers(data = shape_data,
                           # lng = ~st_coordinates(geometry)[,1],  # Längengrad
                           # lat = ~st_coordinates(geometry)[,2],  # Breitengrad
                           color = ~rgb_to_hex(Red, Green, Blue),  # Farbattribute verwenden
                           weight = 1,
                           opacity = 0.9,
                           fillOpacity = 0.5,
                           radius = 5) %>%
          addControl(
            htmltools::div(
              p(listShapefiles[i]),
            ),
            position = "bottomright"
          ) %>%
          addControl(
            htmltools::div(
              img(src = paste0("/data/pointFiltering_png/",listPng[i]), width = 200, height = 200),
              tags$a(href = paste0("/data/matching_png/",listPng[i]), listPng[i], target="_blank"),
            ),
            position = "bottomleft"
          )
      })
      
      leaflet_lists <- lapply(1:length(leaflet_list_PL), function(i) {
        output[[paste0('listPL', i)]] <- renderLeaflet({ leaflet_list_PL[[i]] })
      })
    }, error = function(e) {
      message <- paste("Error in observeEvent(input$listPolygonize):", e$message)
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
      # IMPORTANT not remove!
      config <- read.csv(paste0(workingDir,"/config/config.csv"), header = TRUE, sep = ';')
      outDir <- config$dataOutputDir
      customMouseover <- JS(
        "function(event) { var layer = event.target;
      layer.bindPopup('Dies ist ein benutzerdefinierter Mouseover-Text').openPopup();}"
      )
      marker_data <- read.csv(paste0(outDir, "/spatial_final_data_with_realXY.csv"), sep = ";", header = TRUE)
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
    config <- read.csv(paste0(workingDir,"/config/config.csv"),header = TRUE, sep = ';')
    outDir = config$dataOutputDir
    
    customMouseover <- JS(
      "function(event) {
        var layer = event.target;
        layer.bindPopup('Dies ist ein benutzerdefinierter Mouseover-Text').openPopup();
      }"
    )
    
    # Einlesen der Daten
    filtered_data <- read.csv(paste0(outDir, "/spatial_final_data.csv"), sep = ";", header = TRUE)
    
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
      csv_path <- paste0(outDir, "/spatial_final_data.csv")
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
    
    # IMPORTANT not remove!
    config <- read.csv(paste0(workingDir,"/config/config.csv"),header = TRUE, sep = ';')
    outDir = config$dataOutputDir
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
    
    if(processing == "alignMaps" ){
      tryCatch({
        
        # align
        fname=paste0(workingDir, "/", "src/matching/map_align.py")
        print("Processing align python script:")
        print(fname)
        source_python(fname)
        align_images_directory(workingDir, outDir)
        
        cat("\nSuccessfully executed")
        findTemplateResult = paste0(outDir, "/maps/align/")
        files<- list.files(findTemplateResult, full.names = TRUE, recursive = FALSE)
        countFiles = paste0(length(files),"")
        
        # convert the tif images to png and show this on the plot
        convertTifToPngSave(paste0(outDir, "/maps/align/"), paste0(workingDir, "/www/data/align_png/"))
        
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
        species <- read_legends(workingDir, outDir)
        cat("\nSuccessfully executed")
        findTemplateResult <- paste0(outDir, "/maps/readSpecies/")
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
        print(paste0("Reading page species data and saving the results to a 'pageSpeciesData.csv' file in the ", outDir," directory"))
        source(fname)
        if(length(config$keywordReadSpecies) > 0) {
          species <- readPageSpecies(workingDir, outDir, config$keywordReadSpecies, config$keywordBefore, config$keywordThen, config$middle)
        } else {
          species <- readPageSpecies(workingDir, outDir, 'None', config$keywordBefore, config$keywordThen, config$middle)
        }
        
        cat("\nSuccessfully executed")
        findTemplateResult <- paste0(outDir, "/maps/align/")
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
        map_points_matching(workingDir, outDir, input$threshold_for_PM)
        findTemplateResult = paste0(outDir, "/maps/pointMatching/")
        print(findTemplateResult)
        cat("\nSuccessfully executed")
        files <- list.files(findTemplateResult, full.names = TRUE, recursive = FALSE)
        countFiles <- paste0(length(files), "")
        #outDir = "D:/test/output_2024-07-12_08-18-21/"
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
        main_point_filtering(workingDir, outDir, input$filterK, input$filterG)
        
        cat("\nSuccessfully executed")
        # convert the tif images to png and save in www
        findTemplateResult = paste0(outDir, "/maps/pointFiltering/")
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
        print(outDir)
        mainCircleDetection(workingDir, outDir, input$Gaussian, input$minDist, 
                            input$thresholdEdge, input$thresholdCircles, input$minRadius, input$maxRadius)
        
        # convert the tif images to png and save in www
        findTemplateResult = paste0(outDir, "/maps/circleDetection/")
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
        mainGeomask(workingDir, outDir, input$morph_ellipse)
        
        fname=paste0(workingDir, "/", "src/masking/creating_masks.py")
        print(" Process masking black python script:")
        print(fname)
        source_python(fname)
        mainGeomaskB(workingDir, outDir, input$morph_ellipse)
        
        findTemplateResult = paste0(outDir, "/masking/")
        files <- list.files(findTemplateResult, full.names = TRUE, recursive = FALSE)
        countFiles <- paste0(length(files), "")
        message <- paste0("Ended on: ", 
                          format(current_time(), "%H:%M:%S \n"), " The number masks ", " are \n", 
                          countFiles, " and saved in directory \n", findTemplateResult)
        
        convertTifToPngSave(findTemplateResult, paste0(workingDir, "/www/data/masking_png/"))
        
        findTemplateResult = paste0(outDir, "/masking_black/")
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
        MainMaskCentroids(workingDir, outDir)
        
        findTemplateResult = paste0(outDir, "/masking_black/pointFiltering/")
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
        #mainmaskgeoreferencingMaps(workingDir, outDir)
        #mainmaskgeoreferencingMaps_CD(workingDir, outDir)
        #mainmaskgeoreferencingMasks(workingDir, outDir)
        #mainmaskgeoreferencingMasks_CD(workingDir, outDir)
        mainmaskgeoreferencingMasks_PF(workingDir, outDir)
        # processing rectifying
        
        fname=paste0(workingDir, "/", "src/polygonize/rectifying.py")
        print(" Process rectifying python script:")
        print(fname)
        source_python(fname)
        mainmaskgeoreferencingMaps(workingDir, outDir)
        mainRectifying_Map_PF(workingDir, outDir)
        mainRectifying(workingDir, outDir)
        mainRectifying_CD(workingDir, outDir)
        mainRectifying_PF(workingDir, outDir)
        #outDir = "D:/test/output_2024-08-05_15-38-45/"
        findTemplateResult = paste0(outDir, "/georeferencing/maps/pointFiltering/")
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
        mainCentroidGeoref(workingDir, outDir)
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
        #mainPolygonize(workingDir, outDir)
        #mainPolygonize_Map_PF(workingDir, outDir)
        mainPolygonize_CD(workingDir, outDir)
        mainPolygonize_PF(workingDir, outDir)
        findTemplateResult = paste0(outDir, "/polygonize/pointFiltering")
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
          #main_circle_detection(workingDir, outDir)
          #main_point_filtering(workingDir, outDir)
          
          #fname=paste0(workingDir, "/", "src/extract_coordinates/extract_coords.py")
          #source_python(fname)
          #main_circle_detection(workingDir, outDir)
          #main_point_filtering(workingDir, outDir)
          
          # prepare pages as png for the spatia view
          convertTifToPngSave(paste0(workingDir, "/data/input/pages/"),paste0(workingDir, "/www/data/pages/"))
          source(paste0(workingDir, "/src/spatial_view/merge_spatial_final_data.R"))
          mergeFinalData(workingDir, outDir)
          spatialFinalData(outDir)
          spatialRealCoordinats(outDir)
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
                          " The data spatial_final_data.csv in: " , outDir)
        }
      )
    }
    
    if(processing == "view_csv"){
      # Hier können Sie den Pfad zu Ihrer CSV-Datei angeben
      csv_path <- paste0(outDir, "/spatial_final_data.csv")
      
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
    shinyalert(text = paste(message, format(current_time(), "%H:%M:%S"), "!\n Results are located at: " , outDir ), type = "info", showConfirmButton = TRUE, closeOnEsc = TRUE,
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
  
  prepareImageView <- function(dirName, index){
    tryCatch({
      pathToMatchingImages <- file.path(workingDir, "www", "data", dirName)
      cat("DEBUG pathToMatchingImages:", pathToMatchingImages, "\n")
      
      if(index != ".png"){ index <- paste0("^", index, "\\w*") }
      cat("DEBUG pattern:", index, "\n")
      
      listPngImages <- list.files(pathToMatchingImages, full.names = FALSE, pattern = index)
      cat("DEBUG found files:", listPngImages, "\n")
      
      if (length(listPngImages) == 0) {
        return(HTML("<p><i>No images found.</i></p>"))
      }
      
      display_image <- function(i) {
        relPath <- file.path("data", dirName, listPngImages[i])  # relative path
        HTML(paste0(
          '<div class="shiny-map-image">',
          '<img src="', relPath, '" style="width:100%;">',
          '<a href="', relPath, '" style="width:27%;" target=_blank>', listPngImages[i], '</a>',
          '</div>'
        ))
      }
      
      lapply(seq_along(listPngImages), display_image)
    }, error = function(e) {
      cat("An error occurred during prepareImageView processing:\n")
      print(e)
    })
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
    tryCatch({
      # --- cleanup: remove old PNG files ---
      oldPngFiles <- list.files(pathToPngImages, pattern = "\\.png$", full.names = TRUE)
      if (length(oldPngFiles) > 0) {
        file.remove(oldPngFiles)
      }
      
      # Get list of tif files
      tifFiles <- list.files(pathToTiffImages, pattern = "\\.tif$", recursive = FALSE)
      
      # Convert tif to png and save in the given path
      for (f in tifFiles) {
        tifFile <- file.path(pathToTiffImages, f)
        
        if (file.exists(tifFile)) {
          tifImage <- image_read(tifFile)
          pngFile <- image_convert(tifImage, "png")
          pngName <- tools::file_path_sans_ext(f)
          fname <- file.path(pathToPngImages, paste0(pngName, ".png"))
          image_write(pngFile, path = fname, format = "png")
        } else {
          cat("Error in convertTifToPngSave: The file", tifFile, "does not exist.\n")
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


shinyApp(ui, server)