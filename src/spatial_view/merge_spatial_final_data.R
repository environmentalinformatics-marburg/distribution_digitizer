library(dplyr)

# Funktion zum Mergen der Daten
mergeFinalData <- function(workingDir, outDir) {
  tryCatch(
    {
      # Pfade zu den CSV-Dateien
      csv_path1 <- file.path(outDir, "maps", "csvFiles", "coordinates.csv")
      csv_path2 <- file.path(outDir, "polygonize", "csvFiles", "centroids_colors_pf.csv")
      output_csv_path <- file.path(outDir, "spatial_final_data.csv")
      
      # CSV-Dateien einlesen
      df1 <- read.csv(csv_path1, stringsAsFactors = FALSE)
      df2 <- read.csv(csv_path2, stringsAsFactors = FALSE, sep = ",")
      
      # Filter anwenden: Nur Einträge mit Detection.method == "point_matching"
      df1 <- df1 %>% filter(Detection.method == "point_matching")
      # NA aus Title-Spalten in df1 entfernen
      df1$Title <- gsub("^NA;\\s*", "", df1$Title)
      
      # Farbkombinationen in beiden DataFrames erstellen
      df1$Color_Combo <- paste(df1$Red, df1$Green, df1$Blue, sep = ",")
      df2$Color_Combo <- paste(df2$Red, df2$Green, df2$Blue, sep = ",")
      
      # Zusammenführen der DataFrames basierend auf 'File' und 'Color_Combo'
      merged_df <- merge(df2, df1[, c("File", "Color_Combo", "species", "Title")], 
                         by.x = c("File", "Color_Combo"), by.y = c("File", "Color_Combo"), all.x = TRUE)
      
      # Priorität auf Zeilen mit nicht-leerer Title-Spalte legen und doppelte Einträge entfernen
      merged_df <- merged_df %>%
        arrange(File, ID, Local_X, Local_Y, Real_X, Real_Y, Red, Green, Blue, species, desc(!is.na(Title))) %>%
        distinct(File, ID, Local_X, Local_Y, Real_X, Real_Y, Red, Green, Blue, species, .keep_all = TRUE)
      
      # NA aus Title-Spalten entfernen
      merged_df$Title <- gsub("^NA;\\s*", "", merged_df$Title)
      
      # Die 'Color_Combo'-Spalte entfernen, da sie nicht mehr benötigt wird
      merged_df$Color_Combo <- NULL
      
      # Fehlende Spezies und Titel für Dateien ohne bekannte Farbe ergänzen
      missing_info <- df1 %>%
        filter(File %in% merged_df$File) %>%
        group_by(File) %>%
        summarize(
          species = paste(unique(na.omit(species)), collapse = "_"),
          Title = paste(unique(na.omit(Title)), collapse = "; ")
        )
      
      merged_df <- merged_df %>%
        left_join(missing_info, by = "File", suffix = c("", "_y")) %>%
        mutate(species = ifelse(is.na(species), species_y, species),
               Title = ifelse(is.na(Title), Title_y, Title)) %>%
        dplyr::select(-species_y, -Title_y)  # Verwende dplyr::select
      
      # Doppelte Arten entfernen, die durch das Zusammenfügen entstehen können
      merged_df <- merged_df %>%
        mutate(species = sapply(strsplit(species, "_"), function(x) paste(unique(x), collapse = "_")),
               Title = sapply(strsplit(Title, "; "), function(x) paste(unique(x), collapse = "; ")))
      
      # Die neue CSV-Datei schreiben
      write.csv2(merged_df, output_csv_path, row.names = FALSE)
      
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
#outDir <- "D:/test/output_2024-08-07_15-46-48//"
#mergeFinalData(workingDir, outDir)
