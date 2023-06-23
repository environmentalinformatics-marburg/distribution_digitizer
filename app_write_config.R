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



# Input variables
options(shiny.host = '127.0.0.1')
options(shiny.port = 8888)

# Change the max uploaf size
options(shiny.maxRequestSize=100*1024^2)

scale =20
rescale= (100/scale)

workingDir <- getwd()

print(workingDir)

# read the config file

fileFullPath = (paste0(workingDir,'/config/configStartDialog.csv'))
if (file.exists(fileFullPath)){
  configStartDialog <- read.csv(fileFullPath, header = TRUE, sep = ';')
} else{
  stop("The file configStartDialog.csv was not found, please create them and start the app")
}


# The app body
shinyApp(
  
  # Functions for creating fluid layouts. A fluid page layout consists of rows which in turn include columns. 
  # Rows exist for the purpose of making sure their elements appear on the same line (if the browser has adequate width). 
  # Columns exist for the purpose of defining how much horizontal space within a 12-unit wide grid it's elements should occupy. 
  # Fluid pages scale their components in real time to fill all available browser width.
  
  ui = fluidPage(
    # define the style css for the app
    tags$head(
      # Note the wrapping of the string in HTML()
      tags$link(rel = "stylesheet", type = "text/css", href = "dd_style1.css")
    ),
    
    # App title ----
    titlePanel("Distribution Digitizer"),
    # define a row with columns. 
    fluidRow(
     
             wellPanel(
               h2(strong(configStartDialog$head, style = "color:black")),
               
               #Project directory
               p(paste0("Working directory - ",workingDir), style = "color:black"),
               
               # Data input directory
               fluidRow(column(3,textInput("dataInputDir", label=configStartDialog$i1, value = paste0(workingDir,"/data/input")))),
                        
               # Data output directory
               fluidRow(column(3,textInput("dataOutputDir", label=configStartDialog$i2, value =paste0(workingDir,"/data/output") ))),
               
               # numberSitesPrint
               fluidRow(column(3,selectInput("numberSitesPrint", label=configStartDialog$i3,  c("One site per scan" = 1 ,"Two sites per scan"= 2)))),
               
               # allprintedPages
               fluidRow(column(3,textInput("allPrintedPages", label=configStartDialog$i4, value = 100 ))),
               
               # format;
               fluidRow(column(3,selectInput("pFormat", label=configStartDialog$i5, c("tif"=1 , "png"=2, "jpg"=3), selected=1 ))),
               
               # Page color;
               fluidRow(column(3,selectInput("pColor", label=configStartDialog$i6, c("black white"=1 , "color"=2), selected=1 ))),
               
               # width;
               #fluidRow(column(3,textInput("allprintedPages", label=configStartDialog$i4, value = config$allprintedPages ))),
               fluidRow(column(3, actionButton("saveConfig",  label = "Save")))
            ) 
    )
  ),
  
  
  
  
  ######################################SERVER############################################## 
  server = function(input, output, session) {
    
    # save the last working directory
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
    

  }
)