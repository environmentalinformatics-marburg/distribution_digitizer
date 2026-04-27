
library(dplyr)
library(stringr)



merge_all_maps <- function(outDir, nMapTypes){
  
  for(i in 1:nMapTypes){
    
    mapDir <- file.path(outDir, as.character(i))
    
    cat("➡️ Processing:", mapDir, "\n")
    
    tryCatch({
      add_species_title_safe(
        mapDir = mapDir
      )
      
    }, error = function(e){
      cat("❌ Error in map", i, ":\n")
      print(e$message)
      cat("➡️ Skipping map", i, "\n")
    })
  }
}

add_species_title_safe <- function(mapDir){
  
  file_points  <- file.path(mapDir, "polygonize/csvFiles/centroids_colors_pf.csv")
  file_species <- file.path(mapDir, "pageSpeciesData.csv")
  file_output  <- file.path(mapDir, "spatial_data_final.csv")
  
  # 🔴 Pflichtdatei prüfen
  if(!file.exists(file_points)){
    stop(paste("❌ File not found:", file_points))
  }
  
  cat("➡️ Processing:", mapDir, "\n")
  
  # 🔹 Punkte laden
  df_points <- read.csv(
    file_points,
    stringsAsFactors = FALSE
  )
  
  # 🔹 Vorbereitung Punkte
  df_points$file_base <- basename(df_points$File)
  df_points$species   <- tolower(df_points$specie)
  df_points$title     <- NA   # ← immer initialisieren
  
  # 🔹 Optional: Species laden
  df_species <- NULL
  
  if(file.exists(file_species)){
    
    cat("📄 pageSpeciesData gefunden\n")
    
    df_species <- read.csv2(
      file_species,
      stringsAsFactors = FALSE
    )
    
    # Vorbereitung
    df_species$map_name       <- basename(df_species$map_name)
    df_species$search_specie  <- tolower(df_species$search_specie)
    
  } else {
    cat("⚠️ pageSpeciesData fehlt → Titel bleiben NA\n")
  }
  
  # 🔥 Matching (nur wenn vorhanden)
  if(!is.null(df_species)){
    
    for(i in 1:nrow(df_points)){
      
      file_i    <- df_points$file_base[i]
      species_i <- df_points$species[i]
      
      match_row <- df_species[
        df_species$map_name == file_i &
          df_species$search_specie == species_i,
      ]
      
      if(nrow(match_row) > 0){
        df_points$title[i] <- match_row$species[1]
      }
    }
  }
  
  # 🔹 Debug
  cat("Titel gefunden:", sum(!is.na(df_points$title)), "\n")
  cat("Ohne Titel:", sum(is.na(df_points$title)), "\n")
  
  # ✅ IMMER schreiben
  write.csv(
    df_points,
    file_output,
    row.names = FALSE
  )
  
  cat("✅ spatial_data_final.csv erstellt\n\n")
}

add_species_title <- function(mapDir){
  
  file_points <- file.path(mapDir, "polygonize/csvFiles/centroids_colors_pf.csv")
  file_species <- file.path(mapDir, "pageSpeciesData.csv")
  
  file_output <- file.path(mapDir, "spatial_data_final.csv")  # ← NEU
  
  if(!file.exists(file_points)){
    stop(paste("File not found:", file_points))
  }
  
  if(!file.exists(file_species)){
    stop(paste("File not found:", file_species))
  }
  
  cat("➡️ Adding species titles for:", mapDir, "\n")
  
  df_points <- read.csv(
    file_points,
    stringsAsFactors = FALSE
  )
  
  df_species <- read.csv2(
    file_species,
    stringsAsFactors = FALSE
  )
  
  # 🔹 Vorbereitung
  df_points$file_base <- basename(df_points$File)
  df_points$species <- tolower(df_points$specie)  # ← wichtig
  
  df_species$map_name <- basename(df_species$map_name)
  df_species$search_specie <- tolower(df_species$search_specie)
  
  df_points$title <- NA
  
  # 🔥 Matching
  for(i in 1:nrow(df_points)){
    
    file_i <- df_points$file_base[i]
    species_i <- df_points$species[i]
    
    match_row <- df_species[
      df_species$map_name == file_i &
        df_species$search_specie == species_i,
    ]
    
    if(nrow(match_row) > 0){
      df_points$title[i] <- match_row$species[1]
    } else {
      df_points$title[i] <- NA
    }
  }
  
  # 🔹 Debug
  cat("Titel gefunden:", sum(!is.na(df_points$title)), "\n")
  cat("Ohne Titel:", sum(is.na(df_points$title)), "\n")
  
  # ✅ Neue Datei schreiben
  write.csv(
    df_points,
    file_output,
    row.names = FALSE
  )
  
  cat("✅ spatial_data_final.csv erstellt\n")
}




# Aufrufen der Funktion mit den angegebenen Arbeitsverzeichnissen
#workingDir <- "D:/distribution_digitizer"
#outDir <- "D:/test/output_2026-03-26_11-00-43/"
#spatialFinalData(outDir)
#for(i in 1:2){
# mapDir <- file.path(outDir, i)
#merge_spatial_custom(mapDir)
#}
