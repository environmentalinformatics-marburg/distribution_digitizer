# Author: Your Name
# Date: December 20, 2023
# Description: R script for reading species data from CSV files, processing it, and saving the results to a new CSV file.

os <- import("os") 
library(stringr)
# Load the dplyr package
library(dplyr)

#workingDir="D:/distribution_digitizer"

# Function to read the species
readPageSpecies <- function(workingDir) {
  
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
  
  source_python(paste0(workingDir, "/src/read_species/page_crop_species.py"))
  
  for (i in 1:nrow(filteredData)) {
    #if(filteredData[i,"pageName"] == "004.tif"){
    pagePath = filteredData[i,"file_name"]
    print(pagePath)
    speciesData =  filteredData[i,"species"]
    
    # Split string at spaces and remove empty strings
    speciesData <- speciesData[speciesData != ""]
    print(speciesData)
    
    #pagePath = "D:/distribution_digitizer/data/input/pages/0064.tif"
    #speciesData = "_danna"
    pageTitleSpecies = mainPageCropSpecies(pagePath, speciesData)
    
    # Remove duplicate entries
    #unique_entries_without_duplicates <- unique(pageTitleSpecies)
    unique_entries_without_duplicates <- unique(unlist(pageTitleSpecies))
    
    unique_entries_without_duplicates <- unique_entries_without_duplicates[!grepl("distribution", unique_entries_without_duplicates, ignore.case = TRUE)]
    
    split_entries <- strsplit(unique_entries_without_duplicates, "; ")
    
    # Extract the part after the semicolon and save it in a new array
    new_array <- sapply(split_entries, function(x) x[2])
    
    # Combine the elements of the new array into a single string
    result_string <- paste(new_array, collapse = " ")
    
    new_dataframe <- data.frame(species = result_string, stringsAsFactors = FALSE)
    
    # Add a new column for the file name
    new_dataframe$file_name <- pagePath
    
    # Add a new column for the map name
    new_dataframe$map_name <- filteredData[i,"map_name"]
    
    # Save the dataframe to CSV
    if (i == 1) {
      write.table(new_dataframe, file = paste0(workingDir, "/data/output/pageSpeciesData.csv"), sep = ";", row.names = FALSE, col.names = TRUE, append = TRUE)
    }
    write.table(new_dataframe, file = paste0(workingDir, "/data/output/pageSpeciesData.csv"), sep = ";", row.names = FALSE, col.names = FALSE, append = TRUE)
  }
  
  print(pageTitleSpecies)
}
