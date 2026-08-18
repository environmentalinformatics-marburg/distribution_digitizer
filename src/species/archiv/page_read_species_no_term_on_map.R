# Author: [Spaska Forteva]
# Date: [Creation Date, e.g., 2024-12-06]
# Script: Function to read species data and process map-related information.

# Required libraries
library(stringr)  # For string manipulation
library(dplyr)    # For data manipulation

# Import Python functionality
os <- import("os")  # Required for Python interaction

# Function to read species data from specified directories
readPageSpecies <- function(workingDir, outDir, keywordReadSpecies, keywordBefore, keywordThen, middle, approximatelySpecieMap) {
  # Set the working and output directory paths
  workingDir <- "D:/distribution_digitizer/"
  outDir <- "D:/test/output_2024-12-06_13-41-42/"
  
  # Path to the folder containing pagerecords CSV files
  folder_path <- paste0(outDir, "/pagerecords/")
  
  # List all CSV files in the specified folder
  file_list <- list.files(path = folder_path, pattern = "\\.csv", full.names = TRUE)
  
  # Initialize an empty data frame to combine data from all files
  combined_data <- data.frame()
  
  # Loop through each CSV file and read its content
  for (file_path in file_list) {
    tryCatch({
      current_data <- read.csv(file_path)  # Read the current file
      combined_data <- rbind(combined_data, current_data)  # Append data to the combined data frame
    }, error = function(e) {
      # Handle errors during file processing
      cat("Error occurred while processing file:", file_path, "\n")
      message(e)
    })
  }
  
  # Remove duplicate rows from the combined data
  duplicated_rows <- duplicated(combined_data)
  filteredData <- combined_data[!duplicated_rows, ]
  
  # Initialize variables
  indexNumberMap <- 0
  title_contents <- ""
  
  # Loop through each unique file name in the data
  for (file_name_value in unique(filteredData$file_name)) {
    # Debug: Print the file name being processed
    # print(file_name_value)
    
    # Import Python script for species extraction
    source_python(paste0(workingDir, "/src/read_species/page_crop_species_no_term_on_map.py"))
    
    # Call the Python function to find species context
    title_contents <- find_species_context(file_name_value, "Type", 0, 2)
    print("Debugging title_contents:")
    
    if (is.null(title_contents)) {
      print("title_contents is NULL")  # Handle null result
    } else if (nrow(title_contents) == 0) {
      print("title_contents has no rows")  # Handle empty data
    } else {
      # Process map-related data for the current file
      unique_map_names <- unique(filteredData$map_name[filteredData$file_name == file_name_value])
      
      for (map_name in unique_map_names) {
        # Filter rows for the current map_name
        map_data <- filteredData[filteredData$map_name == map_name, ]
        print("map_data")
        print(map_data)
        
        # Match map_name to corresponding entries in title_contents based on y-position
        for (i in 1:nrow(map_data)) {
          row <- map_data[i, ]
          for (j in 1:nrow(title_contents)) {
            if (abs(title_contents$y[j] - row$y) <= 350) {
              title_contents$map_name[j] <- row$map_name
            }
          }
        }
      }
    }
    
    # Prepare data for output
    new_data <- title_contents
    
    # Dynamically add new columns
    new_data$species <- new_data$title  # Copy 'title' to 'species'
    new_data$title <- NULL              # Remove the original 'title' column
    new_data$legend_key <- 0            # Add 'legend_key' column with default value 0
    new_data$legend_index <- 0          # Add 'legend_index' column with default value 0
    new_data$search_specie <- ""        # Add 'search_specie' column as empty string
    
    # Write the data to a CSV file, append for subsequent iterations
    if (indexNumberMap == 0) {
      write.table(new_data, file = file.path(outDir, "pageSpeciesData.csv"), sep = ";", row.names = FALSE, col.names = TRUE, append = TRUE)
    } else {
      write.table(new_data, file = file.path(outDir, "pageSpeciesData.csv"), sep = ";", row.names = FALSE, col.names = FALSE, append = TRUE)
    }
    indexNumberMap <- indexNumberMap + 1  # Increment the map index
  }
}

# Example call to the function with sample arguments
# readPageSpecies("D:/distribution_digitizer/", "D:/test/output_2024-12-06_13-41-42/", "Type", 0, 2, 0, 1)
