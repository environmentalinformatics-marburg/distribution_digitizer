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
  csv_file_path <- file.path(out_dir, "maps", "csvFiles", "coordinates.csv")
  csv_file_path_transformed <- file.path(out_dir, "coordinates_transformed.csv")
  
  # Load the CSV file once at the beginning
  df <- read.csv(csv_file_path, stringsAsFactors = FALSE)
  df_transformed <- read.csv(csv_file_path_transformed, stringsAsFactors = FALSE)
  
  # Initialize the species column
  df$species <- NA
  df_transformed$species <- NA
  
  # Process each records page
  for (j in seq_along(records_pages)) {
    records_page <- read.csv(records_pages[j], sep = ",", check.names = FALSE, quote = "\"", na.strings = c("NA", "NaN", " "))
    file_name <- records_page$file_name
    map_name <- records_page$map_name
    
    if (!is.na(records_page$y[1]) && !is.na(records_page$h[1])) {
      # Extract species information
      species <- crop_specie(working_dir, out_dir, file_name, map_name, as.integer(records_page$y[1]), as.integer(records_page$h[1]))
      
      print(species)
      records_page$species <- species
      write.csv(records_page, records_pages[j], row.names = FALSE)
      results <- paste0(results, "<br>", map_name, ";", species)
      
      # Remove leading underscore and split species string into components
      species <- sub("^_", "", species)
      species <- gsub("distribution", "", species)
      
      # Split species string into components
      species_list <- str_split(species, "_")[[1]]
      print(species_list)
      # Subset dataframe for matching records
      df_map_name <- subset(df, grepl(basename(map_name), File))
      df_matching <- subset(df_map_name, Detection.method == "point_matching")
      
      # Mapping of template letters to species
      template_to_species <- list(a = species_list[1], b = species_list[2], c = species_list[3], d = species_list[4], e = species_list[5])
      
      # Update species based on template matches
      for (i in seq_len(nrow(df_matching))) {
        tmpl <- df_matching$template[i]
        letter <- substr(tmpl, 1, 1)
        if (letter %in% names(template_to_species)) {
          species_index <- which(names(template_to_species) == letter)
          df$species[df$ID == df_matching$ID[i]] <- species_list[species_index]
        }
      }
      
      # Update df_filtering
      df_filtering <- subset(df_map_name, Detection.method == "point_filtering")
      if (nrow(df_filtering) > 0) {
        for (i in seq_len(nrow(df_filtering))) {
          if (length(species_list) > 1) {
            if (df_filtering$Blue[i] == 255 && df_filtering$Green[i] == 0 && df_filtering$Red[i] == 0) { # Blau
              df_filtering$species[i] <- species_list[1]
            } else if (df_filtering$Blue[i] == 0 && df_filtering$Green[i] == 0 && df_filtering$Red[i] == 255) { # Rot
              df_filtering$species[i] <- species_list[2]
            } else if (df_filtering$Blue[i] == 0 && df_filtering$Green[i] == 255 && df_filtering$Red[i] == 0) { # Grün
              df_filtering$species[i] <- species_list[3]
            } else {
              df_filtering$species[i] <- species
            }
          } else {
            df_filtering$species[i] <- species_list[1]
          }
        }
        df[df$ID %in% df_filtering$ID, "species"] <- df_filtering$species
      } else {
        cat("Keine Zeilen mit Detection.method == 'point_filtering' gefunden.\n")
      }
      
      # Update df_circle
      df_circle <- subset(df_map_name, Detection.method == "circle_detection")
      if (nrow(df_circle) > 0) {
        for (i in seq_len(nrow(df_circle))) {
          if (length(species_list) > 1) {
            if (df_circle$Blue[i] == 255 && df_circle$Green[i] == 0 && df_circle$Red[i] == 0) { # Blau
              df_circle$species[i] <- species_list[1]
            } else if (df_circle$Blue[i] == 0 && df_circle$Green[i] == 0 && df_circle$Red[i] == 255) { # Rot
              df_circle$species[i] <- species_list[2]
            } else if (df_circle$Blue[i] == 0 && df_circle$Green[i] == 255 && df_circle$Red[i] == 0) { # Grün
              df_circle$species[i] <- species_list[3]
            } else {
              df_circle$species[i] <- species
            }
          } else {
            df_circle$species[i] <- species_list[1]
          }
        }
        df[df$ID %in% df_circle$ID, "species"] <- df_circle$species
      } else {
        cat("Keine Zeilen mit Detection.method == 'circle_detection' gefunden.\n")
      }
      
      # Update df_transformed
      for (i in seq_len(nrow(df_transformed))) {
        if (length(species_list) > 1) {
          if (df_transformed$Blue[i] == 255 && df_transformed$Green[i] == 0 && df_transformed$Red[i] == 0) { # Blau
            df_transformed$species[i] <- species_list[1]
          } else if (df_transformed$Blue[i] == 0 && df_transformed$Green[i] == 0 && df_transformed$Red[i] == 255) { # Rot
            df_transformed$species[i] <- species_list[2]
          } else if (df_transformed$Blue[i] == 0 && df_transformed$Green[i] == 255 && df_transformed$Red[i] == 0) { # Grün
            df_transformed$species[i] <- species_list[3]
          } else {
            df_transformed$species[i] <- species
          }
        } else {
          df_transformed$species[i] <- species_list[1]
        }
      }
      
      # Update results string
      results <- paste0(results, "<br>", map_name, ";", species)
      print(paste("Updated species for map:", map_name))
    }
  }
  
  # Save the final DataFrames to the CSV files
  write.csv(df, csv_file_path, row.names = FALSE)
  write.csv(df_transformed, csv_file_path_transformed, row.names = FALSE)
  
  cat("CSV files have been updated.\n")
  print("END")
  
  return(results)
}
