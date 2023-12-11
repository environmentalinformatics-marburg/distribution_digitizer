# ============================================================
# Script Author: [Spaska Forteva]
# Created On: 2023-06-10
# ============================================================

# ============================================================
# Config Dialog for Book Distribution Digitization
# ============================================================
# 
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
               
               # save the values in csv file
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
      
      print(paste("It were ",length(x), "fields information saved!"))
      ## To write a CSV file for input to Excel one might use
      write.table(x, file = paste0(workingDir,"/config/config.csv"), sep = ";", row.names = FALSE,
                  quote=FALSE)
      
    })
    

  }
)