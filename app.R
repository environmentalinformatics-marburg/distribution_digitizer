library(magick)
library(grid)
library(rdrop2)
library(shiny)
library(shinyFiles)
#install.packages("rsvg")
#tiger <- image_read('DD_shiny/0045.png')
#print(tiger)
#image_info(tiger)
#image_crop(tiger, "200x150+150+450")
#image_crop()
# A demonstration of clicking, hovering, and brushing
#outputDir <- "D:/distribution_digitizer_students/Object_Detection/"
options(shiny.maxRequestSize=100*1024^2)

shinyApp(
  ui = fluidPage(
    
    tags$head(
      # Note the wrapping of the string in HTML()
      tags$link(rel = "stylesheet", type = "text/css", href = "dd_style.css")
    ),
    # App title ----
    titlePanel("DD Userinterface"),
    
    fluidRow(
      column(4,
             wellPanel(
               #working direktory
               fluidRow(column(3,textInput("working_dir", label="Working git directory", 
                                           value = "D:/distribution_digitizer_students", width=500))),#, width = NULL, placeholder = NULL)
               # File to choose with legend
               fileInput("image",  label = h3("Choose legend image"), accept = ".png"),
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
                                             choices = list("tiff" = 1, "png" = 2), selected = 1))),
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
               downloadButton("download_button", label = "Download")
               ## Choose the output directory
               #shinyDirButton("dir", "Choose directory", "Upload"),
               ## Choose the output file name
               #textInput("text", label = "", value = "File name..."),
               ## Save the data
               
               ## Give the path selected
               #verbatimTextOutput("dir.res")
             )       
      ),
      
      # Main panel for displaying outputs ----
      column(8,
             plotOutput("plot", width = 500, height = 727,
                        click = "plot_click",  # Equiv, to click=clickOpts(id="plot_click")
                        hover = hoverOpts(id = "plot_hover", delayType = "throttle"),
                        brush = brushOpts(id = "plot_brush")),
             
             plotOutput("plot1", width = 200, height = 200), # plot for the crop point
             plotOutput("plot2", width = 200, height = 200), # plot for the crop point
             plotOutput("plot3", width = 200, height = 200),# plot for the crop point
      ),
      #actionButton("crop", "Save croped image"),),
      
      
      #column(width = 4,
      #       verbatimTextOutput("plot_clickinfo"),
      #       verbatimTextOutput("plot_hoverinfo")
      #),
      # column(width = 4,
      #        wellPanel(actionButton("newplot", "New plot")),
      #       verbatimTextOutput("plot_brushinfo")
      # ),
      tags$head(
        # Note the wrapping of the string in HTML()
        tags$link(rel = "stylesheet", type = "text/css", href = "dark_mode.css")
      )
    )
  ),
  


  
######################################SERVER############################################## 
server = function(input, output, session) {
    
    tempImage=NULL
    plot_png <- function(path, plot_brush, index, add=FALSE)
    {
      require('png')
      fname=paste0(input$working_dir,"/temp_png.png")
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
      
      #tempImage <- image_read(fname)
      #widht=x2-x1
      #height=y1-y2
      #geometrie <- paste0(widht, "x", height, "+",x1,"+", y2)
      #"100x150+0+0")
     # tempImage <- image_crop(tempImage, geometrie)
      #image_write(tempImage, file, format = "png")
      #writePNG(tempImage, target = file)
    }
    
    # A plot of fixed size
    output$plot <- renderImage({
      req(input$image)
      tiger <- image_read(input$image$datapath)
      file <- image_convert(tiger, "png")
      banana <- image_scale(file, "10%")
      fname=paste0(input$working_dir,"/temp_png.png")
      image_write(banana, path = fname, format = "png", )
      req(file)
      
      list(src = fname, alt="alternative text")
    }, deleteFile = FALSE)
    
    #plot1
    output$plot1 <- renderPlot({
      d <- data()
      if(!is.null(input$image$datapath) && input$image$datapath!=""){
        plot_png(input$image$datapath, input$plot_brush, input$imgIndex)
      }
    })
    
    output$downloadImage <- downloadHandler(
      filename = function() {
        paste('map', '_',input$imgIndex,'.tif', sep='')
      },
      content = function(file) {
        #tiff(file)
       # print(plot_png(input$image$datapath, input$plot_brush, input$imgIndex))
        #dev.off()
        
        x1 = input$plot_brush$xmin
        x2 = input$plot_brush$xmax
        y2 = input$plot_brush$ymin
        y1 = input$plot_brush$ymax
        
        tempImage <- image_read(input$image$datapath)
        widht=(x2*10-x1*10)
        height=(y1*10-y2*10)
       
        geometrie <- paste0(widht, "x", height, "+",x1*10,"+", y2*10)
        #"100x150+0+0")
        tempImage <- image_crop(tempImage, geometrie)
        image_write(tempImage, file, format = "tiff")
        #writePNG(tempImage, target = file)
      }) 
    
    
    formData <- reactive({
      data <- sapply(fields, contents)
      data
    })
    
    output$download_button <- downloadHandler(
      
      filename = function(){
        paste("data-", Sys.Date(), ".txt", sep = "")
      },
      content = function(file) {
        fields <- c("numberprintedPages=","pageaxis=","sitenumberor=","mwidth=","iformat=","bsites=","pcolor=",
                    "template_directory=",
                    "training_image_with_maps_category=",
                    "training_image_without_maps_category=",
                    "validation_image_with_maps_category=",
                    "validation_image_without_maps_category=","input_pixel_compression_for_CNN=",
                    "batch_size=","epochs=","output_directory_CI=","output_directory_TM="
        )
        text <- (c(input$numberprintedPages, input$pageaxis,input$sitenumberor,
                   input$mwidth,input$iformat,input$bsites,input$pcolor,
                   input$template_directory,
                   input$training_image_with_maps_category,
                   input$training_image_without_maps_category,
                   input$validation_image_with_maps_category,
                   input$validation_image_without_maps_category,
                   input$input_pixel_compression_for_CNN,
                   input$batch_size,input$epochs,input$output_directory_CI,input$output_directory_TM))
        
        write.table(text, file , col.names = F, row.names = fields, quote = F)
        # write.table(paste(text,collapse=", "), file,col.names=FALSE)
      }
    )
    
  }
)  
