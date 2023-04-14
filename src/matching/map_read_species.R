#install.packages("reticulate")
#library(reticulate)
#install.packages("tesseract")
library(tesseract)
os <- import("os") 
library(stringr)

# Function to read the species
readSpecies2 <- function(workingDir) {
  results = "The following species were found: "
  source_python(paste0(workingDir, "/src/matching/map_crop_species.py"))
  pagerecords = paste0(workingDir, "/data/output/pagerecords/")
  outdir =  paste0(workingDir, "/data/output/maps/align/")
  # select all pages record information csv files as list
  recordsPages <- list.files(path=pagerecords,pattern=".csv",full.names=T,recursive=T)
  
  # for loop into the list
  j = 1
  for(j in j:length(recordsPages)) { 
    recordsPage <- read.csv(recordsPages[j], sep=",", check.names = FALSE, quote="\"",
                            na.strings=c("NA","NaN", " "))
    #print(recordsPage$filename[j])
    #print(j)
    species <- c()
    
    #print(length(recordsPage))
    
    #ERROR HANDLING define
    w=as.integer(recordsPage$w[1])
    y=as.integer(recordsPage$y[1])
    h=as.integer(recordsPage$h[1])
    x=as.integer(recordsPage$x[1])
    filename=recordsPage$filename
    mapName=recordsPage$mapname
    if(!is.na(w) & !is.na(y) &!is.na(h) & !is.na(x)){
     # pathToPage = "D:/distribution_digitizer/data/input/pages/0060.tif"
      # use the crop Image function from the crop_species_name.py
      spacies = cropSpacies(workingDir, filename, mapName, x,y,w,h)
      recordsPage$spacies = spacies
      write.csv(recordsPage, recordsPages[j])
      results = paste0(results, "<br", mapName, ";", spacies)
    }
  } 
  return(results)
}

# Function to read the species with the given pagerecords path
readSpecies <- function(workingDir) {

  source_python(paste0(workingDir, "/src/matching/map_crop_species.py"))
  pagerecords = paste0(workingDir, "/data/output/pagerecords/")
  outdir =  paste0(workingDir, "/data/output/maps/align/")
  # select all pages record information csv files as list
  recordsPages <- list.files(path=pagerecords,pattern=".csv",full.names=T,recursive=T)
  
  # for loop into the list
  j = 1
  for(j in j:length(recordsPages)) { 
    recordsPage <- read.csv(recordsPages[j], sep=",", check.names = FALSE, quote="\"",
                            na.strings=c("NA","NaN", " "))
    #print(recordsPage$filename[j])
    #print(j)
    species <- c()
    
    #print(length(recordsPage))
    
    #ERROR HANDLING define
    w=as.integer(recordsPage$w[1])
    y=as.integer(recordsPage$y[1])
    h=as.integer(recordsPage$h[1])
    x=as.integer(recordsPage$x[1])
    if(!is.na(w) & !is.na(y) &!is.na(h) & !is.na(x)){
      
      # use the crop Image function from the crop_species_name.py
      path = cropImage(workingDir, recordsPage$filename[1], pagerecords, x,y,w,h, as.character(j))
      eng <- tesseract("eng")
      text <- tesseract::ocr_data(path, engine = eng)
      h <- which(text$word == "distribution", arr.ind = TRUE)
      if(!is.na((h)& h>0)){
        if(!is.na(text$word[h+2])){
          # remove blank and append to the vector species if is no ""
          specie <- gsub(" ","",text$word[h+2])
          if (specie!=""){
            species<-append(species,specie )
            #print(recordsPages[j]) 
            name = basename(recordsPages[j])
            name1 <- str_replace(name, ".csv", "")
            newName = paste0(outdir, name1 , "_", specie,".tif")
            oldName = paste0(outdir, name1 , ".tif")
            file.rename(oldName,newName )
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