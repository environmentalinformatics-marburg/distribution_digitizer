import cv2
import numpy as np

def create_centroid_mask(image_path, color_ranges, output_path):
    # Bild laden
    img = cv2.imread(image_path)
    hsv_img = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)

    # Erstellen einer leeren Maske
    final_mask = np.zeros(img.shape[:2], dtype="uint8")

    for color_range in color_ranges:
        # Erstellen einer Maske für jeden Farbbereich
        lower, upper = color_range
        mask = cv2.inRange(hsv_img, lower, upper)
        
        # Hinzufügen der Maske zur finalen Maske
        final_mask = cv2.bitwise_or(final_mask, mask)

    # Konturen finden
    contours, _ = cv2.findContours(final_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    # Erstellen einer neuen Maske für die Zentroiden
    centroid_mask = np.zeros_like(img)

    # Zentroiden berechnen und als Punkte auf die neue Maske zeichnen
    for contour in contours:
        M = cv2.moments(contour)
        if M["m00"] != 0:
            cx = int(M["m10"] / M["m00"])
            cy = int(M["m01"] / M["m00"])
            # Behalte die Farbe des Zentroids vom Originalbild
            color = img[cy, cx]
            # Zeichnen des Punktes auf der Zentroidenmaske
            cv2.circle(centroid_mask, (cx, cy), 3, color.tolist(), -1)

    # Speichern der Zentroidenmaske
    cv2.imwrite(output_path, centroid_mask)

# Beispielhafte Farbbereiche (HSV) für rote, grüne und blaue Kreise
color_ranges = [
    (np.array([0, 70, 50]), np.array([10, 255, 255])),     # Rot
    (np.array([170, 70, 50]), np.array([180, 255, 255])),  # Rot
    (np.array([35, 70, 50]), np.array([85, 255, 255])),    # Grün
    (np.array([100, 70, 50]), np.array([140, 255, 255]))   # Blau
]

# Beispielhafte Pfade (anpassen nach Bedarf)
# Beispielhafte Pfade (anpassen nach Bedarf)
image_path = "D:/test/output_2024-07-12_08-18-21/maps/circleDetection/64-2_0069map_1_0.tif"
output_path = "D:/test/output_2024-07-12_08-18-21/masking_black/geor64-2_0069map_1_0_.tif"
create_centroid_mask(image_path, color_ranges, output_path)


import cv2
import numpy as np
import os
import csv
from osgeo import gdal, ogr, osr

def create_centroid_mask_and_csv(image_path, color_ranges, output_shapefile_path, output_csv_path):
    # Bild laden
    img = cv2.imread(image_path)
    hsv_img = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)

    # Erstellen einer leeren Maske
    final_mask = np.zeros(img.shape[:2], dtype="uint8")

    for color_range in color_ranges:
        # Erstellen einer Maske für jeden Farbbereich
        lower, upper = color_range
        mask = cv2.inRange(hsv_img, lower, upper)
        
        # Hinzufügen der Maske zur finalen Maske
        final_mask = cv2.bitwise_or(final_mask, mask)

    # Konturen finden
    contours, _ = cv2.findContours(final_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    # Erstellen einer neuen Maske für die Zentroiden
    centroid_mask = np.zeros_like(img)

    # Listen für Zentroiden-Koordinaten und Farben
    centroids = []
    colors = []
    local_coords = []

    # Zentroiden berechnen und als Punkte auf die neue Maske zeichnen
    for contour in contours:
        M = cv2.moments(contour)
        if M["m00"] != 0:
            cx = int(M["m10"] / M["m00"])
            cy = int(M["m01"] / M["m00"])
            centroids.append((cx, cy))
            color = img[cy, cx]
            colors.append(color.tolist())
            local_coords.append((cx, cy))
            cv2.circle(centroid_mask, (cx, cy), 3, color.tolist(), -1)

    # Speichern der Zentroidenmaske
    #cv2.imwrite(output_mask_path, centroid_mask)

    # Georeferenzierte Informationen extrahieren
    dataset = gdal.Open(image_path)
    geotransform = dataset.GetGeoTransform()
    spatial_ref = osr.SpatialReference()
    spatial_ref.ImportFromWkt(dataset.GetProjection())

    # Shape File erstellen
    driver = ogr.GetDriverByName("ESRI Shapefile")
    if os.path.exists(output_shapefile_path):
        driver.DeleteDataSource(output_shapefile_path)
    shape_data = driver.CreateDataSource(output_shapefile_path)
    layer = shape_data.CreateLayer("centroids", spatial_ref, ogr.wkbPoint)

    # Hinzufügen von Attributfeldern
    layer.CreateField(ogr.FieldDefn("ID", ogr.OFTInteger))
    layer.CreateField(ogr.FieldDefn("Red", ogr.OFTInteger))
    layer.CreateField(ogr.FieldDefn("Green", ogr.OFTInteger))
    layer.CreateField(ogr.FieldDefn("Blue", ogr.OFTInteger))
    layer.CreateField(ogr.FieldDefn("Local_X", ogr.OFTInteger))
    layer.CreateField(ogr.FieldDefn("Local_Y", ogr.OFTInteger))

    # CSV-Datei vorbereiten
    with open(output_csv_path, mode='w', newline='') as csv_file:
        fieldnames = ['ID', 'Local_X', 'Local_Y', 'Real_X', 'Real_Y', 'Red', 'Green', 'Blue']
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()

        # Zentroiden und Farben ins Shape File und CSV-Datei speichern
        for i, (cx, cy) in enumerate(centroids):
            # Georeferenzierte Koordinaten berechnen
            x = geotransform[0] + cx * geotransform[1] + cy * geotransform[2]
            y = geotransform[3] + cx * geotransform[4] + cy * geotransform[5]

            point = ogr.Geometry(ogr.wkbPoint)
            point.AddPoint(x, y)
            
            feature = ogr.Feature(layer.GetLayerDefn())
            feature.SetGeometry(point)
            feature.SetField("ID", i)
            feature.SetField("Red", colors[i][2])
            feature.SetField("Green", colors[i][1])
            feature.SetField("Blue", colors[i][0])
            feature.SetField("Local_X", local_coords[i][0])
            feature.SetField("Local_Y", local_coords[i][1])
            layer.CreateFeature(feature)
            feature = None

            # In CSV-Datei schreiben
            writer.writerow({
                'ID': i,
                'Local_X': local_coords[i][0],
                'Local_Y': local_coords[i][1],
                'Real_X': x,
                'Real_Y': y,
                'Red': colors[i][2],
                'Green': colors[i][1],
                'Blue': colors[i][0]
            })

    # Shape File schließen
    shape_data = None

# Beispielhafte Farbbereiche (HSV) für rote, grüne und blaue Kreise
color_ranges = [
    (np.array([0, 70, 50]), np.array([10, 255, 255])),     # Rot
    (np.array([170, 70, 50]), np.array([180, 255, 255])),  # Rot
    (np.array([35, 70, 50]), np.array([85, 255, 255])),    # Grün
    (np.array([100, 70, 50]), np.array([140, 255, 255]))   # Blau
]


# Beispielhafte Pfade (anpassen nach Bedarf)
image_path = "D:/test/output_2024-07-12_08-18-21/rectifying/circleDetection/geor64-2_0069map_1_0_centre_rectified.tif"
#output_mask_path = "D:/test/output_2024-07-12_08-18-21/rectifying/geor64-2_0069map_1_0_centre_rectified.tif"
output_shapefile_path = "D:/test/output_2024-07-12_08-18-21/polygonize/circleDetection/geor64-2_0069map_1_0_centre_rectified.shp"
output_csv_path = "D:/test/output_2024-07-12_08-18-21/64-2_0069map_1_0_centroids.csv"

create_centroid_mask_and_csv(image_path, color_ranges,  output_shapefile_path, output_csv_path)
