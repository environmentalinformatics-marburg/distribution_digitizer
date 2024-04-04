# ============================================================
# Script Author: [Spaska Forteva]
# Created On: 2024-01-10
# ============================================================
# Description: R script for reading species data from CSV files, processing it, and saving the results to a new CSV file.

# Required libraries
library(stringr)
library(dplyr)
os <- import("os") 


# Set the working directory
#workingDir="D:/distribution_digitizer_11_01_2024/"

# Function to read the species
readPageSpecies <- function(workingDir, outDir, keywordReadSpecies, keywordBefore, keywordThen, middle) {
  # Set the path to the folder containing CSV files
  folder_path <- paste0(outDir, "/pagerecords/")
  
  # List all CSV files in the folder
  file_list <- list.files(path = folder_path, pattern = "\\.csv", full.names = TRUE)
  
  # Initialize an empty Dataframe
  combined_data <- data.frame()
  
  # Iterate through each CSV file and append it to the combined Dataframe
  for (file_path in file_list) {
    tryCatch({
      # Read the CSV file
      current_data <- read.csv(file_path)
      
      # Append the data to the combined Dataframe
      combined_data <- rbind(combined_data, current_data)
    }, error = function(e) {
      cat("Error occurred while processing file:", file_path, "\n")
      message(e)
    })
  }
  
  # Identify duplicated rows based on the "species" column
  duplicated_rows <- duplicated(combined_data$species)
  
  # Select non-duplicated rows
  filteredData <- combined_data[!duplicated_rows, ]
  
  # Import the Python script for species reading
  source_python(paste0(workingDir, "/src/read_species/page_crop_species.py"))
  for (i in 1:nrow(filteredData)) {
    pagePath = filteredData[i,"file_name"]
    if (i<5000){
      tryCatch({
          pagePath = filteredData[i,"file_name"]
          print(pagePath)
          speciesData =  filteredData[i,"species"]
          print(speciesData)
          speciesData <- speciesData[speciesData != ""]
          
          previous_page_path = filteredData[i,"previous_page_path"]
          next_page_path = filteredData[i,"next_page_path"]
          
          # Call the Python function for species identification
          pageTitleSpecies = find_species_context(pagePath, speciesData, previous_page_path, next_page_path, 
                                                  keywordReadSpecies, keywordBefore, keywordThen, middle)
          print(pageTitleSpecies)
          #pageTitleSpecies = "2_tirichmirensis__Colias wiskotti tirichmirensis Rose subsp. n. — Rosz K. 2001_Colias wiskotti Stgr. - D’Abrera 2001_Colias wiskotti tirichmirensis Rose 2001"
          pageTitleSpecies <- gsub("__", "_", pageTitleSpecies)
          # Remove duplicate entries
          if (length(pageTitleSpecies) > 0) {
            splitted_results <- unique(pageTitleSpecies)
            splitted_results <- strsplit(pageTitleSpecies, "_")
            
            # Extracting flag, search_species, and rspecies
            legend_keys <- sapply(splitted_results, function(x) as.numeric(x[1]))
            search_species <- sapply(splitted_results, function(x) x[2])
            rspecies <- sapply(splitted_results, function(x) x[3])
            print(rspecies)
          } else { 
            # Set all vectors to NA if there's only one entry
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
          
          # Replace any occurrence of '\\' with a placeholder value, e.g., "Error"
          new_dataframe[is.na(new_dataframe)] <- "Error"
          
          # Save the dataframe to CSV
          if (i == 1) {
            write.table(new_dataframe, file = paste0(outDir, "/pageSpeciesData.csv"), sep = ";", row.names = FALSE, col.names = TRUE, append = TRUE)
          }
          else {
            write.table(new_dataframe, file = paste0(outDir, "/pageSpeciesData.csv"), sep = ";", row.names = FALSE, col.names = FALSE, append = TRUE)
          }
      }, error = function(e) {
          cat("Error occurred while processing filteredData row:", i, "\n")
          print(pagePath)
          message(e)
        #  Ausführung fortsetzen, z.B. indem Sie leere Werte oder eine Fehlermeldung in die Ausgabedatei schreiben
          continue_execution <- TRUE
          #if (continue_execution) {
           # Schreiben Sie Platzhalter in die Datei oder eine Fehlermeldung
           # write.table(..., file = ..., append = TRUE)
         #}
      })
    }
  }
}

# Call the function with specified arguments
#readPageSpecies(workingDir, keyword, keywordBefore, keywordThen, middle)
