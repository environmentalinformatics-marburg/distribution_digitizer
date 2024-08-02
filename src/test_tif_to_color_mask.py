import cv2
import numpy as np

def create_color_mask(image_path, output_path, color_ranges):
    # Bild laden
    img = cv2.imread(image_path)
    hsv_img = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)

    # Erstellen einer leeren Maske
    final_mask = np.zeros(img.shape[:2], dtype="uint8")

    for color_range in color_ranges:
        # Erstellen einer Maske für jede Farbbereich
        lower, upper = color_range
        mask = cv2.inRange(hsv_img, lower, upper)
        
        # Hinzufügen der Maske zur finalen Maske
        final_mask = cv2.bitwise_or(final_mask, mask)

    # Anwenden der Maske auf das Originalbild
    result = cv2.bitwise_and(img, img, mask=final_mask)
    
    # Optional: Umkehren der Maske für den Hintergrund
    inverse_mask = cv2.bitwise_not(final_mask)
    background = np.ones_like(img) * 255  # Weißer Hintergrund
    background = cv2.bitwise_and(background, background, mask=inverse_mask)

    # Kombinieren der resultierenden Bereiche mit dem weißen Hintergrund
    combined_result = cv2.add(result, background)

    # Speichern des Ergebnisses
    cv2.imwrite(output_path, combined_result)

# Beispielhafte Farbbereiche (HSV) für rote, grüne und blaue Kreise
color_ranges = [
    (np.array([0, 70, 50]), np.array([10, 255, 255])),     # Rot
    (np.array([170, 70, 50]), np.array([180, 255, 255])),  # Rot
    (np.array([35, 70, 50]), np.array([85, 255, 255])),    # Grün
    (np.array([100, 70, 50]), np.array([140, 255, 255]))   # Blau
]

# Beispielhafte Pfade (anpassen nach Bedarf)
#image_path = "D:/test/output_2024-07-12_08-18-21/maps/circleDetection/64-2_0069map_1_0.tif"
#output_path = "D:/test/output_2024-07-12_08-18-21/masking_black/64-2_0069map_1_0.tif"
#create_color_mask(image_path, output_path, color_ranges)


import cv2
import numpy as np
import csv
import os

def create_centroid_mask(image_path, color_ranges, output_dir, csv_path):
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

    centroids = []

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
            centroids.append((cx, cy, color))

    # Speichern der Zentroidenmaske
    output_path = os.path.join(output_dir, os.path.basename(image_path))
    cv2.imwrite(output_path, centroid_mask)

    # Schreiben der Zentroiden in die CSV-Datei
    with open(csv_path, 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(['ID', 'File', 'X_WGS84', 'Y_WGS84', 'Blue', 'Green', 'Red', 'georef'])
        for i, (cx, cy, color) in enumerate(centroids):
            blue, green, red = color
            
            writer.writerow([i + 1, os.path.basename(image_path), cx, cy, blue, green, red, 0])

# Beispielhafte Farbbereiche (HSV) für rote, grüne und blaue Kreise
color_ranges = [
    (np.array([0, 70, 50]), np.array([10, 255, 255])),     # Rot
    (np.array([170, 70, 50]), np.array([180, 255, 255])),  # Rot
    (np.array([35, 70, 50]), np.array([85, 255, 255])),    # Grün
    (np.array([100, 70, 50]), np.array([140, 255, 255]))   # Blau
]

# Beispielhafte Spezies-Zuordnung
species_relation = [
    (np.array([0, 0, 255]), 'species1'),  # Rot
    (np.array([255, 0, 0]), 'species2'),  # Blau
    (np.array([0, 255, 0]), 'species3')   # Grün
]

# Beispielhafte Pfade (anpassen nach Bedarf)
image_path = "D:/test/output_2024-07-12_08-18-21/maps/circleDetection/64-2_0069map_1_0.tif"
output_path = "D:/test/output_2024-07-12_08-18-21/masking_black/circleDetection/"
csv_path = "D:/test/output_2024-07-12_08-18-21/coordinates_transformed.csv"

create_centroid_mask(image_path, color_ranges, output_path, csv_path)

