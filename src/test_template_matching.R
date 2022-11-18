install.packages("reticulate")
library(reticulate)
os <- import("os") 
use_python("C:/ProgramData/Anaconda3/python.exe")
py_install(packages = "opencv-python", pip = TRUE)
py_install(packages = "pillow", pip = FALSE)



path_dir <- ("D:/distribution_digitizer/")
setwd(path_dir)

# set file names and path names
outdir = "D:/distribution_digitizer/data/output/"
records = "D:/distribution_digitizer/data/output/r.csv"
input = "D:/distribution_digitizer/data/input/"
templates = "D:/distribution_digitizer/data/templates/map/"

#
source_python("D:/distribution_digitizer/src/template_matching.py")

workingDir = "D:/distribution_digitizer/"
mainTemplateMatching(workingDir, 0.23)# = 49
mainTemplateMatching(workingDir, 0.3)
