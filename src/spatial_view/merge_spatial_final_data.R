# Funktion zum Mergen der Daten
mergeFinalData <- function(workingDir, outDir) {
  tryCatch(
    {
      # Pfade zu den CSV-Dateien
      csv_path1 <- file.path(outDir, "maps", "csvFiles", "coordinates.csv")
      csv_path2 <- file.path(outDir, "polygonize", "csvFiles", "centroids_colors.csv")
      output_csv_path <- file.path(outDir, "spatial_final_data.csv")
      
      # CSV-Dateien einlesen
      df1 <- read.csv(csv_path1, stringsAsFactors = FALSE)
      df2 <- read.csv(csv_path2, stringsAsFactors = FALSE, sep = ",")
      
      # Farbkombinationen in beiden DataFrames erstellen
      df1$Color_Combo <- paste(df1$Red, df1$Green, df1$Blue, sep = ",")
      df2$Color_Combo <- paste(df2$Red, df2$Green, df2$Blue, sep = ",")
      
      # Zusammenführen der DataFrames basierend auf 'File' und 'Color_Combo'
      merged_df <- merge(df2, df1[, c("File", "Color_Combo", "species", "Title")], 
                         by.x = c("File", "Color_Combo"), by.y = c("File", "Color_Combo"), all.x = TRUE)
      
      # Doppelte Einträge entfernen
      merged_df <- merged_df[!duplicated(merged_df), ]
      
      # Die 'Color_Combo'-Spalte entfernen, da sie nicht mehr benötigt wird
      merged_df$Color_Combo <- NULL
      
      # Die neue CSV-Datei schreiben
      write.csv(merged_df, output_csv_path, row.names = FALSE)
      
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
# workingDir <- "D:/distribution_digitizer"
# outDir <- "D:/test/output_2024-07-12_08-18-21"
# mergeFinalData(workingDir, outDir)
