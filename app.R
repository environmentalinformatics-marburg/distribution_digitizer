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

library(sf)
library(leaflet)

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

#5 shinyfields_masking
fileFullPath = (paste0(workingDir,'/config/shinyfields_masking.csv'))
if (file.exists(fileFullPath)){
  shinyfields5 <- read.csv(fileFullPath,header = TRUE, sep = ';')
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

#7 shinyfields_georeferensing
fileFullPath = (paste0(workingDir,'/config/shinyfields_polygonize.csv'))
if (file.exists(fileFullPath)){
  shinyfields7 <- read.csv(fileFullPath,header = TRUE, sep = ';')
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
          .shiny-map-image{margin:3px;width:30%}
          .col-sm-3 {width: auto;}"))
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
      menuItem("Polygonize", tabName = "tab6" )
    )
  )
)

body <- dashboardBody(
  # Top Information
  # Working directory
  titlePanel("Distribution Digitizer"),
  p(paste0(config$workingDirInformation,": ",workingDir) , style = "color:black"),

  tabItems(
    
    tabItem(
      tabName = "tab0",
      fluidRow(
        
        wellPanel(
          h3(configStartDialog$head, style = "color:black"),
          # Data input directory
          fluidRow(column(8,textInput("dataInputDir", label=configStartDialog$i1, value = paste0(workingDir,"/data/input")))),
          
          # Data output directory
          fluidRow(column(8,textInput("dataOutputDir", label=configStartDialog$i2, value =paste0(workingDir,"/data/output") ))),
          
          # numberSitesPrint
          fluidRow(column(4,selectInput("numberSitesPrint", label=configStartDialog$i3,  c("One site per scan" = 1 ,"Two sites per scan"= 2)))),
          
          # allprintedPages
          fluidRow(column(3,textInput("allPrintedPages", label=configStartDialog$i4, value = 100 ))),
          
          # format;
          fluidRow(column(3,selectInput("pFormat", label=configStartDialog$i5, c("tif"=1 , "png"=2, "jpg"=3), selected=1 ))),
          
          # Page color;
          fluidRow(column(4,selectInput("pColor", label=configStartDialog$i6, c("black white"=1 , "color"=2), selected=1 ))),
          
          # width;
          #fluidRow(column(3,textInput("allprintedPages", label=configStartDialog$i4, value = config$allprintedPages ))),
          fluidRow(column(4, actionButton("saveConfig",  label = "Save"))),
          #useShinyjs(),
          #extendShinyjs(text = jscode, functions = c("closeWindow")),
         # actionButton("close", "Close window")
          )
        )
    ),
    tabItem(
      tabName = "tab1",
      actionButton("listMTemplates",  label = "List saved map templates"),
      actionButton("listSTemplates",  label = "List saved symbol templates"),
      fluidRow(
        column(4,
          wellPanel(
            # -----------------------------------------# 1. Step - Create templates #---------------------------------------------------------------------
            h3(strong(shinyfields1$head, style = "color:black")),
            
            p(shinyfields1$inf4, style = "color:black"),
            # Choose the file 
            fileInput("image",  label = h5(shinyfields1$lab1), buttonLabel = "Browse...",
                      placeholder = "No file selected"),
            
            ),
          wellPanel(
            h4(strong(shinyfields1$save_template, style = "color:black")),
            # Add number to the file name of the created template file
            fluidRow(column(3, numericInput("imgIndexTemplate", label = h5(shinyfields1$lab2),value = 1),
                            
            # Save the cropped template map image with the given index
            downloadButton('saveTemplate', 'Save map template'))),
            p(strong(paste0(shinyfields1$inf, workingDir, "/data/templates/maps/"), style = "color:black")),
            p(shinyfields1$inf1, style = "color:black"),
           ),
          wellPanel(
            h4(strong(shinyfields1$save_symbol, style = "color:black")),
            # Add number to the file name of the created template file
            fluidRow(column(3, numericInput("imgIndexTemplate", label = h5(shinyfields1$lab2),value = 1),
                            
            # Save the cropped template map image with the given index
            downloadButton('saveSymbol', 'Save map symbol/Legende'))),
            p(strong(paste0(shinyfields1$inf2, workingDir, "/data/templates/symbols"), style = "color:black")),
            p(shinyfields1$inf3, style = "color:black")
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
    tabItem(
      tabName = "tab2",
      actionButton("listMaps",  label = "List maps"),
      actionButton("listAlign",  label = "List aligned maps"),
      actionButton("listCropped",  label = "List cropped maps"),
      fluidRow(
        column(4,
          wellPanel(
            # ----------------------------------------# 2. Maps matching #----------------------------------------------------------------------
            
            # submit action button
            h3(strong(shinyfields2$head, style = "color:black")),
            p(shinyfields2$inf1, style = "color:black"),
            fluidRow(column(3, numericInput("threshold_for_TM", label = shinyfields2$threshold, value = 0.2, min = 0, max = 1, step = 0.05))),
            p(shinyfields2$inf2, style = "color:black"), 
            # Start map matching
            fluidRow(column(3,actionButton("templateMatching",  label = shinyfields2$start1))),
          ),
          wellPanel(
            # maps align 
            h4(shinyfields2$head_sub, style = "color:black"),
            p(shinyfields2$inf3, style = "color:black"),
            fluidRow(column(3, actionButton("alignMaps",  label = shinyfields2$start2))),
          ),
          wellPanel(  
            # maps species 
            h4(shinyfields2$head_species, style = "color:black"),
            p(shinyfields2$inf4, style = "color:black"),
            fluidRow(column(3, actionButton("cropSpecies",  label = shinyfields2$start3))),
          )
        ), # col 4
        column(8,
               uiOutput('listMaps', style="width:35%;float:left"),
               uiOutput('listAlign', style="width:35%;float:left"),
               uiOutput('listCropped', style="width:35%;float:left")
        )
      ) # END fluid Row
    ),  # END tabItem 2
    tabItem(
      tabName = "tab3",  
      actionButton("listPointsM",  label = "List points matching"),
      actionButton("listPointsF",  label = "List points filterng"),
      fluidRow(
        column(4,
               wellPanel(
                 h3(strong(shinyfields3$head, style = "color:black")),
                 p(shinyfields3$inf1, style = "color:black"),
                 p(shinyfields3$inf2, style = "color:black"),
               ),
               wellPanel(
                 # ----------------------------------------# 3.1 Points matching  #----------------------------------------------------------------------
                 h4(shinyfields3$head_sub, style = "color:black"),
                 p(shinyfields3$inf3, style = "color:black"),
                 # Threshold for point matching
                 fluidRow(column(3,numericInput("threshold_for_PM", label = shinyfields3$threshold, value = 0.87, min = 0, max = 1, step = 0.05))),
                 fluidRow(column(3, actionButton("pointMatching",  label = shinyfields3$lab))),
                 p(shinyfields3$inf4, style = "color:black"),
               ),
               wellPanel(
                 # ----------------------------------------# 3.2 Points detection Using filtering  FILE=shinyfields_detect_points_using_filtering #----------------------------------------------------------------------
                 h4(shinyfields4$head, style = "color:black"),
                 fluidRow(column(3,numericInput("filterK", label = shinyfields4$lab1, value = 5))),#, width = NULL, placeholder = NULL)
                 p(shinyfields4$inf1, style = "color:black"),
                 fluidRow(column(3,numericInput("filterG", label = shinyfields4$lab2, value = 9))),#, width = NULL, placeholder = NULL)
                 fluidRow(column(3, actionButton("pointFiltering",  label = shinyfields4$lab3))),
                 p(shinyfields4$inf2, style = "color:black"),
                 
               )
        ), # col 4
        column(8,
               uiOutput('listPM', style="width:35%;float:left"),
               uiOutput('listPF', style="width:35%;float:left")
        )
      ) # END fluid Row
    ),  # END tabItem 3
    tabItem(
      tabName = "tab4",  
      actionButton("listMasks",  label = "List masks"),
      actionButton("listMasksB",  label = "List black masks"),
     # actionButton("listMPointsF",  label = "List points filterng"),
      fluidRow(
        column(4,
               wellPanel(
                 # ----------------------------------------# 4. 1 Masking (white)#----------------------------------------------------------------------
                 h3(strong(shinyfields5$head, style = "color:black")),
                 h4("You can extract masks with white background", style = "color:black"),
                 p(shinyfields5$inf1, style = "color:black"),
                 # p(shinyfields7$inf2, style = "color:black"),
                 fluidRow(column(3,numericInput("morph_ellipse", label = shinyfields5$lab1, value = 5))),#, width = NULL, placeholder = NULL)
                 fluidRow(column(3, actionButton("masking",  label = shinyfields5$lab2))),
               ), 
                wellPanel(
                 
                 # ----------------------------------------# 4. 2 Masking (black)#----------------------------------------------------------------------
                 h4("Or you can extract masks with black background", style = "color:black"),
                 p(shinyfields5$inf2, style = "color:black"),
                 fluidRow(column(3,numericInput("morph_ellipse", label = shinyfields5$lab1, value = 5))),#, width = NULL, placeholder = NULL)
                 fluidRow(column(3, actionButton("maskingBlack",  label = shinyfields5$lab2))),
               )
        ), # col 4
        column(8,
               uiOutput('listMS', style="float:left"),
               uiOutput('listMSB', style="float:left"),
               uiOutput('listMPF', style="float:left")
        )
      ) # END fluid Row
    ),  # END tabItem 4
    tabItem(
      tabName = "tab5",  
      actionButton("listGeoreferencing",  label = "List georeferencing files"),
      fluidRow(
        column(4,
               wellPanel(
                 
                 # ----------------------------------------# 5. Georeferencing  FILE=shinyfields_georeferensing #----------------------------------------------------------------------
                 h3(strong(shinyfields6$head, style = "color:black")),
                 p(shinyfields6$inf1, style = "color:black"),
                 p(shinyfields6$inf2, style = "color:black"),
                 fluidRow(column(3, actionButton("georeferencing",  label = shinyfields6$lab1))),
                 #h4("GCP points extraction", style = "color:black"),
                 #p(shinyfields8$inf, style = "color:black"),
                 #fluidRow(column(3, actionButton("pointextract",  label = h3("Start")))),
                 
               )
        ), # col 4
        column(8,
                uiOutput('listG', style="width:35%;float:left")
        )
      ) # END fluid Row
    ),  # END tabItem 5
    tabItem(
      tabName = "tab6",  
      actionButton("listPolygonize",  label = "List polygonized files"),
      fluidRow(
        column(4,
               wellPanel(
                 # ----------------------------------------# 5 Polygonize  FILE=shinyfields_polygonize #----------------------------------------------------------------------
                 h3(strong(shinyfields7$head, style = "color:black")),
                 p(shinyfields7$inf1, style = "color:black"),
                 p(shinyfields7$inf2, style = "color:black"),
                 fluidRow(column(3, actionButton("polygonize",  label = shinyfields7$lab1))), 
                 
               )
        ), # col 4
        column(8,
               leafletOutput("listPL1"),
               htmlOutput("shape_name1"),
               leafletOutput("listPL2"),
               htmlOutput("shape_name2"),
               leafletOutput("listPL3"),
               htmlOutput("shape_name3")
        )
      ) # END fluid Row
    )  # END tabItem 6
  ) # END tabItems
) # END body


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
                    dataInputDir = input$dataInputDir,
                    dataOutputDir = input$dataOutputDir,
                    numberSitesPrint = input$numberSitesPrint,
                    allPrintedPages = input$allPrintedPages,
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
      prepareImageView("/map_templates_png/", 4)
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
      
      prepareImageView("/symbol_templates_png/", 4)
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
  
  observeEvent(input$listMaps, {
    output$listMaps = renderUI({
      prepareImageView("/matching_png/", 4)
    })
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
    output$listAlign = renderUI({
      prepareImageView("/align_png/", 4)
    })
  })
  
  # ----------------------------------------# 2.2 Crop map species #---------------------------------------------------------------------- #
  # Crop map species
  observeEvent(input$cropSpecies, {
    
    # call the function for cropping
    manageProcessFlow("croppingMap", "cropping map species", "align")
    
    # convert the tif images to png and show this on the plot
    findTemplateResult = paste0(workingDir, "/data/output/maps/align/")
    converTifToPngSave(findTemplateResult, paste0(workingDir, "/www/cropped_png/"))

  })

  observeEvent(input$listCropped, {
    output$listCropped = renderUI({
      prepareImageView("/cropped_png/", 4)
    })
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
    output$listPM = renderUI({
      prepareImageView("/pointMatching_png/", 4)
    })
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
    output$listPF = renderUI({
      prepareImageView("/pointFiltering_png/", 4)
    })
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
  
  observeEvent(input$listMasks, {
    output$listMS = renderUI({
      prepareImageView("/masking_png/", 4)
    })
  })
  
  observeEvent(input$listMasksB, {
    output$listMSB = renderUI({
      prepareImageView("/masking_black_png/", 4)
    })
  })
  

  
  # ----------------------------------------# Georeferencing #----------------------------------------------------------------------
  # Georeferencing start
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
  
  observeEvent(input$listGeoreferencing, {
    output$listG = renderUI({
      prepareImageView("/georeferencing_png/", 4)
    })
  })
  
  # GCP points extraction
  observeEvent(input$pointextract, {
    #Processing template matching
    library(reticulate)
    fname=paste0(workingDir, "/", "src/georeferencing/geo_points_extraction.py")
    source_python(fname)
    maingeopointextract(workingDir,input$filterm)
    cat("\nSuccessfully executed")
    
    
  })
  
  
  # ----------------------------------------# Polygonize #----------------------------------------------------------------------
 
  observeEvent(input$listPolygonize, {
    # Load the shapefile data
    listShapefile = list.files("D:/distribution_digitizer/www/polygonize/", full.names = T, pattern = '.shp')
    
    shape_data1 <- st_read(listShapefile[1])
    shape_data2 <- st_read(listShapefile[2])
    shape_data3 <- st_read(listShapefile[3])
    
    # Render the Leaflet map
    output$listPL1 <- renderLeaflet({
      leaflet() %>%
        addTiles() %>%
        addProviderTiles("OpenStreetMap.Mapnik") %>%
        addPolygons(data = shape_data1,
                    fillColor = "blue",
                    fillOpacity = 0.6,
                    color = "white",
                    stroke = TRUE,
                    weight = 1)
    })
    # Render the HTML shape name 1
    output$shape_name1 <- renderUI({
      HTML(paste("<p><strong>Shape Name:</strong> ", basename(listShapefile[1]), "</p>"))
    })
    # Render the Leaflet map
    output$listPL2 <- renderLeaflet({
      leaflet() %>%
        addTiles() %>%
        addProviderTiles("OpenStreetMap.Mapnik") %>%
        addPolygons(data = shape_data2,
                    fillColor = "blue",
                    fillOpacity = 0.6,
                    color = "white",
                    stroke = TRUE,
                    weight = 1)
    })
    # Render the HTML shape name 2
    output$shape_name2 <- renderUI({
      HTML(paste("<p><strong>Shape Name:</strong> ", basename(listShapefile[2]), "</p>"))
    })
    # Render the Leaflet map
    output$listPL3 <- renderLeaflet({
      leaflet() %>%
        addTiles() %>%
        addProviderTiles("OpenStreetMap.Mapnik") %>%
        addPolygons(data = shape_data3,
                    fillColor = "blue",
                    fillOpacity = 0.6,
                    color = "white",
                    stroke = TRUE,
                    weight = 1)
    })
    # Render the HTML shape name 3
    output$shape_name3 <- renderUI({
      HTML(paste("<p><strong>Shape Name:</strong> ", basename(listShapefile[3]), "</p>"))
    })
  })
  
   # Polygonize start
  observeEvent(input$polygonize, {
   
    # call the function for filtering
    manageProcessFlow("polygonize", "polygonize", "polygonize")
    
    # Write new dir
    new_directory <- paste0(workingDir, "/www/polygonize/")
    dir.create(new_directory)
    
    findTemplateResult = paste0(workingDir, "/data/output/polygonize/")
    shFiles <- list.files(findTemplateResult, pattern = ".sh", recursive = TRUE, full.names = TRUE)
    
    # copy the shape files into /www
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
        mainTemplateMatching(workingDir, input$threshold_for_TM)
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
        align(workingDir)
        print(fname)
        cat("\nSuccessfully executed")
        findTemplateResult = paste0(workingDir, "/data/output/maps/align/")
        files<- list.files(findTemplateResult, full.names = TRUE, recursive = FALSE)
        countFiles = paste0(length(files),"")
        print(countFiles)
      }
      
      if(processing == "croppingMap" ){
        # Croping
        fname=paste0(workingDir, "/", "src/read_species/map_read_species.R")
        print("Croping the species names R script:")
        print(fname)
        source(fname)
        species = readSpecies2(workingDir)
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
        print(" Process pixel filtering  python script:")
        print(fname)
        source_python(fname)
        mainPointFiltering(workingDir, input$filterK, input$filterG)
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

      if(processing == "georeferencing"){
        # processing georeferencing
        #library(reticulate)
        fname=paste0(workingDir, "/", "src/georeferencing/mask_georeferencing.py")
        print(" Process georeferencing python script:")
        print(fname)
        source_python(fname)
        mainmaskgeoreferencingMaps(workingDir)
        mainmaskgeoreferencingMasks(workingDir)
      }
      if(processing=="polygonize"){
        # processing rectifying
        fname=paste0(workingDir, "/", "src/polygonize/rectifying.py")
        print(" Process rectifying python script:")
        print(fname)
        source_python(fname)
        mainRectifying(workingDir)
        
        # processing polygonize
        fname=paste0(workingDir, "/", "src/polygonize/polygonize.py")
        print(" Process polygonizing python script:")
        print(fname)
        source_python(fname)
        mainPolygonize(workingDir)
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
    listPngImages = list.files(pathToMatchingImages, full.names = F, pattern = '.png')
    display_image = function(i) {
      HTML(paste0('<div class="shiny-map-image" > 
                  <img src = ', paste0(dirName,listPngImages[i] ), ' ><a href="',paste0(dirName,listPngImages[i] ),'" style="width:27%;" target=_blank>', listPngImages[i],'</a></div>'))
    }
    lapply(1:length(listPngImages), display_image)
  }
  

  
  # convert tif images to png and save in /www directory
  converTifToPngSave <- function(pathToTiffImages, patjhToPngImages){
    tifFiles <- list.files(pathToTiffImages, pattern = ".tif", recursive = FALSE)
    
    # convert tif to png and save this into the given path
    for (f in tifFiles) {
      tifFile = paste0(pathToTiffImages, f)
      print(tifFile)
      tifImage = image_read(tifFile)
      pngFile <- image_convert(tifImage, "png")
      temp_scale <- image_scale(pngFile, paste0(scale,"%"))
      pngName <- tools::file_path_sans_ext(f)
      fname = paste0(patjhToPngImages, pngName, ".png")
      print(fname)
      image_write(temp_scale, path = fname, format = "png", )
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