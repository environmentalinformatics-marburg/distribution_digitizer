#install.packages("reticulate")
library(reticulate)
#install.packages("tesseract")
library(tesseract)
#os <- import("os") 
library(stringr)

#use_python("C:/ProgramData/Miniconda3/python.exe")
#py_install(packages = "imutils", pip = TRUE)
#py_install(packages = "pillow", pip = TRUE)
#py_install(packages = "pandas", pip = TRUE)
#path_dir <- ("D:/distribution_digitizer/")
#setwd(path_dir)

# set file names and path names
#outdir = "D:/distribution_digitizer/data/output/maps/"
#records = "D:/distribution_digitizer/data/output/r.csv"
#pagerecords = "D:/distribution_digitizer/data/output/pagerecords/"
#input = "D:/distribution_digitizer/data/input/"
#templates = "D:/distribution_digitizer/data/templates/map/"


####################### Align pages ###############################

# Test the align the outputs from template matching
#source_python("D:/distribution_digitizer/src/1_align_pages/align_page.py")
#align(workingDir)


####################### Map Template matching ###############################

# user the Python script template_matching.py
source_python("D:/distribution_digitizer/src/matching/map_matching.py")
# Test template matching from the script template_matching.py
workingDir = "D:/distribution_digitizer/"
mainTemplateMatching(workingDir,  0.27 )


####################### Align maps ###############################

# user the Python script
source_python("D:/distribution_digitizer/src/matching/map_align.py")
# Test the aline the outputs from template matching
workingDir = "D:/distribution_digitizer/"
align(workingDir)

####################### Read species ###############################

# user the R script read_species.R
source("D:/distribution_digitizer/src/matching/map_read_species.R")
workingDir = "D:/distribution_digitizer/"
# use the function read_species from the script read_species.R
readSpecies2(workingDir)


