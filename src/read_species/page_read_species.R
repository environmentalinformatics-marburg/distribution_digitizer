# ============================================================
# Script Author: [Spaska Forteva]
# Created On: 2024-01-10
# ============================================================
# Description: R script for reading species data from CSV files, processing it, and saving the results to a new CSV file.

# Import the 'os' module
os <- import("os") 

# Load the 'stringr' package
library(stringr)

# Load the 'dplyr' package
library(dplyr)

# Set the working directory
#workingDir="D:/distribution_digitizer_11_01_2024/"

# Function to read the species
readPageSpecies <- function(workingDir, keywordReadSpecies, keywordBefore, keywordThen, middle) {
  #species = readPageSpecies(workingDir,config$keywordReadSpecies, 2, 0, TRUE)
  #print(keywordReadSpecies)
  #print(keywordBefore)
  #print(keywordThen)
  #print(middle)
  #keywordReadSpecies = "Range"
  #keywordBefore = 0
  ##keywordThen = 2
  middle = 1
  # Set the path to the folder containing CSV files
  folder_path <- paste0(workingDir, "/data/output/pagerecords/")
  
  # List all CSV files in the folder
  file_list <- list.files(path = folder_path, pattern = "\\.csv", full.names = TRUE)
  
  # Initialize an empty Dataframe
  combined_data <- data.frame()
  
  # Iterate through each CSV file and append it to the combined Dataframe
  for (file_path in file_list) {
    # Read the CSV file
    current_data <- read.csv(file_path)
    
    # Append the data to the combined Dataframe
    combined_data <- rbind(combined_data, current_data)
  }
  
  # Identify duplicated rows based on the "species" column
  duplicated_rows <- duplicated(combined_data$species)
  
  # Select non-duplicated rows
  filteredData <- combined_data[!duplicated_rows, ]
  
  # Import the Python script for species reading
  source_python(paste0(workingDir, "/src/read_species/page_crop_species.py"))
  
  for (i in 1:nrow(filteredData)) {
    pagePath = filteredData[i,"file_name"]
    #pagePath = 'D:/distribution_digitizer_11_01_2024/data/input/pages/0051.tif'
    #print(pagePath)
    speciesData =  filteredData[i,"species"]
    # remove empty strings
    speciesData <- speciesData[speciesData != ""]
    print(speciesData)
    
    previous_page_path = filteredData[i,"previous_page_path"]
    next_page_path = filteredData[i,"next_page_path"]
   
    # Call the Python function for species identification
    pageTitleSpecies = find_species_context(pagePath, speciesData, previous_page_path, next_page_path, 
                       keywordReadSpecies, keywordBefore, keywordThen, middle)
    print(pageTitleSpecies)
    # Remove duplicate entries
    if (length(pageTitleSpecies) > 0) {
      # Splitting flag, search_species, and rspecies
      #pageTitleSpecies <- c("1_elma_Gomalia elma (Trimen, 1862)" ,   "2_litoralis_“Gomalia litoralis, n. sp.” — SWINHOE, C.1885")
      splitted_results <- unique(pageTitleSpecies)
      splitted_results <- strsplit(pageTitleSpecies, "_")
      
      # Extracting flag, search_species, and rspecies
      legend_keys <- sapply(splitted_results, function(x) as.numeric(x[1]))
      print(legend_keys)
      search_species <- sapply(splitted_results, function(x) x[2])
      print(search_species)
      rspecies <- sapply(splitted_results, function(x) x[3])
      print(rspecies)
      
      # Entferne Einträge, die das Wort "distribution" enthalten
      #rspecies <- rspecies[!grepl("distribution", rspecies, ignore.case = TRUE)]
      
      # Bestimme die maximale Länge der Vektoren
     # max_length <- max(length(legend_keys), length(search_species), length(rspecies))
      
      # Fülle die Vektoren auf die gleiche Länge auf, indem du fehlende Elemente mit NA auffüllst
      #legend_keys <- c(legend_keys, rep(NA, max_length - length(legend_keys)))
      #search_species <- c(search_species, rep(NA, max_length - length(search_species)))
      #rspecies <- c(rspecies, rep(NA, max_length - length(rspecies)))
    } else {
        # Setze alle Vektoren auf NA, wenn es nur einen Eintrag gibt
        legend_keys <- NA
        search_species <- NA
        rspecies <- NA
    }
    
    # Create a new dataframe with the processed species data
    new_dataframe <- data.frame(species = rspecies, legend_key = legend_keys, search_specie = search_species, stringsAsFactors = FALSE)

    # Add a new column for the file name
    new_dataframe$file_name <- pagePath
    
    # Add new columns for map name and original species name
    new_dataframe$map_name <- filteredData[i,"map_name"]
 
    
    # Save the dataframe to CSV
    if (i == 1) {
      write.table(new_dataframe, file = paste0(workingDir, "/data/output/pageSpeciesData.csv"), sep = ";", row.names = FALSE, col.names = TRUE, append = TRUE)
    }
    else{
      write.table(new_dataframe, file = paste0(workingDir, "/data/output/pageSpeciesData.csv"), sep = ";", row.names = FALSE, col.names = FALSE, append = TRUE)
    }
    
  }
  #print(pageTitleSpecies)
}

# Call the function with specified arguments
#readPageSpecies(workingDir, keyword, keywordBefore, keywordThen, middle)
