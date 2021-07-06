library(reticulate)
os <- import("os") 
use_python("C:/Program Files (x86)/Python27/python.exe")

path_dir <- ("D:/distribution_digitizer_students")
setwd(path_dir)
#py_install(packages = "GDAL", pip = FALSE)

#
source_python("D:/distribution_digitizer_students/src/geo_points_extraction.py")
maingeopointextract("D:/distribution_digitizer_students/")