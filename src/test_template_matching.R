#install.packages("reticulate")
library(reticulate)
#install.packages("tesseract")
library(tesseract)
os <- import("os") 
library(stringr)

#use_python("C:/ProgramData/Miniconda3/python.exe")
#py_install(packages = "imutils", pip = TRUE)
#py_install(packages = "pillow", pip = TRUE)
#py_install(packages = "pandas", pip = TRUE)
#path_dir <- ("D:/distribution_digitizer/")
#setwd(path_dir)

# set file names and path names
outdir = "D:/distribution_digitizer/data/output/maps/"
records = "D:/distribution_digitizer/data/output/r.csv"
pagerecords = "D:/distribution_digitizer/data/output/pagerecords/"
input = "D:/distribution_digitizer/data/input/"
templates = "D:/distribution_digitizer/data/templates/map/"
workingDir = "D:/distribution_digitizer/"
source_python("D:/distribution_digitizer/src/template_matching.py")

# user the R script read_species.R
source("D:/distribution_digitizer/src/read_species.R")

# Test template matching from the script template_matching.py
mainTemplateMatching(workingDir,  0.2 )

# Test the aline the outputs from template matching
source_python("D:/distribution_digitizer/src/aline.py")
aline(workingDir)

# use the function read_species from the scriptread_species.R
readSpecies(workingDir)


