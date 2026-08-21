library(shiny)
library(shinydashboard)
library(shinyjs)
if(!require(leaflet)){
  install.packages("leaflet",dependencies = T)
  library(leaflet)
}


source("ui/helpers_ui.R")
source("ui/species_distribution_ui.R", local = TRUE)
source("ui/species_reading_ui.R", local = TRUE)

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
image1 = (paste0(workingDir,'/app/www/images/species_points_example.tif'))
image2 = (paste0(workingDir,'/app/www/images/species_contours_example.tif'))



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
    # =============================
    # Tab 0 General Configuration
    # =============================
    
    tabItem(
      tabName = "tab0",
      
      wellPanel(
        
        includeHTML(
          file.path("www", "start_instructions.html")
        ),
        
        fluidRow(
          
          # ==========================================================
          # HEADER
          # ==========================================================
          
          column(
            12,
            
            h4("✅ General Configuration Settings"),
            
            p(
              "Define the book, input data and settings used for processing.",
              style = "color:#555;"
            ),
            
            tags$hr()
          ),
          
          
          # ==========================================================
          # LEFT COLUMN
          # Book and processing settings
          # ==========================================================
          
          column(
            6,
            
            h4(
              strong("Book & Processing"),
              style = "color:black;"
            ),
            
            
            # --------------------------------------------------------
            # Book title
            # --------------------------------------------------------
            
            fluidRow(
              column(
                10,
                
                tags$div(
                  style = "position:relative;",
                  
                  textInput(
                    "title",
                    "Book Title",
                    config$title
                  )
                ),
                
                div(
                  id = "title_infoBox",
                  class = "infobox_tab_0",
                  info$title_infoBox
                )
              )
            ),
            
            
            # --------------------------------------------------------
            # Author
            # --------------------------------------------------------
            
            fluidRow(
              column(
                10,
                
                tags$div(
                  style = "position:relative;",
                  
                  textInput(
                    "author",
                    "Author",
                    config$author
                  )
                ),
                
                div(
                  id = "author_infoBox",
                  class = "infobox_tab_0",
                  info$author_infoBox
                )
              )
            ),
            
            
            # --------------------------------------------------------
            # Publication year
            # --------------------------------------------------------
            
            fluidRow(
              column(
                10,
                
                tags$div(
                  style = "position:relative;",
                  
                  textInput(
                    "pYear",
                    "Publication Year",
                    config$pYear
                  )
                ),
                
                div(
                  id = "pYear_infoBox",
                  class = "infobox_tab_0",
                  info$pYear_infoBox
                )
              )
            ),
            
            
            # --------------------------------------------------------
            # Tesseract
            # --------------------------------------------------------
            
            fluidRow(
              column(
                10,
                
                tags$div(
                  style = "position:relative;",
                  
                  textInput(
                    "tesserAct",
                    "Tesseract Path",
                    config$tesserAct
                  )
                ),
                
                div(
                  id = "tesserAct_infoBox",
                  class = "infobox_tab_0",
                  info$tesserAct_infoBox
                )
              )
            ),
            
            
            # --------------------------------------------------------
            # Number of map types
            # --------------------------------------------------------
            
            fluidRow(
              column(
                10,
                
                tags$div(
                  style = "position:relative;",
                  
                  numericInput(
                    inputId = "nMapTypes",
                    label = "Number of map types",
                    value = as.integer(config$nMapTypes),
                    min = 1,
                    max = 3,
                    step = 1
                  )
                ),
                
                div(
                  id = "nMapTypes_infoBox",
                  class = "infobox_tab_0",
                  info$nMapTypes_infoBox
                )
              )
            ),
            
            
            # --------------------------------------------------------
            # Species distribution representation
            # --------------------------------------------------------
            
            # --------------------------------------------------------
            # Species distribution representation
            # --------------------------------------------------------
            
            fluidRow(
              column(
                10,
                
                tags$div(
                  style = "position:relative;",
                  
                  tags$label(
                    "How is the species distribution represented on the maps?"
                  ),
                  

                  # Example images
                  fluidRow(
                    radioButtons(
                      inputId = "speciesRepresentation",
                      label = NULL,
                      choices = c(
                        "Points / symbols" = "point",
                        "Contours / areas" = "contour"
                      ),
                      selected = if (!is.null(config$speciesRepresentation)) {
                        config$speciesRepresentation
                      } else {
                        "point"
                      },
                      inline = TRUE
                    ),
                    
                    column(
                      6,
                      tags$div(
                        style = "text-align:center;",
                        
                        tags$img(
                          src = "images/species_points_example.png",
                          style = "
                width:150px;
                max-height:110px;
                object-fit:contain;
                border:1px solid #ddd;
                border-radius:4px;
                padding:3px;
              "
                        ),
                        
                        tags$div(
                          "Example: Points / symbols",
                          style = "font-size:12px; color:#666; margin-top:4px;"
                        )
                      )
                    ),
                    
                    column(
                      6,
                      tags$div(
                        style = "text-align:center;",
                        
                        tags$img(
                          src = "images/species_contours_example.png",
                          style = "
                width:150px;
                max-height:110px;
                object-fit:contain;
                border:1px solid #ddd;
                border-radius:4px;
                padding:3px;
              "
                        ),
                        
                        tags$div(
                          "Example: Contours / areas",
                          style = "font-size:12px; color:#666; margin-top:4px;"
                        )
                      )
                    )
                  )
                ),
                
                div(
                  id = "speciesRepresentation_infoBox",
                  class = "infobox_tab_0",
                  info$speciesRepresentation_infoBox
                )
              )
            )
          ),
          
          
          # ==========================================================
          # RIGHT COLUMN
          # Input/output and image settings
          # ==========================================================
          
          column(
            6,
            
            h4(
              strong("Input & Image Settings"),
              style = "color:black;"
            ),
            
            
            # --------------------------------------------------------
            # Input directory
            # --------------------------------------------------------
            
            configFolderInput(
              id = "dataInputDir",
              label = "Input Directory",
              value = config$dataInputDir,
              infoText = info$dataInputDir_infoBox
            ),
            
            
            # --------------------------------------------------------
            # Output directory
            # --------------------------------------------------------
            
            configFolderInput(
              id = "dataOutputDir",
              label = "Output Directory",
              value = config$dataOutputDir,
              infoText = info$dataOutputDir_infoBox,
              color = "#007bff"
            ),
            
            
            # --------------------------------------------------------
            # Image format
            # --------------------------------------------------------
            
            fluidRow(
              column(
                10,
                
                tags$div(
                  id = "d_pFormat",
                  style = "position:relative;",
                  
                  selectInput(
                    "pFormat",
                    "Image Format",
                    choices = c(
                      "tif" = 1,
                      "png" = 2,
                      "jpg" = 3
                    ),
                    selected = config$pFormat
                  )
                ),
                
                div(
                  id = "pFormat_infoBox",
                  class = "infobox_tab_0",
                  info$pFormat_infoBox
                )
              )
            ),
            
            
            # --------------------------------------------------------
            # Page color
            # --------------------------------------------------------
            
            fluidRow(
              column(
                10,
                
                tags$div(
                  id = "d_pColor",
                  style = "position:relative;",
                  
                  selectInput(
                    "pColor",
                    "Page Color",
                    choices = c(
                      "black white" = 1,
                      "color" = 2
                    ),
                    selected = config$pColor
                  )
                ),
                
                div(
                  id = "pColor_infoBox",
                  class = "infobox_tab_0",
                  info$pColor_infoBox
                )
              )
            ),
            
            
            # ========================================================
            # SPECIES IDENTIFICATION SETTINGS
            # ========================================================
            
            tags$hr(),
            
            h4(
              strong("Species Identification Settings"),
              style = "color:black;"
            ),
            
            p(
              paste(
                "These settings describe how species titles",
                "and species information are organized in this book."
              ),
              style = "color:#555; margin-bottom:15px;"
            ),
            
            
            # --------------------------------------------------------
            # Species title keyword
            # --------------------------------------------------------
            
            fluidRow(
              column(
                10,
                
                tags$div(
                  style = "position:relative;",
                  
                  textInput(
                    "specieTitleKeyword",
                    "Keyword used near species titles",
                    value = config$speciesTitleKeywords
                  )
                ),
                
                div(
                  id = "specieTitleKeyword_infoBox",
                  class = "infobox_tab_0",
                  info$specieTitleKeyword_infoBox
                )
              )
            ),
            
            
            # --------------------------------------------------------
            # Number of lines before keyword
            # --------------------------------------------------------
            
            fluidRow(
              column(
                10,
                
                tags$div(
                  style = "position:relative;",
                  
                  textInput(
                    "specieTitleKeywordBefore",
                    "Number of lines before the keyword",
                    value = config$keywordBefore
                  )
                ),
                
                div(
                  id = "keywordBefore_infoBox",
                  class = "infobox_tab_0",
                  info$keywordBefore_infoBox
                )
              )
            ),
            
            
            # --------------------------------------------------------
            # Number of lines after keyword
            # --------------------------------------------------------
            
            fluidRow(
              column(
                10,
                
                tags$div(
                  style = "position:relative;",
                  
                  textInput(
                    "specieTitleKeywordThen",
                    "Number of lines after the keyword",
                    value = config$keywordThen
                  )
                ),
                
                div(
                  id = "keywordThen_infoBox",
                  class = "infobox_tab_0",
                  info$keywordThen_infoBox
                )
              )
            ),
            
            
            # --------------------------------------------------------
            # Species title position
            # --------------------------------------------------------
            
            fluidRow(
              column(
                10,
                
                tags$div(
                  style = "position:relative;",
                  
                  checkboxInput(
                    "middle",
                    "Species titles are usually centered on the page",
                    value = isTRUE(
                      as.logical(config$middle)
                    )
                  )
                ),
                
                div(
                  id = "middle_infoBox",
                  class = "infobox_tab_0",
                  info$middle_infoBox
                )
              )
            ),
            
            
            # ========================================================
            # MAP LEGEND IDENTIFICATION
            # ========================================================
            
            tags$hr(),
            
            h5(
              strong("Map Legend Identification"),
              style = "color:black;"
            ),
            
            p(
              paste(
                "Use characteristic words or phrases from the",
                "map legends to help identify species information."
              ),
              style = "color:#555; margin-bottom:10px;"
            ),
            
            
            # --------------------------------------------------------
            # Legend keywords
            # --------------------------------------------------------
            
            fluidRow(
              column(
                10,
                
                tags$div(
                  style = "position:relative;",
                  
                  textInput(
                    "legendKeywords",
                    "Keywords used in map legends",
                    value = config$legendKeywords,
                    placeholder = "e.g. distribution of, type locality of"
                  )
                ),
                
                div(
                  id = "legendKeywords_infoBox",
                  class = "infobox_tab_0",
                  info$legendKeywords_infoBox
                )
              )
            )
          )
        ),
        
        
        # ==========================================================
        # SAVE CONFIGURATION
        # ==========================================================
        
        tags$hr(),
        
        tags$div(
          style = "text-align:center;",
          
          actionButton(
            "saveConfig",
            "Save Configuration",
            style = paste(
              "color:#FFFFFF;",
              "background:#007bff;"
            )
          )
        ),
        
        
        # ==========================================================
        # OUTPUT FOLDER
        # ==========================================================
        
        shinyjs::hidden(
          tags$div(
            style = "text-align:center; margin-top:20px;",
            
            h3("Inspect Result Folder"),
            
            actionButton(
              "open_output",
              "Open Output Directory in Explorer",
              style = "color:#FFFFFF;background:#28a745;"
            )
          )
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
    # Tab 3 – Species Distribution
    # ----------------------------------------------------------------------
    species_distribution_ui(
      shinyfields2 = shinyfields2,
      shinyfields3 = shinyfields3,
      shinyfields4 = shinyfields4,
      mapTypes = mapTypes
    ),
    
    
    

    # ----------------------------------------------------------------------
    # Tab 4 – Masking
    # ----------------------------------------------------------------------
    tabItem(
      tabName = "tab4",
      
      fluidRow(
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
    
    
    # ----------------------------------------------------------------------
    # Tab 5 – Species Reading 
    # ----------------------------------------------------------------------
    species_reading_ui(
      shinyfields2 = shinyfields2,
      shinyfields6 = shinyfields6
    ),
    
    


    # ----------------------------------------------------------------------
    # Tab 6 – Georeferencing
    # ----------------------------------------------------------------------
    tabItem(
      tabName = "tab6",
      
      fluidRow(
        column(
          6,
          
          wellPanel(
            
            # ---------------- HEADER ----------------
            h3(strong(shinyfields6$head, style = "color:black")),
            p(shinyfields6$inf1, style = "color:black"),
            p(shinyfields6$inf2, style = "color:black"),
            
            # HIER EINFÜGEN
            radioButtons(
              "georef_mask_type",
              label = "Species distribution representation:",
              choices = c(
                "Points / symbols" = "point",
                "Contours / areas" = "contour"
              ),
              selected = "point",
              inline = TRUE
            ),
            
            actionButton(
              "georeferencing",
              label = shinyfields6$lab1,
              style="color:#FFFFFF;background:#999999"
            ),
            
            tags$hr(),
            
            # ---------------- LIST ELEMENTS ----------------
            conditionalPanel(
              condition = "input.georeferencing > 0",
              
              fluidRow(
                column(
                  4,
                  textInput(
                    "range_list_Georeferencing",
                    label = HTML(shinyfields2$inf7),
                    value = "1-2"
                  )
                ),
                column(
                  4,
                  selectInput(
                    "map_type_Georeferencing",
                    label = "Select map type:",
                    choices = mapTypes,
                    selected = mapTypes[1]
                  )
                ),
                column(
                  4,
                  actionButton(
                    "listGeoreferencing",
                    "List georeferenced files"
                  )
                )
              )
            )
          ),
          
          # ---------------- LEAFLET OUTPUT ----------------
          uiOutput("leaflet_outputs_GEO")
        )
      ),
      
      # ---------------- CSV GEOREF ----------------
      wellPanel(
        h4(shinyfields8$head_sub, style = "color:red"),
        p(shinyfields8$info1, style = "color:black"),
        p(shinyfields8$info2, style = "color:black"),
        
        actionButton(
          "georef_coords_from_csv",
          label = shinyfields8$lab1,
          style="color:#FFFFFF;background:#999999"
        )
      )
    ), # END tabItem
    

    # -------------------------------------------------
    # Tab 7 – Polygonize
    # -------------------------------------------------
    
    tabItem(
      tabName = "tab7",
      
      fluidRow(
        column(
          6,
          
          wellPanel(
            
            # ---------------- HEADER ----------------
            h3(strong(shinyfields7$head, style = "color:black")),
            p(shinyfields7$inf1, style = "color:black"),
            p(shinyfields7$inf2, style = "color:black"),
            
            radioButtons(
              "polygonize_mask_type",
              label = "Species distribution representation:",
              choices = c(
                "Points / symbols" = "point",
                "Contours / areas" = "contour"
              ),
              selected = "point",
              inline = TRUE
            ),
            
            actionButton(
              "polygonize",
              label = shinyfields7$lab1,
              style = "color:#FFFFFF;background:#999999"
            ),
            
            tags$hr(),
            
            # ---------------- LIST ELEMENTS ----------------
            fluidRow(
              column(
                4,
                textInput(
                  "range_list_Polygonize",
                  label = HTML(shinyfields2$inf7),
                  value = "1-2"
                )
              ),
              
              column(
                4,
                selectInput(
                  "map_type_Polygonize",
                  label = "Select map type:",
                  choices = mapTypes,
                  selected = mapTypes[1]
                )
              ),
              
              column(
                4,
                actionButton(
                  "listPolygonize",
                  "List polygonized files"
                )
              )
            )
          ),
          
          # ---------------- LEAFLET OUTPUT ----------------
          uiOutput("leaflet_outputs_PL")
          
        )
      )
    ), # END tabItem 7
    
    
    

    # ----------------------------------------------------------------------
    # Tab 8 – Spatial Data View 
    # ----------------------------------------------------------------------
    
    tabItem(
      tabName = "tab8",
      
      fluidRow(
        column(
          6,
          
          wellPanel(
            
            # ---------------- HEADER ----------------
            h3(strong("Spatial Data View", style = "color:black")),
            p("Compute and explore the final species distribution data.",
              style = "color:black"),
            # ---------------- REPRESENTATION TYPE ----------------
            radioButtons(
              "spatial_representation",
              label = "Species distribution representation:",
              choices = c(
                "Points / symbols" = "point",
                "Contours / areas" = "contour"
              ),
              selected = "point",
              inline = TRUE
            ),
            
            actionButton(
              "startSpatialDataComputing",
              label = "Spatial Data Computing",
              style = "color:#FFFFFF;background:#999999"
            ),
            
            tags$hr(),
            
           
            # ---------------- POINT VIEW CONTROLS ----------------
            conditionalPanel(
              condition = "input.spatial_representation == 'point'",
              
              fluidRow(
                column(
                  4,
                  textInput(
                    "range_list_Spatial",
                    label = HTML(shinyfields2$inf7),
                    value = "1-2"
                  )
                ),
                
                column(
                  4,
                  selectInput(
                    "map_type_Spatial",
                    label = "Select map type:",
                    choices = mapTypes,
                    selected = mapTypes[1]
                  )
                ),
                
                column(
                  4,
                  actionButton(
                    "spatialViewPF",
                    "Start View point detection"
                  )
                )
              )
            )
          ),
          
          # ---------------- POINT LEAFLET OUTPUT ----------------
          conditionalPanel(
            condition = "input.spatial_representation == 'point'",
            
            wellPanel(
              leafletOutput("mapSpatialViewPF", height = 600),
              verbatimTextOutput("hoverInfo3")
            )
          ),
          # ---------------- FINAL SPECIES DATA ----------------

          wellPanel(
            
            h4(
              "Final Species Distribution Data",
              style = "color:black"
            ),
            
            p(
              "Load and display the final species distribution data.",
              style = "color:black"
            ),
            
            actionButton(
              "showFinalSpeciesData",
              "Show final data",
              style = "
                color:#FFFFFF;
                background:#337ab7;
                border-color:#2e6da4;
              "
            ),
            
            br(),
            br(),
            
            DT::DTOutput("finalSpeciesTable"),
            

            tags$hr(),
            
            textInput(
              "speciesSpatialSearch",
              label = "Search species:",
              placeholder = "e.g. Watsonalla binaria"
            ),
            
            actionButton(
              "showSpeciesDistribution",
              "Show species distribution"
            ),
                    
            downloadButton(
            "downloadFinalSpeciesCSV",
            "Download CSV"
            )
          
          ),
          # ---------------- SPECIES MAP ----------------
          wellPanel(
            
            uiOutput("selectedSpeciesTitle"),
            
            leafletOutput(
              "speciesDistributionMap",
              height = 600
            )
          )
          
        )
      )
    ) # END tabItems
  )
) # END BODY


sidebar <-
  ui <- dashboardPage(
    header = header,
    sidebar = dashboardSidebar(disable = TRUE, width = 0),
    body = body,
    title = NULL,
    skin = "black"
  )
