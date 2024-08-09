"""
Author: Spaska Forteva
Description: This script processes TIFF images to identify and mask 
centroids based on specific color ranges. 
It extracts centroid coordinates, saves them as masked images, and logs the details in a CSV file.
"""

import numpy as np
from PIL import Image
import cv2
import csv
import os
import glob

### Mask drawn centroids

def mask_centroids(tiffile, outdir):
  try:
    img = np.array(Image.open(tiffile))
    
    # Define the exact red color used in circle detection
    red_color_lower = np.array([139, 0, 0], dtype=np.uint8)
    red_color_upper = np.array([139, 0, 0], dtype=np.uint8)
    
    # Create a binary mask by filtering out only the exact red color range
    mask = cv2.inRange(img, red_color_lower, red_color_upper)
    
    # Save the centroid mask as a TIFF file in the specified outdir
    outfile = os.path.basename(tiffile)
    output_filepath = os.path.join(outdir, outfile)
    cv2.imwrite(output_filepath, mask)
    
  except Exception as e:
        print("An error occurred in mask_centroids:", e)


def create_centroid_mask(image_path, output_dir, csv_writer):
    # Beispielhafte Farbbereiche (HSV) für rote, grüne und blaue Kreise
    color_ranges = [
        (np.array([0, 70, 50]), np.array([10, 255, 255])),     # Rot
        (np.array([170, 70, 50]), np.array([180, 255, 255])),  # Rot
        (np.array([35, 70, 50]), np.array([85, 255, 255])),    # Grün
        (np.array([100, 70, 50]), np.array([140, 255, 255]))   # Blau
    ]
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
    for i, (cx, cy, color) in enumerate(centroids):
        blue, green, red = color
        csv_writer.writerow([len(centroids), os.path.basename(image_path), cx, cy, blue, green, red, 0])


def MainMaskCentroids(workingDir, outDir):
  try:
    inputDirs = [
        os.path.join(outDir, "maps", "pointFiltering/"),
        #os.path.join(outDir, "maps", "pointFiltering/")
    ]
    outputDirs = [
        os.path.join(outDir, "masking_black", "pointFiltering/"),
        #os.path.join(outDir, "masking_black", "pointFiltering/")
    ]
    csv_path = os.path.join(outDir, "coordinates_transformed.csv")

    with open(csv_path, 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(['ID', 'File', 'X_WGS84', 'Y_WGS84', 'Blue', 'Green', 'Red', 'georef'])

        for inputDir, outputDir in zip(inputDirs, outputDirs):
            # Loop through TIFF files in the input directory
            for file in glob.glob(inputDir + '*.tif'):
                print(file)
                if os.path.exists(file):
                    # call the function
                    create_centroid_mask(file, outputDir, writer)
                else:
                    print("Die Datei existiert nicht:", file)
  except Exception as e:
        print("An error occurred in MainMaskCentroids:", e)


#MainMaskCentroids("D:/distribution_digitizer/", "D:/test/output_2024-08-06_18-02-17/")
