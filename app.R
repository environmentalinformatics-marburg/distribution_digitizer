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

# Input variables
options(shiny.host = '127.0.0.1')
options(shiny.port = 8888)

# Change the max uploaf size
options(shiny.maxRequestSize=100*1024^2)
tempImage="temp.png"
scale =20
rescale= (100/scale)

workingDir <- getwd()
print("dir")
print(workingDir)
test = 0


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

#5 shinyfields_georeferensing
fileFullPath = (paste0(workingDir,'/config/shinyfields_georeferensing.csv'))
if (file.exists(fileFullPath)){
  shinyfields5 <- read.csv(fileFullPath,header = TRUE, sep = ';')
} else{
  stop(paste0("file:", fileFullPath, "not found, please create them and start the app"))
}

#6 shinyfields_postprocessing
fileFullPath = (paste0(workingDir,'/config/shinyfields_postprocessing.csv'))
if (file.exists(fileFullPath)){
  shinyfields6 <- read.csv(fileFullPath,header = TRUE, sep = ';')
} else{
  stop(paste0("file:", fileFullPath, "not found, please create them and start the app"))
}

#7 shinyfields_centroid_masc_georeferensing
fileFullPath = (paste0(workingDir,'/config/shinyfields_centroid_masc_georeferensing.csv'))
if (file.exists(fileFullPath)){
  shinyfields7 <- read.csv(fileFullPath,header = TRUE, sep = ';')
} else{
  stop(paste0("file:", fileFullPath, "not found, please create them and start the app"))
}

#8 shinyfields_centroid_extraction
fileFullPath = (paste0(workingDir,'/config/shinyfields_centroid_extraction.csv'))
if (file.exists(fileFullPath)){
  shinyfields8 <- read.csv(fileFullPath,header = TRUE, sep = ';')
} else{
  stop(paste0("file:", fileFullPath, "not found, please create them and start the app"))
}


# The app body
shinyApp(
  
  # Functions for creating fluid layouts. A fluid page layout consists of rows which in turn include columns. 
  # Rows exist for the purpose of making sure their elements appear on the same line (if the browser has adequate width). 
  # Columns exist for the purpose of defining how much horizontal space within a 12-unit wide grid it's elements should occupy. 
  # Fluid pages scale their components in real time to fill all available browser width.
  
  ui = fluidPage(
  # define custum style css for the app
  tags$head(
    # Note the wrapping of the string in HTML()
    tags$link(rel = "stylesheet", type = "text/css", href = "dd_style.css")
  ),
  
  # App title ----
  titlePanel("Distribution Digitizer"),
  # define a row with columns. 
  fluidRow(
    column(4,
    wellPanel(
      #fluidRow(column(3,selectInput("iformat", label = h3("Scan format"),
      #                             choices = list("tif" = 1, "png" = 2), selected = 1))),
     
      # Top Information
      p(shinyfields1$start_information  , style = "color:black"),
      
      # Working directory
      p(workingDir, style = "color:black"),

      # -----------------------------------------# 1. Step - Create templates #---------------------------------------------------------------------
      h2(strong(shinyfields1$head, style = "color:black")),
      # Choose the file 
      fileInput("image",  label = h5(shinyfields1$lab1), buttonLabel = "Browse...",
                         placeholder = "No file selected"),
      h3(strong(shinyfields1$save_template, style = "color:black")),
      
      # Add number to the file name of the created template file
      fluidRow(column(3, numericInput("imgIndexTemplate", label = h5(shinyfields1$lab2),value = 1),
      
      # Save the cropped template map image with the given index
      downloadButton('saveTemplate', 'save'))),
      p(strong(paste0(shinyfields1$inf, workingDir, "/data/templates/maps/!"), style = "color:black")),
      p(shinyfields1$inf1, style = "color:black"),
      p(strong(paste0(shinyfields1$inf2, workingDir, "/data/templates/symbols"), style = "color:black")),
      p(shinyfields1$inf3, style = "color:black"),
               
               
      # ----------------------------------------# 2. Map detection #----------------------------------------------------------------------
      h2(shinyfields2$head, style = "color:black"),
      p(shinyfields2$nf1, style = "color:black"),
      fluidRow(column(3,numericInput("threshold_for_TM", label=shinyfields2$threshold, value = 0.2))),
       
      # Start map detection
      fluidRow(column(3, actionButton("templateMatching",  label = shinyfields2$start1))),
      p(shinyfields2$inf2, style = "color:black"), 
      tags$div(style = "position: absolute; top: -100px;", textOutput("clock") ),  
      
      # Aligning maps
      h4(shinyfields2$head_sub, style = "color:black"),
      p(shinyfields2$inf3, style = "color:black"),
      fluidRow(column(3, actionButton("alignMaps",  label = h3(shinyfields2$start2)))),
     
      
      # ----------------------------------------# 3. Points detection #----------------------------------------------------------------------
      h2(shinyfields3$head, style = "color:black"),
      p(shinyfields3$inf1, style = "color:black"),
      p(shinyfields3$inf2, style = "color:black"),
      
      # ----------------------------------------# 3.1 Using matching #----------------------------------------------------------------------
      h4(shinyfields3$head_sub, style = "color:black"),
      p(shinyfields3$inf3, style = "color:black"),
      # Threshold for pixel matching
      fluidRow(column(3,numericInput("threshold_for_PM", label=shinyfields3$threshold, value = 0.87))),
      fluidRow(column(3, actionButton("pixelMatching",  label = h3(shinyfields3$lab)))),
      p(shinyfields3$inf4, style = "color:black"),
      p(shinyfields3$inf5, style = "color:black"),
      
      # ----------------------------------------# 3.2 Using filtering  FILE=shinyfields_detect_points_using_filtering #----------------------------------------------------------------------
      h4(shinyfields4$head, style = "color:black"),
      fluidRow(column(3,numericInput("filterK", label=shinyfields4$lab1, value = 5))),#, width = NULL, placeholder = NULL)
      p(shinyfields4$inf1, style = "color:black"),
      fluidRow(column(3,numericInput("filterG", label=shinyfields4$lab2, value = 9))),#, width = NULL, placeholder = NULL)
      fluidRow(column(3, actionButton("pixelClassification",  label = h3(shinyfields4$lab3)))),
      p(shinyfields4$inf2, style = "color:black"),

      
      # ----------------------------------------# 4. Georeferencing  FILE=shinyfields_georeferensing #----------------------------------------------------------------------
      h2("4. Georeferencing", style = "color:black"),
      p(shinyfields5$head, style = "color:black"),
      p(shinyfields5$inf1, style = "color:black"),
      p(shinyfields5$inf2, style = "color:black"),
      fluidRow(column(3, actionButton(shinyfields5$act,  label = h3(shinyfields5$lab)))), 
      
      
      # ----------------------------------------# 5 Postprocessing  FILE=shinyfields_postprocessing #----------------------------------------------------------------------
      h2(shinyfields6$head, style = "color:black"),
      h4(shinyfields6$head_sub, style = "color:black"),
      fluidRow(column(3,numericInput(shinyfields6$input, label=shinyfields6$lab1, value = 5))),#, width = NULL, placeholder = NULL)
      p(shinyfields6$inf1, style = "color:black"),
      fluidRow(column(3, actionButton("geomasks",  label = h3(shinyfields6$lab2)))),
      p(shinyfields6$inf2, style = "color:black"),

      # ----------------------------------------# 5.2. Mask Georeferencing  FILE=shinyfields_centroid_masc_georeferensing#----------------------------------------------------------------------
      h4(shinyfields7$head, style = "color:black"),
      p(shinyfields7$inf1, style = "color:black"),
      p(shinyfields7$inf2, style = "color:black"),
      fluidRow(column(3, actionButton("maskgeoreferencing",  label = h3(shinyfields7$lab)))),
      
      # ----------------------------------------# 5.3. Centroid Extraction FILE=shinyfields_centroid_extraction #----------------------------------------------------------------------
      h4(shinyfields8$head, style = "color:black"),
      p(shinyfields8$inf, style = "color:black"),
      fluidRow(column(3, actionButton("pointextract",  label = h3(shinyfields8$lab)))),
               
      
      # Number Pages on the printed Site
      #fluidRow(column(3, radioButtons("numberprintedPages", label = h3("Printed pages"),
      #                                choices = list("1 page" = 1, "2 pages" = 2), selected = 1))), 
      # Page orientation
      #fluidRow(column(3, selectInput("pageaxis", label = h3("Page axis"),
      # choices = list("Horizontal" = 1, "Vertical" = 2),selected = 1))),
      # Site number orientation
      # fluidRow(column(3, radioButtons("sitenumberor", label = h3("Site number orientation"),
      #choices = list("top" = 1, "bottom" = 2), selected = 1))),
      # Map with
      #fluidRow(column(3,numericInput("mwidth", label = h3("Map width(~)"),value = 1))),    
      # Format of the scaned page
      
      # Number of the boor sites
      #fluidRow(column(3,numericInput("bsites", label = h3("Number book sites"),value = 1))),
      # Is the Scan color or no
      # fluidRow(column(3, checkboxInput("pcolor", label = h3("Color scan yes/no"), value = TRUE))),
      #fluidRow(column(3, textInput("template_directory", label = h3("Template directory"), value = TRUE))),
      # fluidRow(column(3, checkboxInput("training_image_with_maps_category", 
      # label = h3("Training image /n with maps category=yes|no"), value = TRUE))),
      # fluidRow(column(3, checkboxInput("training_image_without_maps_category",
      #label = h3("Training image-without maps category=yes|no"), value = TRUE))),
      # fluidRow(column(3, checkboxInput("validation_image_with_maps_category", 
      # label = h3("Validation image-with maps category=yes|no"), value = TRUE))),
      # fluidRow(column(3, checkboxInput("validation_image_without_maps_category", 
      # label = h3("Validation image-without maps category"), value = TRUE))),
      # fluidRow(column(3,numericInput("input_pixel_compression_for_CNN", label = h3("Input pixel compression for CNN"),value = 100))), 
      # fluidRow(column(3,numericInput("batch_size", label = h3("Batch Size"),value = 128))), 
      # fluidRow(column(3,numericInput("epochs", label = h3("Epochs"),value = 1000))),
      #fluidRow(column(3,textInput("output_directory_CI", label="Output directory (cropped images)", value = ""))),#, width = NULL, placeholder = NULL)
      #fluidRow(column(3,textInput("output_directory_TM", label="Output directory (Template matching)", value = ""))),#, width = NULL, placeholder = NULL)
      
      # SAVE FIELDS
      #actionButton("submit", "Save input fields"),
      downloadButton("download_button", label = "Download the values as .txt")
        )       
      ),
      
      # Main panel for displaying plots of the input image and croped image ----
      column(8,
             plotOutput("plot", width="70%", 
                        click = "plot_click",  # Equiv, to click=clickOpts(id="plot_click")
                        hover = hoverOpts(id = "plot_hover", delayType = "throttle"),
                        brush = brushOpts(id = "plot_brush")),
             
             plotOutput("plot1", width = 200, height = 200), # plot for the crop point
             # plotOutput("plot2", width = 200, height = 200), # plot for the crop point
             # plotOutput("plot3", width = 200, height = 200),# plot for the crop point
      ),
      
      #column(width = 4,
      #       verbatimTextOutput("plot_clickinfo"),
      #       verbatimTextOutput("plot_hoverinfo")
      #),
      # column(width = 4,
      #        wellPanel(actionButton("newplot", "New plot")),
      #       verbatimTextOutput("plot_brushinfo")
      # ),
    )
  ),
  
  
  
  
  ######################################SERVER############################################## 
  server = function(input, output, session) {
    
    # save the last working directory
    onStop(function() {
      cat(workingDir)
      # fields<-c ("working_dir=")
      # text<-c(workingDir)
      # write.csv(text, file = "lastwd.csv" , col.names = F, row.names = fields, quote = F, append=T)
      # write.table(x, file = paste0(workingDir,"/lastwd.txt") ,sep = ",", col.names = NA)
    })
    
    # Update the clock every second using a reactiveTimer
    current_time <- reactiveTimer(1000)
 
    # ----------------------------------------# 2. Map detection #----------------------------------------------------------------------
    # Template matching start
    observeEvent(input$templateMatching, {
      
      # show start action message
      message=paste0("Process map detection is started on: ")
      shinyalert(text = paste(message, format(current_time(), "%H:%M:%S")), type = "info", showConfirmButton = FALSE, closeOnEsc = TRUE,
                 closeOnClickOutside = FALSE, animation = TRUE)
      
      #Processing template matching
      fname=paste0(workingDir, "/", "src/template_matching/template_matching.py")
      source_python(fname)
      print(input$threshold_for_TM)
      mainTemplateMatching(workingDir, input$threshold_for_TM)
      cat("\nSuccessfully executed")
      findTemplateResult = paste0(workingDir, "/data/output/maps/")
      patternSum = paste0(input$threshold_for_TM,"_")
      patternSum =gsub(".", "", patternSum, fixed=TRUE)
      patternSum =gsub("0", "", patternSum, fixed=TRUE)
      files<- list.files(findTemplateResult, pattern=patternSum, full.names = TRUE, recursive = FALSE)
      countFiles = paste0(length(files),"")
      print(countFiles)
      message2=paste0("Process align maps is ended on: ", format(current_time(), "%H:%M:%S"), ". The number extracted outputs with threshold=",input$threshold_for_TM , " are ", countFiles ,"! High threshold values lead to few detections, low values to many detections.")
      closeAlert(num = 0, id = NULL)
      shinyalert(message2, inputType = "text")
      
     # shinyalert(message2, inputType = "text")
    })
    
    # ----------------------------------------# 2.1 Align Maps #----------------------------------------------------------------------
    # Align maps  start
    observeEvent(input$alignMaps, {
      # show start action message
      message=paste0("Process align maps is started on: ")
      shinyalert(text = paste(message, format(current_time(), "%H:%M:%S")), type = "info", showConfirmButton = FALSE, closeOnEsc = TRUE,
                 closeOnClickOutside = FALSE, animation = TRUE)
      
      # Test the align the outputs from template matching
      fname=paste0(workingDir, "/", "src/align_maps/align_map.py")
      source_python(fname)
      align(workingDir)
      # show start action message
      message=paste0("Process align mapsis ended on: ")
      closeAlert(num = 0, id = NULL)
      shinyalert(text = paste(message, format(current_time(), "%H:%M:%S")), type = "info", showConfirmButton = TRUE, closeOnEsc = TRUE,
                 closeOnClickOutside = TRUE, animation = TRUE)
      
    })
    
    # ----------------------------------------# 2. Pixel detection #----------------------------------------------------------------------
    # Pixel matching start
    observeEvent(input$pixelMatching, {
      #Processing template matching
      library(reticulate)
      fname=paste0(workingDir, "/", "src/template_matching/Pixel_matching.py")
      source_python(fname)
      mainpixelmatching(workingDir, input$threshold_for_PM)
      cat("\nSuccessfully executed")
    })
    
    # Template matching start
    observeEvent(input$pixelClassification, {
      #Processing template matching
      library(reticulate)
      fname=paste0(workingDir, "/", "src/template_matching/Pixel_Classification.py")
      source_python(fname)
      mainpixelclassification(workingDir, input$filterK, input$filterG)
      cat("\nSuccessfully executed")
    })
    
    # ----------------------------------------# Georeferencing #----------------------------------------------------------------------
    # Georeferencing start
    observeEvent(input$georeferencing, {
      #Processing template matching
      library(reticulate)
      fname=paste0(workingDir, "/", "src/georeferencing.py")
      source_python(fname)
      maingeoreferencing(workingDir)
      cat("\nSuccessfully executed")
    })
    
    # GCP points extraction
    observeEvent(input$pointextract, {
      #Processing template matching
      library(reticulate)
      fname=paste0(workingDir, "/", "src/geo_points_extraction.py")
      source_python(fname)
      maingeopointextract(workingDir,input$filterm)
      cat("\nSuccessfully executed")
      
      
    })
    # masking start
    observeEvent(input$geomasks, {
      #Processing template matching
      library(reticulate)
      fname=paste0(workingDir, "/", "src/creating_masks.py")
      source_python(fname)
      maingeomask(workingDir, input$filterm)
      cat("\nSuccessfully executed")
    })
    
    
    # mask_Georeferencing start
    observeEvent(input$maskgeoreferencing, {
      #Processing template matching
      library(reticulate)
      fname=paste0(workingDir, "/", "src/mask_georeferencing.py")
      source_python(fname)
      mainmaskgeoreferencing(workingDir)
      cat("\nSuccessfully executed")
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
    
    # Function to save the croped tepmlate map image
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
    
    # Function to save the croped template symbol image
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
 
    
    formData <- reactive({
      data <- sapply(fields, contents)
      data
    })
    
    # Function to save the values from the input fields
    output$download_button <- downloadHandler(
      filename = function(){
        paste("data-", Sys.Date(), ".txt", sep = "")
      },
      content = function(file) {
        # fields <- c("numberprintedPages=","pageaxis=","sitenumberor=","mwidth=","iformat=","bsites=","pcolor=",
        #             "template_directory=",
        #             "training_image_with_maps_category=",
        #             "training_image_without_maps_category=",
        #             "validation_image_with_maps_category=",
        #             "validation_image_without_maps_category=","input_pixel_compression_for_CNN=",
        ##)
        #  text <- (c(input$numberprintedPages, input$pageaxis,input$sitenumberor,
        #            input$mwidth,input$iformat,input$bsites,input$pcolor,
        #             input$template_directory,
        #            input$training_image_with_maps_category,
        #            input$training_image_without_maps_category,
        # #            input$validation_image_with_maps_category,
        #            input$validation_image_without_maps_category,
        #            input$input_pixel_compression_for_CNN,
        #            input$batch_size,input$epochs,input$output_directory_CI,input$output_directory_TM))
        
        fields <- c("numberprintedPages=",
                    "pageaxis=",
                    "sitenumberor=",
                    "mwidth=",
                    "iformat=",
                    "bsites=",
                    "pcolor=",
                    "template_directory=",
                    "training_image_with_maps_category=",
                    "training_image_without_maps_category=",
                    "validation_image_with_maps_category=",
                    "validation_image_without_maps_category=",
                    "input_pixel_compression_for_CNN="
        )
        
        text <- (c(workingDir, 1, 1,
                   500,"tif",1,
                   TRUE,
                   TRUE,
                   TRUE,
                   TRUE,
                   TRUE,
                   100,
                   128))
        
        write.table(text, file , col.names = F, row.names = fields, quote = F, append=T)
        # write.table(paste(text,collapse=", "), file,col.names=FALSE)
      }
    )
    
  }#,
  #onStart = function() {
  #   cat(workingDir)
  
  #   onStop(function() {
  #     cat(workingDir)
  #  })
  # }
)  
