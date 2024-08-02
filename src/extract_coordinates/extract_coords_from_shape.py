import geopandas as gpd
import pandas as pd
from shapely.geometry import Point, Polygon

def extract_contours_and_centroids(shapefile_path, output_csv):
    # Shapefile laden
    gdf = gpd.read_file(shapefile_path)
    
    # Spaltennamen ausgeben
    print("Spaltennamen im GeoDataFrame:", gdf.columns)
    
    centroids = []
    for geom in gdf.geometry:
        if geom.geom_type == 'Polygon':
            centroid = geom.centroid
            centroids.append((centroid.x, centroid.y))
        elif geom.geom_type == 'MultiPolygon':
            for poly in geom:
                centroid = poly.centroid
                centroids.append((centroid.x, centroid.y))
    
    # Überprüfen der extrahierten Zentroiden
    print(f"Anzahl der extrahierten Zentroiden: {len(centroids)}")
    
    # Speichern der Zentren in einer CSV-Datei
    df = pd.DataFrame(centroids, columns=['Longitude', 'Latitude'])
    df.to_csv(output_csv, index=False)

# Beispielhafte Pfade (anpassen nach Bedarf)
shapefile_path = "D:/test/output_2024-07-12_08-18D:/test/output_2024-07-12_08-18-21/polygonize/circleDetection/geor64-2_0069map_1_0_centre/geor64-2_0069map_1_0_centre_with_colors.shp"
output_csv = "D:/test/output_2024-07-12_08-18-21/centroids.csv"
extract_contours_and_centroids(shapefile_path, output_csv)


# Benötigte Bibliotheken laden
library(sf)
library(leaflet)

# Pfad zur Shapefile (anpassen nach Bedarf)
shapefile_path <- "D:/test/output_2024-07-12_08-18-21/polygonize/circleDetection/geor64-2_0069map_1_0_centre_rectified.shp"

# Shapefile einlesen
shapefile_data <- st_read(shapefile_path)

# Überprüfen der geladenen Daten
print(head(shapefile_data))

# Erstellen der Leaflet-Karte
map <- leaflet() %>%
  addTiles() %>%  # OpenStreetMap Tiles hinzufügen
  addPolygons(data = shapefile_data,
              color = "blue",  # Farbe der Polygone
              weight = 1,  # Linienbreite
              opacity = 0.7,  # Linien-Deckkraft
              fillOpacity = 0.5)  # Füll-Deckkraft

# Karte anzeigen
map
