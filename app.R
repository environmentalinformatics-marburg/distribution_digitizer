library(magick)
library(grid)
library(rdrop2)
library(shiny)
library(shinyFiles)

# Input variables
# Change the max uploaf size
options(shiny.maxRequestSize=100*1024^2)
tempFile="._temp.png"
scale =20
rescale= (100/scale)

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
    titlePanel("DD Userinterface"),
    # define a row whith columns. 
    fluidRow(
      column(4,
             wellPanel(
               # Working directory
               fluidRow(column(3,textInput("working_dir", label="Working git directory", 
                                           value = "D:/distribution_digitizer_students/"))),#, width = NULL, placeholder = NULL)
               # File to choose with legend
               fileInput("image",  label = h3("Choose legend image")),
               
               # Select index of the croped image
               fluidRow(column(3, numericInput("imgIndex", label = h3("Select index of the croped image"),value = 1),
                               # SAVE the croped images with the given index
                               downloadButton('downloadImage', 'Save the cropped image'))),
               
               # Number Pages on the printed Site
               fluidRow(column(3, radioButtons("numberprintedPages", label = h3("Printed pages"),
                                               choices = list("1 page" = 1, "2 pages" = 2), selected = 1))), 
               
               # Page orientation
               #fluidRow(column(3, selectInput("pageaxis", label = h3("Page axis"),
                                             # choices = list("Horizontal" = 1, "Vertical" = 2),selected = 1))),
               # Site number orientation
              # fluidRow(column(3, radioButtons("sitenumberor", label = h3("Site number orientation"),
                                               #choices = list("top" = 1, "bottom" = 2), selected = 1))),
               # Map with
               #fluidRow(column(3,numericInput("mwidth", label = h3("Map width(~)"),value = 1))),    
               # Format of the scaned page
               fluidRow(column(3,selectInput("iformat", label = h3("Scan format"),
                                             choices = list("tif" = 1, "png" = 2), selected = 1))),
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
              
               fluidRow(column(3,textInput("threshold_for_TM", label="Threshold (for Template Matching)", value = "0,25"))),#, width = NULL, placeholder = NULL)
               fluidRow(column(3,textInput("output_directory_CI", label="Output directory (cropped images)", value = ""))),#, width = NULL, placeholder = NULL)
               fluidRow(column(3,textInput("output_directory_TM", label="Output directory (Template matching)", value = ""))),#, width = NULL, placeholder = NULL)
               
               # SAVE FIELDS
               #actionButton("submit", "Save input fields"),
               downloadButton("download_button", label = "Download the values as .txt")
             )       
      ),
      
      # Main panel for displaying plots of the input image and croped image ----
      column(8,
             plotOutput("plot", 
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
           
           
    # Function to show the ccrop process in the app 
    plot_png <- function(path, plot_brush, index, add=FALSE)
    {
      require('png')
      fname=paste0(input$working_dir,tempFile)
      png = png::readPNG(fname, native=T) # read the file
      # png <- image_read('DD_shiny/0045.png')
      res = dim(png)[2:1] # get the resolution, [x, y]
      if (!add) # initialize an empty plot area if add==FALSE
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
      fname = paste0(input$working_dir,tempFile)
      image_write(temp_scale, path = fname, format = "png", )
      
      req(file)
      list(src = fname, alt="alternative text")
    }, deleteFile = FALSE)
    
    #plot1
    output$plot1 <- renderPlot({
      req(input$image)
      d <- data()
      if(!is.null(input$image$datapath) && input$image$datapath!=""){
        plot_png(input$image$datapath, input$plot_brush, input$imgIndex)
      }
    })
    
    # Function to save the croped image
    output$downloadImage <- downloadHandler(
      filename = function() {
        paste('map', '_',input$imgIndex,'.tif', sep='')
      },
      content = function(file) {
        
        x1 = input$plot_brush$xmin
        x2 = input$plot_brush$xmax
        y2 = input$plot_brush$ymin
        y1 = input$plot_brush$ymax
        
        tempImage <- image_read(input$image$datapath)
        widht=(x2*rescale-x1*rescale)
        height=(y1*rescale-y2*rescale)
       
        geometrie <- paste0(widht, "x", height, "+",x1*rescale,"+", y2*rescale)
        #"100x150+0+0")
        tempImage <- image_crop(tempImage, geometrie)
        image_write(tempImage, file, format = "tif")
        #writePNG(tempImage, target = file)
        unlink(paste0(input$working_dir,"/._temp.png"))
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

           text <- (c(2, 1, 1,
                     500,"tif",1,
                     TRUE,
                     TRUE,
                     TRUE,
                     TRUE,
                     TRUE,
                     100,
                     128))
        
        write.table(text, file , col.names = F, row.names = fields, quote = F)
        # write.table(paste(text,collapse=", "), file,col.names=FALSE)
      }
    )
    
  }
)  
