# ============================================================
# File: point_filtering.py
# Author: Spaska Forteva
# Last updated on: 2026-03-31
#
# Description:
# This script refines detected point symbols from the previous
# point matching stage by applying image processing techniques
# to identify clean and reliable centroids.
#
# Core functionality:
# - Remove previously detected colored symbols from the image
# - Detect object regions using morphological operations
# - Separate overlapping symbols using distance transformation
# - Extract contour-based centroids
# - Classify points based on dominant color
# - Filter out invalid detections (e.g., outside map area)
#
# Additional features:
# - Integration of map boundary constraints (map hull)
# - Filtering based on previously detected points
# - Robust color classification using pixel statistics
#
# Output:
# - Refined centroid coordinates stored in CSV files
# - Processed images with visualized centroids
#
# This step improves the quality of detected point data and
# prepares it for polygonization and spatial analysis.
# ============================================================

import cv2
import PIL
from PIL import Image
import os
import glob
import numpy as np
import csv
import pandas as pd


# ------------------------------------------------------------
# Load map boundary (convex hull) from .points file
# ------------------------------------------------------------
# The hull defines the valid spatial region of the map.
#
# Purpose:
# - Remove detections outside the actual map area
#
# Note:
# - Y-coordinates are inverted to match image coordinate system
# ------------------------------------------------------------
def load_map_hull(points_file):

    df = pd.read_csv(points_file)

    if not {"sourceX","sourceY"}.issubset(df.columns):
        print("sourceX/sourceY missing")
        return None

    pts = df[["sourceX","sourceY"]].values.astype(np.float32)

    # Y invertieren
    pts[:,1] = -pts[:,1]

    pts = pts.astype(np.int32)

    return pts.reshape((-1,1,2))
  
  
# ------------------------------------------------------------
# Check if a point lies inside the map boundary
# ------------------------------------------------------------
# Uses OpenCV pointPolygonTest for efficient spatial filtering.
# ------------------------------------------------------------
def point_inside_map(cx, cy, map_hull):

    if map_hull is None:
        return True

    result = cv2.pointPolygonTest(map_hull, (cx, cy), False)

    return result >= 0
  
  
  
# Function to convert image to black and white
def convert_to_black_and_white(image_path):
    image = cv2.imread(image_path)
    gray_image = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    _, bw_image = cv2.threshold(gray_image, 128, 255, cv2.THRESH_BINARY)
    return bw_image



# ------------------------------------------------------------
# Remove previously detected colored symbols
# ------------------------------------------------------------
# Purpose:
# - Prevent already detected points from interfering with
#   contour detection
#
# Method:
# - Convert image to HSV
# - Mask predefined color ranges (red, blue, green, etc.)
# - Remove these regions from the image
#
# Result:
# - Cleaner input for contour-based detection
# ------------------------------------------------------------
def mask_existing_circles(image_array):
    hsv_image = cv2.cvtColor(image_array, cv2.COLOR_RGB2HSV)

    # Define color ranges in HSV
    lower_red1 = np.array([0, 100, 100])
    upper_red1 = np.array([10, 255, 255])

    lower_red2 = np.array([170, 100, 100])
    upper_red2 = np.array([180, 255, 255])

    lower_blue = np.array([100, 100, 100])
    upper_blue = np.array([130, 255, 255])

    lower_green = np.array([40, 100, 100])
    upper_green = np.array([80, 255, 255])

    lower_yellow = np.array([20, 100, 100])
    upper_yellow = np.array([35, 255, 255])

    lower_orange = np.array([10, 100, 100])
    upper_orange = np.array([20, 255, 255])

    lower_purple = np.array([130, 50, 50])
    upper_purple = np.array([160, 255, 255])

    lower_black = np.array([0, 0, 0])
    upper_black = np.array([180, 255, 50])

    # Create masks
    mask_red = cv2.bitwise_or(
        cv2.inRange(hsv_image, lower_red1, upper_red1),
        cv2.inRange(hsv_image, lower_red2, upper_red2)
    )

    mask_blue = cv2.inRange(hsv_image, lower_blue, upper_blue)
    mask_green = cv2.inRange(hsv_image, lower_green, upper_green)
    mask_yellow = cv2.inRange(hsv_image, lower_yellow, upper_yellow)
    mask_orange = cv2.inRange(hsv_image, lower_orange, upper_orange)
    mask_purple = cv2.inRange(hsv_image, lower_purple, upper_purple)
    mask_black = cv2.inRange(hsv_image, lower_black, upper_black)

    combined_mask = mask_red
    combined_mask = cv2.bitwise_or(combined_mask, mask_blue)
    combined_mask = cv2.bitwise_or(combined_mask, mask_green)
    combined_mask = cv2.bitwise_or(combined_mask, mask_yellow)
    combined_mask = cv2.bitwise_or(combined_mask, mask_orange)
    combined_mask = cv2.bitwise_or(combined_mask, mask_purple)
    combined_mask = cv2.bitwise_or(combined_mask, mask_black)

    inverted_mask = cv2.bitwise_not(combined_mask)

    masked_image = cv2.bitwise_and(image_array, image_array, mask=inverted_mask)
    final_image = cv2.addWeighted(image_array, 1, masked_image, 0, 0)

    return final_image
  
  
# Function to determine the average color of a contour
def get_contour_color(image, contour):
    # Erstellt eine Maske nur für den aktuellen Kontur
    mask = np.zeros(image.shape[:2], dtype=np.uint8)
    cv2.drawContours(mask, [contour], -1, 255, -1)
    mean_val = cv2.mean(image, mask=mask)
    return (int(mean_val[2]), int(mean_val[1]), int(mean_val[0]))  # Return as BGR


# Function to convert RGB to hex
def rgb_to_hex(rgb_color):
    return '#{:02x}{:02x}{:02x}'.format(rgb_color[0], rgb_color[1], rgb_color[2])


def determine_color(color_count, min_pixels=20):
    filtered = {k: v for k, v in color_count.items() if v >= min_pixels}
    
    if not filtered:
        return 'orange'
    
    return max(filtered, key=filtered.get)


def count_color_pixels(image, contour, color_ranges):
    mask = np.zeros(image.shape[:2], dtype=np.uint8)
    cv2.drawContours(mask, [contour], -1, 255, -1)
    color_count = {}
    for color, (lower, upper) in color_ranges.items():
        color_mask = cv2.inRange(image, lower, upper)
        color_mask = cv2.bitwise_and(color_mask, color_mask, mask=mask)
        count = np.count_nonzero(color_mask)
        color_count[color] = count
    return color_count


def get_last_id(csv_file_path):
    if not os.path.exists(csv_file_path):
        return 0
    
    with open(csv_file_path, 'r') as file:
        lines = file.readlines()
        if len(lines) <= 1:
            return 0
        
        last_line = lines[-1].strip()
        try:
            return int(last_line.split(',')[0])
        except:
            return 0
          
          
# ------------------------------------------------------------
# Detect centroids of map symbols using contour analysis
# ------------------------------------------------------------
# Core idea:
# Identify spatial regions corresponding to point symbols
# and extract their centroids.
#
# Key steps:
# - Remove colored symbols (masking)
# - Convert to grayscale and smooth image
# - Apply thresholding to isolate objects
# - Use morphological opening to remove noise
# - Apply distance transform to separate overlapping points
# - Detect contours representing candidate objects
#
# Advanced filtering:
# - Skip contours containing multiple previously detected points
# - Restrict detections to valid map region (map hull)
#
# Color classification:
# - Determine dominant color within each contour
# - Assign RGB values based on pixel statistics
#
# Output:
# - List of centroid coordinates with color attributes
# - Processed image with visualized detections
#
# This function is central for transforming raster-based
# symbol clusters into clean point representations.
# ------------------------------------------------------------
def detect_edges_and_centroids(tiffile, outdir, kernel_size, blur_radius, map_hull=None, df_existing=None):

    original_image = np.array(PIL.Image.open(tiffile))
    # Für Kontur-Erkennung (bereinigt)
    image_array = mask_existing_circles(original_image.copy())
    gray_image = cv2.cvtColor(image_array, cv2.COLOR_BGR2GRAY)
    gray_image = cv2.GaussianBlur(gray_image, (blur_radius, blur_radius), 0)
    _, thresh_image = cv2.threshold(gray_image, 120, 255, cv2.THRESH_TOZERO_INV)
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (kernel_size, kernel_size))
    opened_image = cv2.morphologyEx(thresh_image, cv2.MORPH_OPEN, kernel, iterations=3)
    # Distance transform to separate touching points
    dist_transform = cv2.distanceTransform(opened_image, cv2.DIST_L2, 5)
    
    # Normalize for peak detection
    dist_norm = cv2.normalize(dist_transform, None, 0, 1.0, cv2.NORM_MINMAX)
    
    # Threshold to get peaks
    _, peaks = cv2.threshold(dist_norm, 0.4, 1.0, cv2.THRESH_BINARY)
    
    peaks = np.uint8(peaks * 255)
    
    # Find contours on peaks instead
    #contours, _ = cv2.findContours(peaks, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
    # --- STEP 1: finde vollständige Objekte ---
    contours, _ = cv2.findContours(opened_image, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

  
    centroids = []
    processed_image = image_array.copy()
    #if map_hull is not None:
    #    cv2.polylines(processed_image, [map_hull], True, (0,255,0), 2)

    # Definiere Farbbereiche in BGR
    color_ranges = {
        'red': (np.array([0, 0, 150]), np.array([120, 120, 255])),
        'blue': (np.array([150, 0, 0]), np.array([255, 120, 120])),
        'green': (np.array([0, 150, 0]), np.array([120, 255, 120])),
        'yellow': (np.array([0, 150, 150]), np.array([120, 255, 255])),
        'orange': (np.array([0, 80, 150]), np.array([120, 180, 255])),
        'magenta': (np.array([150, 0, 150]), np.array([255, 120, 255]))
    }

    for contour in contours:
          # 🔥 NEU: prüfe ob Kontur mehrere Punkte enthält
        if df_existing is not None:
            if contour_contains_multiple_existing_points(contour, df_existing):
                continue
        #color_count = count_color_pixels(image_array, contour, color_ranges)
        dominant_color = None

        if df_existing is not None and not df_existing.empty:
            for _, row in df_existing.iterrows():
                px = int(row["X_WGS84"])
                py = int(row["Y_WGS84"])
        
                inside = cv2.pointPolygonTest(contour, (px, py), False)
        
                if inside >= 0:
                    # 🔥 Farbe direkt übernehmen
                    r = int(row["Red"])
                    g = int(row["Green"])
                    b = int(row["Blue"])
        
                    if r > 200 and g < 100 and b < 100:
                        dominant_color = 'red'
                    elif b > 200 and r < 100 and g < 100:
                        dominant_color = 'blue'
                    elif g > 200 and r < 100 and b < 100:
                        dominant_color = 'green'
                    else:
                        dominant_color = 'unknown'
        
                    break

        # Wähle die entsprechende BGR-Farbe
        # Richtiges BGR-zu-RGB-Mapping für das Zeichnen
        if dominant_color == 'red':
            color_rgb = (0, 0, 255)

        elif dominant_color == 'blue':
            color_rgb = (255, 0, 0)
        
        elif dominant_color == 'green':
            color_rgb = (0, 255, 0)
        
        elif dominant_color == 'yellow':
            color_rgb = (0, 255, 255)
        
        elif dominant_color == 'orange':
            color_rgb = (0, 165, 255)
        
        elif dominant_color == 'magenta':
            color_rgb = (255, 0, 255)
        
        else:
            color_rgb = (0, 0, 255)

        # Zeichne die Konturen und Zentroide
        M = cv2.moments(contour)
        if M["m00"] != 0:
            cx = int(M["m10"] / M["m00"])
            cy = int(M["m01"] / M["m00"])
            # NEW: remove points outside map
            inside = point_inside_map(cx, cy, map_hull)

            if inside:
                # normaler Punkt
                cv2.drawContours(processed_image, [contour], -1, color_rgb, -1)
                cv2.circle(processed_image, (cx, cy), 5, color_rgb, -1)
            
                centroids.append((cx, cy, color_rgb[2], color_rgb[1], color_rgb[0]))

            else:
                # Ausreißer
                cv2.circle(processed_image, (cx, cy), 5, (160,160,160), -1)
    
    output_file = os.path.join(outdir, os.path.basename(tiffile))
    PIL.Image.fromarray(processed_image, 'RGB').save(output_file)
    
    return centroids, output_file

# Initialize CSV file for storing coordinates
def initialize_csv_file(csv_file_path, x_col, y_col):
    if not os.path.exists(csv_file_path):
        with open(csv_file_path, 'w') as file:
            file.write(f"ID,File,Detection method,{x_col},{y_col},georef,template,Red,Green,Blue\n")
    return csv_file_path


def template_matching(image_path, template_path, method=cv2.TM_CCOEFF_NORMED):
    bw_image = convert_to_black_and_white(image_path)
    bw_template = convert_to_black_and_white(template_path)
    result, max_loc = cv2.matchTemplate(bw_image, bw_template, method)
    _, _, _, max_loc = cv2.minMaxLoc(result)
    return result, max_loc
  
  
# ------------------------------------------------------------
# Filter contours containing multiple known points
# ------------------------------------------------------------
# Purpose:
# Avoid merging multiple detections into a single centroid.
#
# Logic:
# - Check how many existing points lie within the contour
# - If >= 2 → discard contour
#
# Result:
# - Prevents incorrect centroid merging
# ------------------------------------------------------------
def contour_contains_multiple_existing_points(contour, df_existing, threshold=5):

    if df_existing.empty:
        return False

    count = 0

    for _, row in df_existing.iterrows():
        px = int(row["X_WGS84"])
        py = int(row["Y_WGS84"])

        # Prüfe ob Punkt in Kontur liegt
        inside = cv2.pointPolygonTest(contour, (px, py), False)

        if inside >= 0:
            count += 1

        if count >= 2:
            return True  # 🔥 mehrere Punkte → ignorieren

    return False
  

# ------------------------------------------------------------
# Main workflow: point filtering for all map types
# ------------------------------------------------------------
# This function orchestrates the refinement of detected points.
#
# Workflow:
# 1. Iterate over all map type directories
# 2. Load previously detected points (if available)
# 3. Load map boundary (optional)
# 4. Process each map image:
#    - detect centroids
#    - classify colors
#    - filter invalid detections
# 5. Store refined points in CSV
#
# Key features:
# - Incremental ID assignment across runs
# - Reuse of existing template-color associations
# - Fallback handling for unknown templates
#
# Output:
# output/<type>/maps/pointFiltering/
# output/<type>/maps/csvFiles/coordinates.csv
#
# This step significantly improves the spatial accuracy
# and reliability of detected point data.
# ------------------------------------------------------------
def main_point_filtering(working_dir, output_dir, kernel_size, blur_radius, nMapTypes=1):
    """
    Process point filtering for multiple map types (1 or 2).
    Processes all TIFF files in <output_dir>/maps/pointMatching/ and saves results in <output_dir>/maps/pointFiltering/.

    Args:
        working_dir (str): Base working directory.
        output_dir (str): Output directory (e.g., output_2025-09-26_13-16-11).
        kernel_size (int): Size of the morphological kernel.
        blur_radius (int): Radius for Gaussian blur.
        nMapTypes (int): Number of map types (1 or 2). Used to limit processing.
    """
    # --- Finde alle map-type Ordner ---
    map_type_dirs = []
    for name in os.listdir(output_dir):
        full = os.path.join(output_dir, name)
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
        input_tif_dir = os.path.join(map_dir, "maps", "pointMatching")
        output_tif_dir_type = os.path.join(map_dir, "maps", "pointFiltering")
        csv_dir_type = os.path.join(map_dir, "maps", "csvFiles")

        os.makedirs(output_tif_dir_type, exist_ok=True)
        os.makedirs(csv_dir_type, exist_ok=True)

        # CSV-Datei für diesen Typ
        csv_path_type = os.path.join(csv_dir_type, "coordinates.csv")
        existing_templates = {}
        df_existing = None
        if os.path.exists(csv_path_type):
          
            df_existing = pd.read_csv(csv_path_type)
            
            with open(csv_path_type, 'r') as file:
                reader = csv.DictReader(file)
                for row in reader:

                    # 🔴 Header oder kaputte Zeilen überspringen
                    if not row['Red'].isdigit():
                        continue
                
                    key = (int(row['Red']), int(row['Green']), int(row['Blue']))
                
                    if row['template'] != 'none':
                        existing_templates[key] = row['template']
        current_id = get_last_id(csv_path_type) + 1

        with open(csv_path_type, "a", newline="") as coord_csvfile:

            coord_fieldnames = [
                "ID", "File", "Detection method",
                "X_WGS84", "Y_WGS84", "template",
                "Red", "Green", "Blue",'score', "georef"
            ]
            coord_writer = csv.DictWriter(coord_csvfile, fieldnames=coord_fieldnames)

            if current_id == 1:
                coord_writer.writeheader()

            points_dir = os.path.join(
                working_dir,
                "data",
                "input",
                "templates",
                map_type,
                "geopoints"
            )
            
            points_files = glob.glob(os.path.join(points_dir, "*.points"))
            
            map_hull = None
            
            if points_files:
                map_hull = load_map_hull(points_files[0])
    
    
            # --- Alle TIFs verarbeiten ---
            for file in glob.glob(os.path.join(input_tif_dir, "*.tif")):
                print(f"Processing: {os.path.basename(file)}")
                centroids, output_file = detect_edges_and_centroids(file, output_tif_dir_type, int(kernel_size), int(blur_radius),  map_hull, df_existing=df_existing)
                
                
                print("Centroids detected:")
                if centroids:
                  for centroid in centroids:
                    color_key = (centroid[2], centroid[3], centroid[4])
                    assigned_template = existing_templates.get(color_key, "none")
        
                    if assigned_template == "none":
                          assigned_template = "unknown_1"
                    coord_writer.writerow({
                        'ID': current_id,
                        'File': os.path.basename(file),
                        'Detection method': 'point_filtering',
                        'X_WGS84': centroid[0],
                        'Y_WGS84': centroid[1],
                        'template': assigned_template,
                        'Red': centroid[2],
                        'Green': centroid[3],
                        'Blue': centroid[4],
                        'score': 0,   # 🔥 FIX
                        'georef': 0
                    })
                    current_id += 1
                
                if not centroids:
                  print("No centroids found for:", os.path.basename(file))
    print("\n✓ Point filtering completed for all map types.")
