library(reticulate)
use_python(Sys.which("python"))
os <- import("os") 
py_install(packages = "opencv-python", pip = TRUE)
py_install(packages = "pillow", pip = FALSE)

setwd("D:/distribution_digitizer_students-main/")
library(shiny)
runApp('app.R')


#shiny::runGist("https://gist.github.com/sforteva/138af2ea533c2d1c3d1631b5d2d41e86")

