import numpy as np
from PIL import Image
import cv2
import csv
import os
import glob

def create_centroid_mask(image_path, output_dir, csv_writer):
    # Definiere Farbbereiche für farbige Zentroiden (keine grauen oder weißen)
    color_ranges = [
        (np.array([0, 70, 50]), np.array([10, 255, 255]), (0, 0, 255)),     # Rot
        (np.array([170, 70, 50]), np.array([180, 255, 255]), (0, 0, 255)),  # Rot
        (np.array([35, 70, 50]), np.array([85, 255, 255]), (0, 255, 0)),    # Grün
        (np.array([100, 70, 50]), np.array([140, 255, 255]), (255, 0, 0)),  # Blau
        (np.array([10, 150, 150]), np.array([25, 255, 255]), (0,165,255)) # Orange wird als rot gespeichert
    ]
    
    img = cv2.imread(image_path)
    hsv_img = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    final_mask = np.zeros(img.shape[:2], dtype="uint8")
    centroid_mask = np.zeros_like(img)
    centroids = []
    
    for lower, upper, color in color_ranges:
        mask = cv2.inRange(hsv_img, lower, upper)
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        for contour in contours:
            M = cv2.moments(contour)
            if M["m00"] != 0:
                cx = int(M["m10"] / M["m00"])
                cy = int(M["m01"] / M["m00"])
            else:
                continue  # Falls kein eindeutiger Mittelpunkt, ignoriere die Kontur
            
            cv2.circle(centroid_mask, (cx, cy), 3, color, -1)  # Zentroid in Originalfarbe markieren
            centroids.append((cx, cy, color))
    
    output_path = os.path.join(output_dir, os.path.basename(image_path))
    cv2.imwrite(output_path, centroid_mask)
    
    for i, (cx, cy, color) in enumerate(centroids):
        blue, green, red = color
        csv_writer.writerow([len(centroids), os.path.basename(image_path), cx, cy, blue, green, red, 0])
    if len(centroids) == 0:
        csv_writer.writerow([len(centroids), os.path.basename(image_path), 0, 0, 0, 0, 0, 0])

def MainMaskCentroids(workingDir, outDir):
    try:
        inputDirs = [
            os.path.join(outDir, "maps", "pointFiltering/")
        ]
        outputDirs = [
            os.path.join(outDir, "masking_black", "pointFiltering/")
        ]
        csv_path = os.path.join(outDir, "coordinates_transformed.csv")

        with open(csv_path, 'w', newline='') as csvfile:
            writer = csv.writer(csvfile)
            writer.writerow(['ID', 'File', 'X_WGS84', 'Y_WGS84', 'Blue', 'Green', 'Red', 'georef'])
            
            for inputDir, outputDir in zip(inputDirs, outputDirs):
                for file in glob.glob(inputDir + '*.tif'):
                    print(file)
                    if os.path.exists(file):
                        create_centroid_mask(file, outputDir, writer)
                    else:
                        print("Die Datei existiert nicht:", file)
    except Exception as e:
        print("An error occurred in MainMaskCentroids:", e)
