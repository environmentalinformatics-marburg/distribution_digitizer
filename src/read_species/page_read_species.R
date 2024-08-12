# Required libraries
library(stringr)
library(dplyr)
os <- import("os") 

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
  indexNumberMap = 0
  # Import the Python script for species reading
  source_python(paste0(workingDir, "/src/read_species/page_crop_species.py"))
  for (i in 1:nrow(filteredData)) {
    #print(filteredData)
    pagePath = filteredData[i,"file_name"]
    if (i < 5000) {
      tryCatch({
        pagePath = filteredData[i,"file_name"]
        #print(pagePath)
        speciesData = filteredData[i,"species"]
        #print(speciesData)
        speciesData <- speciesData[speciesData != ""]
        
        previous_page_path = filteredData[i,"previous_page_path"]
        next_page_path = filteredData[i,"next_page_path"]
        
        # Call the Python function for species identification
        pageTitleSpecies = find_species_context(pagePath, speciesData, previous_page_path, next_page_path, 
                                                keywordReadSpecies, keywordBefore, keywordThen, middle)
      
        # pageTitleSpecies = '0_schistacea_Virachola isocrates isocrates (Fabricius, 1793) e distribution of schistacea'
        pageTitleSpecies <- gsub("__", "_", pageTitleSpecies)
        indexNumberMap = indexNumberMap +1
        # Remove duplicate entries
        if (length(pageTitleSpecies) > 0) {
          splitted_results <- unique(pageTitleSpecies)
          splitted_results <- strsplit(pageTitleSpecies, "_")
          
          # Extracting flag, search_species, and rspecies
          legend_keys <- sapply(splitted_results, function(x) as.numeric(x[1]))
          legend_indexs <- sapply(splitted_results, function(x) as.numeric(x[2]))
          search_species <- sapply(splitted_results, function(x) x[3])
          rspecies <- sapply(splitted_results, function(x) x[4])
          print(indexNumberMap)
          print(search_species)
          print(rspecies)
          # Update titles in coordinates.csv
          update_titles(csv_path = file.path(outDir, "maps", "csvFiles", "coordinates.csv"), search_species, rspecies)
        } else { 
          # Set all vectors to NA if there's only one entry
          legend_keys <- NA
          search_species <- NA
          rspecies <- NA
        }
        search_species[is.na(search_species)] <- speciesData
        rspecies[is.na(rspecies)] <- "Not found"
        
        # Create a new dataframe with the processed species data
        new_dataframe <- data.frame(species = rspecies, legend_key = legend_keys, legend_index = legend_indexs, search_specie = search_species, stringsAsFactors = FALSE)
        
        # Add a new column for the file name
        new_dataframe$file_name <- pagePath
        
        # Add new columns for map name and original species name
        new_dataframe$map_name <- filteredData[i,"map_name"]
        
        # Replace any occurrence of '\\' with a placeholder value, e.g., "Error"
        new_dataframe[is.na(new_dataframe)] <- "Error"
        
        # Save the dataframe to CSV
        if (i == 1) {
          write.table(new_dataframe, file = file.path(outDir, "pageSpeciesData.csv"), sep = ";", row.names = FALSE, col.names = TRUE, append = TRUE)
        } else {
          write.table(new_dataframe, file = file.path(outDir, "pageSpeciesData.csv"), sep = ";", row.names = FALSE, col.names = FALSE, append = TRUE)
        }
        
      }, error = function(e) {
        cat("Error occurred while processing filteredData row:", i, "\n")
        print(pagePath)
        message(e)
        # Ausführung fortsetzen, z.B. indem Sie leere Werte oder eine Fehlermeldung in die Ausgabedatei schreiben
        continue_execution <- TRUE
        # if (continue_execution) {
        # Schreiben Sie Platzhalter in die Datei oder eine Fehlermeldung
        # write.table(..., file = ..., append = TRUE)
        # }
      })
    }
  }
  # update_titles(csv_path=file.path(outDir, "coordinates_transformed.csv"), pageTitleSpecies)
  
  # processCoordinates(coordinatesPath = file.path(outDir,"maps", "csvFiles", "coordinates.csv"), pageSpeciesDataPath=file.path(outDir, "pageSpeciesData.csv"))
}

update_titles <- function(csv_path, species_list, titles_list) {
  # Read the CSV file
  df <- read.csv(csv_path, stringsAsFactors = FALSE)
  
  # Initialize the Title column if it doesn't exist
  if (!"Title" %in% colnames(df)) {
    df$Title <- NA
  }
  
  # Loop through each species in the species_list
  for (species in species_list) {
    matching_titles <- NULL
    
    # Search for the species in each title in titles_list
    for (title in titles_list) {
      if (grepl(species, title)) {
        matching_titles <- c(matching_titles, title)
      }
    }
    
    # If matching titles are found, update the Title column
    if (!is.null(matching_titles)) {
      df$Title <- ifelse(df$species == species, 
                         paste(df$Title[which(df$species == species)], 
                               paste(matching_titles, collapse = "; "), 
                               sep = "; "), 
                         df$Title)
    }
  }
  
  # Remove any leading or trailing semicolons and whitespace from the Title column
  df$Title <- trimws(gsub("^;\\s*|\\s*;$", "", df$Title))
  
  # Write the updated data back to the CSV file
  write.csv(df, csv_path, row.names = FALSE)
  
  cat("Updated CSV file successfully for species:", paste(species_list, collapse = ", "), "\n")
}


# Beispielaufruf:
# Angenommen, du möchtest die Titel für mehrere Spezies aktualisieren:
# species_list <- c("baltistana", "balucha", "pallida")
# titles_list <- c("Title for baltistana", "Title for balucha", "Title for pallida")
# update_titles("path/to/your/csv_file.csv", species_list, titles_list)

# Beispielaufruf:
# Angenommen, du möchtest den Titel "Syla Title" für alle Zeilen mit dem `species` "syla" aktualisieren:
# update_titles("path/to/your/csv_file.csv", "syla", "Syla Title")



# Function to read and process data
processCoordinates <- function(coordinatesPath, pageSpeciesDataPath) {
  # Read coordinates.csv and pageSpeciesData.csv
  coordinates <- read.csv(coordinatesPath, stringsAsFactors = FALSE)
  pageSpeciesData <- read.csv(pageSpeciesDataPath, sep = ";", stringsAsFactors = FALSE)
  coordinates$title <- NA
  
  # Define the palette colors vector
  palette_colors <- c("#FF0000", "#00FF00", "#0000FF")
  
  # Loop through each row in coordinates.csv
  for (i in 1:nrow(coordinates)) {
    # Extract relevant information
    map_name <- coordinates[i, "File"]
    species <- coordinates[i, "species"]
    color <- coordinates[i, "color"]
    
    # Check condition: color is not in palette_colors and species contains "_"
    if (!(color %in% palette_colors) & grepl("_", species)) {
      # Find corresponding rows in pageSpeciesData.csv with the same map_name and species
      matching_rows <- pageSpeciesData[basename(pageSpeciesData$map_name) == map_name, ]
      
      # Extract titles that contain the species
      if (nrow(matching_rows) > 0) {
        matching_titles <- matching_rows$species
        
        # Update coordinates dataframe
        coordinates[i, "title"] <- paste(matching_titles, collapse = "; ")
      } else {
        coordinates[i, "title"] <- NA
      }
      
    } else if (length(species) == 1 & !grepl("_", species)) {
      # Find corresponding rows in pageSpeciesData.csv with the same map_name and species
      matching_title <- pageSpeciesData[basename(pageSpeciesData$map_name) == map_name & pageSpeciesData$search_specie == species, "species"]
      
      # If matching title is found, update coordinates dataframe
      if (length(matching_title) > 0) {
        coordinates[i, "title"] <- paste(matching_title, collapse = "; ")
      } else {
        coordinates[i, "title"] <- NA
      }
      
    } else {
      coordinates[i, "title"] <- NA
    }
  }
  
  # Write updated coordinates.csv with title column
  write.csv(coordinates, coordinatesPath, row.names = FALSE)
  cat("Updated coordinates.csv successfully.\n")
}

#species = readPageSpecies("D:/distribution_digitizer/", "D:/test/output_2024-08-07_15-46-48/", "Range", 0, 2, 1)
# Call the function with specified arguments
# coordinates
