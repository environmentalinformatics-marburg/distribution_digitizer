install.packages("reticulate")
library(reticulate)
os <- import("os") 
use_python("C:/ProgramData/Anaconda3/python.exe")
py_install(packages = "opencv-python", pip = TRUE)
py_install(packages = "pillow", pip = FALSE)



path_dir <- ("D:/distribution_digitizer_students")
setwd(path_dir)

# set file names and path names
outdir = "D:/distribution_digitizer_students/data/output/"
records = "D:/distribution_digitizer_students/data/output/r.csv"
input = "D:/distribution_digitizer_students/data/input/"
templates = "D:/distribution_digitizer_students/data/templates/map/"

#
source_python("D:/distribution_digitizer_students/src/template_matching.py")

mainTemplateMatching(templates, input, outdir , records, 0.2)

