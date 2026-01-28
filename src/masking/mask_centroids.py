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

def MainMaskCentroids(workingDir, outDir, nMapTypes=1):
    """
    Create centroid masks for all TIFF files in the input directory.
    Processes multiple map types (1, 2, ...).

    Args:
        workingDir (str): Working directory containing input and output directories.
        outDir (str): Output directory (e.g., output_2025-09-26_13-16-11).
        nMapTypes (int): Number of map types (1 or 2). Used to limit processing.
    """
    try:
        # --- Finde alle map-type Ordner ---
        map_type_dirs = []
        for name in os.listdir(outDir):
            full = os.path.join(outDir, name)
            if os.path.isdir(full) and name.isdigit():
                map_type_dirs.append(full)

        # --- Nur die ersten nMapTypes verarbeiten ---
        map_type_dirs = map_type_dirs[:int(nMapTypes)]

        if not map_type_dirs:
            print("⚠️ No map-type folders found in output/")
            return

        # --- Jeden map-type Ordner einzeln verarbeiten ---
        for map_dir in map_type_dirs:
            map_type = os.path.basename(map_dir)
            print(f"\n=== Processing map type folder: {map_type} ===")

            # Input und Output für diesen Typ
            inputDir = os.path.join(map_dir, "maps", "pointFiltering")
            outputDir = os.path.join(map_dir, "masking_black", "pointFiltering")
            csv_path = os.path.join(map_dir, "maps", "csvFiles", "coordinates_transformed.csv")

            # Erstelle den Output-Ordner
            os.makedirs(outputDir, exist_ok=True)

            # Erstelle die CSV-Datei
            with open(csv_path, 'w', newline='') as csvfile:
                writer = csv.writer(csvfile)
                writer.writerow(['ID', 'File', 'X_WGS84', 'Y_WGS84', 'Blue', 'Green', 'Red', 'georef'])
                
                # --- Alle TIFs verarbeiten ---
                for file in glob.glob(os.path.join(inputDir, "*.tif")):
                    print(f"Processing: {os.path.basename(file)}")
                    if os.path.exists(file):
                        create_centroid_mask(file, outputDir, writer)
                    else:
                        print("Die Datei existiert nicht:", file)

        print("\n✓ Centroid masking completed for all map types.")

    except Exception as e:
        print("An error occurred in MainMaskCentroids:", e)
