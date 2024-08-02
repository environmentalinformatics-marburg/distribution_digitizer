# Notwendige Bibliotheken laden
library(readr)
library(leaflet)
library(dplyr)
library(tidyr)  # Für die Funktion separate
library(stringr)  # Für die Funktion str_replace_all

# Pfad zur CSV-Datei
csv_file_path <- "D:/test/output_2024-07-12_08-18-21/centroids_with_colors.csv"

# CSV-Datei einlesen
data <- read_csv(csv_file_path)

# Sicherstellen, dass die Koordinatenspalten numerisch sind
data <- data %>%
  mutate(Longitude = as.numeric(Longitude), 
         Latitude = as.numeric(Latitude),
         Color = str_replace_all(Color, "\\[|\\]", "")) %>%
  separate(Color, into = c("R", "G", "B"), sep = ", ", convert = TRUE) %>%
  mutate(Color = rgb(R / 255, G / 255, B / 255))

# Leaflet-Karte erstellen
map <- leaflet(data) %>%
  addTiles() %>%  # OpenStreetMap Tiles hinzufügen
  addCircleMarkers(
    lng = ~Longitude, lat = ~Latitude,  # Längen- und Breitengrad-Spalten
    radius = 5,  # Radius der Marker
    color = ~Color,  # Farbe der Marker
    stroke = FALSE, fillOpacity = 0.8  # Stil der Marker
  )

# Karte anzeigen
map

# Installieren und Laden der notwendigen Pakete
if (!require(sf)) install.packages("sf", dependencies=TRUE)
if (!require(ggplot2)) install.packages("ggplot2", dependencies=TRUE)
if (!require(leaflet)) install.packages("leaflet", dependencies=TRUE)

library(sf)
library(ggplot2)
library(leaflet)

# Pfad zur Shapefile (bitte anpassen)
shapefile_path <- "D:/test/output_2024-07-12_08-18-21/polygonize/circleDetection/geor64-2_0069map_1_0.shp"

# Shapefile laden
gdf <- st_read(shapefile_path)

# Überprüfen der geladenen Daten
print("Datenstruktur der Shapefile:")
print(str(gdf))

print("Zusammenfassung der Shapefile-Daten:")
print(summary(gdf))

# Visualisieren der Shapefile-Daten mit ggplot2
ggplot(data = gdf) +
  geom_sf() +
  ggtitle("Visualisierung der Shapefile-Daten") +
  theme_minimal()

# Konvertieren der Koordinaten auf das WGS84-Koordinatensystem für Leaflet
gdf <- st_transform(gdf, crs = 4326)

# Erstellen einer interaktiven Leaflet-Karte
leaflet(data = gdf) %>%
  addTiles() %>%
  addPolygons(color = "#FF0000", weight = 2, opacity = 1, fillOpacity = 0.5) %>%
  addMarkers(lng = ~st_coordinates(gdf)[,1], lat = ~st_coordinates(gdf)[,2], 
             popup = ~paste("Koordinaten:", st_coordinates(gdf)[,1], ",", st_coordinates(gdf)[,2])) %>%
  addLegend(position = "bottomright", colors = "#FF0000", labels = "Polygon") %>%
  addScaleBar(position = "bottomleft")


# Benötigte Bibliotheken laden
library(sf)
library(ggplot2)

# Pfad zur Shapefile (anpassen nach Bedarf)
shapefile_path <- "D:/test/output_2024-07-12_08-18-21/polygonize/circleDetection/geor64-2_0069map_1_0_centre_rectified.shp"

# Shapefile einlesen
shapefile_data <- st_read(shapefile_path)

# Überprüfen der geladenen Daten
print(head(shapefile_data))

# Visualisierung der Shapefile-Daten mit ggplot2
ggplot(data = shapefile_data) +
  geom_sf() +
  theme_minimal() +
  labs(title = "Visualisierung der Shapefile-Daten")

# Benötigte Bibliotheken laden
library(sf)
library(leaflet)

# Benötigte Bibliotheken laden
library(sf)
library(leaflet)
library(rgdal)

# Pfad zur Shape-Datei anpassen
shapefile_path <- "D:/test/output_2024-07-12_08-18-21/polygonize/circleDetection/geor64-2_0069map_1_0_centre_rectified.shp"

# Shape-Datei laden
points_data <- st_read(shapefile_path)

# Überprüfen der geladenen Daten
print(head(points_data))

# Erstellen der Leaflet-Karte
map <- leaflet() %>%
  addTiles() %>%  # OpenStreetMap Tiles hinzufügen
  addCircles(data = points_data,
             lng = ~st_coordinates(geometry)[,1], 
             lat = ~st_coordinates(geometry)[,2],
             color = "red",  # Farbe der Punkte
             fillColor = "red",
             radius = 5,  # Radius der Punkte
             stroke = FALSE,  # Keine Randlinie um Punkte
             fillOpacity = 0.8)  # Füll-Deckkraft für Punkte

# Karte anzeigen
map

# Benötigte Bibliotheken laden
library(sf)
library(leaflet)

# Benötigte Bibliotheken laden
library(sf)
library(leaflet)

# Pfad zur Shapefile (anpassen nach Bedarf)
shapefile_path <- "D:/test/output_2024-07-12_08-18-21/polygonize/circleDetection/geor64-2_0069map_1_0_centre_rectified.shp"


# Shapefile einlesen
shapefile_data <- st_read(shapefile_path)

# Überprüfen der geladenen Daten
print(head(shapefile_data))

# Funktion zum Erstellen von Farbcodes aus RGB-Werten
rgb_to_hex <- function(r, g, b) {
  rgb(r / 255, g / 255, b / 255, maxColorValue = 1)
}

# Erstellen der Leaflet-Karte mit farbkodierten Punkten
map <- leaflet() %>%
  addTiles() %>%
  addCircleMarkers(data = shapefile_data,
                   lng = ~st_coordinates(geometry)[,1],  # Längengrad
                   lat = ~st_coordinates(geometry)[,2],  # Breitengrad
                   color = ~rgb_to_hex(Red, Green, Blue),  # Farbattribute verwenden
                   weight = 1,
                   opacity = 0.9,
                   fillOpacity = 0.5,
                   radius = 5)

# Karte anzeigen
map


# Benötigte Bibliotheken laden
library(sf)
library(leaflet)
library(dplyr)

# Pfad zur CSV-Datei (anpassen nach Bedarf)
csv_path <- "D:/test/output_2024-07-12_08-18-21/polygonize/csvFiles/centroids_colors.csv"

# CSV-Datei einlesen
centroids_data <- read.csv(csv_path)

# Überprüfen der geladenen Daten
print(head(centroids_data))

# Funktion zum Erstellen von Farbcodes aus RGB-Werten
rgb_to_hex <- function(r, g, b) {
  rgb(r / 255, g / 255, b / 255, maxColorValue = 1)
}

# Hinzufügen einer Spalte für Hex-Farben
centroids_data <- centroids_data %>%
  mutate(color = rgb_to_hex(Red, Green, Blue))

# Überprüfen der Daten nach dem Hinzufügen der Farbspalte
print(head(centroids_data))

# Hinzufügen einer Spalte für Hex-Farben
centroids_data <- centroids_data %>%
  mutate(color = rgb_to_hex(Red, Green, Blue))

# Erstellen der Leaflet-Karte mit farbkodierten Punkten
map <- leaflet(centroids_data) %>%
  addTiles() %>%
  addCircleMarkers(
    lng = ~Real_X,  # Längengrad
    lat = ~Real_Y,  # Breitengrad
    color = ~color,  # Hex-Farben verwenden
    weight = 1,
    opacity = 0.9,
    fillOpacity = 0.5,
    radius = 5
  )

# Karte anzeigen
map


