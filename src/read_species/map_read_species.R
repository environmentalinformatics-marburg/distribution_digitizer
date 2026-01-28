# Required libraries
library(tesseract)
library(stringr)


clean_species <- function(species) {
  species <- gsub("_", "", species)  # Entferne alle Unterstriche
  species <- trimws(species)         # Entferne führende und nachfolgende Leerzeichen
  return(species)
}


read_legends <- function(working_dir, out_dir, nMapTypes = 1) {
  
  results <- "The following species were found: "
  
  # Source Python script for additional processing if needed
  source_python(file.path(working_dir, "src/read_species/map_crop_species.py"))
  
  # Directory setup

  
  # --- Finde alle map-type Ordner ---
  map_type_dirs <- list.dirs(out_dir, full.names = TRUE, recursive = FALSE)
  map_type_dirs <- map_type_dirs[grepl("/[0-9]+$", map_type_dirs)]
  
  # --- Nur die ersten nMapTypes verarbeiten ---
  map_type_dirs <- map_type_dirs[seq_len(nMapTypes)]
  
  if (length(map_type_dirs) == 0) {
    cat("⚠️ No map-type folders found in output/\n")
    return(results)
  }
  
  # --- Jeden map-type Ordner einzeln verarbeiten ---
  for (map_dir in map_type_dirs) {
    map_type <- basename(map_dir)
    cat("\n=== Processing map type folder:", map_type, "===\n")
    
    # CSV-Datei für diesen Typ
    csv_file_path_type <- file.path(map_dir, "maps", "csvFiles", "coordinates.csv")
    
    # Load the CSV file
    df <- read.csv(csv_file_path_type, stringsAsFactors = FALSE)
    
    # Initialize the species column
    df$species <- NA
    pagerecords <- file.path(out_dir, map_dir, "pagerecords")
    records_pages <- list.files(path = pagerecords, pattern = ".csv", full.names = TRUE, recursive = TRUE)
    cat("\n=== rpagerecords:", pagerecords, "===\n")
    # Process each records page
    for (j in seq_along(records_pages)) {
      records_page <- read.csv(records_pages[j], sep = ",", check.names = FALSE, quote = "\"", na.strings = c("NA", "NaN", " "))
      file_name <- records_page$file_name
      cat("\n=== Processing file_name:", file_name, "===\n")
      map_name <- records_page$map_name
      
      if (!is.na(records_page$y[1]) && !is.na(records_page$h[1])) {
        # Extract species information
        species <- crop_specie(
          working_dir = working_dir,
          out_dir = out_dir,
          path_to_page = file.path(pagerecords, file_name),
          path_to_map = file.path(map_dir, "maps", "align", map_name),
          y = as.integer(records_page$y[1]),
          h = as.integer(records_page$h[1]),
          attempt = 1
        )
        print("Here the specie:")
        print(species)
        
        results <- paste0(results, "<br>", map_name, ";", species)
        
        # Remove leading underscore and split species string into components
        species <- sub("^_", "", species)
        species <- gsub("distribution", "", species)
        
        # Split species string into components
        species_list <- str_split(species, "_")[[1]]
        print(species_list)
        
        # Function to clean species names
        clean_species <- function(species) {
          species <- gsub("\\d", "", species)  # Remove digits
          species <- gsub("S.*", "", species)  # Remove everything after 'S'
          species <- gsub("_", "", species)
          return(species)
        }
        
        # Clean species names
        cleaned_species <- sapply(species_list, clean_species)
        print(cleaned_species)
        
        # Create a named vector of cleaned species
        names(cleaned_species) <- sapply(species_list, function(x) sub(".*S", "", x))
        
        print(paste(unique(cleaned_species), collapse = "_"))
        
        records_page$species <- paste(unique(cleaned_species), collapse = "_")
        write.csv(records_page, records_pages[j], row.names = FALSE)
        
        # Subset dataframe for matching records
        df_map_name <- subset(df, grepl(basename(map_name), File))
        
        # Update species based on template matches
        for (i in seq_len(nrow(df_map_name))) {
          tmpl <- df_map_name$template[i]
          letter <- substr(tmpl, 1, 1)
          matched_species <- cleaned_species[letter]
          if (!is.na(matched_species)) {
            df$species[df$ID == df_map_name$ID[i]] <- matched_species
          } else {
            df$species[df$ID == df_map_name$ID[i]] <- paste(unique(cleaned_species), collapse = "_")
          }
        }
        
        # Remove any double underscores from the species names
        df$species <- gsub("__", "_", df$species)
        
        # Update results string
        results <- paste0(results, "<br>", map_name, ";", species)
        print(paste("Updated species for map:", map_name))
      }
    }
    
    # Save the final DataFrames to the CSV files
    write.csv(df, csv_file_path_type, row.names = FALSE)
    
    cat("CSV files have been updated for map type", map_type, "\n")
  }
  
  cat("All CSV files have been updated.\n")
  print("END")
  
  return(results)
}

# Call the function with specified arguments
