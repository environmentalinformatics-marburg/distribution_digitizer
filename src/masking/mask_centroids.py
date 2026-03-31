# ============================================================
# File: mask_centroids.py
# Author: Spaska Forteva
#
# Description:
# This script extracts and refines centroid positions from
# previously filtered point images.
#
# It detects colored centroids in HSV color space, removes
# duplicates, links them to existing template information,
# and exports both visual masks and structured CSV data.
#
# This step represents the transition from pixel-based
# detection to structured point data ready for georeferencing.
# ============================================================

import numpy as np
from PIL import Image
import cv2
import csv
import os
import glob


# ------------------------------------------------------------
# Load already detected points from previous processing steps
# ------------------------------------------------------------
# These points are used to:
# - avoid duplicate detections
# - transfer template information to newly detected centroids
# ------------------------------------------------------------
def load_existing_points(csv_path):
    existing = []
    
    if not os.path.exists(csv_path):
        return existing
    
    with open(csv_path, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                x = int(float(row["X_WGS84"]))
                y = int(float(row["Y_WGS84"]))
                template = row.get("template", "unknown")
                existing.append((x, y, template))
            except:
                continue
    
    return existing


# ------------------------------------------------------------
# Assign template to a centroid based on spatial proximity
# ------------------------------------------------------------
# The function searches for a previously known point that is
# spatially close and transfers its template label.
# ------------------------------------------------------------
def find_template_for_point(cx, cy, existing_points, threshold=10):
    for px, py, template in existing_points:
        if is_close((cx, cy), (px, py), threshold):
            return template
    return "unknown"


# ------------------------------------------------------------
# Euclidean distance check for spatial proximity
# ------------------------------------------------------------
def is_close(p1, p2, threshold=10):
    return ((p1[0]-p2[0])**2 + (p1[1]-p2[1])**2) ** 0.5 < threshold


# ------------------------------------------------------------
# Detect colored centroids and create mask image
# ------------------------------------------------------------
# Core idea:
# - Detect colored points in HSV space
# - Extract contours representing centroids
# - Remove duplicates based on spatial proximity
# - Assign templates using previously detected points
#
# Output:
# - Image with centroid markers
# - CSV entries with coordinates and metadata
# ------------------------------------------------------------
def create_centroid_mask(image_path, output_dir, csv_writer, existing_points):
    
    # --------------------------------------------------------
    # Define HSV color ranges for centroid detection
    # Only saturated colors are considered (no gray/white)
    # --------------------------------------------------------
    color_ranges = [
    
        # RED (two ranges due to HSV wrap-around)
        (np.array([0, 70, 50]), np.array([10, 255, 255]), (0, 0, 255)),
        (np.array([170, 70, 50]), np.array([180, 255, 255]), (0, 0, 255)),
    
        # GREEN
        (np.array([35, 70, 50]), np.array([85, 255, 255]), (0, 255, 0)),
    
        # BLUE
        (np.array([100, 70, 50]), np.array([140, 255, 255]), (255, 0, 0)),
    
        # YELLOW
        (np.array([20, 100, 100]), np.array([35, 255, 255]), (0, 255, 255)),
    
        # ORANGE
        (np.array([10, 150, 150]), np.array([20, 255, 255]), (0,165,255)),
    
        # MAGENTA
        (np.array([140, 70, 50]), np.array([170, 255, 255]), (255, 0, 255))
    ]
        
    img = cv2.imread(image_path)
    hsv_img = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)

    centroid_mask = np.zeros_like(img)
    centroids = []
    used_centers = []
    
    # --------------------------------------------------------
    # Loop over all color ranges
    # --------------------------------------------------------
    for lower, upper, color in color_ranges:

        mask = cv2.inRange(hsv_img, lower, upper)

        # ----------------------------------------------------
        # Additional saturation filtering
        # → removes weak/grayish colors
        # ----------------------------------------------------
        sat = hsv_img[:,:,1]
        sat_mask = cv2.inRange(sat, 100, 255)
        mask = cv2.bitwise_and(mask, sat_mask)
        
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        for contour in contours:
            M = cv2.moments(contour)

            if M["m00"] == 0:
                continue
            
            # ------------------------------------------------
            # Compute centroid
            # ------------------------------------------------
            cx = int(M["m10"] / M["m00"])
            cy = int(M["m01"] / M["m00"])

            # ------------------------------------------------
            # Remove duplicates (very important!)
            # ------------------------------------------------
            skip = False
            for px, py in used_centers:
                if abs(cx - px) < 6 and abs(cy - py) < 6:
                    skip = True
                    break
            
            if skip:
                continue

            used_centers.append((cx, cy))

            # ------------------------------------------------
            # Check if point already exists
            # ------------------------------------------------
            duplicate = False
            for px, py, _ in existing_points:
                if is_close((cx, cy), (px, py), threshold=10):
                    duplicate = True
                    break
            
            # Assign template (important for later steps!)
            template = find_template_for_point(cx, cy, existing_points)

            # Store centroid
            centroids.append((cx, cy, color, template))

            # Update existing points list
            if not duplicate:
                existing_points.append((cx, cy, template))
    
    # --------------------------------------------------------
    # Save visualization (centroid mask image)
    # --------------------------------------------------------
    output_path = os.path.join(output_dir, os.path.basename(image_path))
    cv2.imwrite(output_path, centroid_mask)
    
    # --------------------------------------------------------
    # Write results to CSV
    # --------------------------------------------------------
    for i, (cx, cy, color, template) in enumerate(centroids):
        blue, green, red = color
        csv_writer.writerow([
            len(centroids),
            os.path.basename(image_path),
            cx, cy,
            template,
            blue, green, red,
            0
        ])

    # If nothing found → write empty entry
    if len(centroids) == 0:
        csv_writer.writerow([
            0,
            os.path.basename(image_path),
            0, 0,
            0, 0, 0, 0,
            0
        ])


# ------------------------------------------------------------
# Main controller for centroid masking
# ------------------------------------------------------------
# Workflow:
# - Iterate over map types
# - Load previously detected points
# - Detect centroids in each image
# - Store results in CSV and images
# ------------------------------------------------------------
def MainMaskCentroids(workingDir, outDir, nMapTypes=1):

    try:
        map_type_dirs = []

        # Detect available map-type folders
        for name in os.listdir(outDir):
            full = os.path.join(outDir, name)
            if os.path.isdir(full) and name.isdigit():
                map_type_dirs.append(full)

        map_type_dirs = map_type_dirs[:int(nMapTypes)]

        if not map_type_dirs:
            print("⚠️ No map-type folders found in output/")
            return

        for map_dir in map_type_dirs:
            map_type = os.path.basename(map_dir)
            print(f"\n=== Processing map type folder: {map_type} ===")

            inputDir = os.path.join(map_dir, "maps", "pointFiltering")
            outputDir = os.path.join(map_dir, "masking_black", "pointFiltering")
            csv_path = os.path.join(map_dir, "maps", "csvFiles", "coordinates_transformed.csv")

            os.makedirs(outputDir, exist_ok=True)

            with open(csv_path, 'w', newline='') as csvfile:
                writer = csv.writer(csvfile)

                writer.writerow([
                    'ID', 'File',
                    'X_WGS84', 'Y_WGS84',
                    'template',
                    'Blue', 'Green', 'Red',
                    'georef'
                ])

                pf_csv_path = os.path.join(map_dir, "maps", "csvFiles", "coordinates.csv")

                # Load previous detections
                existing_points = load_existing_points(pf_csv_path)

                # Process all images
                for file in glob.glob(os.path.join(inputDir, "*.tif")):
                    print(f"Processing: {os.path.basename(file)}")

                    if os.path.exists(file):
                        create_centroid_mask(file, outputDir, writer, existing_points)
                    else:
                        print("File not found:", file)

        print("\n✓ Centroid masking completed for all map types.")

    except Exception as e:
        print("An error occurred in MainMaskCentroids:", e)
