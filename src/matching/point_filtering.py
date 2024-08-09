"""
Author: Spaska Forteva
Last modified on 2024-08-09 by Spaska Forteva:
Description: This script processes images to detect and mask centroids of specific colors (red, blue, green) in TIFF files. 
It applies various image processing techniques, including color filtering, contour detection, and template matching, and logs the results in a CSV file.
"""

import cv2
import PIL
from PIL import Image
import os
import glob
import numpy as np
import csv

# Function to convert image to black and white
def convert_to_black_and_white(image_path):
    image = cv2.imread(image_path)
    gray_image = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    _, bw_image = cv2.threshold(gray_image, 128, 255, cv2.THRESH_BINARY)
    return bw_image

# Function to mask existing red, blue, and green circles
def mask_existing_circles(image_array):
    hsv_image = cv2.cvtColor(image_array, cv2.COLOR_RGB2HSV)

    # Define color ranges for red, blue, and green in HSV
    lower_red = np.array([0, 100, 100])
    upper_red = np.array([10, 255, 255])
    lower_blue = np.array([110, 100, 100])
    upper_blue = np.array([130, 255, 255])
    lower_green = np.array([50, 100, 100])
    upper_green = np.array([70, 255, 255])

    # Create masks for red, blue, and green
    mask_red = cv2.inRange(hsv_image, lower_red, upper_red)
    mask_blue = cv2.inRange(hsv_image, lower_blue, upper_blue)
    mask_green = cv2.inRange(hsv_image, lower_green, upper_green)

    # Combine masks
    combined_mask = cv2.bitwise_or(mask_red, mask_blue)
    combined_mask = cv2.bitwise_or(combined_mask, mask_green)

    # Invert mask
    inverted_mask = cv2.bitwise_not(combined_mask)

    # Apply inverted mask to the image
    masked_image = cv2.bitwise_and(image_array, image_array, mask=inverted_mask)
    
    # Combine masked image with original to keep original colors where the mask is applied
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

def determine_color(color_count, threshold=3):
    for color, count in color_count.items():
        if count >= threshold:
            return color
    return 'orange'

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

def detect_edges_and_centroids(tiffile, outdir, kernel_size, blur_radius):
    image_array = np.array(PIL.Image.open(tiffile))
    image_array = mask_existing_circles(image_array)
    gray_image = cv2.cvtColor(image_array, cv2.COLOR_BGR2GRAY)
    gray_image = cv2.GaussianBlur(gray_image, (blur_radius, blur_radius), 0)
    _, thresh_image = cv2.threshold(gray_image, 120, 255, cv2.THRESH_TOZERO_INV)
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (kernel_size, kernel_size))
    opened_image = cv2.morphologyEx(thresh_image, cv2.MORPH_OPEN, kernel, iterations=3)
    contours, _ = cv2.findContours(opened_image, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
    
    centroids = []
    processed_image = image_array.copy()

    # Definiere Farbbereiche in BGR
    color_ranges = {
        'red': (np.array([0, 0, 150]), np.array([100, 100, 255])),
        'blue': (np.array([150, 0, 0]), np.array([255, 100, 100])),
        'green': (np.array([0, 150, 0]), np.array([100, 255, 100]))
    }

    for contour in contours:
        color_count = count_color_pixels(image_array, contour, color_ranges)
        dominant_color = determine_color(color_count)

        # Wähle die entsprechende BGR-Farbe
        # Richtiges BGR-zu-RGB-Mapping für das Zeichnen
        if dominant_color == 'red':
            color_rgb = (0, 0, 255)
        elif dominant_color == 'blue':
            color_rgb = (255, 0, 0)
        elif dominant_color == 'green':
            color_rgb = (0, 255, 0)
        else:
            color_rgb = (255, 165, 0)  # Orange als Fallback

        # Zeichne die Konturen und Zentroide
        M = cv2.moments(contour)
        if M["m00"] != 0:
            cx = int(M["m10"] / M["m00"])
            cy = int(M["m01"] / M["m00"])
            cv2.drawContours(processed_image, [contour], -1, color_rgb, 3)
            cv2.circle(processed_image, (cx, cy), 5, color_rgb, -1)
            # Stelle sicher, dass die BGR-Werte korrekt in die CSV geschrieben werden
            centroids.append((cx, cy, color_rgb[2], color_rgb[1], color_rgb[0]))  # Append in RGB format

    output_file = os.path.join(outdir, os.path.basename(tiffile))
    PIL.Image.fromarray(processed_image, 'RGB').save(output_file)
    
    return centroids, output_file

# Initialize CSV file for storing coordinates
def initialize_csv_file(csv_file_path, x_col, y_col):
    if not os.path.exists(csv_file_path):
        with open(csv_file_path, 'w') as file:
            file.write(f"ID,File,Detection method,{x_col},{y_col},georef,template,Red,Green,Blue\n")
    return csv_file_path

# Append coordinates to CSV file
def append_to_csv(csv_file_path, centroids, filename, method, georef, template='none'):
    if not os.path.exists(csv_file_path):
        initialize_csv_file(csv_file_path, "X_WGS84", "Y_WGS84")
        last_id = 0
    else:
        with open(csv_file_path, 'r') as file:
            lines = file.readlines()
            if len(lines) > 1:  # Skip header line
                last_line = lines[-1]
                last_id = int(last_line.split(',')[0])  # Read last ID
            else:
                last_id = 0
    
    existing_templates = {}
    with open(csv_file_path, 'r') as file:
        reader = csv.DictReader(file)
        for row in reader:
            if row['template'] != 'none':
                key = (int(row['Red']), int(row['Green']), int(row['Blue']))
                existing_templates[key] = row['template']
    
    # Open the file in append mode and add the new line
    with open(csv_file_path, 'a', newline='') as file:
        writer = csv.writer(file)
        if last_id == 0:
            writer.writerow(['ID', 'File', 'Detection method', 'X_WGS84', 'Y_WGS84', 'template', 'Red', 'Green', 'Blue', 'georef'])
        for centroid in centroids:
            color_key = (centroid[2], centroid[3], centroid[4])
            assigned_template = existing_templates.get(color_key, template)
            writer.writerow([last_id + 1, filename, method, centroid[0], centroid[1], assigned_template, centroid[2], centroid[3], centroid[4], georef])
            last_id += 1

def template_matching(image_path, template_path, method=cv2.TM_CCOEFF_NORMED):
    bw_image = convert_to_black_and_white(image_path)
    bw_template = convert_to_black_and_white(template_path)
    result, max_loc = cv2.matchTemplate(bw_image, bw_template, method)
    _, _, _, max_loc = cv2.minMaxLoc(result)
    return result, max_loc

def main_point_filtering(working_dir, output_dir, kernel_size, blur_radius):
    input_dir = os.path.join(output_dir, "maps/pointMatching/")
    output_tif_dir = os.path.join(output_dir, "maps/pointFiltering/")
    os.makedirs(output_tif_dir, exist_ok=True)

    csv_path = os.path.join(output_dir, "maps/csvFiles/", "coordinates.csv")
    initialize_csv_file(csv_path, "X_WGS84", "Y_WGS84")
    
    for file in glob.glob(input_dir + '*.tif'):
        print(file)
        centroids, output_file = detect_edges_and_centroids(file, output_tif_dir, int(kernel_size), int(blur_radius))
        print("Centroids detected:")
        if centroids:
            append_to_csv(csv_path, centroids, os.path.basename(file), "point_filtering", 0, "none")
        else:
            PIL.Image.fromarray(np.array(PIL.Image.open(file)), 'RGB').save(output_file)

# Usage example:
# main_point_filtering("D:/distribution_digitizer/", "D:/test/output_2024-07-12_08-18-21/", 9, 5)
