#install.packages("reticulate")
#library(reticulate)
#install.packages("tesseract")
library(tesseract)
os <- import("os") 
library(stringr)


#working_dir = "D:/distribution_digitizer/"

# Function to read the species
read_species2 <- function(working_dir) {
 
  results = "The following species were found: "
  source_python(paste0(working_dir, "/src/read_species/map_crop_species.py"))
  pagerecords = paste0(working_dir, "/data/output/pagerecords/")
  outdir =  paste0(working_dir, "/data/output/maps/align/")
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
    w=as.integer(records_page$w[1])
    y=as.integer(records_page$y[1])
    h=as.integer(records_page$h[1])
    x=as.integer(records_page$x[1])
    file_name=records_page$file_name
    map_name=records_page$map_name
    if(!is.na(w) & !is.na(y) &!is.na(h) & !is.na(x)){
     # pathToPage = "D:/distribution_digitizer/data/input/pages/0060.tif"
      # use the crop Image function from the crop_species_name.py
      species = crop_species(working_dir, file_name, map_name, x,y,w,h)
      records_page$species = species
      write.csv(records_page, records_pages[j])
      results = paste0(results, "<br", map_name, ";", species)
    }
  } 
  return(results)
}

# Function to read the species with the given pagerecords path
read_species <- function(working_dir) {
  
  source_python(paste0(working_dir, "/src/read_species/map_crop_species.py"))
  pagerecords = paste0(working_dir, "/data/output/pagerecords/")
  outTifdir =  paste0(working_dir, "/data/output/maps/align/")
  outPngdir =  paste0(working_dir, "/www/croped_png/")
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
    w=as.integer(records_page$w[1])
    y=as.integer(records_page$y[1])
    h=as.integer(records_page$h[1])
    x=as.integer(records_page$x[1])
    if(!is.na(w) & !is.na(y) &!is.na(h) & !is.na(x)){
      
      # use the crop Image function from the crop_species_name.py
      path = cropImage(records_page$filename[1], pagerecords, x,y,w,h, as.character(j))
      eng <- tesseract("eng")
      text <- tesseract::ocr_data(path, engine = eng)
      h <- which(text$word == "distribution", arr.ind = TRUE)
      if(!is.na((h)& h>0)){
        if(!is.na(text$word[h+2])){
          # remove blank and append to the vector species if is no ""
          specie <- gsub(" ","",text$word[h+2])
          if (specie!=""){
            species<-append(species,specie )
            #print(records_pages[j]) 
            name = basename(records_pages[j])
            name1 <- str_replace(name, ".csv", "")
            newNameTif = paste0(outTifdir, name1 , "_", specie,".tif")
            oldName = paste0(outTifdir, name1 , ".tif")
            file.copy(oldName,newNameTif,overwrite = TRUE )
          }else{
            specie <- 'not found'
            species<-append(species,specie )
          } 
        }
        #print(species)  
      }
    }  
  }#end 1 for
}