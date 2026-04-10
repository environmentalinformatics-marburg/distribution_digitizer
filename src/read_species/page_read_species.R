# ------------------------------------------------------------
# Author: Spaska Forteva
# Last updated: 2026-03-31
#
# Description:
# This script processes page-level species information and
# integrates extended species titles extracted from scanned
# book pages into the Distribution Digitizer workflow.
#
# It acts as a bridge between R-based data handling and
# Python-based OCR text extraction, enriching previously
# detected species (from map legends) with additional
# contextual information (e.g., full species names, titles).
#
# The workflow includes:
# - Reading intermediate CSV files (pagerecords)
# - Filtering and deduplicating species entries
# - Calling Python functions for species context extraction
# - Parsing structured OCR results
# - Storing extracted titles in a consolidated CSV file
# - Linking titles back to spatial coordinate data
#
# This module extends the species extraction pipeline by
# incorporating textual context from book pages, enabling
# more complete species identification and validation.
# ------------------------------------------------------------

# Required libraries
library(stringr)
library(dplyr)
os <- import("os") 


# ------------------------------------------------------------
# Main function for extracting species titles from page-level
# OCR results and storing them in a structured CSV format.
#
# Workflow:
# - Reads all pagerecord CSV files for a given map type
# - Validates and combines species entries
# - Removes duplicate species
# - Calls Python function 'find_species_context' to extract
#   textual context (titles) from page images
# - Parses encoded results into structured components
# - Writes results incrementally to 'pageSpeciesData.csv'
#
# Includes robust error handling at both file and row level.
#
# Output:
# - CSV file containing species titles and metadata
# ------------------------------------------------------------
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
    next
  }
  
  file_list <- list.files(folder_path, pattern = "\\.csv$", full.names = TRUE)
  
  if (length(file_list) == 0) {
    cat("ℹ️ No pagerecord CSV files found in:", folder_path, "\n")
    cat("➡️ Skipping species reading for this map type.\n")
    next
  }
  
  combined_data <- data.frame()
  
  # ---------- CSV-LEVEL PROTECTION ----------
  for (file_path in file_list) {
    tryCatch({
      current_data <- read.csv(file_path, stringsAsFactors = FALSE)
      
      if (!"species" %in% colnames(current_data)) {
        cat("⚠️ CSV without 'species' column skipped:", file_path, "\n")
        next
      }
      
      combined_data <- rbind(combined_data, current_data)
      
    }, error = function(e) {
      cat("⚠️ Failed to read CSV:", file_path, "\n")
      message(e)
    })
  }
  
  if (nrow(combined_data) == 0) {
    cat("ℹ️ No valid species data after reading CSVs in:", folder_path, "\n")
    next
  }
  
  filteredData <- combined_data[!duplicated(combined_data$species), ]
  
  if (nrow(filteredData) == 0) {
    cat("ℹ️ All species duplicated – nothing to process in:", folder_path, "\n")
    next
  }
  
  # Python nur laden, wenn wirklich nötig
  source_python(file.path(workingDir, "src/read_species/page_crop_species.py"))
  
  # ---------- ROW-LEVEL PROTECTION ----------
  for (i in seq_len(nrow(filteredData))) {

    tryCatch({
      
      pagePath <- filteredData$file_name[i]
      print(pagePath)
      print(filteredData$file_name[i])
      if (is.na(pagePath) || pagePath == "" || !file.exists(pagePath)) {
        cat("⚠️ Invalid or missing page path at row", i, "\n")
        next
      }
      
      speciesData <- filteredData$species[i]
      if (is.na(speciesData) || speciesData == "") {
        cat("⚠️ Empty species at row", i, "– skipping\n")
        next
      }
      
      previous_page_path <- filteredData$previous_page_path[i]
      next_page_path     <- filteredData$next_page_path[i]
      print(speciesData)
      legend_list <- c("distribution of", "type locality of")
      pageTitleSpecies <- find_species_context(
        workingDir,
        pagePath,
        speciesData,
        previous_page_path,
        next_page_path,
        keywordReadSpecies,
        keywordBefore,
        keywordThen,
        middle,
        legend_list = legend_list
      )
      

      if (length(pageTitleSpecies) == 0) {
        cat("ℹ️ Only 'Not found' entries – skipping:", basename(pagePath), "\n")
        next
      }
      
      pageTitleSpecies <- gsub("__", "_", pageTitleSpecies)
      
      # 👉 ERST splitten
      splitted_results <- strsplit(pageTitleSpecies, "_")
      
      # 👉 DANN filtern
      splitted_results <- splitted_results[sapply(splitted_results, length) >= 4]
     
      
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


# ------------------------------------------------------------
# Updates a CSV file by assigning textual titles to species
# based on matching entries in a provided list of titles.
#
# Workflow:
# - Iterates over species names
# - Searches for occurrences in the title list
# - Appends matching titles to the corresponding rows
# - Cleans formatting (removes duplicate separators)
#
# Output:
# - Updated CSV file with a populated 'Title' column
# ------------------------------------------------------------
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


# ------------------------------------------------------------
# Wrapper function for processing multiple map types.
#
# Iterates over all specified map types and applies the
# 'readPageSpecies' function independently to each type.
#
# Ensures that species title extraction is performed
# consistently across multiple datasets or map categories.
# ------------------------------------------------------------
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


# ------------------------------------------------------------
# Integrates extracted species titles into spatial coordinate
# data by linking page-level species information with
# coordinate-based records.
#
# Workflow:
# - Reads coordinate data and extracted page species data
# - Matches species based on map name and species identifier
# - Handles different species formats (single vs. multiple)
# - Assigns corresponding titles to each coordinate entry
# - Writes updated coordinates CSV with a new 'title' column
#
# Output:
# - Updated coordinates.csv enriched with species titles
# ------------------------------------------------------------
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

# readPageSpecies(
#   workingDir = "D:/distribution_digitizer",
#   outDir = file.path("D:/test/output_2026-04-08_22-01-21/", "1"),
#   keywordReadSpecies = "Range",
#   keywordBefore = 0,
#   keywordThen = 2,
#   middle = 1
# )
#species = readPageSpecies("D:/distribution_digitizer/", "D:/test/output_2024-08-07_15-46-48/", "Range", 0, 2, 1)
# Call the function with specified arguments
# coordinates
