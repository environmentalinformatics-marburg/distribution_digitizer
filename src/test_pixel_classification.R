install.packages("reticulate")
library(reticulate)
os <- import("os") 
library(reticulate)
use_python("C:/Program Files (x86)/Python27/python.exe")
py_install(packages = "opencv-python", pip = TRUE)
py_install(packages = "pillow", pip = FALSE)
setwd("D:/distribution_digitizer_students-main/")
source_python("D:/distribution_digitizer_students-main/src/Pixel_Classification.py")
pix_inputs ="D:/distribution_digitizer_students-main/data/output/"
out_pix ="D:/distribution_digitizer_students-main/data/sample_output/"
n = 5
m = 9
mainpixelclassification(pix_inputs, out_pix, n, m)
