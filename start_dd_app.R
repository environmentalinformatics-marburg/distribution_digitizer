library(reticulate)
os <- import("os") 
use_python("C:/ProgramData/Anaconda3/python.exe")
py_install(packages = "opencv-python", pip = TRUE)
py_install(packages = "pillow", pip = FALSE)

setwd("D:/distribution_digitizer_students/")
library(shiny)
runApp('app.R')


#shiny::runGist("https://gist.github.com/sforteva/138af2ea533c2d1c3d1631b5d2d41e86")

