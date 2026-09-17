library(shiny)
library(shinydashboard)
library(shinyjs)
if(!require(leaflet)){
  install.packages("leaflet",dependencies = T)
  library(leaflet)
}

source("ui/helpers_ui.R")
source("ui/general_config_ui.R")
source("ui/book_structure_training_ui.R")
source("ui/map_matching_ui.R")
source("ui/species_distribution_ui.R", local = TRUE)
source("ui/masking_ui.R")
source("ui/species_reading_ui.R", local = TRUE)
source("ui/georeferencing_ui.R")
source("ui/polygonize_ui.R")
source("ui/spatial_view_ui.R")
source("ui/pipeline_ui.R")

config_list <- read.csv2(paste0(workingDir, '/config/config.csv'), header = FALSE, sep = ';', stringsAsFactors = FALSE)
colnames(config_list) <- c("key", "value")
config <- as.list(setNames(config_list$value, config_list$key))

info_list <- read.csv2(paste0(workingDir, '/config/info.csv'), header = FALSE, sep = ';', stringsAsFactors = FALSE)
colnames(info_list) <- c("key", "value")
info <- as.list(setNames(info_list$value, info_list$key))

fileFullPath <- paste0(workingDir, '/config/shinyfields_create_templates.csv')
if (file.exists(fileFullPath)) {
  shinyfields1 <- read.csv(fileFullPath, header = TRUE, sep = ';')
} else {
  stop("file shinyfields_create_templates.csv not found, please create them and start the app")
}

fileFullPath <- paste0(workingDir, '/config/shinyfields_detect_maps.csv')
if (file.exists(fileFullPath)) {
  shinyfields2 <- read.csv2(fileFullPath, header = TRUE, stringsAsFactors = FALSE, fileEncoding = "UTF-8")
  names(shinyfields2)
  shinyfields2$inf7
  str(shinyfields2)
} else {
  stop(paste0("file:", fileFullPath, "not found, please create them and start the app"))
}

fileFullPath <- paste0(workingDir, '/config/shinyfields_detect_points.csv')
if (file.exists(fileFullPath)) {
  shinyfields3 <- read.csv(fileFullPath, header = TRUE, sep = ';')
} else {
  stop(paste0("file:", fileFullPath, "not found, please create them and start the app"))
}

fileFullPath <- paste0(workingDir, '/config/shinyfields_detect_points_using_filtering.csv')
if (file.exists(fileFullPath)) {
  shinyfields4 <- read.csv(fileFullPath, header = TRUE, sep = ';')
} else {
  stop(paste0("file:", fileFullPath, "not found, please create them and start the app"))
}

fileFullPath <- paste0(workingDir, '/config/shinyfields_detect_points_using_circle_detection.csv')
if (file.exists(fileFullPath)) {
  shinyfields4.1 <- read.csv(fileFullPath, header = TRUE, sep = ';')
} else {
  stop(paste0("file:", fileFullPath, "not found, please create them and start the app"))
}

fileFullPath <- paste0(workingDir, '/config/shinyfields_masking.csv')
if (file.exists(fileFullPath)) {
  shinyfields5 <- read.csv(fileFullPath, header = TRUE, sep = ';')
} else {
  stop(paste0("file:", fileFullPath, "not found, please create them and start the app"))
}

fileFullPath <- paste0(workingDir, '/config/shinyfields_mask_centroids.csv')
if (file.exists(fileFullPath)) {
  shinyfields5.1 <- read.csv(fileFullPath, header = TRUE, sep = ';')
} else {
  stop(paste0("file:", fileFullPath, "not found, please create them and start the app"))
}

fileFullPath <- paste0(workingDir, '/config/shinyfields_georeferensing.csv')
if (file.exists(fileFullPath)) {
  shinyfields6 <- read.csv(fileFullPath, header = TRUE, sep = ';')
} else {
  stop(paste0("file:", fileFullPath, "not found, please create them and start the app"))
}

fileFullPath <- paste0(workingDir, '/config/shinyfields_polygonize.csv')
if (file.exists(fileFullPath)) {
  shinyfields7 <- read.csv(fileFullPath, header = TRUE, sep = ';')
} else {
  stop(paste0("file:", fileFullPath, "not found, please create them and start the app"))
}

fileFullPath <- paste0(workingDir, '/config/shinyfields_georef_coords_from_csv_file.csv')
if (file.exists(fileFullPath)) {
  shinyfields8 <- read.csv(fileFullPath, header = TRUE, sep = ';')
} else {
  stop(paste0("file:", fileFullPath, "not found, please create them and start the app"))
}

header <- dashboardHeader(
  tags$li(
    class = "dropdown",
    tags$style(HTML(".navbar-custom-menu{float:left !important;} .sidebar-menu{display:flex;align-items:baseline;} .shiny-map-image{margin:7px;} #message {color: red;}"))
  ),
  tags$li(
    class = "dropdown",
    sidebarMenu(
      id = "tablist",
      menuItem("General Config", tabName = "tab0"),
      menuItem("Create Templates", tabName = "tab1"),
      menuItem("Map Detection", tabName = "tab2"),
      menuItem("Species Distribution", tabName = "tab3"),
      menuItem("Masking", tabName = "tab4"),
      menuItem("Read Species", tabName = "tab5"),
      menuItem("Georeferencing", tabName = "tab6"),
      menuItem("Polygonize", tabName = "tab7"),
      menuItem("Spatial View", tabName = "tab8"),
      menuItem("Complete Pipeline", tabName = "tab9")
    )
  )
)

image1 <- paste0(workingDir, '/app/www/images/species_points_example.tif')
image2 <- paste0(workingDir, '/app/www/images/species_contours_example.tif')

head_content <- tags$head(
  tags$script(src = "custom.js"),
  tags$link(
    rel = "stylesheet", type = "text/css",
    href = paste0("dd_style.css?v=", unname(tools::md5sum(file.path("www", "dd_style.css"))))
  ),
  tags$script("shinyjs.options({debug: false});")
)

body <- dashboardBody(
  useShinyjs(),
  head_content,
  titlePanel("Distribution Digitizer"),
  conditionalPanel(condition = "input.someCondition == true", tags$script(src = "custom.js")),
  h3(paste0(info$workingDir_info, " ", workingDir), style = "color:black"),
  tabItems(
    general_config_ui(config = config, info = info),
    book_structure_training_ui(shinyfields1 = shinyfields1, workingDir = workingDir),
    map_matching_ui(shinyfields2 = shinyfields2, mapTypes = mapTypes),
    species_distribution_ui(shinyfields2 = shinyfields2, shinyfields3 = shinyfields3, shinyfields4 = shinyfields4, mapTypes = mapTypes),
    masking_ui(shinyfields2 = shinyfields2, shinyfields5.1 = shinyfields5.1, mapTypes = mapTypes),
    species_reading_ui(shinyfields2 = shinyfields2, shinyfields6 = shinyfields6, config = config),
    georeferencing_ui(shinyfields6 = shinyfields6, shinyfields8 = shinyfields8, shinyfields2 = shinyfields2, mapTypes = mapTypes),
    polygonize_ui(shinyfields2 = shinyfields2, shinyfields7 = shinyfields7, mapTypes = mapTypes),
    spatial_view_ui(shinyfields2 = shinyfields2, mapTypes = mapTypes),
    pipeline_ui()
  )
)

sidebar <-
  ui <- dashboardPage(
    header = header,
    sidebar = dashboardSidebar(disable = TRUE, width = 0),
    body = body,
    title = NULL,
    skin = "black"
  )
