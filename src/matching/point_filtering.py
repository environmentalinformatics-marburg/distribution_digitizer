import cv2
import PIL
from PIL import Image
import os.path
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
    mask = np.zeros(image.shape[:2], dtype=np.uint8)
    cv2.drawContours(mask, [contour], -1, 255, -1)
    mean_val = cv2.mean(image, mask=mask)
    return (int(mean_val[2]), int(mean_val[1]), int(mean_val[0]))  # Return as (R, G, B)

# Function to convert RGB to hex
def rgb_to_hex(rgb_color):
    return '#{:02x}{:02x}{:02x}'.format(rgb_color[0], rgb_color[1], rgb_color[2])

# Function to determine if a color is considered red, blue, or green
def determine_color(rgb_color):
    hex_color = rgb_to_hex(rgb_color)
    red_hex = '#FF0000'
    blue_hex = '#0000FF'
    green_hex = '#00FF00'
    if rgb_color[0] > 150 and rgb_color[1] < 100 and rgb_color[2] < 100:
        return 'red', red_hex
    elif rgb_color[0] < 100 and rgb_color[1] < 100 and rgb_color[2] > 150:
        return 'blue', blue_hex
    elif rgb_color[0] < 100 and rgb_color[1] > 150 and rgb_color[2] < 100:
        return 'green', green_hex
    else:
        return 'orange', '#FFa500'  # Hex color for orange

# Edge and Contour Detection
def detect_edges_and_centroids(tiffile, outdir, kernel_size, blur_radius):
    image_array = np.array(PIL.Image.open(tiffile))

    # Mask existing red, blue, and green circles
    image_array = mask_existing_circles(image_array)

    gray_image = cv2.cvtColor(image_array, cv2.COLOR_BGR2GRAY)
    gray_image = cv2.GaussianBlur(gray_image, (blur_radius, blur_radius), 0)
    
    _, thresh_image = cv2.threshold(gray_image, 120, 255, cv2.THRESH_TOZERO_INV)
    
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (kernel_size, kernel_size))
    opened_image = cv2.morphologyEx(thresh_image, cv2.MORPH_OPEN, kernel, iterations=3)
    
    contours, _ = cv2.findContours(opened_image, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
    
    centroids = []  # List to store centroids and colors
    
    processed_image = image_array.copy()  # Create a copy of the original image
    for contour in contours:
        # Calculate the centroid of the contour
        moments = cv2.moments(contour)
        if moments["m00"] != 0:
            centroid_x = int(moments["m10"] / moments["m00"])
            centroid_y = int(moments["m01"] / moments["m00"])
            
            # Determine the color of the contour
            contour_color = get_contour_color(image_array, contour)
            color_name, hex_color = determine_color(contour_color)
            color_bgr = (0, 0, 255)  # Default to red (if color_name is 'orange')
            if color_name == 'red':
                color_bgr = (0, 0, 255)
            elif color_name == 'blue':
                color_bgr = (255, 0, 0)
            elif color_name == 'green':
                color_bgr = (0, 255, 0)
            elif color_name == 'orange':
                color_bgr = (255,127,36)

            # Append centroid to the list with its color
            centroids.append((centroid_x, centroid_y, hex_color))
            
            # Draw the contour and centroid in the appropriate color
            processed_image = cv2.drawContours(processed_image, [contour], -1, color_bgr, 3)
            cv2.circle(processed_image, (centroid_x, centroid_y), 5, color_bgr, -1)

    # Save the image with contours and centroids
    output_file = os.path.join(outdir, os.path.basename(tiffile))
    PIL.Image.fromarray(processed_image, 'RGB').save(output_file)
    
    return centroids, output_file

# Initialize CSV file for storing coordinates
def initialize_csv_file(csv_file_path, x_col, y_col):
    if not os.path.exists(csv_file_path):
        with open(csv_file_path, 'w') as file:
            file.write(f"ID,File,Detection method,{x_col},{y_col},georef,template,color\n")
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
    
    # Open the file in append mode and add the new line
    with open(csv_file_path, 'a', newline='') as file:
        writer = csv.writer(file)
        if last_id == 0:
            writer.writerow(['ID', 'File', 'Detection method', 'X_WGS84', 'Y_WGS84', 'template', 'number_points', 'color', 'georef'])
        for centroid in centroids:
            writer.writerow([last_id + 1, filename, method, centroid[0], centroid[1], template, len(centroids), centroid[2], georef])
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

    csv_path = os.path.join(output_dir, "maps/csvFiles/", "coordinats.csv")
    initialize_csv_file(csv_path, "X_WGS84", "Y_WGS84")
    
    for file in glob.glob(input_dir + '*.tif'):
        print(file)
        centroids, output_file = detect_edges_and_centroids(file, output_tif_dir, int(kernel_size), int(blur_radius))
        print("Centroids detected:")
        if centroids:
            append_to_csv(csv_path, centroids, os.path.basename(file), "point_filtering", 0, "none")
        else:
            PIL.Image.fromarray(np.array(PIL.Image.open(file)), 'RGB').save(output_file)
