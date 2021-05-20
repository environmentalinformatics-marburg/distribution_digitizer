setwd("D:/distribution_digitizer_students/")
library(shiny)
library(shinydashboard)
library(shinyWidgets)
library(dashboardthemes)
library(DT)
library(png)
library(rasterImage)
library(ggpubr)
library(plotly)
library(shiny)
library(ShinyImage)
library(EBImage)

library(shiny)
options(shiny.host = '127.0.0.1')
options(shiny.port = 8888)
options(shiny.maxRequestSize=100*1024^2)
runApp('app.R')


shiny::runGist("https://gist.github.com/sforteva/138af2ea533c2d1c3d1631b5d2d41e86")

install.packages("BiocManager") 
BiocManager::install("EBImage")
install.packages("rdrop2", dependencies = T)
install.packages("shinyFiles", dependencies = T)
install.packages("rlang", dependencies = T)
library(devtools)
devtools::install_github("r-lib/rlang")

#Problems pillar installa in userdirektory