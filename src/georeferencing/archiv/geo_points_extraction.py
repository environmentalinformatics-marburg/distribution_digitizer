import cv2
import numpy as np
import pandas as pd
import os
from osgeo import gdal

def read_geotransform_from_points_file(file_path):
    df = pd.read_csv(file_path)
    # Berechnen der Pixel- und Geokoordinaten-Differenzen
    source_x = df['sourceX']
    source_y = df['sourceY']
    map_x = df['mapX']
    map_y = df['mapY']
    
    # Berechnen der Pixelgröße und der Geotransformation mit mehreren Punkten
    pixel_size_x = np.mean(np.diff(map_x) / np.diff(source_x))
    pixel_size_y = np.mean(np.diff(map_y) / np.diff(source_y))
    
    # Obere linke Ecke des Bildes
    x_min = map_x[0] - source_x[0] * pixel_size_x
    y_max = map_y[0] - source_y[0] * pixel_size_y

    # Geotransformation (GDAL-style)
    geotransform = [x_min, pixel_size_x, 0, y_max, 0, -pixel_size_y]
    
    return geotransform

def pixel_to_geo(pixel_coords, geotransform):
    x_geo = geotransform[0] + pixel_coords[0] * geotransform[1]
    y_geo = geotransform[3] + pixel_coords[1] * geotransform[5]
    return (x_geo, y_geo)

def process_image(image_path, geotransform):
    # Laden des Bildes
    image = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)

    # Finden der Konturen
    contours, _ = cv2.findContours(image, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    # Liste für die Centroiden-Koordinaten
    centroids = []

    for contour in contours:
        M = cv2.moments(contour)
        if M['m00'] != 0:
            cx = int(M['m10'] / M['m00'])
            cy = int(M['m01'] / M['m00'])
            geo_coords = pixel_to_geo((cx, cy), geotransform)
            centroids.append((cx, cy, geo_coords[0], geo_coords[1]))
    
    return centroids

def main(input_folder, points_file, output_csv):
    geotransform = read_geotransform_from_points_file(points_file)
    
    all_centroids = []
    for filename in os.listdir(input_folder):
        if filename.endswith('.tif'):
            image_path = os.path.join(input_folder, filename)
            centroids = process_image(image_path, geotransform)
            all_centroids.extend(centroids)
    
    # Speichern der Koordinaten in einer CSV-Datei
    df = pd.DataFrame(all_centroids, columns=['Pixel_X', 'Pixel_Y', 'Longitude', 'Latitude'])
    df.to_csv(output_csv, index=False)

# Dateipfade
#points_file = "D:/distribution_digitizer/data/input/templates/geopoints/gcp_point_map1.points"
#input_folder ="D:/test/output_2024-07-12_08-18-21/rectifying/maps"
#output_csv = "D:/test/output_2024-07-12_08-18-21/centroids.csv"

#main(input_folder, points_file, output_csv)
