"""
File: mask_centroids.py
Author: Kai Richter
Date: 2023-11-10

Description: 
Script for masking the red marked pixels representing centroids detected by Circle Detection and Point Filtering. 

function 'mask_centroids': The red pixels represnting the centroids are masked. The output is the input for georeferencing.

function 'MainMaskCentroids': Functions for looping over all files that should be processed. 
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
        print("An error occurred in mainGeomask:", e)


def create_centroid_mask(image_path, output_dir, csv_path):
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
    with open(csv_path, 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(['ID', 'File', 'X_WGS84', 'Y_WGS84', 'Blue', 'Green', 'Red', 'georef'])
        for i, (cx, cy, color) in enumerate(centroids):
            blue, green, red = color
            
            writer.writerow([i + 1, os.path.basename(image_path), cx, cy, blue, green, red, 0])


def MainMaskCentroids(workingDir, outDir):
  try:
    ## For output of circle_detection:
    # Define input and output directories
    inputDir = outDir + "/maps/circleDetection/"
    outputDir = outDir + "/masking_black/circleDetection/"
    csv_path = "D:/test/output_2024-07-12_08-18-21/coordinates_transformed.csv"
    # Loop through TIFF files in the input directory
    for file in glob.glob(inputDir + '*.tif'):
        print(file)
        if os.path.exists(file):
             # call the function
            #mask_centroids(file, outputDir)
            create_centroid_mask(file, outputDir, csv_path)
        else:
          print("Die Datei existiert nicht:", file)
      
   
    ## For output of point_filtering:    
    # Define input and output directories
    inputDirPF = outDir + "/maps/pointFiltering/"
    outputDirPF = outDir + "/masking_black/pointFiltering/"
   
    # Loop through TIFF files in the input directory
    for file in glob.glob(inputDirPF + '*.tif'):
        print(file)
        if os.path.exists(file):
             # call the function
            create_centroid_mask(file, outputDirPF, csv_path)
        else:
          print("Die Datei existiert nicht:", file)
        # call the function

  except Exception as e:
        print("An error occurred in MainMaskCentroids:", e)


#MainMaskCentroids("C:/Users/user/Documents/MSc_Physische_Geographie/HiWi/distribution_digitizer")
