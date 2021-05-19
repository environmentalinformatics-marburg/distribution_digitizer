setwd("D:/")
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
options(shiny.host = '0.0.0.0')
options(shiny.port = 8888)
runApp('DD_shiny')



install.packages("BiocManager") 
BiocManager::install("EBImage")
install.packages("rdrop2", dependencies = T)
install.packages("shinyFiles", dependencies = T)
install.packages("rlang", dependencies = T)
library(devtools)
devtools::install_github("r-lib/rlang")

#Problems pillar installa in userdirektory