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

mergeFinalData <- function(workingDir, outDir) {
  tryCatch(
    {
      # Pfade zu den CSV-Dateien
      csv_path1 <- file.path(outDir, "maps", "csvFiles", "coordinates.csv")
      csv_path2 <- file.path(outDir, "polygonize", "csvFiles", "centroids_colors_pf.csv")
      csv_path3 <- file.path(outDir, "pageSpeciesData.csv")
      
      output_csv_path <- file.path(outDir, "spatial_final_data.csv")
      
      # CSV-Dateien einlesen
      df1 <- read.csv(csv_path1, stringsAsFactors = FALSE, sep = ",")
      df2 <- read.csv(csv_path2, stringsAsFactors = FALSE, sep = ",")
      df3 <- read.csv(csv_path3, stringsAsFactors = FALSE, sep = ";")
      
      # Überprüfe Spaltennamen
      colnames(df1) <- trimws(colnames(df1))
      colnames(df3) <- trimws(colnames(df3))
      
      # Korrigiere die Spaltennamen in df3
      df3 <- df3 %>%
        rename(Title = species, species = search_specie) %>%
        mutate(File = basename(map_name))  # Basename aus `map_name`
      
      df1$Title <- sapply(df1$Title, function(x) {
        if (!is.na(x)) {
          unique_titles <- unique(unlist(strsplit(x, ";\\s*")))  # Splitten und doppelte entfernen
          unique_titles <- unique_titles[unique_titles != ""]  # Leere Strings entfernen
          
          # Entferne "NA", wenn andere Werte existieren
          if ("NA" %in% unique_titles & length(unique_titles) > 1) {
            unique_titles <- setdiff(unique_titles, "NA")
          }
          
          return(paste(unique_titles, collapse = " "))  # Zusammenfügen mit Leerzeichen
        } else {
          return(NA)
        }
      })
      
      # Bereinige `species` (Entferne `_` am Ende)
      df1$species <- gsub("_$", "", df1$species)
      df3$species <- gsub("_$", "", df3$species)
      
      # Normalisiere `File`-Pfad (ersetze `\` mit `/`)
      df1$File <- gsub("\\\\", "/", df1$File)
      df3$File <- gsub("\\\\", "/", df3$File)
      
      # Titel-Informationen aus point_matching extrahieren
      title_mapping <- unique(df1[df1$Detection.method == "point_matching", c("File", "species", "Title")])
      
      # Title für point_filtering-Zeilen aktualisieren, falls File und species übereinstimmen
      df1$Title <- sapply(1:nrow(df1), function(i) {
        if (df1$Detection.method[i] == "point_filtering") {
          match_row <- title_mapping[title_mapping$File == df1$File[i] & title_mapping$species == df1$species[i], "Title"]
          if (length(match_row) > 0) {
            return(match_row[1])  # Den gefundenen Titel übernehmen
          }
        }
        return(df1$Title[i])  # Andernfalls den bestehenden Wert beibehalten
      })
      # Nur "point_filtering"-Einträge in df1 behalten
      df1 <- df1 %>% filter(Detection.method == "point_filtering")
      
      print("Merging Title von df3 nach df1...")
      
      # Merge: Falls `Title` in df1 leer ist, ersetze es mit df3
      df1 <- df1 %>%
        left_join(df3 %>% dplyr::select(File, species, Title), by = c("File", "species")) %>%
        mutate(Title = ifelse(is.na(Title.x) | Title.x == "", Title.y, Title.x)) %>%
        dplyr::select(-Title.x, -Title.y)  # Entferne doppelte Spalten nach dem Merge
      
      # 🚀 Fix: Entferne "NA;" aus Title-Spalte
      df1$Title <- gsub("^NA;\\s*", "", df1$Title)
      df1$Title <- gsub("^NA$", "", df1$Title)  # Falls nur "NA" als Wert steht
      
      print("Merging abgeschlossen.")
      
      # Speichern der Datei
       write.csv2(df1, output_csv_path,  row.names = FALSE, sep = ";", quote = FALSE, fileEncoding = "UTF-8")
      
      print(paste("Output CSV file created at:", output_csv_path))
      
    }, 
    error = function(e) {
      print(e)
    },
    finally = {
      cat("\nSuccessfully executed")
    }
  )
}




# Aufrufen der Funktion mit den angegebenen Arbeitsverzeichnissen
#workingDir <- "D:/distribution_digitizer"
#outDir <- "D:/test/output_2025-02-28_12-05-28/"
#mergeFinalData(workingDir, outDir)
