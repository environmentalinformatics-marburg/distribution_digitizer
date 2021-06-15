#install.packages("reticulate")
library(reticulate)
os <- import("os") 
use_python("C:/ProgramData/Anaconda3/python.exe")
py_install(packages = "opencv-python", pip = TRUE)
py_install(packages = "pillow", pip = FALSE)



path_dir <- ("D:/distribution_digitizer_students")
setwd(path_dir)

# set file names and path names
outputpcdir = "D:/distribution_digitizer_students/data/output/pixelc/"
input = "D:/distribution_digitizer_students/data/input/"
templates = "D:/distribution_digitizer_students/data/templates/map/"

#
source_python("D:/distribution_digitizer_students/src/Pixel_matching.py")

mainpixelmatching( "D:/distribution_digitizer_students/", 0.5)
