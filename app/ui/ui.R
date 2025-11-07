library(shiny)
library(shinydashboard)
library(shinyjs)
if(!require(leaflet)){
  install.packages("leaflet",dependencies = T)
  library(leaflet)
}

#workingDir <- "D:/distribution_digitizer"
#setwd(workingDir)

source("ui/helpers_ui.R")

# Reading configuration files
config_list<- read.csv2(paste0(workingDir,'/config/config.csv'), header = FALSE, sep = ';',stringsAsFactors = FALSE)
colnames(config_list) <- c("key", "value")
# Als Liste umwandeln
config<- as.list(setNames(config_list$value, config_list$key))

# Reading info files
info_list<- read.csv2(paste0(workingDir,'/config/info.csv'), header = FALSE, sep = ';',stringsAsFactors = FALSE)
colnames(info_list) <- c("key", "value")
# Als Liste umwandeln
info<- as.list(setNames(info_list$value, info_list$key))



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

# Füge JavaScript-Datei in den Kopfbereich der Seite ein

# In deinem ui.R, am Ende von tags$head:
head_content <- tags$head(
  tags$script(src = "custom.js"),
  tags$link(rel = "stylesheet", type = "text/css", href = "dd_style.css"),
  tags$script("shinyjs.options({debug: false});")
)

body <- dashboardBody(
  useShinyjs(),   # 🔹 <- WICHTIG: shinyjs aktivieren
  head_content, 
  # Top Information
  # Working directory
  
  # Add a title panel for the app and a link to the README.pdf file.  
  # The PDF contains program documentation and instructions.  
  # Users can click on the link (📘 Open README.pdf) to read more details 
  # about how the "Distribution Digitizer" works.  
  # The label/tooltip informs the user about the purpose of the link.
  titlePanel("Distribution Digitizer"),
  conditionalPanel(
    condition = "input.someCondition == true", 
    tags$script(src = "custom.js")
  ),
  # Second title panel for the README link
  tags$h4(
    tags$a(
      href = "README.pdf",
      target = "_blank",
      "📘 Read the program description and usage instructions - README.pdf",
      title = "Read the program description and usage instructions"
    )
  ),

  h3(paste0(info$workingDir_info, " ", workingDir), style = "color:black"),


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
                   column(10, 
                          # Wrapper um das textInput, damit wir das Style anwenden können
                          tags$div(style = "position:relative;",
                                   textInput("title", "Book Title", config$title)
                          ),
                          # zusätzliche Info-Box für "title", die erscheint, wenn man über das Eingabefeld fährt
                          div(id = "title_infoBox", class="infobox_tab_0" ,
                              info$title_infoBox), # Optionaler Button, öffnet den Pfad im Explorer

                   )
                 ),


                 fluidRow(
                   column(10, 
                          # Wrapper um das textInput, damit wir das Style anwenden können
                          tags$div(style = "position:relative;",
                                   textInput("author", "Author", config$author)
                          ),
                          # zusätzliche Info-Box für "author", die erscheint, wenn man über das Eingabefeld fährt
                          div(id = "author_infoBox",  class="infobox_tab_0",
                              info$author_infoBox)
                   )
                 ),
                
                 fluidRow(
                   column(10, 
                          # Wrapper um das textInput, damit wir das Style anwenden können
                          tags$div(style = "position:relative;",
                                   textInput("pYear", "Publication Year", config$pYear)
                          ),
                          # zusätzliche Info-Box für "pYear", die erscheint, wenn man über das Eingabefeld fährt
                          div(id = "pYear_infoBox", class="infobox_tab_0",
                              info$pYear_infoBox)
                   )
                 ),
                 fluidRow(
                   column(10, 
                          # Wrapper um das textInput, damit wir das Style anwenden können
                          tags$div(style = "position:relative;",
                                   textInput("tesserAct", "Tesseract Path", config$tesserAct)
                          ),
                          # zusätzliche Info-Box für "tesserAct", die erscheint, wenn man über das Eingabefeld fährt
                          div(id = "tesserAct_infoBox", class="infobox_tab_0",
                              info$tesserAct_infoBox)
                   )
                 ),
                 fluidRow(
                   column(10,
                          tags$div(style = "position:relative;",
                                   numericInput(
                                     inputId = "nMapTypes",
                                     label = "Number of map types",
                                     value = as.integer(config$nMapTypes),   # 👈 Wert aus der Config
                                     min = 1,
                                     max = 3,
                                     step = 1
                                   )
                          ),
                          div(id = "nMapTypes_infoBox", class = "infobox_tab_0",
                              "Specify how many different map types your book contains (e.g. 1 = all maps look similar, 3 = three distinct layouts).")
                   )
                 ),
                 
          ),
          
          # Right column
          column(6,
                 
                 configFolderInput(
                   id = "dataInputDir",
                   label = "Input Directory",
                   value = config$dataInputDir,
                   infoText = info$dataInputDir_infoBox
                 ),
                 
                 configFolderInput(
                   id = "dataOutputDir",
                   label = "Output Directory",
                   value = config$dataOutputDir,
                   infoText = info$dataOutputDir_infoBox,
                   color = "#007bff"
                 ),
                 
                 
                 
                 fluidRow(
                   column(10, tags$div(id = "d_pFormat", style = "position:relative;",
                                       selectInput("pFormat", "Image Format", 
                                                   choices = c("tif" = 1, "png" = 2, "jpg" = 3),
                                                   selected = config$pFormat)
                                       ),
                         # zusätzliche Info-Box für "pColor", die erscheint, wenn man über das Eingabefeld fährt
                         div(id = "pFormat_infoBox", class="infobox_tab_0",
                             info$pFormat_infoBox)
                   )
                 ),
                 
                 
                 
                 fluidRow(
                   column(10, tags$div(id = "d_pColor", style = "position:relative;",
                                       selectInput("pColor", "Page Color", 
                                                   choices = c("black white" = 1, "color" = 2),selected = config$pColor)
                                  ),
                          # zusätzliche Info-Box für "pColor", die erscheint, wenn man über das Eingabefeld fährt
                          div(id = "pColor_infoBox", class="infobox_tab_0", 
                              info$pColor_infoBox)
                          
                    )
                   ),
                   
                
          )
        ),actionButton("saveConfig", "Save Sonfiguration", style = "with:100pc;color:#FFFFFF;background:#007bff;position: absolute;
  left: 43%;"),
     
        #actionButton("open_output", "Open Output Folder in Explorer", style = "color:#FFFFFF;background:#28a745"),
        shinyjs::hidden(
          h3("Inspect Result Folder"),
          actionButton("open_output", "Open Output Directory in Explorer",
                       style = "color:#FFFFFF;background:#28a745;position: absolute;
  left: 43%;")
        )
      ), includeHTML(file.path("..", "www", "start_instructions.html"))

    ),
    
    # Tab 1 Create Templates #---------------------------------------------------------------------
    tabItem(
      tabName = "tab1",
      fluidRow(
        column(11, 
               wellPanel(
                 h3(strong(shinyfields1$head, style = "color:black")),
                 p(shinyfields1$inf4, style = "color:black"),
                 # Choose the file 
                 fileInput("image",  label = h5(shinyfields1$lab1), buttonLabel = "Browse...",
                           placeholder = "No file selected"),
                 #shinyFilesButton("pick_file", "Datei wählen", "Bitte Datei auswählen", multiple = TRUE),
                 verbatimTextOutput("file_out")
               ),
               
               wellPanel(
                 h4(strong(shinyfields1$save_symbol, style = "color:black")),
                 # Add number to the file name of the created template file
                 fluidRow(column(8, numericInput("imgIndexTemplate", label = h5(shinyfields1$lab2),value = 1),
                                 
                                 p(strong(paste0(shinyfields1$inf2, workingDir, "/data/templates/symbols"), style = "color:black")),
                                 p(shinyfields1$inf3, style = "color:black"),                
                                 # Save the template map image with the given index
                                 downloadButton('saveSymbol', 'Save map symbol/Legende', style="color:#FFFFFF;background:#999999")))
               )
        ), # col 4
        column(
          width = 8,
          div(
            class = "plot-flex-row",  # Flexbox-Container
            div(
              id = "leftPlotPanel",
              plotOutput(
                "plot",
                click = "plot_click",
                hover = hoverOpts(id = "plot_hover", delayType = "throttle"),
                brush = brushOpts(id = "plot_brush")
              )
            ),
            div(
              id = "rightPlotPanel",
              plotOutput("plot1"),
              conditionalPanel(
                condition = "output.showCropHint",
                # --- Neuer Hinweis zur Anzahl der Templates ---
                tags$p(
                  "⚠️ Important:",tags$br(),
                  "Please select only map pages that are already well-scanned and correctly aligned — this will significantly improve the accuracy of the template matching process!",
                  tags$br(),
                ),
                tags$p(
                  style = "color:#333; font-weight:bold; margin-top:10px;",
                  "👉 When cropping the map area, make sure to select the region carefully so that the entire map border is included —",
                  "but extend the selection only a few pixels beyond the frame.",
                  "No page text or captions should appear inside the cropped template image."
                ),
                tags$p(
                  style = "color:#333; font-weight:bold; margin-top:10px;",
                  "👉 For best results, create at least two template maps.",
                ),
                
                # --- Bildanzeige ---
                tags$div(
                  style = "text-align:center; margin:10px 0;",
                  tags$img(
                    src = "assets/templates_struct_1.JPG",   # <- Pfad relativ zu www/
                    alt = "Template folder structure example",
                    style = "max-width:100%; border:1px solid #ccc; border-radius:8px;"
                )),
                tags$p(
                  "👉 If your book contains different types or layouts of maps, you should create separate template groups under the templates directory.",
                  tags$br(), 
                  "Each group (e.g. t_1, t_2, t_3) should have the same internal structure as a single-type template set."
                ),
                # --- Bildanzeige ---
                tags$div(
                  style = "text-align:center; margin:10px 0;",
                  tags$img(
                    src = "assets/templates_struct_2.JPG",   # <- Pfad relativ zu www/
                    alt = "Template folder structure example",
                    style = "max-width:100%; border:1px solid #ccc; border-radius:8px;"
                )),

                wellPanel(
                  h4(strong(shinyfields1$save_template, style = "color:black")),
                  # Add number to the file name of the created template file
                  fluidRow(column(8, #numericInput("imgIndexTemplate", label = h5(shinyfields1$lab2),value = 1),
                                  # Save the template map image with the given index
                                  downloadButton('saveTemplate', 'Save map template', style="color:#FFFFFF;background:#999999"))),
                )
              )
            )
          ),
          
        )
        
        
        
        
      ) # END fluid Row
    ),  # END tabItem 1
    
    
    # =============================
    # Tab 2 Maps Matching
    # =============================
    tabItem(
      fluidRow(column(8,wellPanel(
        textInput("range_matching", label=HTML(shinyfields2$inf6), value = '1-1'),
        textOutput("range_warning"),
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
        column(4,  
               wellPanel(
                 # Eine Zeile mit den Buttons
                 tags$div(
                   style = "display:flex; gap:15px; align-items:center; margin-bottom:10px;",
                   
                   actionButton("showRecords", "Show records"),
                   
                   tags$a(
                     href   = "records.csv",
                     target = "_blank",
                     class  = "btn btn-warning btn-sm",
                     style  = "color:white; text-decoration:none;",
                     "Save records.csv"
                   )
                 ),
                 
                 # Tabelle darunter
                 DT::dataTableOutput("records_tbl")
               ,
                
               textInput("range_list", label=HTML(shinyfields2$inf7), value = '1-2'),
               tags$div(
                 style = "display:flex; gap:20px; align-items:flex-start; flex-wrap:wrap;",
                 
                 tags$div(
                   style="flex:1; min-width:300px;",
                   actionButton("listMatchingButton", label = "List maps"),
                   uiOutput("listMaps")
                 ),
                 
                 tags$div(
                   style="flex:1; min-width:300px;",
                   actionButton("listAlignButton", label = "List aligned maps"),
                   uiOutput("listAlign")
                 )
               ),
               
               #uiOutput('listCropped', style="width:30%;float:left")
                h3("Inspect Result Folder"),
              actionButton("open_output_map", "Open Map Output Folder in Explorer")),
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
    
    # Tab 4 Masking #----------------------------------------------------------------------
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
    
    
    # Tab 5 Read Spezies #----------------------------------------------------------------------
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
        ), # col 4
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
    
    # Tab 7 Polygonize  FILE=shinyfields_polygonize #----------------------------------------------------------------------
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
