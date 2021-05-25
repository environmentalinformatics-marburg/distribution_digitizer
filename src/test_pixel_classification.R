install.packages("reticulate")
library(reticulate)

os <- import("os") 

library(reticulate)

use_python("C:/ProgramData/Anaconda3/python.exe")
py_install(packages = "opencv-python", pip = TRUE)
py_install(packages = "pillow", pip = FALSE)

setwd("D:/distribution_digitizer_students/")
source_python("D:/distribution_digitizer_students/src/Pixel_Classification.py")
workingDir ="D:/distribution_digitizer_students/output/"
n = 5
m = 9
mainpixelclassification(workingDir, n, m)
