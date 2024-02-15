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
    print(pagePath)
    speciesData =  filteredData[i,"species"]
    # Split string at spaces and remove empty strings
    speciesData <- speciesData[speciesData != ""]
    print(speciesData)
    
    previous_page_path = filteredData[i,"previous_page_path"]
    next_page_path = filteredData[i,"next_page_path"]
   
    # Call the Python function for species identification
    pageTitleSpecies = find_species_context(pagePath, speciesData, previous_page_path, next_page_path, 
                       keywordReadSpecies, keywordBefore, keywordThen, middle)
    
    # Remove duplicate entries
    if ( length(pageTitleSpecies) > 1 ){
      unique_entries_without_duplicates <- unique(unlist(pageTitleSpecies))
      
      unique_entries_without_duplicates <- unique_entries_without_duplicates[!grepl("distribution", unique_entries_without_duplicates, ignore.case = TRUE)]
      
      result_string = pageTitleSpecies
      print(result_string)
      #split_entries <- strsplit(unique_entries_without_duplicates, "; ")
      
      # Extract the part after the semicolon and save it in a new array
      #new_array <- sapply(split_entries, function(x) x[2])
      
      # Combine the elements of the new array into a single string
      #result_string <- paste(new_array, collapse = " ")
      
    } else result_string = pageTitleSpecies
    
    # Create a new dataframe with the processed species data
    new_dataframe <- data.frame(species = result_string, stringsAsFactors = FALSE)

    # Add a new column for the file name
    new_dataframe$file_name <- pagePath
    
    # Add new columns for map name and original species name
    new_dataframe$map_name <- filteredData[i,"map_name"]
    new_dataframe$specie_on_map <- filteredData[i,"species"]
    
    
    # Save the dataframe to CSV
    if (i == 1) {
      write.table(new_dataframe, file = paste0(workingDir, "/data/output/pageSpeciesData.csv"), sep = ";", row.names = FALSE, col.names = TRUE, append = TRUE)
    }
    else{
      write.table(new_dataframe, file = paste0(workingDir, "/data/output/pageSpeciesData.csv"), sep = ";", row.names = FALSE, col.names = FALSE, append = TRUE)
    }
    
  }
  print(pageTitleSpecies)
}

# Call the function with specified arguments
#readPageSpecies(workingDir, keyword, keywordBefore, keywordThen, middle)
