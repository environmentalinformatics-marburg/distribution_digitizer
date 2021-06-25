library(reticulate) # Python binding for R. If the package is not installed, execute 
# install.packages("reticulate") # and hit Y when prompted for the miniconda installation
use_python(Sys.which("python")) # Set the path to a local python installation.
os <- import("os") # python module needed for managing files, folders and their paths
py_install(packages = "opencv-python", pip = TRUE) # python module for computer vision
py_install(packages = "pillow", pip = TRUE) # Python Imaging Library


# Set the path to app.R for being able to execute the shiny app (runApp('app.R'))
# By default, this app.R lies at the root of this repository. 
# In RStudio, this path can be set automatically with
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
# or manually with a path of your choice:
# setwd("D:/distribution_digitizer_students-main/") # uncomment this line for setting the working directory manually.

getwd() # print the path to the working directory for copying into the Digitizer application (Field: "Working Directory").


library(shiny) # shiny library necessary for starting the app
runApp('app.R') # the app itself

