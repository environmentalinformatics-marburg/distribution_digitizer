-------------------------------------------------------------------------------------------------

# use_python(Sys.which("python")) # Set the path to a local python installation.
 
# use this row if you not use Anaconda or miniconda. the best way is to set the python system (environment)variables (Windows->system,...) 
# use_python("C:/Program Files (x86)/Python27/python.exe")
# os <- import("os") # python module needed for managing files, folders and their paths
# py_install(packages = "opencv-python", pip = FALSE)
# setwd("C:/ProgramData/Miniconda3/")

# py_install(packages = "pillow", pip = FALSE)
# py_install(packages = "pandas", pip = FALSE)
# py_install(packages = "GDAL", pip = FALSE)

# Set the path to app.R for being able to execute the shiny app (runApp('app.R'))
# By default, this app.R lies at the root of this repository. 
# In RStudio, this path can be set automatically with
# setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
# or manually with a path of your choice:
---------------------------------------------------------------------------------------------------

library(reticulate) # Python binding for R. 
# install.packages("reticulate") # start the RStudio as admin and hit Y when prompted for the miniconda installation

setwd("D:/distribution_digitizer/") # uncomment this line for setting the working directory manually.

getwd() # print the path to the working directory for copying into the Digitizer application (Field: "Working Directory").

library(shiny) # shiny library necessary for starting the app
# start this app to write the config file
runApp('app_write_config.R')
       
# start the main app
runApp('app.R') # the app itself

