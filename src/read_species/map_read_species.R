# Author: [Spaska Forteva]
# Created On: 2023-11-18
# Description: This script automatically processes CSV records to update species information based on map data.
# Last change: July 10, 2024

# Required libraries
library(tesseract)
library(stringr)

# Function to read the species
read_legends <- function(working_dir, out_dir) {
  
  results <- "The following species were found: "
  
  # Source Python script for additional processing if needed
  source_python(file.path(working_dir, "src/read_species/map_crop_species.py"))
  
  # Directory setup
  pagerecords <- file.path(out_dir, "pagerecords")
  records_pages <- list.files(path = pagerecords, pattern = ".csv", full.names = TRUE, recursive = TRUE)
  csv_file_path <- "D:/test/output_2024-07-10_15-36-42/maps/csvFiles/coordinates.csv"
  csv_file_path <-file.path(out_dir, "maps", "csvFiles", "coordinates.csv")
  # Load the CSV file once at the beginning
  df <- read.csv(csv_file_path, stringsAsFactors = FALSE)
  
  # Initialize the species column
  df$species <- NA
  
  # Process each records page
  for (j in seq_along(records_pages)) {
    records_page <- read.csv(records_pages[j], sep = ",", check.names = FALSE, quote = "\"", na.strings = c("NA", "NaN", " "))
    file_name <- records_page$file_name
    map_name <- records_page$map_name
    
    if (!is.na(records_page$y[1]) && !is.na(records_page$h[1])) {
      # Extract species information
      species <- crop_specie(working_dir, out_dir, file_name, map_name, as.integer(records_page$y[1]), as.integer(records_page$h[1]))
      
      species <- gsub("^_", "", species)
      species_filtering <- species
      species <- gsub("distribution", "", unlist(strsplit(species, "_")))
      
      # Subset dataframe for matching records
      df_map_name <- subset(df, grepl(basename(map_name), File))
      df_matching <- subset(df_map_name, Detection.method == "point_matching")

      # Mapping of template letters to species
      template_to_species <- list(a = species[1], b = species[2], c = species[3], d = species[4], e = species[5])
      
      # Update species based on template matches
      for (i in seq_len(nrow(df_matching))) {
        tmpl <- df_matching$template[i]
        letter <- substr(tmpl, 1, 1)
        if (letter %in% names(template_to_species)) {
          species_index <- which(names(template_to_species) == letter)
          df$species[df$ID == df_matching$ID[i]] <- species[species_index]
        }
      }
      
      # Update df_filtering
      df_filtering <- subset(df_map_name, Detection.method == "point_filtering")
  
      if (nrow(df_filtering) > 0) {
        df_filtering$species <- species_filtering
        # Weitere Verarbeitung hier...
      } else {
        cat("Keine Zeilen mit Detection.method == 'point_filtering' gefunden.\n")
      }
      
      df[df$ID %in% df_filtering$ID, "species"] <- df_filtering$species

      # Update df_circle
      df_circle <- subset(df_map_name, Detection.method == "circle_detection")
      if (nrow(df_circle) > 0) {
        df_circle$species <- species_filtering
        # Weitere Verarbeitung hier...
      } else {
        cat("Keine Zeilen mit Detection.method == 'circle_detection' gefunden.\n")
      }
      df[df$ID %in% df_circle$ID, "species"] <- df_circle$species
      
      # Update results string
      results <- paste0(results, "<br>", map_name, ";", species)
      print(paste("Updated species for map:", map_name))
      #print(df)
    }
    
    # Additional actions or results storage can be implemented here as needed
    
  }
  
  # Save the final DataFrame to the CSV file
  write.csv(df, csv_file_path, row.names = FALSE)
  
  cat("CSV file has been updated.\n")
  print("END")
  
  return(results)
}
