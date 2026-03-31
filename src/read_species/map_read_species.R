# Required libraries
library(tesseract)
library(stringr)


clean_species <- function(species) {
  species <- gsub("_", "", species)  # Entferne alle Unterstriche
  species <- trimws(species)         # Entferne führende und nachfolgende Leerzeichen
  return(species)
}

# Call the function with specified arguments
# Function to read the species
read_legends <- function(working_dir, out_dir, nMapTypes = 1) {
  
  results <- "The following species were found: "
  print("Read start")
  # Source Python script for additional processing if needed
  source_python(file.path(working_dir, "src/read_species/map_crop_species.py"))
  
  # --- NEU: über Map-Typen (1..nMapTypes) iterieren ---
  for (type_id in seq_len(as.integer(nMapTypes))) {
    print("Read start 2")
    out_dir_type <- file.path(out_dir, as.character(type_id))
    
    # Directory setup (pro Typ!)
    pagerecords <- file.path(out_dir_type, "pagerecords")
    records_pages <- list.files(path = pagerecords, pattern = ".csv", full.names = TRUE, recursive = TRUE)
    csv_file_path <- file.path(out_dir_type, "maps", "csvFiles", "coordinates.csv")
    
    # Falls es den Typ-Ordner nicht gibt oder keine Seiten-CSV vorhanden sind: skip
    if (!dir.exists(out_dir_type)) next
    if (!dir.exists(pagerecords) || length(records_pages) == 0) next
    if (!file.exists(csv_file_path)) next
    
    # Load the CSV file once at the beginning (pro Typ!)
    df <- read.csv(csv_file_path, stringsAsFactors = FALSE)
    
    # Initialize the species column
    df$species <- NA
    df$legende <- NA
    symbol_dir <- file.path(
      working_dir,
      "data", "input", "templates",
      as.character(type_id),
      "symbols"
    )
    
    symbol_list <- list.files(
      symbol_dir,
      pattern = "\\.tif$",
      full.names = TRUE
    )
    print(symbol_list)
    legend_list = c("distribution of", "type locality of")
    # Process each records page
    for (j in seq_along(records_pages)) {  
      records_page <- read.csv(records_pages[j], sep = ",", check.names = FALSE, quote = "\"", na.strings = c("NA", "NaN", " "))
      file_name <- records_page$file_name
      map_name <- records_page$map_name
      print(records_page)
      if (!is.na(records_page$y[1]) && !is.na(records_page$h[1])) {
        # Extract species information
        
        species <- crop_specie(working_dir, out_dir_type, file_name, map_name,
                               as.integer(records_page$y[1]), as.integer(records_page$h[1]),legend_list=legend_list,  symbol_list = symbol_list)   # 🔥 NEU symbol_list legend_list
        print("Here the specie:")
        print(species)
        
        results <- paste0(results, "<br>", map_name, ";", species)
        
        # Remove leading underscore and split species string into components
        species <- sub("^_", "", species)
      
        
        # Split species string into components
        species_list <- str_split(species, "_")[[1]]
        #print(species_list)
        
        # Function to clean species names
        clean_species <- function(species) {
          species <- gsub("\\d", "", species)  # Remove digits
          species <- gsub("X.*", "", species)  # Remove everything after 'S'
          species <- gsub("_", "", species)
          return(species)
        }
        
        # Clean species names
        cleaned_species <- sapply(species_list, clean_species)
        print(cleaned_species)
        
        # Create a named vector of cleaned species
        names(cleaned_species) <- sapply(species_list, function(x) sub(".*S", "", x))
        
        #print(paste(unique(cleaned_species), collapse = "_"))
        #records_page$species <- paste(unique(cleaned_species), collapse = "_")
        
        # Duplicate species names are allowed
        records_page$species <- paste(cleaned_species, collapse = "_")
        write.csv(records_page, records_pages[j], row.names = FALSE)
        
        # Subset dataframe for matching records
        df_map_name <- subset(df, grepl(basename(map_name), File))
        # 🔴 WICHTIG: komplette Legende speichern
        if (nrow(df_map_name) > 0) {
          df$legende[df$ID %in% df_map_name$ID] <- species
        }
        
        # Update species based on template matches
        for (i in seq_len(nrow(df_map_name))) {
          
          row_id <- df_map_name$ID[i]
          tmpl   <- df_map_name$template[i]
          
          # 👉 Farbe aus template
          color <- tolower(sub("_.*", "", tmpl))
          
          # 👉 legend string
          legend_str <- species
          
          parts <- str_split(legend_str, "_")[[1]]
          
          found_species <- NA
          
          for (p in parts) {
            
            if (p == "") next
            
            # species
            sp <- sub("X.*", "", p)
            
            # color extrahieren (zwischen Y und Y1)
            col <- str_split(p, "Y")[[1]][2]
            col <- gsub("\\d+", "", col)
            col <- tolower(col)
            
            if (col == color) {
              found_species <- sp
              break
            }
          }
          
          # 👉 FALL 1: Treffer
          if (!is.na(found_species)) {
            df$species[df$ID == row_id] <- found_species
            
          } else {
            # 👉 FALL 2: KEIN Treffer → alle speichern (wie vorher)
            df$species[df$ID == row_id] <- paste(unique(cleaned_species), collapse = "_")
          }
        }
        
        # Remove any double underscores from the species names
        df$species <- gsub("__", "_", df$species)
        
        # Update results string
        results <- paste0(results, "<br>", map_name, ";", species)
        print(paste("Updated species for map:", map_name))
      }
    }
    
    # Save the final DataFrames to the CSV files (pro Typ!)
    write.csv(df, csv_file_path, row.names = FALSE)
  }
  
  cat("CSV files have been updated.\n")
  print("END")
  
  return(results)
}
