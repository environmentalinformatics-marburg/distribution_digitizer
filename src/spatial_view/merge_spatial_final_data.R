library(dplyr)

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
