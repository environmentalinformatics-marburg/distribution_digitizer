#-------------------------------------------------------------------------------------------------

# Installation of needed packages (python) ####
# deactivate using comment after first installation
#py_install(packages = "opencv", pip = FALSE) #used for map matching
#py_install(packages = "pillow", pip = FALSE)
#py_install(packages = "tesseract", pip = FALSE)
#py_install(packages = "pandas", pip = FALSE)
#py_install(packages = "GDAL", pip = FALSE)
#py_install(packages = "imutils", pip = FALSE)
#py_install(packages = "rasterio", pip = FALSE)
#py_install(packages = "geopandas", pip = FALSE)

#use_python(Sys.which("python")) # Set the path to a local python installation.
# use this row if you not use Anaconda or miniconda. the best way is to set the python system (environment)variables (Windows->system,...) 

#use_python("C:/ProgramData/miniconda3/python.exe")
# os <- import("os") # python module needed for managing files, folders and their paths

#py_install(packages = "osgeo", pip = FALSE)
#py_install(packages = "opencv-python", pip = TRUE)
#setwd("C:/ProgramData/Miniconda3/")

#py_install(packages = "pillow", pip = FALSE)
#py_install(packages = "pandas", pip = FALSE)
#py_install(packages = "GDAL", pip = FALSE)


#---------------------------------------------------------------------------------------------------

# run this commands to load needed libraries
library(reticulate) # Python binding for R. 
library(shiny) # shiny library necessary for starting the app

# install.packages("reticulate") # start the RStudio as admin and hit Y when prompted for the miniconda installation
# Set the path to app.R for being able to execute the shiny app (runApp('app.R'))
# By default, this app.R lies at the root of this repository. 
# In RStudio, this path can be set automatically with
# setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
# or manually with a path of your choice:

Sys.setenv(TESSDATA_PREFIX = "C:/Program Files/Tesseract-OCR/tessdata")
setwd("D:/distribution_digitizer") # adjust path as necessary
getwd() # print the path to the working directory for copying into the Digitizer application (Field: "Working Directory").

# start this app to write the config file
#runApp('app_write_config.R')
       
# start the main app
#runApp('app.R') # the app itself

# ===== start_app.R =====

# 1. Config-Dialog ausführen
config_path <- shiny::runApp("app_write_config.R")  # stopApp() gibt hier den Pfad zurück

# 2. Pfad zwischenspeichern
saveRDS(config_path, file = "config_path.rds")

# 3. Haupt-App starten
shiny::runApp("app.R")

