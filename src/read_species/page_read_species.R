os <- import("os") 
library(stringr)
# Lade das dplyr-Paket
library(dplyr)


#workingDir="D:/distribution_digitizer"
# Function to read the species
readPageSpecies <- function(workingDir) {
  
  # Definiere einen leeren Datenrahmen (DataFrame)
  pageSpeciesData <- data.frame(species = character(), page_name = character(), map_name = character(), stringsAsFactors = FALSE)
 
  # Speichere den leeren Datenrahmen in eine CSV-Datei
  recordsResultPath = paste0(workingDir, "/data/output/pageSpeciesData.csv")
  write.csv(pageSpeciesData, file = recordsResultPath, row.names = TRUE)
  
  
  # Setze den Pfad zum Ordner, der die CSV-Dateien enthält
  folder_path <- paste0(workingDir, "/data/output/pagerecords/")
  
  # Liste aller CSV-Dateien im Ordner
  file_list <- list.files(path = folder_path, pattern = "\\.csv", full.names = TRUE)
  
  # Initialisiere ein leeres Dataframe
  combined_data <- data.frame()
  
  # Iteriere durch jede CSV-Datei und füge sie dem kombinierten Dataframe hinzu
  for (file_path in file_list) {
    # Lese die CSV-Datei ein
    current_data <- read.csv(file_path)
    
    # Füge die Daten dem kombinierten Dataframe hinzu
    combined_data <- rbind(combined_data, current_data)
  }
  
  # Identifiziere die duplizierten Zeilen basierend auf der Spalte "species"
  duplicated_rows <- duplicated(combined_data$species)
  
  # Wähle die nicht duplizierten Zeilen aus
  filteredData <- combined_data[!duplicated_rows, ]
  
  source_python(paste0(workingDir, "/src/read_species/page_crop_species.py"))

  for (i in 1:nrow(filteredData)) {
    #if(filteredData[i,"pageName"] == "004.tif"){
      pagePath = filteredData[i,"file_name"]
      print(pagePath)
      speciesData =  filteredData[i,"species"]
      
      # String an Leerzeichen splitten und leere Strings entfernen
      speciesData <- speciesData[speciesData != ""]
      print(speciesData)

      #pagePath = "D:/distribution_digitizer/data/input/pages/0064.tif"
      #speciesData = "_danna"
      pageTitleSpecies = mainPageCropSpecies(pagePath, speciesData)

      # Alle nicht-alfanumerischen Zeichen am Ende jeder Zeichenkette entfernen
      #pageTitleSpecies <- gsub("[^[:alnum:]]*$", "", pageTitleSpecies)
      
      # Ergebnis anzeigen
      # Identifiziere die duplizierten Zeilen basierend auf der Spalte "species"
      # String nach "-" splitten
      #pageTitleSpecies <- strsplit(pageTitleSpecies, ",")
      
      # Gesplittete Liste ohne Duplikate und Reihenfolge beibehalten
      # Gesplittete Liste ohne Duplikate
      
      # Doppelte Einträge entfernen
      #gesplittete_array_ohne_duplikate <- unique(pageTitleSpecies)
      
      gesplittete_array_ohne_duplikate <- unique(unlist(pageTitleSpecies))
      
      gesplittete_array_ohne_duplikate <- gesplittete_array_ohne_duplikate[!grepl("distribution", gesplittete_array_ohne_duplikate, ignore.case = TRUE)]
      
      #gesplittete_array_ohne_duplikate <- lapply(pageTitleSpecies, function(x) unlist(strsplit(x, ";")))
      
      # Datenrahmen erstellen
      #new_dataframe <- data.frame(matrix(unlist(gesplittete_array_ohne_duplikate), ncol = length(gesplittete_array_ohne_duplikate), byrow = TRUE))
      
      split_entries <- strsplit(gesplittete_array_ohne_duplikate, "; ")
      
      # Extrahieren Sie den Teil nach dem Semikolon und speichern Sie ihn in einem neuen Array
      new_array <- sapply(split_entries, function(x) x[2])
      
      
      # Verbinden Sie die Elemente des neuen Arrays zu einem einzelnen String
      result_string <- paste(new_array, collapse = " ")
      
      new_dataframe <- data.frame(species = result_string, stringsAsFactors = FALSE)
      
      # Neue Spalte für den Dateinamen hinzufügen
      new_dataframe$file_name <- pagePath
      
      # Neue Spalte für den Dateinamen hinzufügen
      new_dataframe$map_name <- filteredData[i,"map_name"]
      
      # Datenrahmen in CSV speichern
      write.table(new_dataframe, file = paste0(workingDir, "/ausgabe.csv"), sep = ";", row.names = FALSE, col.names = TRUE, append = TRUE)
      
      # Das Ergebnis ausgeben
      #print(gesplittete_array_ohne_duplikate)
      # Jeden String im Array nach "-" splitten
      # Funktion zum Splitten eines Strings nach "-"
      
   }
      
      
      print(pageTitleSpecies)
  
      
      # Füge neue Zeilen hinzu
      #neueZeile <- c(speciesData, newPageName)
      #pageSpeciesData <- rbind(pageSpeciesData, neueZeile)
      #print(pageTitleSpecies)
      #myData <- data.frame(species=pageTitleSpecies,stringsAsFactors = FALSE)
   # }
  }





