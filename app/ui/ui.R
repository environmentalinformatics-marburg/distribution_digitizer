library(shiny)
library(shinydashboard)
library(shinyjs)
if(!require(leaflet)){
  install.packages("leaflet",dependencies = T)
  library(leaflet)
}


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
 # shinyfields2 <- read.csv(fileFullPath,header = TRUE, sep = ';')
  shinyfields2 <- read.csv2(
    fileFullPath,
    header = TRUE,
    stringsAsFactors = FALSE,
    fileEncoding = "UTF-8"
  )
  names(shinyfields2)
  shinyfields2$inf7
  str(shinyfields2)
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
 # tags$h4(
 #   tags$a(
  #    href = "README.pdf",
 #     target = "_blank",
  #    "📘 Read the program description and usage instructions - README.pdf",
  #    title = "Read the program description and usage instructions"
  #  )
  #),

  h3(paste0(info$workingDir_info, " ", workingDir), style = "color:black"),


  tabItems(
    # =============================
    # Tab 0 General Configuration
    # =============================
    tabItem(
      tabName = "tab0",
      wellPanel(
        
        includeHTML(file.path("www", "start_instructions.html")),
        
        fluidRow(
          h4("✅ General Configuration Settings"),
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
                              info$nMapTypes_infoBox)
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
      )

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
        fluidRow(
          
          # ================= LEFT: MATCHING =================
          column(
            6,
            
            wellPanel(
              h3(strong(shinyfields2$head, style = "color:black")),
              p(shinyfields2$inf1, style = "color:black"),
              
              numericInput(
                "threshold_for_TM",
                label = shinyfields2$threshold,
                value = 0.18, min = 0, max = 1, step = 0.05
              ),
              
              actionButton(
                "templateMatching",
                label = shinyfields2$start1,
                style = "color:#FFFFFF;background:#28a745"
              ),
              
              p(shinyfields2$inf2, style = "color:black")
            ),
            
            shinyjs::hidden(
              div(
                id = "matching_results_block",
                
                wellPanel(
                  h4("Matching results"),
                  
                  selectInput(
                    "map_type_matching",
                    label = "Select map type:",
                    choices = mapTypes,
                    selected = mapTypes[1]
                  ),
                  textInput(
                    "range_list_matching",
                    label = HTML(shinyfields2$inf7),
                    value = "1-2"
                  ),
                  actionButton("listMatchingButton", "List maps"),
                  uiOutput("listMaps")
                )
              )
            )
          ),
          
          # ================= RIGHT: ALIGN =================
          column(
            6,
            
            wellPanel(
              h3(strong(shinyfields2$head_sub, style = "color:black")),
              p(shinyfields2$inf3, style = "color:black"),
              
              actionButton(
                "alignMaps",
                label = shinyfields2$start2,
                style = "color:#FFFFFF;background:#007bff"
              )
            ),
            
            shinyjs::hidden(
              div(
                id = "align_results_block",
                
                wellPanel(
                  h4("Aligned results"),
                  
                  selectInput(
                    "map_type_align",
                    label = "Select map type:",
                    choices = mapTypes,
                    selected = mapTypes[1]
                  ),
                  textInput(
                    "range_list_align",
                    label = HTML(shinyfields2$inf7),
                    value = "1-2"
                  ),
                  actionButton("listAlignButton", "List aligned maps"),
                  uiOutput("listAlign")
                )
              )
            )
            
          )
        )
        
      ) # END fluid Row
    ),  # END tabItem 2
    
    
    
    # ----------------------------------------------------------------------
    # Tab 3 – Points Matching
    # ----------------------------------------------------------------------
    tabItem(
      tabName = "tab3",
      
      # ============================================================
      # TOP: Info
      # ============================================================

      
      # ============================================================
      # TOP: Range + Map type
      # ============================================================
      fluidRow(
        fluidRow(
          column(
            12,
            wellPanel(
              h3(strong(shinyfields3$head, style = "color:black")),
              p(shinyfields3$inf1, style = "color:black"),
              p(shinyfields3$inf2, style = "color:black")
            )
          )
        )
      ),
      
      br(),
      
      # ============================================================
      # MAIN: Left / Right
      # ============================================================
      fluidRow(
        
        # ---------------- LEFT ----------------
        column(
          6,

          wellPanel(
            
            # ---------------- HEADER ----------------
            h4(shinyfields3$head_sub, style = "color:black"),
            p(shinyfields3$inf3, style = "color:black"),
            
            numericInput(
              "threshold_for_PM",
              label = shinyfields3$threshold,
              value = 0.75,
              min = 0,
              max = 1,
              step = 0.05
            ),
            
            p(shinyfields3$inf4, style = "color:black"),
            
            actionButton(
              "pointMatching",
              label = shinyfields3$lab,
              style = "color:#FFFFFF;background:#999999"
            ),
            
            tags$hr(),
            
            # ---------------- LIST ELEMENTS (HIDDEN INITIALLY) ----------------
            conditionalPanel(
              condition = "input.pointMatching > 0",
              
              fluidRow(
                column(
                  4,
                  textInput(
                    "range_list_PointsMatching",
                    label = HTML(shinyfields2$inf7),
                    value = "1-2"
                  )
                ),
                column(
                  4,
                  selectInput(
                    "map_type_PointsMatching",
                    label = "Select map type:",
                    choices = mapTypes,
                    selected = mapTypes[1]
                  )
                ),
                column(
                  4,
                  actionButton("listPointsM", "List points matching")
                )
              )
            )
          ),
          
          # Ergebnis Point Matching
          uiOutput("listPM")
        ),
        
        # ---------------- RIGHT ----------------
        column(
          6,
          
          wellPanel(
            
            h4(shinyfields4$head, style = "color:black"),
            
            numericInput("filterK", shinyfields4$lab1, value = 5),
            p(shinyfields4$inf1),
            
            numericInput("filterG", shinyfields4$lab2, value = 9),
            p(shinyfields4$inf2),
            
            actionButton(
              "pointFiltering",
              label = shinyfields4$lab3,
              style = "color:#FFFFFF;background:#999999"
            ),
            
            tags$hr(),
            
            conditionalPanel(
              condition = "input.pointFiltering > 0",
              
              fluidRow(
                column(
                  4,
                  textInput(
                    "range_list_PointsFiltering",
                    label = HTML(shinyfields2$inf7),
                    value = "1-2"
                  )
                ),
                column(
                  4,
                  selectInput(
                    "map_type_PointsFiltering",
                    label = "Select map type:",
                    choices = mapTypes,
                    selected = mapTypes[1]
                  )
                ),
                column(
                  4,
                  actionButton("listPointsF", "List points filtering")
                )
              )
              
            )
          ),
          
          # Ergebnis Point Filtering
          uiOutput("listPF")
        )
      )# END fluid Row
    ),  # END tabItem 3
    
    
    # ----------------------------------------------------------------------
    # Tab 4 – Masking
    # ----------------------------------------------------------------------
    tabItem(
      tabName = "tab4",
      
      fluidRow(
        
        # ================= LEFT: Masking =================
        column(
          6,
          
          wellPanel(
            h3(shinyfields5$head_sub, style = "color:black"),
            h4("You can extract masks with white background", style = "color:black"),
            p(shinyfields5$inf1, style = "color:black"),
            
            numericInput(
              "morph_ellipse",
              label = shinyfields5$lab1,
              value = 5
            ),
            
            actionButton(
              "masking",
              label = shinyfields5$lab2,
              style = "color:#FFFFFF;background:#999999"
            ),
            
            conditionalPanel(
              condition = "input.masking > 0",
              
              fluidRow(
                column(
                  6,
                  h4("White masks"),
                  textInput(
                    "range_list_Masks",
                    HTML(shinyfields2$inf7),
                    "1-2"
                  ),
                  selectInput(
                    "map_type_Masks",
                    "Select map type:",
                    mapTypes
                  ),
                  actionButton("listMasks", "List masks")
                )
              ),
              
              tags$hr(),
              uiOutput("listMS")
            )
          )
        ),
        
        # ================= RIGHT: Masking Centroids =================
        column(
          6,
          
          wellPanel(
            h3(shinyfields5.1$head_sub, style = "color:black"),
            h4(
              "You can mask the centroids of the points detected by Point Filtering and Circle Detection.",
              style = "color:black"
            ),
            p(shinyfields5.1$inf1, style = "color:black"),
            
            actionButton(
              "maskingCentroids",
              label = shinyfields5.1$lab1,
              style = "color:#FFFFFF;background:#999999"
            ),
            
            conditionalPanel(
              condition = "input.maskingCentroids > 0",
              
              fluidRow(
                column(
                  6,
                  h4("Centroid masks"),
                  textInput(
                    "range_list_MasksCentroids",
                    HTML(shinyfields2$inf7),
                    "1-2"
                  ),
                  selectInput(
                    "map_type_MasksCentroids",
                    "Select map type:",
                    mapTypes
                  ),
                  actionButton("listMasksCD", "List masks")
                )
              ),
              
              tags$hr(),
              uiOutput("listMCD")
            )
          )
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
    sidebar = dashboardSidebar(disable = TRUE, width = 0),
    body = body,
    title = NULL,
    skin = "black"
  )
