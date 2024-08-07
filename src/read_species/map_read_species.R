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
      print("Here the specie:")
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
      
      # Function to clean species names
      clean_species <- function(species) {
        species <- gsub("\\d", "", species)  # Remove digits
        species <- gsub("S.*", "", species)  # Remove everything after 'S'
        return(species)
      }
      
      # Clean species names
      cleaned_species <- sapply(species_list, clean_species)
      print(cleaned_species)
      
      # Create a named vector of cleaned species
      names(cleaned_species) <- sapply(species_list, function(x) sub(".*S", "", x))
      print(names(cleaned_species))
      
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
  write.csv(df, csv_file_path, row.names = FALSE)
  
  cat("CSV files have been updated.\n")
  print("END")
  
  return(results)
}

# Call the function with specified arguments
