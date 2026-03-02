library(dplyr)

spatialRealCoordinats <- function(outDir){
  
  # Einlesen der Dateien
  df_spatial <- read.csv(file.path(outDir,"spatial_final_data.csv"), sep = ";", header = TRUE)
  df_centroids <- read.csv(file.path(outDir,"polygonize/csvFiles/centroids_colors_pf.csv"))
  
  # Konvertiere ggf. , zu . in Koordinaten
  df_spatial$X_WGS84 <- as.numeric(gsub(",", ".", df_spatial$X_WGS84))
  df_spatial$Y_WGS84 <- as.numeric(gsub(",", ".", df_spatial$Y_WGS84))
  
  # Neue Funktion, die auch Local_X, Local_Y zurückgibt
  find_best_match <- function(file, x, y) {
    subset <- df_centroids[df_centroids$File == file, ]
    if (nrow(subset) == 0 || is.na(x) || is.na(y)) {
      return(c(NA, NA, NA, NA))
    }
    dists <- sqrt((subset$Local_X - x)^2 + (subset$Local_Y - y)^2)
    best <- subset[which.min(dists), ]
    return(c(best$Real_X, best$Real_Y, best$Local_X, best$Local_Y))
  }
  
  # Anwenden
  matches <- mapply(find_best_match, 
                    df_spatial$File, 
                    df_spatial$X_WGS84, 
                    df_spatial$Y_WGS84)
  
  # Neue Spalten hinzufügen
  df_spatial$Real_X <- matches[1, ]
  df_spatial$Real_Y <- matches[2, ]
  df_spatial$Local_X <- matches[3, ]
  df_spatial$Local_Y <- matches[4, ]
  
  # Ergebnis speichern
  write.csv2(df_spatial, file.path(outDir,"spatial_final_data_with_realXY.csv"), row.names = FALSE, sep = ";")
  
  
}
spatialFinalData <- function(outDir){
  # Datei einlesen
  spatial_final_data_path <- file.path(outDir, "spatial_final_data.csv")
  spatial_final_data <- read.csv2(spatial_final_data_path, stringsAsFactors = FALSE, sep = ";")
  
  # Alle CSV-Dateien im Verzeichnis pagerecords einlesen save as pagerecords.csv
  
  
  #######
  csv_files <- list.files(file.path(outDir,"pagerecords"), pattern = "\\.csv$", full.names = TRUE)
  outputFile <- file.path(outDir,"pagerecords.csv")
  
  # Leere Liste zum Speichern der DataFrames
  data_list <- list()
  
  for (file in csv_files) {
    df <- read.csv(file, stringsAsFactors = FALSE, sep = ",")
    
    # Falls die Datei leer ist, überspringen
    if (nrow(df) == 0) next
    
    # Neue Spalte `File` mit dem Basename von `map_name` hinzufügen
    if ("map_name" %in% colnames(df)) {
      df$File <- basename(df$map_name)
    } else {
      df$File <- NA  # Falls `map_name` fehlt, setzen wir `NA`
    }
    
    # DataFrame zur Liste hinzufügen
    data_list[[length(data_list) + 1]] <- df
  }
  
  # Alle DataFrames zu einem kombinieren
  if (length(data_list) > 0) {
    final_df <- bind_rows(data_list)
    
    # Speichern als CSV
    write.csv(final_df, outputFile, row.names = FALSE, sep = ";", quote = FALSE, fileEncoding = "UTF-8")
    
    print(paste("✅ Alle Dateien wurden erfolgreich kombiniert und gespeichert unter:", outputFile))
  } else {
    print("⚠️ Keine CSV-Dateien gefunden oder alle Dateien waren leer.")
  }
  
}


mergeFinalData <- function(workingDir, outDir, nMapTypes = 1){
  
  library(dplyr)
  
  for(i in seq_len(nMapTypes)){
    
    mapDir <- file.path(outDir, i)
   # workingDir <- "D:/distribution_digitizer" 
   # mapDir <- "D:/test/output_2026-02-20_08-40-28/1"
    if(!dir.exists(mapDir)) next
    
    tryCatch({
      
      # ---------------------------------------
      # CSV Pfade
      # ---------------------------------------
      csv_path1 <- file.path(mapDir, "maps", "csvFiles", "coordinates.csv")
      csv_path2 <- file.path(mapDir, "polygonize", "csvFiles", "centroids_colors_pf.csv")
      csv_path3 <- file.path(mapDir, "pageSpeciesData.csv")
      
      output_csv_path <- file.path(mapDir, "spatial_final_data.csv")
      
      # ---------------------------------------
      # Einlesen
      # ---------------------------------------
      df1 <- read.csv(csv_path1, stringsAsFactors = FALSE)
      df2 <- read.csv(csv_path2, stringsAsFactors = FALSE)
      df3 <- read.csv(csv_path3, stringsAsFactors = FALSE, sep = ";")
      
      colnames(df1) <- trimws(colnames(df1))
      colnames(df2) <- trimws(colnames(df2))
      colnames(df3) <- trimws(colnames(df3))
      
      # ---------------------------------------
      # Species bereinigen
      # ---------------------------------------
      df1$species <- gsub("_$", "", df1$species)
      df3$species <- gsub("_$", "", df3$species)
      
      # File normalisieren
      df1$File <- gsub("\\\\", "/", df1$File)
      df3$File <- gsub("\\\\", "/", df3$File)
      
      # ---------------------------------------
      # 1️⃣ Merge df1 + df2 (Real Koordinaten)
      # ---------------------------------------
      df_merged <- df1 %>%
        left_join(
          df2 %>% select(File, Red, Green, Blue, Local_X, Local_Y, Real_X, Real_Y),
          by = c("File", "Red", "Green", "Blue")
        )
      
      # ---------------------------------------
      # 2️⃣ Merge mit df3 (Title)
      # ---------------------------------------
      df3 <- df3 %>%
        rename(
          Title   = species,
          species = search_specie
        ) %>%
        mutate(
          File = basename(file_name)
        )
      
      # ---------------------------------------
      # 3️⃣ Nur point_filtering behalten
      # ---------------------------------------
      df_merged <- df_merged %>%
        filter(Detection.method == "point_filtering")
      
      # ---------------------------------------
      # Speichern
      # ---------------------------------------
      write.csv2(
        df_merged,
        output_csv_path,
        row.names = FALSE,
        quote = FALSE
      )
      
      cat("✅ Map", i, "erfolgreich gemerged\n")
      
    },
    error = function(e){
      print(e)
    },
    finally = {
      cat("Successfully executed\n")
    })
  }
}



# Aufrufen der Funktion mit den angegebenen Arbeitsverzeichnissen
workingDir <- "D:/distribution_digitizer"
outDir <- "D:/test/output_2026-02-20_08-40-28/"
mergeFinalData(workingDir, outDir, 2)
