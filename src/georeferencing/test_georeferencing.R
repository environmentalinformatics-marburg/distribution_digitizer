library(reticulate)
os <- import("os") 
use_python("C:/ProgramData/miniconda3/python.exe")


path_dir <- ("D:/distribution_digitizer/")
setwd(path_dir)
#py_install(packages = "pandas", pip = FALSE)
#py_install(packages = "GDAL", pip = FALSE)

#

source_python("D:/distribution_digitizer/src/georeferencing/georeferencing.py")

maingeoreferencing("D:/distribution_digitizer/")

fname=paste0(workingDir, "/", "src/georeferencing/geo_points_extraction.py")
source_python(fname)
maingeopointextract("D:/distribution_digitizer/",5)
