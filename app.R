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
library(reticulate)
library(tesseract)

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
tempImage="temp.png"
scale =20
rescale= (100/scale)

workingDir <- getwd()
print("Working directory 1:")
print(workingDir)



#read config fields from config.csv in .../distribution_digitizer/config directory
fileFullPath = (paste0(workingDir,'/config/config.csv'))
if (file.exists(fileFullPath)){
  config <- read.csv(fileFullPath,header = TRUE, sep = ';')
} else{
  stop(paste0("file:", fileFullPath, "not found, please create them and start the app"))
}


# read the config file

fileFullPath = (paste0(workingDir,'/config/configStartDialog.csv'))
if (file.exists(fileFullPath)){
  configStartDialog <- read.csv(fileFullPath, header = TRUE, sep = ';')
} else{
  stop("The file configStartDialog.csv was not found, please create them and start the app")
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
          "))
  ),
  
  tags$li(
    class = "dropdown",
    sidebarMenu(
      id = "tablist",
      menuItem("Environment DD", tabName = "tab0"),
      menuItem("Create Templates", tabName = "tab1"),
      menuItem("Maps Matching", tabName = "tab2"),
      menuItem("Points Matching", tabName = "tab3"),
      menuItem("Masking", tabName = "tab4" ),
      menuItem("Georeferencing", tabName = "tab5" ),
      menuItem("Polygonize", tabName = "tab6" ),
      menuItem("Spatial View", tabName = "tab7" ),
      menuItem("Download", tabName = "tab8" )
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
      fluidRow(
        
        wellPanel(
          h3(configStartDialog$head, style = "color:black"),
          #Project directory
          p(paste0("Working directory - ",workingDir), style = "color:black"),
          
          # Title: Provide the name of the book's author.
          fluidRow(column(3,textInput("title", label="Title", value = "Title"))),
          
          # Author: Provide the name of the book's author.
          fluidRow(column(3,textInput("author", label="Author", value = "Autorname"))),
          
          # Publication Year: Specify the year the book was published.
          fluidRow(column(3,textInput("pYear", label="Publication Year", value = "2023"))),
          
          # Data input directory
          fluidRow(column(3,textInput("dataInputDir", label="Data input directory", value = paste0(workingDir,"/data/input")))),
          
          # Data output directory
          fluidRow(column(3,textInput("dataOutputDir", label="Data output directory", value =paste0(workingDir,"/data/output")))),
          
          # numberSitesPrint
          fluidRow(column(3,selectInput("numberSitesPrint", label="Number of Book Sites per One Print",  c("One site per scan" = 1 ,"Two sites per scan"= 2)))),
          
          # allprintedPages
          fluidRow(column(3,textInput("allPrintedPages", label="All Printed Pages", value = 100 ))),
          
          # site number position
          fluidRow(column(3,selectInput("sNumberPosition", label="Site Number Position", c("top"=1 , "botom"=2), selected=1 ))),
          
          # format;
          fluidRow(column(3,selectInput("pFormat", label="Image Format of the Scanned Sites", c("tif"=1 , "png"=2, "jpg"=3), selected=1 ))),
          
          # Page color;
          fluidRow(column(3,selectInput("pColor", label="Page Color", c("black white"=1 , "color"=2), selected=1 ))),
          # width;
          #fluidRow(column(3,textInput("allprintedPages", label=configStartDialog$i4, value = config$allprintedPages ))),
          fluidRow(column(4, actionButton("saveConfig",  label = "Save", style="color:#FFFFFF;background:#999999"))),
          #useShinyjs(),
          #extendShinyjs(text = jscode, functions = c("closeWindow")),
         # actionButton("close", "Close window")
          )
        )
    ),
  
  
  # Tab 1 Create Templates #---------------------------------------------------------------------
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
            h4(strong(shinyfields1$save_template, style = "color:black")),
            # Add number to the file name of the created template file
            fluidRow(column(8, numericInput("imgIndexTemplate", label = h5(shinyfields1$lab2),value = 1),
            p(strong(paste0(shinyfields1$inf, workingDir, "/data/templates/maps/"), style = "color:black")),
            p(shinyfields1$inf1, style = "color:black"),                
            # Save the cropped template map image with the given index
            downloadButton('saveTemplate', 'Save map template', style="color:#FFFFFF;background:#999999"))),
           ),
          wellPanel(
            h4(strong(shinyfields1$save_symbol, style = "color:black")),
            # Add number to the file name of the created template file
            fluidRow(column(8, numericInput("imgIndexTemplate", label = h5(shinyfields1$lab2),value = 1),
            
            p(strong(paste0(shinyfields1$inf2, workingDir, "/data/templates/symbols"), style = "color:black")),
            p(shinyfields1$inf3, style = "color:black"),                
            # Save the cropped template map image with the given index
            downloadButton('saveSymbol', 'Save map symbol/Legende', style="color:#FFFFFF;background:#999999")))
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
    
  
  # Tab 2 Maps Matching #----------------------------------------------------------------------
    tabItem(
      tabName = "tab2",
      # which site become overview
      fluidRow(column(3,textInput("siteNumberMapsMatching", label=shinyfields6$input, value = ''))),
      actionButton("listMapsMatching",  label = "List maps"),
      actionButton("listAlign",  label = "List aligned maps"),
      actionButton("listCropped",  label = "List cropped maps"),
      fluidRow(
        column(4,
          wellPanel(
            # submit action button
            h3(strong(shinyfields2$head, style = "color:black")),
            p(shinyfields2$inf1, style = "color:black"),
            fluidRow(column(8, numericInput("threshold_for_TM", label = shinyfields2$threshold, value = 0.2, min = 0, max = 1, step = 0.05))),
            p(shinyfields2$inf2, style = "color:black"), 
            # Start map matching
            fluidRow(column(3,actionButton("templateMatching",  label = shinyfields2$start1, style="color:#FFFFFF;background:#999999"))),
          ),
          wellPanel(
            # maps align 
            h3(shinyfields2$head_sub, style = "color:black"),
            p(shinyfields2$inf3, style = "color:black"),
            fluidRow(column(3, actionButton("alignMaps",  label = shinyfields2$start2, style="color:#FFFFFF;background:#999999"))),
          ),
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
        ), # col 4
        column(8,
               uiOutput('listMaps', style="width:30%;float:left"),
               uiOutput('listAlign', style="width:30%;float:left"),
               uiOutput('listCropped', style="width:30%;float:left")
        )
      ) # END fluid Row
    ),  # END tabItem 2
  
  
  # Tab 3 Points Matching  #----------------------------------------------------------------------
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
                 fluidRow(column(8,numericInput("threshold_for_PM", label = shinyfields3$threshold, value = 0.87, min = 0, max = 1, step = 0.05))),
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
   
  # Tab 4 Masking #----------------------------------------------------------------------
  tabItem(
      tabName = "tab4",  
      fluidRow(column(3,textInput("siteNumberMasks", label=shinyfields6$input, value = ''))),
      actionButton("listMasks",  label = "List masks"),
      actionButton("listMasksB",  label = "List black masks"),
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
                wellPanel(
                 # ----------------------------------------# Masking (black)#----------------------------------------------------------------------
                 h4("Or you can extract masks with black background", style = "color:black"),
                 p(shinyfields5$inf2, style = "color:black"),
                 fluidRow(column(8,numericInput("morph_ellipse", label = shinyfields5$lab1, value = 5))),#, width = NULL, placeholder = NULL)
                 fluidRow(column(3, actionButton("maskingBlack",  label = shinyfields5$lab2, style="color:#FFFFFF;background:#999999"))),
               ),
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
               uiOutput('listMPF', style="float:left")
        )
      ) # END fluid Row
    ),  # END tabItem 4
  
  # Tab 5 Georeferencing  FILES=shinyfields_georeferensing & shinyfields_georef_coords_from_csv_file.csv #-------------------------------------------------
    tabItem(
      tabName = "tab5",  
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
        h4(shinyfields8$head_sub, style = "color:black"),
        p(shinyfields8$info1, style = "color:black"),
        p(shinyfields8$info2, style = "color:black"),
        actionButton("georef_coords_from_csv", label = shinyfields8$lab1, style="color:#FFFFFF;background:#999999")
      )
      # END fluid Row
    ),# END tabItem 5
   
  # Tab 6 Polygonize  FILE=shinyfields_polygonize #----------------------------------------------------------------------
  tabItem(
      tabName = "tab6", 
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
    ),  # END tabItem 6
  
  # 7. Spatial data view #----------------------------------------------------------------------
  tabItem(
    tabName = "tab7", 
   # wellPanel(
    #  h3(strong("Save the outputs in csv file", style = "color:black")),
    #  p("hier kommt noch mehr Text", style = "color:black"),
    #  p("hier kommt noch mehr Text", style = "color:black"),
    actionButton("startSpatialDataComputing",  label ="Spatial Data Computing", style="color:#FFFFFF;background:#999999"),
    #),
    wellPanel(
      # which site become overview
      #fluidRow(column(3,textInput("siteNumberSave", label="Test", value = ''))),
      
      actionButton("spatialViewCD",  label = "Start View circle detection",),
      leafletOutput("mapSpatialViewCD"),
      verbatimTextOutput("hoverInfo")
    ),
   wellPanel(
     # which site become overview
     #fluidRow(column(3,textInput("siteNumberSave", label="Test", value = ''))),
     
     actionButton("spatialViewPF",  label = "Start View point detection",),
     leafletOutput("mapSpatialViewPF"),
     verbatimTextOutput("hoverInfo3")
   )
  ),  # END tabItem 6
  
  tabItem(
    tabName = "tab8",
    actionButton("viewCSV",  label ="Overview spatial final data", style="color:#FFFFFF;background:#999999"),
    downloadButton("downloadCSV", "CSV download"),
    wellPanel( 
      dataTableOutput("myTable")
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
# Shiny SERVER CODE
################################################################################
################################################################################

server <- shinyServer(function(input, output, session) {
  
  # Update the clock every second using a reactiveTimer
  current_time <- reactiveTimer(1000)
  
# SAVE the last working directory
  observeEvent(input$saveConfig, {
    
    # text<-paste0(input$workingDir,";", input$dataInputDir)
    #, input$dataOutputDir, input$numberSitesPrint, input$allprintedPages,
    #           input$pFormat, input$pColor )
    
    x <- data.frame(workingDir= workingDir, 
                    workingDirInformation = "Your working directory is the local digitizer repository!",
                    title = input$title,
                    autor = input$author,
                    pYear = input$pYear,
                    dataInputDir = input$dataInputDir,
                    dataOutputDir = input$dataOutputDir,
                    numberSitesPrint = input$numberSitesPrint,
                    allPrintedPages = input$allPrintedPages,
                    sNumberPosition = input$sNumberPosition,
                    pFormat = input$pFormat,
                    pColor = input$pColor)
    tf <- tempfile(fileext = ".csv")
    
    ## To write a CSV file for input to Excel one might use
    write.table(x, file = paste0(workingDir,"/config/config.csv"), sep = ";", row.names = FALSE,
                quote=FALSE)
    
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
    #output$plot <- renderImage({
    ##    NULL
      
    #})
    output$listMapTemplates = renderUI({
      # Define the directory path
      new_directory <- paste0(workingDir, "/www/map_templates_png/")
      print(new_directory)
      # Check if the directory already exists
      if (!dir.exists(new_directory)) {
        # Create the directory if it doesn't exist
        dir.create(new_directory)
        
        findTemplateResult = paste0(workingDir, "/data/input/templates/maps/")
        converTifToPngSave(findTemplateResult, paste0(workingDir, "/www/map_templates_png/"))
        #cat("New directory created:", new_directory, "\n")
      } else {
        cat("Directory already exists:", new_directory, "\n")
        findTemplateResult = paste0(workingDir, "/data/input/templates/maps/")
        converTifToPngSave(findTemplateResult, paste0(workingDir, "/www/map_templates_png/"))
      }
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
      
      # Define the directory path
      new_directory <- paste0(workingDir, "/www/symbol_templates_png/")
      
      # Check if the directory already exists
      if (!dir.exists(new_directory)) {
        # Create the directory if it doesn't exist
        dir.create(new_directory)
        cat("New directory created:", new_directory, "\n")
      } else {
        cat("Directory already exists:", new_directory, "\n")
      }
      
      findTemplateResult = paste0(workingDir, "/data/input/templates/symbols/")
      converTifToPngSave(findTemplateResult, paste0(workingDir, "/www/symbol_templates_png/"))
      
      prepareImageView("/symbol_templates_png/", '.png')
    })
  })
  
  # ----------------------------------------# 2. Maps matching #----------------------------------------------------------------------
  # Template matching start
  observeEvent(input$templateMatching, {
    
    # Define the directory path
    new_directory <- paste0(workingDir, "/www/matching_png/")
    
    # Check if the directory already exists
    if (!dir.exists(new_directory)) {
      # Create the directory if it doesn't exist
      dir.create(new_directory)
      cat("New directory created:", new_directory, "\n")
    } else {
      cat("Directory already exists:", new_directory, "\n")
    }
    
    # call the function for map matching 
    manageProcessFlow("mapMatching", "map matching", "matching")

    # convert the tif images to png and show this on the plot
    findTemplateResult = paste0(workingDir, "/data/output/maps/matching/")
    converTifToPngSave(findTemplateResult, paste0(workingDir, "/www/matching_png/"))

  })
  
  observeEvent(input$listMapsMatching, {
    if(input$siteNumberMapsMatching != ''){
      print(input$siteNumberMapsMatching)
      output$listMaps = renderUI({
        prepareImageView("/matching_png/", input$siteNumberMapsMatching)
      })
    }
    else{
      output$listMaps = renderUI({
        prepareImageView("/matching_png/", '.png')
      })
    }
  })

  # ----------------------------------------# 2.1 Maps align #----------------------------------------------------------------------
  # Align maps start
  observeEvent(input$alignMaps, {
    
    # call the function for align maps 
    manageProcessFlow("alignMaps", "align maps", "allign")
    
    # convert the tif images to png and show this on the plot
    findTemplateResult = paste0(workingDir, "/data/output/maps/align/")
    converTifToPngSave(findTemplateResult, paste0(workingDir, "/www/align_png/"))

  })

  observeEvent(input$listAlign, {
    if(input$siteNumberMapsMatching != ''){
      print(input$siteNumberMapsMatching)
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
  
  # ----------------------------------------# 2.2 Crop map species #---------------------------------------------------------------------- #
  # Crop map species
  observeEvent(input$mapReadRpecies, {
    
    # call the function for cropping
    manageProcessFlow("mapReadRpecies", "cropping map species", "align")
    
    # convert the tif images to png and show this on the plot
    findTemplateResult = paste0(workingDir, "/data/output/maps/align/")
    converTifToPngSave(findTemplateResult, paste0(workingDir, "/www/cropped_png/"))

  })

  observeEvent(input$listCropped, {
    if(input$siteNumberMapsMatching != ''){
      print(input$siteNumberMapsMatching)
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
  
  
  # Crop page species
  observeEvent(input$pageReadRpecies, {
    
    # call the function for cropping
    manageProcessFlow("pageReadRpecies", "read page species", "output")
    
  })
  
  # ----------------------------------------# 3. Points Matching #----------------------------------------------------------------------
  # points detection with matching 
  observeEvent(input$pointMatching, {
    # call the function for cropping
    manageProcessFlow("pointMatching", "points matching", "pointMatching")
    # convert the tif images to png and show this on the plot
    findTemplateResult = paste0(workingDir, "/data/output/maps/align/")
    converTifToPngSave(findTemplateResult, paste0(workingDir, "/www/pointMatching_png/"))
  })
  
  observeEvent(input$listPointsM, {
    if(input$siteNumberPointsMatching != ''){
      print(input$siteNumberPointsMatching)
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
  
  # Process point filtering 
  observeEvent(input$pointFiltering, {
    # call the function for filtering
    manageProcessFlow("pointFiltering", "points filtering", "pointFiltering")
    
    # convert the tif images to png and show this on the plot
    findTemplateResult = paste0(workingDir, "/data/output/maps/pointFiltering/")
    converTifToPngSave(findTemplateResult, paste0(workingDir, "/www/pointFiltering_png/"))
  })
  
  observeEvent(input$listPointsF, {
    if(input$siteNumberPointsMatching != ''){
      print(input$siteNumberPointsMatching)
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
        prepareImageView("/matching_png/", input$siteNumberPointsMatching)
      })
    }
    else{
      output$listMapsMatching2 = renderUI({
        prepareImageView("/matching_png/", '.png')
      })
    }
  })
  
  # Process circle detection
  observeEvent(input$pointCircleDetection, {
    # call the function for circle detection
    manageProcessFlow("pointCircleDetection", "points circle detection", "pointCircleDetection")
    
    # convert the tif images to png and show this on the plot
    findTemplateResult = paste0(workingDir, "/data/output/maps/circleDetection/")
    converTifToPngSave(findTemplateResult, paste0(workingDir, "/www/CircleDetection_png/"))
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
  
  # ----------------------------------------# Masking #----------------------------------------------------------------------
  observeEvent(input$masking, {
    # call the function for filtering
    manageProcessFlow("masking", "masking white background", "masking")
    
    findTemplateResult = paste0(workingDir, "/data/output/masking/")
    converTifToPngSave(findTemplateResult, paste0(workingDir, "/www/masking_png/"))
  })
  
  observeEvent(input$maskingBlack, {
    # call the function for filtering
    manageProcessFlow("maskingB", "masking black background", "masking")
    
    findTemplateResult = paste0(workingDir, "/data/output/masking_black/")
    converTifToPngSave(findTemplateResult, paste0(workingDir, "/www/masking_black_png/"))
  })
  # ---- # Masking centroids --------
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

  
  # ----------------------------------------# Georeferencing #----------------------------------------------------------------------
  # Georeferencing start
  # GCP points extraction
  observeEvent(input$pointextract, {
    #Processing georeferencing
    library(reticulate)
    fname=paste0(workingDir, "/", "src/georeferencing/geo_points_extraction.py")
    source_python(fname)
    maingeopointextract(workingDir,input$filterm)
    cat("\nSuccessfully executed")
  })
  
  observeEvent(input$georeferencing, {
    # call the function for filtering
    manageProcessFlow("georeferencing", "georeferencing", "georeferencing")
    
    # Verzeichnis erstellen
    new_directory <- paste0(workingDir, "/www/georeferencing_png/")
    dir.create(new_directory)
    
    # convert the tif images to png and save this in /www directory
    findTemplateResult = paste0(workingDir, "/data/output/georeferencing/masks/")
    converTifToPngSave(findTemplateResult, paste0(workingDir, "/www/georeferencing_png/"))
    
  })
  
  
  # Georeferencing list maps
  observeEvent(input$listGeoreferencing, {
    # Anzahl der Leaflet-Elemente, die Sie hinzufügen möchten
    # show start action message
    message=paste0("Process ", "Georeferencing", " is started on: ")
    shinyalert(text = paste(message, format(current_time(), "%H:%M:%S")), type = "info", showConfirmButton = FALSE, closeOnEsc = TRUE,
               closeOnClickOutside = FALSE, animation = TRUE)
    
    listgeoTiffiles = list.files(paste0(workingDir, "/data/output/rectifying/"), full.names = T, pattern = paste0('georeferenced',input$siteNumberGeoreferencing))
    if( length(listgeoTiffiles) == 0) {
        listgeoTiffiles = list.files(paste0(workingDir, "/data/output/rectifying/"), full.names = T, pattern = '.tif')
    }
    num_leaflet_outputs_GEO <- length(listgeoTiffiles)
    
    # Liste der ursprunlichen map Files zum Vergleich mit den polygonizierten Maps
    listPng = list.files(paste0(workingDir, "/www/georeferencing_png/"), full.names = F, pattern = paste0('georeferenced', input$siteNumberGeoreferencing))  #print(listPng)
    
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
      print(listgeoTiffiles[i])
      leaflet() %>%
        addTiles("Test") %>%
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
            img(src = paste0("/georeferencing_png/",listPng[i]), width = 200, height = 200),
            tags$a(href = paste0("/georeferencing_png/",listPng[i]), listPng[i], target="_blank"),
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
  
 
  
  # ----------------------------------------# Polygonize #----------------------------------------------------------------------
  # Polygonize start
  observeEvent(input$polygonize, {
    # call the function for filtering
    manageProcessFlow("polygonize", "polygonize", "polygonize")
    
    # Write new directory
    new_directory <- paste0(workingDir, "/www/polygonize/")
    dir.create(new_directory)
    
    findTemplateResult = paste0(workingDir, "/data/output/polygonize/")
    shFiles <- list.files(findTemplateResult, pattern = ".sh", recursive = TRUE, full.names = TRUE)
    
    # copy the shape files into www directory
    for (f in shFiles) {
      # Source and destination file paths
      baseName = basename(f)
      destination_file <- paste0(workingDir, "/www/polygonize/", baseName)
      print(destination_file)
      # Copy the file
      file.copy(from = f, to = destination_file, overwrite = TRUE)
      
      # Check if the copy was successful
      if (file.exists(destination_file)) {
        cat("File copied successfully to:", destination_file)
      } else {
        cat("File copy failed.")
      }
    }
  }) 
  
  # Polygonize list maps  
  observeEvent(input$listPolygonize, {
    # Load the shapefile data
    listShapefiles = list.files(paste0(workingDir, "/www/polygonize/"), full.names = T, pattern = '.shp')
    #input$siteNumberPolygonize='69'
    listShapefiles = grep(input$siteNumberPolygonize, listShapefiles, value= TRUE)
    
    # diese shape files sind erstmal von keine Bedeutung
    muster <- "filtered"
    
    # Index der Dateien finden, die das Muster nicht enthalten
    listShapefiles <- grep(paste0("^((?!(", muster, ")).)*$"), listShapefiles, value = TRUE, perl = TRUE)
    num_leaflet_outputs <- length(listShapefiles)
    print(listShapefiles)
    
    # Liste der ursprunlichen map Files zum Vergleich mit den polygonizierten Maps
    listPng = list.files(paste0(workingDir, "/www/cropped_png/"), full.names = F, pattern = input$siteNumberPolygonize)
    print(listPng)
    
    output$leaflet_outputs_PL <- renderUI({
      # Liste von Leaflet-Elementen
      leaflet_outputs_list <- lapply(1:num_leaflet_outputs, function(i) {
        leafletOutput(outputId = paste0("listPL", i))
      })
      
      # Liste der Leaflet-Elemente in UI auszugeben
      do.call(tagList, leaflet_outputs_list)
    })
    
  
    
    # Liste von Leaflet-Objektenlapply(seq_along(my_list), function(i) {
    leaflet_list_PL <- lapply(seq_along(listShapefiles), function(i) {
      print(listShapefiles[i])
      leaflet() %>%
        addTiles("Test") %>%
        addProviderTiles("OpenStreetMap.Mapnik") %>%
        addPolygons(data = st_read(listShapefiles[i]),
                    fillColor = "blue",
                    fillOpacity = 0.6,
                    color = "white",
                    stroke = TRUE,
                    weight = 6) %>%
        addControl(
          htmltools::div(
            p(listShapefiles[i]),
          ),
        position = "bottomright"
        ) %>%
        addControl(
        htmltools::div(
          img(src = paste0("/cropped_png/",listPng[i]), width = 200, height = 200),
          #p(listPng[i])
          tags$a(href = paste0("/cropped_png/",listPng[i]), listPng[i], target="_blank"),
        ),
        
        position = "bottomleft"
      )
    })
    
    # Ergebnisse in den Output-Variablen speichern
    
    leaflet_lists <- lapply(1:length(leaflet_list_PL), function(i) {
      output[[paste0('listPL', i)]] <- renderLeaflet({ leaflet_list_PL[[i]] })
    })
    # Render the HTML shape name 1
   # output$shape_name1 <- renderUI({
    #  HTML(paste("<p><strong>Shape Name:</strong> ", basename(listShapefile[1]), "</p>"))
   # })
    # Render the HTML align map1
   # output$align_map1 <- renderUI({
   #   HTML(paste("<img src=", workingDir, "/www/align_png/",basename(listShapefile[1]), ">"))
   # })
  })
  
  # Render the HTML align map3
  # output$align_map3 <- renderUI({
  #    HTML(paste("<img src=", workingDir, "/www/align_png/",basename(listShapefile[3]), ">"))
  #  })
  
 

  # ----------------------------------------# Save the outputs #----------------------------------------------------------------------
  observeEvent(input$saveOutputs, {
    # Datei erstellen, z.B. mit write.csv()
    
    data <- data.frame(Name = c("Alice", "Bob", "Charlie"),
                       Alter = c(25, 30, 22))
    write.csv(data, "beispiel.csv", row.names = FALSE)
  })
  
  
  observeEvent(input$startSpatialDataComputing, {
    
    # show start action message
    message=paste0("Process ", "Spatial data computing", " is started on: ")
    shinyalert(text = paste(message, format(current_time(), "%H:%M:%S")), type = "info", showConfirmButton = FALSE, closeOnEsc = TRUE,
               closeOnClickOutside = FALSE, animation = TRUE)
    messageOnClose = ""
    tryCatch(
      # Processing spatial data computing
      expr = {
        fname=paste0(workingDir, "/", "src/extract_coordinates/poly_to_point.py")
        source_python(fname)
        main_circle_detection(workingDir)
        main_point_filtering(workingDir)
    
        fname=paste0(workingDir, "/", "src/extract_coordinates/extract_coords.py")
        source_python(fname)
        main_circle_detection(workingDir)
        main_point_filtering(workingDir)
        
        # prepare pages as png for the spatia view
        converTifToPngSave(paste0(workingDir, "/data/input/pages/"),paste0(workingDir, "/www/pages/"))
        source(paste0(workingDir, "/src/spatial_view/merge_spatial_final_data.R"))
        mergeFinalData(workingDir)
      },
      error = function(e) {
        messageOnClose = e$message
        # Hier steht der Code, der ausgeführt wird, wenn ein Fehler auftritt
        showModal(
          modalDialog(
            title = "Fehler",
            paste("Ein Fehler ist aufgetreten:", e$message),
            easyClose = TRUE,
            footer = NULL
          )
        )
      },
      finally = {
        cat("\nSuccessfully executed")
        # show end action message if no errors
        closeAlert(num = 0, id = NULL)
        if(messageOnClose == "") {messageOnClose = "Spatial final data computing" }
        shinyalert(text = paste(message, format(current_time(), "%H:%M:%S"), 
                    "The Spatial final data is saved in spatial_final_data.csv in directory /data/output/" ),
                   type = "info", showConfirmButton = TRUE, closeOnEsc = TRUE,
                   closeOnClickOutside = TRUE, animation = TRUE)
      }
    )
  })
  
  observeEvent(input$spatialViewPF, {
    
    customMouseover <- JS(
      "function(event) {
    var layer = event.target;
    layer.bindPopup('Dies ist ein benutzerdefinierter Mouseover-Text').openPopup();
  }"
    )
    
    marker_data <- read.csv(paste0(workingDir, "/data/output/spatial_final_data.csv"))
    filtered_data <- marker_data[marker_data$Detection.method == "point_filtering", ]
    name = paste0(filtered_data$File,".png")
    page = basename(filtered_data$file_name)
    page <- sub("\\.tif$", "", basename(filtered_data$file_name))
    page = paste0(page, ".png")
    # OpenStreetMap show "File","Detection.method","X","Y","georef","X_WGS84","Y_WGS84","species","file_name"
    
    # OpenStreetMap show
    output$mapSpatialViewPF <- renderLeaflet({
      leaflet() %>%
        addTiles() %>%
        addMarkers(
          data = filtered_data,
          lat = ~Y_WGS84,
          lng = ~X_WGS84,
          label = name,
          labelOptions = labelOptions(
            direction = "auto",
            noHide = TRUE,
            onEachFeature = customMouseover  # Hier fügen Sie die benutzerdefinierte Mouseover-Funktion hinzu
          ),
          #popup = ~paste0("<a href='/matching_png/", Link, "' target='_blank'>", marker_data$Name, "</a>")
          popup = ~paste0("<b>", filtered_data$species, "</b><a href='/matching_png/", name, "' target='_blank'>",
                          "<img src='/matching_png/", name, "' width='100' height='100'></a>",
                          "<a href='/pages/", page, "' target='_blank'>",
                          "<img src='/pages/", page, "' width='100' height='100'></a>")
        )
    })
    
   
    cat("\nSuccessfully executed")
    
  })
  
  observeEvent(input$spatialViewCD, {
   
    customMouseover <- JS(
      "function(event) {
    var layer = event.target;
    layer.bindPopup('Dies ist ein benutzerdefinierter Mouseover-Text').openPopup();
  }"
    )
    marker_data <- read.csv(paste0(workingDir, "/data/output/spatial_final_data.csv"))
    filtered_data <- marker_data[marker_data$Detection.method == "circle_detection", ]
    name = paste0(filtered_data$File,".png")
    page = basename(filtered_data$file_name)
    page <- sub("\\.tif$", "", basename(filtered_data$file_name))
    page = paste0(page, ".png")
    # OpenStreetMap show "File","Detection.method","X","Y","georef","X_WGS84","Y_WGS84","species","file_name"
    
 
    output$mapSpatialViewCD <- renderLeaflet({
      
      leaflet() %>%
        addTiles() %>%
        addMarkers(
          data = filtered_data,
          lat = ~Y_WGS84,
          lng = ~X_WGS84,
          label = name,
          labelOptions = labelOptions(
            direction = "auto",
            noHide = TRUE,
            onEachFeature = customMouseover  # Hier fügen Sie die benutzerdefinierte Mouseover-Funktion hinzu
          ),
          #popup = ~paste0("<a href='/matching_png/", Link, "' target='_blank'>", marker_data$Name, "</a>")
          popup = ~paste0("<b>", filtered_data$species, "</b><a href='/matching_png/", name, "' target='_blank'>",
                          "<img src='/matching_png/", name, "' width='100' height='100'></a>",
                          "<a href='/pages/", page, "' target='_blank'>",
                          "<img src='/pages/", page, "' width='100' height='100'></a>")
        )
    })
    
   
    cat("\nSuccessfully executed")
 
  })
    # Daten aus der hochgeladenen CSV-Datei lesen
    #data2 <- reactive({
      #req(input$file)
    #  df <- read.csv(input$file$datapath)
    #  df
   # })
    
    # OpenStreetMap show
   # output$mapShowCsv <- renderLeaflet({
     # leaflet(data = data2()) %>%
      #  addTiles() %>%
      #  addMarkers(lng = ~Longitude, lat = ~Latitude,
     #   label = ~Name,
     #   labelOptions = labelOptions(
     #   direction = "auto",
      #  noHide = TRUE
     #   ),
     #   popup = ~paste0("<a href='/matching_png/", Name, "' target='_blank'>", ~Link, "</a>")
      #  )
    #})
    
  output$downloadCSV <- downloadHandler(
    # Hier können Sie den Pfad zu Ihrer CSV-Datei angeben
    
    filename = function() {
      csv_path <- paste0(workingDir, "/data/output/spatial_final_data.csv")
      # Hier können Sie den Dateinamen für die heruntergeladene Datei festlegen
      # In diesem Beispiel verwenden wir den ursprünglichen Dateinamen
      basename(csv_path)
    },
    content = function(file) {
      csv_path <- paste0(workingDir, "/data/output/spatial_final_data.csv")
      # Hier wird die gesamte CSV-Datei in die herunterzuladende Datei kopiert
      file.copy(csv_path, file)
    }
  )
  
  observeEvent(input$viewCSV, {
    
    # Hier können Sie den Pfad zu Ihrer CSV-Datei angeben
    csv_path <- paste0(workingDir, "/data/output/spatial_final_data.csv")
    
    # Hier können Sie Daten für Ihre Tabelle oder Visualisierung laden
    # In diesem Beispiel lesen wir die CSV-Datei
    data <- reactive({
      read.csv(csv_path)
    })
    
    output$myTable <- renderDataTable({
      data()
    })
   
  })
  
  manageProcessFlow <- function(processing, allertText1, allertText2){
   
      # show start action message
      message=paste0("Process ", allertText1, " is started on: ")
      shinyalert(text = paste(message, format(current_time(), "%H:%M:%S")), type = "info", showConfirmButton = FALSE, closeOnEsc = TRUE,
                 closeOnClickOutside = FALSE, animation = TRUE)
      if(processing == "mapMatching"){
        
        # processing template matching
        fname=paste0(workingDir, "/", "src/matching/map_matching.py")
        print("Processing template matching python script:")
        print(fname)
        source_python(fname)
        print("Threshold:")
        print(input$threshold_for_TM)
        main_template_matching(workingDir, input$threshold_for_TM, config$sNumberPosition)
        findTemplateResult = paste0(workingDir, "/data/output/maps/matching/")
        files<- list.files(findTemplateResult, full.names = TRUE, recursive = FALSE)
        countFiles = paste0(length(files),"")
        message=paste0("Process align maps is ended on: ", format(current_time(), "%H:%M:%S \n ."), " The number extracted outputs with threshold=",input$threshold_for_TM , " are ", countFiles ,"! \n High threshold values lead to few matchings, low values to many matchings.")

      }
     
      if(processing == "alignMaps" ){
        # align
        fname=paste0(workingDir, "/", "src/matching/map_align.py")
        print("Processing align python script:")
        print(fname)
        source_python(fname)
        align_images_directory(workingDir)
        print(fname)
        cat("\nSuccessfully executed")
        findTemplateResult = paste0(workingDir, "/data/output/maps/align/")
        files<- list.files(findTemplateResult, full.names = TRUE, recursive = FALSE)
        countFiles = paste0(length(files),"")
        print(countFiles)
      }
      
      if(processing == "mapReadRpecies" ){
        # Croping
        fname=paste0(workingDir, "/", "src/read_species/map_read_species.R")
        print("Croping the species names from the map botton R script:")
        print(fname)
        source(fname)
        species = read_species2(workingDir)
      }
      
      if(processing == "pageReadRpecies" ){
        # read page species
        fname=paste0(workingDir, "/", "src/read_species/page_read_species.R")
        print("Reading page species data and saving the results to a pageSpeciesData CSV file in D:/distribution_digitizer/data/output.")
        print(fname)
        source(fname)
        species = readPageSpecies(workingDir)
      }
      
      
      if(processing == "pointMatching") {
        # Processing points matching
        fname=paste0(workingDir, "/", "src/matching/point_matching.py")
        print(" Processing point python script:")
        print(fname)
        source_python(fname)
        mainPointMatching(workingDir, input$threshold_for_PM)
      }
      
      if(processing == "pointFiltering") {
        fname=paste0(workingDir, "/", "src/matching/point_filtering.py")
        fname2 = paste0(workingDir, "/", "src/matching/coords_to_csv.py")
        print(" Process pixel filtering  python script:")
        print(fname)
        source_python(fname)
        source_python(fname2)
        mainPointFiltering(workingDir, input$filterK, input$filterG)
      }
      
      if(processing == "pointCircleDetection") {
        fname=paste0(workingDir, "/", "src/matching/circle_detection.py")
        fname2 = paste0(workingDir, "/", "src/matching/coords_to_csv.py")
        print("Processing circle detection python script:")
        print(fname)
        source_python(fname)
        source_python(fname2)
        mainCircleDetection(workingDir, input$Gaussian, input$minDist, input$thresholdEdge, input$thresholdCircles, input$minRadius, input$maxRadius)
      }
      
      if(processing == "masking"){
        fname=paste0(workingDir, "/", "src/masking/masking.py")
        print(" Process masking python script:")
        print(fname)
        source_python(fname)
        mainGeomask(workingDir, input$morph_ellipse)
        fname=paste0(workingDir, "/", "src/masking/creating_masks.py")
        source_python(fname)
        mainGeomaskB(workingDir, input$morph_ellipse)
      }
      
      if(processing == "maskingCentroids"){
        fname=paste0(workingDir, "/", "src/masking/mask_centroids.py")
        print(" Process masking python script:")
        print(fname)
        source_python(fname)
        MainMaskCentroids(workingDir)
      }
      
      if(processing == "georeferencing"){
        # processing georeferencing
        fname=paste0(workingDir, "/", "src/georeferencing/mask_georeferencing.py")
        print(" Process georeferencing python script:")
        print(fname)
        source_python(fname)
        mainmaskgeoreferencingMaps(workingDir)
        mainmaskgeoreferencingMaps_CD(workingDir)
        mainmaskgeoreferencingMasks(workingDir)
        mainmaskgeoreferencingMasks_CD(workingDir)
        mainmaskgeoreferencingMasks_PF(workingDir)
        # processing rectifying
        fname=paste0(workingDir, "/", "src/polygonize/rectifying.py")
        print(" Process rectifying python script:")
        print(fname)
        source_python(fname)
        mainRectifying(workingDir)
        mainRectifying_CD(workingDir)
        mainRectifying_PF(workingDir)
      }
      
      if(processing == "georef_coords_from_csv"){
        # processing mathematical georeferencing of extracted coordinates stored in csv file
        fname=paste0(workingDir, "/", "src/georeferencing/centroid_georeferencing.py")
        print(" Process georeferencing python script:")
        print(fname)
        source_python(fname)
        mainCentroidGeoref(workingDir)
      }
      
      if(processing=="polygonize"){
        # processing polygonize
        fname=paste0(workingDir, "/", "src/polygonize/polygonize.py")
        print(" Process polygonizing python script:")
        print(fname)
        source_python(fname)
        mainPolygonize(workingDir)
        mainPolygonize_CD(workingDir)
        mainPolygonize_PF(workingDir)
      }
      
      cat("\nSuccessfully executed")
      # show end action message
      if(processing != "mapMatching"){
        message=paste0("Process ", allertText1, " is ended on: ")
      }
      closeAlert(num = 0, id = NULL)
      shinyalert(text = paste(message, format(current_time(), "%H:%M:%S"), "!\n The ones found are appended to the file names of the corresponding file in directory /data/output/maps/" , allertText2 ), type = "info", showConfirmButton = TRUE, closeOnEsc = TRUE,
                 closeOnClickOutside = TRUE, animation = TRUE)
    
  }
  # ----------------------------------------# Function to list the result images #---------------------------------------------------------------------- #
  prepareImageView <- function(dirName, index){
    pathToMatchingImages = paste0(workingDir, "/www", dirName)
    if(index !=".png"){index <- paste0("^", index, "\\w*")}
    listPngImages = list.files(pathToMatchingImages, full.names = F, pattern = index)
    display_image = function(i) {
      HTML(paste0('<div class="shiny-map-image" > 
                  <img src = ', paste0(dirName,listPngImages[i] ), ' style="width:100%;"><a href="',paste0(dirName,listPngImages[i] ),'" style="width:27%;" target=_blank>', listPngImages[i],'</a></div>'))
    }
    lapply(1:length(listPngImages), display_image)
  }
  

  # ----------------------------------------
  # Function to list CSV files as links
  # ----------------------------------------
  prepareCSVLinks <- function(dirName, index) {
    #pathToCSVFiles = paste0(workingDir, "/www", dirName)
    listCSVFiles = list.files(paste0(workingDir, "/data/output"), full.names = FALSE, pattern = index)
    
    display_link = function(i) {
      HTML(paste0('<div class="csv-link" > 
                <a href="', paste0(dirName, listCSVFiles[i]), '" target="_blank">', listCSVFiles[i], '</a></div>'))
    }
    
    lapply(1:length(listCSVFiles), display_link)
  }
  
  # Beispielaufruf:
  dirName <- "/example_directory"
  index <- ".csv"  # Muster für die CSV-Dateien
  prepareCSVLinks(dirName, index)
  
  
  # convert tif images to png and save in /www directory
  converTifToPngSave <- function(pathToTiffImages, patjhToPngImages){
    tifFiles <- list.files(pathToTiffImages, pattern = ".tif", recursive = FALSE)
    # convert tif to png and save this into the given path
    for (f in tifFiles) {
      tifFile = paste0(pathToTiffImages, f)
      print(tifFile)
      tifImage = image_read(tifFile)
      pngFile <- image_convert(tifImage, "png")
      #temp_scale <- image_scale(pngFile, paste0(scale,"%"))
      pngName <- tools::file_path_sans_ext(f)
      fname = paste0(patjhToPngImages, pngName, ".png")
      print(fname)
      image_write(pngFile, path = fname, format = "png", )
    }
  }
  
  # save the last working directory
  onStop(function() {
    cat(workingDir)
    # fields<-c ("working_dir=")
    # text<-c(workingDir)
    # write.csv(text, file = "lastwd.csv" , col.names = F, row.names = fields, quote = F, append=T)
    # write.table(x, file = paste0(workingDir,"/lastwd.txt") ,sep = ",", col.names = NA)
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
  

 
  
})

shinyApp(ui, server)