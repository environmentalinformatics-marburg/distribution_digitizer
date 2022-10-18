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

# Input variables
options(shiny.host = '127.0.0.1')
options(shiny.port = 8888)

# Change the max uploaf size
options(shiny.maxRequestSize=100*1024^2)
tempImage="temp.png"
scale =20
rescale= (100/scale)
workingDir = ""

if (file.exists('lastwd.csv')){
  carSpeeds <- read.csv(file = 'lastwd.csv')
  #workingDir <- carSpeeds[1, ]
}
workingDir <- getwd()
print("dir")
print(workingDir)

test = 0

# The app body
shinyApp(
  
  # Functions for creating fluid layouts. A fluid page layout consists of rows which in turn include columns. 
  # Rows exist for the purpose of making sure their elements appear on the same line (if the browser has adequate width). 
  # Columns exist for the purpose of defining how much horizontal space within a 12-unit wide grid it's elements should occupy. 
  # Fluid pages scale their components in realtime to fill all available browser width.
  
  
  
  
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
               # Working directory
               # h2("1. Set your working directory", style = "color:black"),
               
               
               p("Your working directory is the local digitizer repository", style = "color:black"),
               p(workingDir, style = "color:black"),
               
               
               # fluidRow(column(3,textInput("workingDir", label=p("To change this, enter here"), 
               #  value = workingDir))),#, width = NULL, placeholder = NULL),
               
               # --------------------------------------------------------------------------------------------------------------
               # Create templates
               h2("1. Create template maps and template symbols", style = "color:black"),
               # File to choose 
               fileInput("image",  label = h3("1.1 Select image file for creating templates"), buttonLabel = "Browse...",
                         placeholder = "No file selected"),
               
               # --------------------------------------------------------------------------------------------------------------
               h3(strong("1.2 Save map templates", style = "color:black")),
               # Add number to the filename of the created template file
               fluidRow(column(3, numericInput("imgIndexTemplate", label = h5("Add index to the filename of the created map template"),value = 1),
                               # SAVE the croped template map image with the given index
                               downloadButton('saveTemplate', 'Save map'))),
               p(strong(paste0("Important! Save in ", workingDir, "/data/templates/maps/!"), style = "color:black")),
               p("The map templates saved in /data/templates/maps/ will be used to match to the content of the files in your input directory for extracting maps.", style = "color:black"),
               
               
               # --------------------------------------------------------------------------------------------------------------
               h3(strong("1.3 Save symbol templates", style = "color:black")),
               fluidRow(column(3, numericInput("imgIndexSymbol", label = h5("Add index to the filename of the created symbol template"),value = 1),
                               # SAVE the croped symbol image with the given index
                               downloadButton('saveSymbol', 'Save symbol'))),
               p(strong(paste0("Important! Save in ", workingDir, "/data/templates/symbols"), style = "color:black")),
               p("The symbol templates saved in /data/templates/symbols will be used to match to the content of the files in your output directory with extracted maps (/output/classification/matching).", style = "color:black"),
               
               
               
               
               # --------------------------------------------------------------------------------------------------------------
               # Map detection
               h2("2. Detect maps", style = "color:black"),
               
               p("High threshold values will lead to few detections, low values to many detections. Start with the threshold value 0.4 and keep decreasing it until all the outputs are extracted. The minimum possible output value will be 0.2.", style = "color:black"),
               fluidRow(column(3,numericInput("threshold_for_TM", label="Threshold (for map detection with template matching)", value = 0.2))),
               
               
               # Start map detection
               
               fluidRow(column(3, actionButton("templateMatching",  label = "Start map detection"))),
               
               p("You can find the extracted maps in your output directory (/data/output/)", style = "color:black"),
               
               
               h2("3. Classify points on maps", style = "color:black"),
               
               p("Two methods are available: template matching and filtering.", style = "color:black"),
               
               p("Template matching used the same approach as for clipping maps from images. Here, the templates are symbols extracted from legend elements, which should be saved in /templates/symbols/", style = "color:black"),
               
               p("Two methods are available: template matching and filtering.", style = "color:black"),
               
               
               h4("3.1 Using template matching", style = "color:black"),
               
               p("Start with values between 0.8 and 0.9.", style = "color:black"),
               
               # Threshold for pixel matching
               
               fluidRow(column(3,numericInput("threshold_for_PM", label="Threshold (for symbol detection with template matching)", value = 0.87))),
               
               fluidRow(column(3, actionButton("pixelMatching",  label = h3("Start template matching")))),
               
               p("You can find the classified maps in your /data/output/classifcation/matching folder ", style = "color:black"),
               
               h4("3.2 Using filtering", style = "color:black"),
               
               
               fluidRow(column(3,numericInput("filterK", label="Enter value for Kernel filter", value = 5))),#, width = NULL, placeholder = NULL)
               
               p("You can only enter odd values between 1 and 9. The value for the Gaussion filter should be higher than the value for the Kernel filter. The lower this value, the more points will be detected", style = "color:black"),
               
               fluidRow(column(3,numericInput("filterG", label="Enter value for Guassian filter", value = 9))),#, width = NULL, placeholder = NULL)
               
               fluidRow(column(3, actionButton("pixelClassification",  label = h3("Start filtering")))),
               
               p("You can find the classified maps in your /data/output/classification/filtering folder", style = "color:black"),
               
               
               h2("4. Georeferencing", style = "color:black"),
               
               p("Magick is going to happen (or not).", style = "color:black"),
               
               p("You need to have a file with GCP points in /data/templates/geopoints/ with the ending .points. The expected format is the default export of GCPs from QGIS containing the columns mapX, mapY, pixelX, and pixelY. This should be the first line the .points file. In case if you have any other information, you can manually remove it for now.You can find the output at the data/output/georeferencing/ folder. ", style = "color:black"),
               
               
               
               fluidRow(column(3, actionButton("georeferencing",  label = h3("Start georeferencing")))), 
               
               
               
               h2("5. Postprocessing", style = "color:black"),
               
               h4("5.1. Creating Masks for Postprocessing ", style = "color:black"),
               
               fluidRow(column(3,numericInput("filterm", label="Enter value for Kernel filter", value = 5))),#, width = NULL, placeholder = NULL)
               
               p(" You can use the same value of Kernel Filter from 4.2 and look at the masks. Here, the image will be filtered only with Kernel filter and hence, the value might vary. This is also the input for 6.3.", style = "color:black"),
               
               fluidRow(column(3, actionButton("geomasks",  label = h3("Create masks")))),
               
               p("You can find the classified maps in your /data/output/mask/non_georeferenced_masks/ folder.", style = "color:black"),
               
               
               h4("5.2. Mask Georeferencing", style = "color:black"),
               
               p("This georeferences the mask files.You can find the georeferenced maps in your /data/output/mask/georeferenced_masks/ folder.", style = "color:black"),
               
               p("You can use the same GCP points from the georeferencing step.", style = "color:black"),
               
               
               fluidRow(column(3, actionButton("maskgeoreferencing",  label = h3("Georeference the masks")))),
               
               h4("5.3. Centroid Extraction", style = "color:black"),
               
               
               p("Extracting the centroid of blue contours.", style = "color:black"),
               
               fluidRow(column(3, actionButton("pointextract",  label = h3("Extract the points")))),
               
               
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
    # Template matching start
    observeEvent(input$templateMatching, {
      #Processing template matching
      library(reticulate)
      fname=paste0(workingDir, "/", "src/template_matching.py")
      source_python(fname)
      print(input$threshold_for_TM)
      mainTemplateMatching(workingDir, input$threshold_for_TM)
      cat("\nSuccessfully executed")
      findTemplateResult = paste0(workingDir, "/data/output/")
      patternSum = paste0(input$threshold_for_TM,"_")
      files<- list.files(findTemplateResult, pattern=patternSum, full.names = TRUE, recursive = FALSE)
      countFiles = paste0(length(files),"")
      print(countFiles)
      message=paste0("The number extracted outputs with threshold=",input$threshold_for_TM , " are ", countFiles ,"! High threshold values lead to few detections, low values to many detections.")
      shinyalert(message, inputType = "text")
    })
    
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
    
    # Template matching start
    observeEvent(input$pixelClassification, {
      #Processing template matching
      library(reticulate)
      fname=paste0(workingDir, "/", "src/Pixel_Classification.py")
      source_python(fname)
      mainpixelclassification(workingDir, input$filterK, input$filterG)
      cat("\nSuccessfully executed")
    })
    
    # Pixel matching start
    observeEvent(input$pixelMatching, {
      #Processing template matching
      library(reticulate)
      fname=paste0(workingDir, "/", "src/Pixel_matching.py")
      source_python(fname)
      mainpixelmatching(workingDir, input$threshold_for_PM)
      cat("\nSuccessfully executed")
    })
    
    
    # Function to show the ccrop process in the app 
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
    
    # Render the image in the plot with given dynmicaly 10%
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
