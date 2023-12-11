os <- import("os") 
library(stringr)
# Lade das dplyr-Paket
library(dplyr)


workingDir="D:/distribution_digitizer"
# Function to read the species
readPageSpecies <- function(workingDir) {
  
  # Definiere einen leeren Datenrahmen (DataFrame)
  pageSpeciesData <- data.frame(species = character(), pageName = character(), stringsAsFactors = FALSE)
 
  # Speichere den leeren Datenrahmen in eine CSV-Datei
  recordsResultPath = paste0(workingDir, "/data/output/pageSpeciesData.csv")
  write.csv(pageSpeciesData, file = recordsResultPath, row.names = TRUE)
  
  
  # Define the file path for the new CSV file
  recordsPath = paste0(workingDir, "/data/output/records_species.csv")
  recordsSpeciesData <- read.csv(recordsPath, sep=";", check.names = FALSE, quote="\"",
                          na.strings=c("NA","NaN", " "))
  
  # Identifiziere die duplizierten Zeilen basierend auf der Spalte "species"
  duplicated_rows <- duplicated(recordsSpeciesData$species)
  
  # Wähle die nicht duplizierten Zeilen aus
  filteredData <- recordsSpeciesData[!duplicated_rows, ]
  
  source_python(paste0(workingDir, "/src/read_species/page_crop_species.py"))

  for (i in 1:nrow(filteredData)) {
    #if(filteredData[i,"pageName"] == "004.tif"){
      pagePath = paste0('D:/distribution_digitizer/data/input/pages/' ,filteredData[i,"pageName"])
      print(pagePath)
      speciesData =  filteredData[i,"species"]
      
      # String an Leerzeichen splitten und leere Strings entfernen
      speciesData <- speciesData[speciesData != ""]
      print(speciesData)

      pageTitleSpecies = mainPageCropSpecies(pagePath,speciesData)

      # Alle nicht-alfanumerischen Zeichen am Ende jeder Zeichenkette entfernen
      #pageTitleSpecies <- gsub("[^[:alnum:]]*$", "", pageTitleSpecies)
      
      # Ergebnis anzeigen
      # Identifiziere die duplizierten Zeilen basierend auf der Spalte "species"
      # String nach "-" splitten
      #pageTitleSpecies <- strsplit(pageTitleSpecies, ",")
      
      # Gesplittete Liste ohne Duplikate und Reihenfolge beibehalten
      # Gesplittete Liste ohne Duplikate
      
      # Doppelte Einträge entfernen
      gesplittete_array_ohne_duplikate <- unique(pageTitleSpecies)
      
      gesplittete_array_ohne_duplikate <- lapply(pageTitleSpecies, function(x) unlist(strsplit(x, ";")))
      
      # Datenrahmen erstellen
      datenrahmen <- data.frame(matrix(unlist(gesplittete_array_ohne_duplikate), ncol = length(gesplittete_array_ohne_duplikate), byrow = TRUE))
      
      # Neue Spalte für den Dateinamen hinzufügen
      datenrahmen$Dateiname <- rep(pagePath, nrow(datenrahmen))
      
      # Neue Spalte für den Dateinamen hinzufügen
      datenrahmen$mapName <- rep(filteredData[i,"mapName"], nrow(datenrahmen))
      
      # Datenrahmen in CSV speichern
      write.table(datenrahmen, file = paste0(workingDir, "/ausgabe.csv"), sep = ",", row.names = FALSE, col.names = FALSE, append = TRUE)
      # Das Ergebnis ausgeben
      print(gesplittete_array_ohne_duplikate)
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
}





