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
  
  
  
def create_species_contour_mask(
        image_path,
        output_dir,
        min_area_ratio=0.03,
        debug=False
    ):
    """
    Creates a binary mask containing large closed species distribution areas.

    The detection is intended for maps where species distributions are
    represented by large closed contours/areas rather than individual points.

    The function:
    - detects dark/gray lines
    - detects strongly colored lines
    - combines both into one binary image
    - closes small gaps in contour lines
    - finds closed contours
    - removes small contours such as text, borders and map details
    - keeps all sufficiently large distribution areas

    Args:
        image_path (str):
            Input map image.

        output_dir (str):
            Directory where the resulting mask is stored.

        min_area_ratio (float):
            Minimum contour area relative to the complete map area.
            Default = 0.03 (= 3 %).

        debug (bool):
            Print information about detected contours.

    Returns:
        bool:
            True if processing succeeded.
    """

    try:
        # ------------------------------------------------------------
        # Load image
        # ------------------------------------------------------------
        img = cv2.imread(image_path)

        if img is None:
            print(f"❌ Could not read image: {image_path}")
            return False

        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)

        height, width = gray.shape
        map_area = height * width

        # ------------------------------------------------------------
        # 1. Detect dark / gray lines
        # ------------------------------------------------------------
        # Everything clearly darker than the light map background
        dark_mask = cv2.inRange(
            gray,
            0,
            170
        )

        # ------------------------------------------------------------
        # 2. Detect colored lines
        # ------------------------------------------------------------
        # Strong saturation captures red, blue, green etc.
        saturation = hsv[:, :, 1]

        color_mask = cv2.inRange(
            saturation,
            80,
            255
        )

        # ------------------------------------------------------------
        # 3. Combine dark and colored structures
        # ------------------------------------------------------------
        candidate_mask = cv2.bitwise_or(
            dark_mask,
            color_mask
        )

        # ------------------------------------------------------------
        # 4. Close small gaps in contour lines
        # ------------------------------------------------------------
        # Important for old scanned maps where contour lines may be
        # interrupted or weak in some places.
        kernel = np.ones((3, 3), np.uint8)

        candidate_mask = cv2.morphologyEx(
            candidate_mask,
            cv2.MORPH_CLOSE,
            kernel,
            iterations=2
        )

        # ------------------------------------------------------------
        # 5. Find contours
        # ------------------------------------------------------------
        # RETR_EXTERNAL:
        # We are interested primarily in the large outer distribution
        # areas and not small structures inside them.
        contours, _ = cv2.findContours(
            candidate_mask,
            cv2.RETR_EXTERNAL,
            cv2.CHAIN_APPROX_SIMPLE
        )

        if debug:
            print(
                f"🔍 {os.path.basename(image_path)}: "
                f"{len(contours)} candidate contours"
            )

        # ------------------------------------------------------------
        # 6. Final empty mask
        # ------------------------------------------------------------
        final_mask = np.zeros(
            (height, width),
            dtype=np.uint8
        )

        accepted = 0

        # ------------------------------------------------------------
        # 7. Filter contours by size
        # ------------------------------------------------------------
        for contour in contours:

            contour_area = cv2.contourArea(contour)

            if contour_area <= 0:
                continue

            area_ratio = contour_area / float(map_area)

            if debug:
                x, y, w, h = cv2.boundingRect(contour)

                print(
                    f"   contour:"
                    f" area={contour_area:.0f},"
                    f" ratio={area_ratio:.4f},"
                    f" box={w}x{h}"
                )

            # --------------------------------------------------------
            # Ignore small map structures, text, borders etc.
            # --------------------------------------------------------
            if area_ratio < min_area_ratio:
                continue

            # --------------------------------------------------------
            # ACCEPT species distribution area
            # --------------------------------------------------------
            cv2.drawContours(
                final_mask,
                [contour],
                -1,
                255,
                thickness=cv2.FILLED
            )

            accepted += 1

        # ------------------------------------------------------------
        # 8. Save result
        # ------------------------------------------------------------
        os.makedirs(
            output_dir,
            exist_ok=True
        )

        output_path = os.path.join(
            output_dir,
            os.path.basename(image_path)
        )

        cv2.imwrite(
            output_path,
            final_mask
        )

        print(
            f"✅ {os.path.basename(image_path)}: "
            f"{accepted} large contour(s) accepted"
        )

        return True

    except Exception as e:
        print(
            "❌ Error in create_species_contour_mask:",
            e
        )
        return False
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
    
    # Definiere Farbbereiche für farbige Zentroiden (keine grauen oder weißen)
    color_ranges = [
    
        # RED
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
    final_mask = np.zeros(img.shape[:2], dtype="uint8")
    centroid_mask = np.zeros_like(img)
    centroids = []
    used_centers = []
    
    # --------------------------------------------------------
    # Loop over all color ranges
    # --------------------------------------------------------
    for lower, upper, color in color_ranges:
        mask = cv2.inRange(hsv_img, lower, upper)
        hsv = hsv_img

        # ----------------------------------------------------
        # Additional saturation filtering
        # → removes weak/grayish colors
        # ----------------------------------------------------
        sat = hsv[:,:,1]
        
        # nur stark gesättigte Farben behalten
        sat_mask = cv2.inRange(sat, 100, 255)
        
        # kombinieren
        mask = cv2.bitwise_and(mask, sat_mask)
        
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        for contour in contours:
            M = cv2.moments(contour)
            if M["m00"] != 0:
                cx = int(M["m10"] / M["m00"])
                cy = int(M["m01"] / M["m00"])
                skip = False
                for px, py in used_centers:
                    if abs(cx - px) < 6 and abs(cy - py) < 6:
                        skip = True
                        break
                
                if skip:
                    continue

                used_centers.append((cx, cy))
            else:
                continue  # Falls kein eindeutiger Mittelpunkt, ignoriere die Kontur
            
            cv2.circle(centroid_mask, (cx, cy), 3, color, -1)  # Zentroid in Originalfarbe markieren
            # Prüfe ob Punkt schon existiert
            duplicate = False
            
            for px, py, _ in existing_points:
                if is_close((cx, cy), (px, py), threshold=10):
                    duplicate = True
                    break
            
            template = find_template_for_point(cx, cy, existing_points)

            centroids.append((cx, cy, color, template))
            if not duplicate:
                existing_points.append((cx, cy, template)) # wichtig!
    
    # --------------------------------------------------------
    # Save visualization (centroid mask image)
    # --------------------------------------------------------
    output_path = os.path.join(output_dir, os.path.basename(image_path))
    cv2.imwrite(output_path, centroid_mask)
    
    for i, (cx, cy, color, template) in enumerate(centroids):
        blue, green, red = color
        csv_writer.writerow([len(centroids), os.path.basename(image_path), cx, cy, template, blue, green, red, 0])
    if len(centroids) == 0:
        csv_writer.writerow([len(centroids), os.path.basename(image_path), 0, 0, 0, 0, 0, 0, 0])


# ------------------------------------------------------------
# Main controller for centroid masking
# ------------------------------------------------------------
# Workflow:
# - Iterate over map types
# - Load previously detected points
# - Detect centroids in each image
# - Store results in CSV and images
# ------------------------------------------------------------
def MainMaskCentroids(workingDir, outDir, nMapTypes=1, speciesRepresentation="point"):
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
            # ------------------------------------------------------------
            # Input depends on species representation
            # ------------------------------------------------------------
            
            if speciesRepresentation == "contour":
            
                # Contour maps come directly from alignment
                inputDir = os.path.join(
                    map_dir,
                    "maps",
                    "align"
                )
            
                outputDir = os.path.join(
                    map_dir,
                    "masking_black",
                    "align"
                )
            
            else:
            
                # Existing point workflow
                inputDir = os.path.join(
                    map_dir,
                    "maps",
                    "pointFiltering"
                )
            
                outputDir = os.path.join(
                    map_dir,
                    "masking_black",
                    "pointFiltering"
                )
            
            print(f"Species representation: {speciesRepresentation}")
            print(f"Masking input: {inputDir}")
            
            os.makedirs(outputDir, exist_ok=True)
            csv_path = os.path.join(map_dir, "maps", "csvFiles", "coordinates_transformed.csv")

            # Erstelle den Output-Ordner
            os.makedirs(outputDir, exist_ok=True)

            # Erstelle die CSV-Datei
            with open(csv_path, 'w', newline='') as csvfile:
                writer = csv.writer(csvfile)
                writer.writerow(['ID', 'File', 'X_WGS84', 'Y_WGS84', 'template', 'Blue', 'Green', 'Red', 'georef'])
                if speciesRepresentation == "point":

                    pf_csv_path = os.path.join(
                        map_dir,
                        "maps",
                        "csvFiles",
                        "coordinates.csv"
                    )
                
                    existing_points = load_existing_points(pf_csv_path)
                
                else:
                    existing_points = []
                existing_points = load_existing_points(pf_csv_path)
                # --- Alle TIFs verarbeiten ---
                for file in glob.glob(os.path.join(inputDir, "*.tif")):
                    print(f"Processing: {os.path.basename(file)}")
                    if os.path.exists(file):
                        create_centroid_mask(file, outputDir, writer, existing_points)
                    else:
                        print("Die Datei existiert nicht:", file)

        print("\n✓ Centroid masking completed for afll map types.")

    except Exception as e:
        print("An error occurred in MainMaskCentroids:", e)
        
        
        
