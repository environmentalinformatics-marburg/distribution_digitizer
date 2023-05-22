install.packages("reticulate")
library(reticulate)

os <- import("os") 

library(reticulate)

use_python("C:/ProgramData/Anaconda3/python.exe")
py_install(packages = "opencv-python", pip = TRUE)
py_install(packages = "pillow", pip = FALSE)

setwd("D:/distribution_digitizer")
source_python("D:/distribution_digitizer/src/template_matching/Pixel_Classification.py")
workingDir ="D:/distribution_digitizer"
n = 5
m = 9
mainpixelclassification(workingDir, n, m)
