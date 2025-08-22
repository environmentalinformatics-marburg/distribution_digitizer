args <- commandArgs(trailingOnly = TRUE)

args <- commandArgs(trailingOnly = TRUE)

inputDir <- args[1]
outDir   <- args[2]
pageSel  <- ifelse(length(args) >= 3, args[3], "ALL")

cat("📂 Input directory: ", inputDir, "\n")
cat("💾 Output directory:", outDir, "\n")

# Interpretation von pageSel
if (toupper(pageSel) == "ALL") {
  cat("➡️ Processing ALL pages\n")
} else if (grepl("\\.tif$", pageSel, ignore.case = TRUE)) {
  cat("➡️ Processing single page: ", pageSel, "\n")
} else if (grepl("^[0-9]+$", pageSel)) {
  cat("➡️ Processing first ", pageSel, " pages\n")
} else {
  stop(paste("❌ Invalid pageSel argument:", pageSel))
}


cat("➡️ Page selection:  ", pageSel, "\n")

# Beispiel: überschreibe workingDir/outDir mit den Angaben
workingDir <- inputDir
outDir <- outDir
# ---- Config laden ----
config_path <- file.path(inputDir, "config", "config.csv")
if (!file.exists(config_path)) {
  stop(paste("❌ Config file not found:", config_path))
}
config <- read.csv(config_path, header = TRUE, sep = ";")

#######
# Load Required Libraries and Define Paths
#######

library(reticulate)
library(tesseract)
library(dplyr)
library(stringr)
library(leaflet)
library(readr)

#######
# Run Template Matching
#######

fname = paste0(workingDir, "/src/matching/map_matching.py")
print("The processing template matching python script:")
print(fname)
source_python(fname)
print("Threshold:")
print(2)
print(outDir)
#main_template_matching(workingDir, outDir, 0.18, config$sNumberPosition, config$matchingType)

main_template_matching(workingDir, outDir, 0.18, config$sNumberPosition, config$matchingType, pageSel)

#######
# Align Images
#######

fname = paste0(workingDir, "/src/matching/map_align.py")
print("Processing align python script:")
print(fname)
source_python(fname)
align_images_directory(workingDir, outDir)


#######
# Point Matching
#######

fname = paste0(workingDir, "/src/matching/point_matching.py")
print("Processing point python script:")
print(fname)
source_python(fname)
map_points_matching(workingDir, outDir, 0.75)


#######
# Point Filtering
#######

fname = paste0(workingDir, "/src/matching/point_filtering.py")
fname2 = paste0(workingDir, "/src/matching/coords_to_csv.py")
print("Processing point filtering python script:")
print(fname)
source_python(fname)
source_python(fname2)
main_point_filtering(workingDir, outDir, 5, 9)


#######
# Circle Detection
#######

fname = paste0(workingDir, "/src/matching/circle_detection.py")
print("Processing circle detection python script:")
print(fname)
source_python(fname)

# Circle detection parameters
gaussian <- 9L
minDist <- 5L
thresholdEdge <- 50L
thresholdCircles <- 30L
minRadius <- 10L
maxRadius <- 40L

mainCircleDetection(workingDir, outDir, gaussian, minDist, thresholdEdge, thresholdCircles, minRadius, maxRadius)


#######
# Create Geomasks
#######

# Normal mask
fname = paste0(workingDir, "/src/masking/masking.py")
print("Processing normal masking python script:")
print(fname)
source_python(fname)
mainGeomask(workingDir, outDir, 5L)

# Black mask
fname = paste0(workingDir, "/src/masking/creating_masks.py")
print("Processing black masking python script:")
print(fname)
source_python(fname)
mainGeomaskB(workingDir, outDir, 5L)

# Mask Centroids
fname = paste0(workingDir, "/src/masking/mask_centroids.py")
print("Processing masking centroids python script:")
print(fname)
source_python(fname)
MainMaskCentroids(workingDir, outDir)



#######
# Crop Species Names from Map
#######

fname <- paste0(workingDir, "/src/read_species/map_read_species.R")
print("Cropping the species names from the map using R script:")
print(fname)
source(fname)
species <- read_legends(workingDir, outDir)
cat("\nSuccessfully executed")


#######
# Read Page Titles and Species Info
#######

fname <- paste0(workingDir, "/src/read_species/page_read_species.R")
print(paste0("Reading page species data and saving the results to a 'pageSpeciesData.csv' file in the ", outDir, " directory"))
source(fname)

if (length(config$keywordReadSpecies) > 0) {
  species <- readPageSpecies(workingDir, outDir, config$keywordReadSpecies, config$keywordBefore, config$keywordThen, config$middle)
} else {
  species <- readPageSpecies(workingDir, outDir, 'None', config$keywordBefore, config$keywordThen, config$middle)
}


#######
# Georeferencing
#######

fname = paste0(workingDir, "/src/georeferencing/mask_georeferencing.py")
print("Processing georeferencing python script:")
print(fname)
source_python(fname)
mainmaskgeoreferencingMasks_PF(workingDir, outDir)


#######
# Rectifying
#######

fname = paste0(workingDir, "/src/polygonize/rectifying.py")
print("Processing rectifying python script:")
print(fname)
source_python(fname)
mainRectifying_PF(workingDir, outDir)


#######
# Polygonizing
#######

fname = paste0(workingDir, "/src/polygonize/polygonize.py")
print("Processing polygonizing python script:")
print(fname)
source_python(fname)
mainPolygonize_PF(workingDir, outDir)



###############################################################################

#######
# Merge save spatial
#######

source(paste0(workingDir, "/src/spatial_view/merge_spatial_final_data.R"))
mergeFinalData(workingDir, outDir)


#######
# Save pagerecords.csv"
#######

# Datei einlesen
spatial_final_data_path <- file.path(outDir, "spatial_final_data.csv")
spatial_final_data <- read.csv2(spatial_final_data_path, stringsAsFactors = FALSE, sep = ";")

# Alle CSV-Dateien im Verzeichnis pagerecords einlesen save as pagerecords.csv
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


#######
# Add Real_X and Real_Y 
# in spatial_final_data_with_realXY.csv
#######

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


#######
# Merge pagerecords.csv 
# and spatial_final_data_with_realXY.csv  
# to spatial_final_data_with_new_pagerecordsFiles.csv
#######

combined_df <- read.csv(file.path(outDir,"pagerecords.csv"), stringsAsFactors = FALSE, sep = ",")
spatial_df <- read.csv(file.path(outDir, "spatial_final_data_with_realXY.csv"), stringsAsFactors = FALSE, sep = ";")
outputFile <- file.path(outDir, "spatial_final_data_with_new_pagerecordsFiles.csv")
# Falls die Spaltennamen Leerzeichen enthalten, diese trimmen
colnames(combined_df) <- trimws(colnames(combined_df))
colnames(spatial_df) <- trimws(colnames(spatial_df))

# Sicherstellen, dass beide DataFrames die Spalte `File` enthalten
if (!"File" %in% colnames(combined_df) | !"File" %in% colnames(spatial_df)) {
  stop("⚠️ Eine der Dateien enthält keine `File`-Spalte!")
}

# Prüfen, welche `File`-Einträge aus `combined_data.csv` NICHT in `spatial_final_data.csv` sind
missing_files <- setdiff(combined_df$File, spatial_df$File)

print(paste("⚠️ Neue Maps gefunden:", paste(missing_files, collapse = ", ")))

# Neue Zeilen erstellen mit `map_found = "NEW"`
new_rows <- combined_df %>%
  filter(File %in% missing_files) %>%
  mutate(
    Detection.method = "NA",  # Standardwert für neue Einträge
    species = as.character(NA),  # Setzt NA als Character, um Fehler zu vermeiden
    Title = as.character(NA),    # Setzt NA als Character
    map_found = "NEW"
  ) %>%
  select(File, Detection.method, species, Title, map_found)  # Nur relevante Spalten übernehmen

# Sicherstellen, dass `species` und `Title` auch in `spatial_df` als character vorliegen
spatial_df$species <- as.character(spatial_df$species)
spatial_df$Title <- as.character(spatial_df$Title)

# Neue Zeilen zu spatial_df hinzufügen
spatial_df <- bind_rows(spatial_df, new_rows)

# Funktion zum Extrahieren der Nummer vor "map"
spatial_df$file_map <- as.integer(sub("^0*", "", sapply(strsplit(sub("map.*", "", spatial_df$File), "_"), `[`, 2)))

# Neue vorlaufende ID pro `file_map`
spatial_df <- spatial_df %>%
  group_by(file_map) %>%
  mutate(map_ID = row_number()) %>%
  ungroup()

# Spaltenreihenfolge anpassen: ID bleibt, map_ID wird nach ID eingefügt
spatial_df <- spatial_df %>% select(ID, file_map, map_ID,everything())

# Datei speichern
write.table(spatial_df, file = outputFile, sep = ";", row.names = FALSE, quote = FALSE)

cat("Die Datei wurde erfolgreich aktualisiert und gespeichert unter:", outputFile)

