library(reticulate) # Python binding for R
use_python(Sys.which("python")) # Set the path to a local python installation
os <- import("os") # python module needed for managing files, folders and their paths
py_install(packages = "opencv-python", pip = TRUE) # python module for computer vision
py_install(packages = "pillow", pip = FALSE) # python module for ...


# Set the path to app.R for being able to execute the shiny app (runApp('app.R'))
# By default, this app.R lies at the root of this repository. 
# In RStudio, this path can be set automatically with
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
# or manually with a path of your choice:
# setwd("D:/distribution_digitizer_students-main/") # uncomment this line for setting the working directory manually.


library(shiny) # shiny library necessary for starting the app
runApp('app.R') # the app itself

