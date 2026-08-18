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
    legendKeywords,
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
  source_python(file.path(workingDir, "src/species/species_title_processing_ocr.py"))
  target_map <- "0-thr18_0105_map_1_y2310_x287_n0.tif"
  # ---------- ROW-LEVEL PROTECTION ----------
  for (i in seq_len(nrow(filteredData))) {
    # 👉 TEST FILTER
    if (basename(filteredData$map_name[i]) != target_map) {
      next
    }
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
      legendKeywords <- strsplit(config$legendKeywords, ",")[[1]]
      legendKeywords <- trimws(legendKeywords)
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
        legendKeywords = legendKeywords
      )
      pageTitleSpecies <- pageTitleSpecies[
        grepl("\\b(18|19|20)\\d{2}\\b", pageTitleSpecies)
      ]
      #  HIER EINFÜGEN
      pageTitleSpecies <- pageTitleSpecies[!is.na(pageTitleSpecies)]
      pageTitleSpecies <- pageTitleSpecies[nchar(pageTitleSpecies) > 0]
      if (length(pageTitleSpecies) == 0) {
        cat("ℹ️ Only 'Not found' entries – skipping:", basename(pagePath), "\n")
        next
      }
      
      pageTitleSpecies <- gsub("__", "_", pageTitleSpecies)
      
      #  ERST splitten
      splitted_results <- strsplit(pageTitleSpecies, "_")
      
      # ROBUSTER FILTER (NEU)
      splitted_results <- splitted_results[
        sapply(splitted_results, function(x) {
          length(x) >= 4 &&
            suppressWarnings(!is.na(as.numeric(x[1]))) &&
            suppressWarnings(!is.na(as.numeric(x[2])))
        })
      ]
     
      
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
# Read species information for multiple map types
#
# This function call loads and processes species data based on
# parameters defined in the configuration file (config.csv),
# which is populated through the Shiny GUI.
#
# Key aspects:
# - All keyword parameters (e.g., keywordReadSpecies, keywordBefore,
#   keywordThen, middle) are dynamically read from the user-defined
#   configuration.
# - If no keywordReadSpecies is provided, a fallback value "None" is used.
# - The function is specifically designed to handle workflows with
#   multiple map types (nMapTypes), ensuring flexible and scalable
#   species extraction across different map categories.
# - workingDir and current_out_dir define the input/output context
#   for the current processing run.
#
# This allows a fully configurable and GUI-driven species extraction
# workflow without hardcoding parameters in the script.
# ------------------------------------------------------------
readPageSpeciesTitleMulti <- function(
    workingDir,
    outDir,
    keywordReadSpecies,
    keywordBefore,
    keywordThen,
    middle,
    legendKeywords,
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
      legendKeywords    = legendKeywords ,
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


# ============================================================
# Process direct species-title detection for all map types
# ============================================================
#
# This function controls species-title processing for all
# map-type output directories generated during the current run.
#
# For each map type (1, 2, 3, ...):
# - builds the corresponding output directory
# - checks whether records.csv exists
# - delegates the actual page processing to
#   readPageSpeciesDirect()
#
# The detailed OCR and title-detection logic remains in
# readPageSpeciesDirect() and the corresponding Python module.
# ============================================================

readPageSpeciesDirectMulti <- function(
    workingDir,
    outDir,
    nMapTypes
) {
  
  cat("\n=======================================\n")
  cat("DIRECT SPECIES TITLE PROCESSING\n")
  cat("Map types:", nMapTypes, "\n")
  cat("=======================================\n")
  
  
  # ----------------------------------------------------------
  # Process each map type independently
  # ----------------------------------------------------------
  
  for (mapType in seq_len(nMapTypes)) {
    
    cat("\n---------------------------------------\n")
    cat("MAP TYPE:", mapType, "\n")
    cat("---------------------------------------\n")
    
    
    # Output directory for this map type
    map_out_dir <- file.path(
      outDir,
      as.character(mapType)
    )
    
    
    # records.csv contains the maps detected on the
    # original book pages for this map type
    records_path <- file.path(
      map_out_dir,
      "records.csv"
    )
    
    
    cat("Output directory:", map_out_dir, "\n")
    cat("Records file:", records_path, "\n")
    
    
    # --------------------------------------------------------
    # Skip map types that were not processed
    # --------------------------------------------------------
    
    if (!file.exists(records_path)) {
      
      cat(
        "No records.csv found for map type",
        mapType,
        "- skipping.\n"
      )
      
      next
    }
    
    
    # --------------------------------------------------------
    # Process all pages belonging to this map type
    # --------------------------------------------------------
    
    readPageSpeciesDirect(
      workingDir = workingDir,
      outDir = map_out_dir,
      recordsPath = records_path
    )
  }
  
  
  cat("\n=======================================\n")
  cat("ALL MAP TYPES PROCESSED\n")
  cat("=======================================\n")
  
  invisible(TRUE)
}

readPageSpeciesDirect <- function(
    workingDir,
    outDir,
    recordsPath
) {
  
  # ----------------------------------------------------------
  # Read map records
  # ----------------------------------------------------------
  
  if (!file.exists(recordsPath)) {
    cat("⚠️ records.csv not found:", recordsPath, "\n")
    return(invisible(FALSE))
  }
  
  records <- read.csv(
    recordsPath,
    stringsAsFactors = FALSE
  )
  
  if (nrow(records) == 0) {
    cat("ℹ️ records.csv is empty.\n")
    return(invisible(FALSE))
  }
  
  
  # ----------------------------------------------------------
  # Load Python title detection
  # ----------------------------------------------------------
  
  source_python(
    file.path(
      workingDir,
      "src/species/species_title_processing_ocr.py"
    )
  )
  
  
  # ----------------------------------------------------------
  # Unique successfully processed pages
  # ----------------------------------------------------------
  
  pages <- unique(records$file_name)
  
  pages <- pages[
    !is.na(pages) &
      pages != ""
  ]
  
  
  all_results <- data.frame()
  
  
  # ==========================================================
  # Process page by page
  # ==========================================================
  
  for (pagePath in pages) {
    
    cat("\n=======================================\n")
    cat("PROCESS PAGE:", basename(pagePath), "\n")
    cat("=======================================\n")
    
    
    if (!file.exists(pagePath)) {
      
      cat("⚠️ Page not found:", pagePath, "\n")
      next
    }
    
    
    # --------------------------------------------------------
    # Maps belonging to this page
    # --------------------------------------------------------
    
    page_maps <- records[
      records$file_name == pagePath,
      ,
      drop = FALSE
    ]
    
    cat("Maps on page:", nrow(page_maps), "\n")
    
    
    # --------------------------------------------------------
    # Python:
    # Detect all species titles on this page
    #
    # The Python function should return something like:
    #
    # text | x | y | w | h
    # --------------------------------------------------------
    
    training_csv <- file.path(
      workingDir,
      "training",
      "species_title_training.csv"
    )
    
    detected_titles <- detect_species_titles_from_training(
      pagePath,
      training_csv
    )
    
    
    if (is.null(detected_titles) ||
        length(detected_titles) == 0) {
      
      cat("ℹ️ No titles detected.\n")
      next
    }
    cat("\n--- RAW PYTHON RESULT ---\n")
    print(detected_titles)
    str(detected_titles)
    
    # --------------------------------------------------------
    # Convert Python list of detected titles to R data.frame
    # --------------------------------------------------------
    
    titles <- do.call(
      rbind,
      lapply(
        detected_titles,
        function(item) {
          
          data.frame(
            text = as.character(item$text),
            x    = as.numeric(item$x),
            y    = as.numeric(item$y),
            w    = as.numeric(item$w),
            h    = as.numeric(item$h),
            stringsAsFactors = FALSE
          )
        }
      )
    )
    
    rownames(titles) <- NULL
    
    
    cat("Titles detected:", nrow(titles), "\n")
    
    
    # --------------------------------------------------------
    # IMPORTANT:
    # First test only.
    #
    # Do NOT assign title <-> map yet.
    # Print both Y coordinates first.
    # --------------------------------------------------------
    
    cat("\n--- TITLES ---\n")
    
    print(
      titles[, c(
        "text",
        "x",
        "y",
        "w",
        "h"
      )]
    )
    
    
    cat("\n--- MAPS ---\n")
    
    print(
      page_maps[, c(
        "map_name",
        "x",
        "y",
        "w",
        "h"
      )]
    )
    
    
    # --------------------------------------------------------
    # Sort both by vertical position
    # --------------------------------------------------------
    
    titles <- titles[
      order(titles$y),
      ,
      drop = FALSE
    ]
    
    page_maps <- page_maps[
      order(page_maps$y),
      ,
      drop = FALSE
    ]
    
    # --------------------------------------------------------
    # Assign nearest title to each map using Y coordinate
    # --------------------------------------------------------
    
    page_matches <- data.frame()
    
    for (i in seq_len(nrow(page_maps))) {
      
      current_map <- page_maps[i, ]
      
      # Distance between this map and every detected title
      y_distance <- abs(
        titles$y - current_map$y
      )
      
      # Title with smallest Y distance
      nearest_index <- which.min(
        y_distance
      )
      
      nearest_title <- titles[
        nearest_index,
        ,
        drop = FALSE
      ]
      
      match_row <- data.frame(
        file_name = current_map$file_name,
        map_name = current_map$map_name,
        
        map_x = current_map$x,
        map_y = current_map$y,
        map_w = current_map$w,
        map_h = current_map$h,
        
        species = nearest_title$text,
        
        title_x = nearest_title$x,
        title_y = nearest_title$y,
        title_w = nearest_title$w,
        title_h = nearest_title$h,
        
        y_distance = y_distance[nearest_index],
        
        stringsAsFactors = FALSE
      )
      
      page_matches <- rbind(
        page_matches,
        match_row
      )
    }
    
    
    cat("\n--- TITLE / MAP ASSIGNMENT ---\n")
    
    print(
      page_matches[, c(
        "species",
        "map_y",
        "title_y",
        "y_distance"
      )]
    )
    all_results <- rbind(
      all_results,
      page_matches
    )

  }
  
  # ==========================================================
  # Prepare pageSpeciesData
  # ==========================================================
  
  if (nrow(all_results) == 0) {
    cat("ℹ️ No species results found.\n")
    return(invisible(FALSE))
  }
  
  
  # ----------------------------------------------------------
  # Extract search species
  #
  # Example:
  # Eriogaster rimicola (...) -> rimicola
  # Malacosoma castrensis (...) -> castrensis
  # ----------------------------------------------------------
  
  search_specie <- vapply(
    strsplit(trimws(all_results$species), "\\s+"),
    function(words) {
      
      if (length(words) >= 2) {
        return(words[2])
      }
      
      NA_character_
    },
    character(1)
  )
  
  
  # ----------------------------------------------------------
  # Create pageSpeciesData in the SAME structure
  # as used by the existing workflow
  # ----------------------------------------------------------
  
  pageSpeciesData <- data.frame(
    species = all_results$species,
    legend_key = 1,
    legend_index = 1,
    search_specie = search_specie,
    file_name = all_results$file_name,
    map_name = all_results$map_name,
    stringsAsFactors = FALSE
  )
  
  
  # ----------------------------------------------------------
  # Show final result
  # ----------------------------------------------------------
  
  cat("\n=======================================\n")
  cat("FINAL PAGE SPECIES DATA\n")
  cat("=======================================\n")
  
  print(pageSpeciesData)
  
  
  # ----------------------------------------------------------
  # Save pageSpeciesData.csv
  # ----------------------------------------------------------
  
  output_file <- file.path(
    outDir,
    "pageSpeciesData.csv"
  )
  
  write.table(
    pageSpeciesData,
    file = output_file,
    sep = ";",
    row.names = FALSE,
    col.names = TRUE,
    quote = TRUE,
    na = ""
  )
  
  
  cat("\n=======================================\n")
  cat("PAGE SPECIES DATA SAVED\n")
  cat("=======================================\n")
  cat("File:", output_file, "\n")
  cat("Species:", nrow(pageSpeciesData), "\n")
  
  
  invisible(pageSpeciesData)
}


# readPageSpeciesDirect(
#   workingDir = "D:/distribution_digitizer",
#   outDir = "D:/test_eu/output_2026-08-11_11-45-32/1",
#   recordsPath = "D:/test_eu/output_2026-08-11_11-45-32/1/records.csv"
# )

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
