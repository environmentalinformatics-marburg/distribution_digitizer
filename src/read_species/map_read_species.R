# ============================================================
# Script Author: [Spaska Forteva]
# Created On: 2024-01-10
# ============================================================

# Required libraries
library(tesseract)
library(stringr)
os <- import("os") 

#working_dir = "D:/distribution_digitizer_11_01_2024"

# Function to read the species
read_legends <- function(working_dir, out_dir) {
  
  results = "The following species were found: "
  source_python(paste0(working_dir, "/src/read_species/map_crop_species.py"))
  pagerecords = paste0(out_dir, "/pagerecords/")
  #outdir =  paste0(working_dir, "/data/output/maps/align/")
  # select all pages record information csv files as list
  records_pages <- list.files(path=pagerecords,pattern=".csv",full.names=T,recursive=T)
  
  # for loop into the list
  j = 1
  for(j in j:length(records_pages)) {
    records_page <- read.csv(records_pages[j], sep=",", check.names = FALSE, quote="\"",
                             na.strings=c("NA","NaN", " "))
    #print(records_page$filename[j])
    #print(j)
    species <- c()
    
    #print(length(records_page))
    
    #ERROR HANDLING define
    #w=as.integer(records_page$w[1])
    y=as.integer(records_page$y[1])
    h=as.integer(records_page$h[1])
    #x=as.integer(records_page$x[1])
    file_name=records_page$file_name
    map_name=records_page$map_name
    if(!is.na(y) &!is.na(h)){
      # pathToPage = "D:/distribution_digitizer/data/input/pages/0060.tif"
      # use the crop Image function from the crop_species_name.py
      print("Start")
      species = crop_specie(working_dir, out_dir, file_name, map_name, y, h)
      print(species)
      records_page$species = species
      write.csv(records_page, records_pages[j])
      results = paste0(results, "<br", map_name, ";", species)
    }
  }
  print("END")
  return(results)
}
