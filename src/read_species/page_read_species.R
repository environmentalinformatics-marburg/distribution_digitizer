# Required libraries
library(stringr)
library(dplyr)
os <- import("os") 

readPageSpecies <- function(
    workingDir,
    outDir,
    keywordReadSpecies,
    keywordBefore,
    keywordThen,
    middle
) {
  
  folder_path <- file.path(outDir, "pagerecords")
  
  if (!dir.exists(folder_path)) {
    cat("ℹ️ No pagerecords directory found:", folder_path, "\n")
    return(invisible(NULL))
  }
  
  file_list <- list.files(folder_path, pattern = "\\.csv$", full.names = TRUE)
  
  if (length(file_list) == 0) {
    cat("ℹ️ No pagerecord CSV files found in:", folder_path, "\n")
    cat("➡️ Skipping species reading for this map type.\n")
    return(invisible(NULL))
  }
  
  combined_data <- data.frame()
  
  # ---------- CSV-LEVEL PROTECTION ----------
  for (file_path in file_list) {
    tryCatch({
      current_data <- read.csv(file_path, stringsAsFactors = FALSE)
      
      if (!"species" %in% colnames(current_data)) {
        cat("⚠️ CSV without 'species' column skipped:", file_path, "\n")
        return(NULL)
      }
      
      combined_data <- rbind(combined_data, current_data)
      
    }, error = function(e) {
      cat("⚠️ Failed to read CSV:", file_path, "\n")
      message(e)
    })
  }
  
  if (nrow(combined_data) == 0) {
    cat("ℹ️ No valid species data after reading CSVs in:", folder_path, "\n")
    return(invisible(NULL))
  }
  
  filteredData <- combined_data[!duplicated(combined_data$species), ]
  
  if (nrow(filteredData) == 0) {
    cat("ℹ️ All species duplicated – nothing to process in:", folder_path, "\n")
    return(invisible(NULL))
  }
  
  # Python nur laden, wenn wirklich nötig
  source_python(file.path(workingDir, "src/read_species/page_crop_species.py"))
  
  # ---------- ROW-LEVEL PROTECTION ----------
  for (i in seq_len(nrow(filteredData))) {
    
    tryCatch({
      
      pagePath <- filteredData$file_name[i]
      
      if (is.na(pagePath) || pagePath == "" || !file.exists(pagePath)) {
        cat("⚠️ Invalid or missing page path at row", i, "\n")
        return(NULL)
      }
      
      speciesData <- filteredData$species[i]
      if (is.na(speciesData) || speciesData == "") {
        cat("⚠️ Empty species at row", i, "– skipping\n")
        return(NULL)
      }
      
      previous_page_path <- filteredData$previous_page_path[i]
      next_page_path     <- filteredData$next_page_path[i]
      
      pageTitleSpecies <- find_species_context(
        workingDir,
        pagePath,
        speciesData,
        previous_page_path,
        next_page_path,
        keywordReadSpecies,
        keywordBefore,
        keywordThen,
        middle
      )
      
      if (length(pageTitleSpecies) == 0 || pageTitleSpecies == "Not found") {
        cat("ℹ️ Species not found on page:", basename(pagePath), "\n")
        return(NULL)
      }
      
      pageTitleSpecies <- gsub("__", "_", pageTitleSpecies)
      splitted_results <- strsplit(pageTitleSpecies, "_")
      
      legend_keys   <- sapply(splitted_results, \(x) as.numeric(x[1]))
      legend_indexs <- sapply(splitted_results, \(x) as.numeric(x[2]))
      search_species <- sapply(splitted_results, \(x) x[3])
      rspecies       <- sapply(splitted_results, \(x) x[4])
      
      new_dataframe <- data.frame(
        species = rspecies,
        legend_key = legend_keys,
        legend_index = legend_indexs,
        search_specie = search_species,
        file_name = pagePath,
        map_name = filteredData$map_name[i],
        stringsAsFactors = FALSE
      )
      
      new_dataframe[is.na(new_dataframe)] <- "Error"
      
      out_csv <- file.path(outDir, "pageSpeciesData.csv")
      
      write.table(
        new_dataframe,
        file = out_csv,
        sep = ";",
        row.names = FALSE,
        col.names = !file.exists(out_csv),
        append = file.exists(out_csv)
      )
      
    }, error = function(e) {
      cat("🚨 Error while processing species row", i, "\n")
      message(e)
    })
  }
  
  invisible(TRUE)
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

# Wrapper function for multiple map types
readPageSpeciesMulti <- function(
    workingDir,
    outDir,
    keywordReadSpecies,
    keywordBefore,
    keywordThen,
    middle,
    nMapTypes = 1
) {
  
  for (type_id in seq_len(as.integer(nMapTypes))) {
    
    cat("\n===============================\n")
    cat("Processing Map Type:", type_id, "\n")
    cat("===============================\n")
    
    # outDir pro Map-Typ
    outDir_type <- file.path(outDir, as.character(type_id))
    
    if (!dir.exists(outDir_type)) {
      cat("⚠️ Skipping Map Type", type_id, "- directory not found:\n",
          outDir_type, "\n")
      next
    }
    
    # Aufruf der ALTEN Funktion (unverändert!)
    readPageSpecies(
      workingDir        = workingDir,
      outDir            = outDir_type,
      keywordReadSpecies = keywordReadSpecies,
      keywordBefore     = keywordBefore,
      keywordThen       = keywordThen,
      middle            = middle
    )
  }
}


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
