# Author: Spaska Forteva
# Date: 2024-08-02
# Update 2025-02-28 (Fehler in py_call_impl(callable, call_args$unnamed, call_args$named) Line 70-78
# Description: This script performs point matching between TIFF images and templates, 
# applies non-maximum suppression, and saves the results. It also includes a function to copy TIFF images and convert colors.


import cv2
import PIL
from PIL import Image
import os
import glob
import numpy as np
import csv
import shutil

def copy_tiff_images(input_dir, output_dir):
    # Create the output directory if it does not exist
    os.makedirs(output_dir, exist_ok=True)
    for file in os.listdir(input_dir):
        if file.endswith(".tif"):
            source_path = os.path.join(input_dir, file)
            dest_path = os.path.join(output_dir, file)
            shutil.copyfile(source_path, dest_path)

def non_max_suppression_fast(points, overlapThresh):
    if len(points) == 0:
        return []

    if points.dtype.kind == "i":
        points = points.astype("float")

    pick = []
    x1 = points[:, 0]
    y1 = points[:, 1]
    x2 = x1 + points[:, 2]
    y2 = y1 + points[:, 3]

    area = (x2 - x1 + 1) * (y2 - y1 + 1)
    idxs = np.argsort(y2)

    while len(idxs) > 0:
        last = len(idxs) - 1
        i = idxs[last]
        pick.append(i)

        xx1 = np.maximum(x1[i], x1[idxs[:last]])
        yy1 = np.maximum(y1[i], y1[idxs[:last]])
        xx2 = np.minimum(x2[i], x2[idxs[:last]])
        yy2 = np.minimum(y2[i], y2[idxs[:last]])

        w = np.maximum(0, xx2 - xx1 + 1)
        h = np.maximum(0, yy2 - yy1 + 1)

        overlap = (w * h) / area[idxs[:last]]

        idxs = np.delete(idxs, np.concatenate(([last], np.where(overlap > overlapThresh)[0])))

    return points[pick].astype("int")

def hex_to_rgb(hex_color):
    """ Convert hex color to RGB tuple. """
    hex_color = hex_color.lstrip('#')
    return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))

def point_match(tiffile, file, outputpcdir, point_threshold, template_id, template_name, color, coord_writer, current_id, nms_thresh=0.3):
    print(f"Processing template: {template_name} with color: {color}")  # Debugging output
    
    # Load the image and the template
    img = np.array(PIL.Image.open(tiffile))
    tmp = np.array(PIL.Image.open(file))
    
    w, h = tmp.shape[:2]  # Adjusted to handle grayscale and RGB images

    # Perform template matching
    res = cv2.matchTemplate(img, tmp, cv2.TM_CCOEFF_NORMED)
    loc = np.where(res >= point_threshold)

    points = []
    for pt in zip(*loc[::-1]):
        points.append([pt[0], pt[1], w, h])
    points = np.array(points)

    # Apply non-maximum suppression
    nms_points = non_max_suppression_fast(points, nms_thresh)

    # Convert hex color to RGB format
    red, green, blue = hex_to_rgb(color)
    print(f"Converted color for {template_name}: (R: {red}, G: {green}, B: {blue})")  # Debugging output

    detected_points = []
    for (x, y, w, h) in nms_points:
        center_x = x + w // 2
        center_y = y + h // 2
        radius = min(w, h) // 4
        
        # Debugging output just before drawing
        #print(f"Drawing circle at ({center_x}, {center_y}) with color: (R: {red}, G: {green}, B: {blue})")
        
        # Draw the circle on the image
        cv2.circle(img, (center_x, center_y), radius, (red, green, blue), -1, lineType=cv2.LINE_AA)  # Fill the circle
        cv2.circle(img, (center_x, center_y), radius, (red, green, blue), 2, lineType=cv2.LINE_AA)   # Outline the circle
        
        detected_points.append((center_x, center_y))
        if detected_points:
            print(f"Matched at ({center_x}, {center_y}) with color: (R: {red}, G: {green}, B: {blue})")  # Debugging output
            coord_writer.writerow({
                'ID': current_id,
                'File': os.path.basename(tiffile),
                'Detection method': 'point_matching',
                'X_WGS84': center_x,
                'Y_WGS84': center_y,
                'template': template_name,
                'Red': red,
                'Green': green,
                'Blue': blue,
                'georef': 0
            })
            current_id += 1
        else:
            print(f"No points finding")  # Debugging output
            coord_writer.writerow({
                'ID': current_id,
                'File': os.path.basename(tiffile),
                'Detection method': 'point_matching',
                'X_WGS84': 0,
                'Y_WGS84': 0,
                'template': template_name,
                'Red': 0,
                'Green': 0,
                'Blue': 0,
                'georef': 0
            })
            current_id += 1

    # save the image in "pointMatching"
    base_name = os.path.basename(tiffile).rsplit('.', 1)[0]
    new_file_name = f"{base_name}.tif"
    output_file_path = os.path.join(outputpcdir, new_file_name)
    PIL.Image.fromarray(img).save(output_file_path)
    
    if detected_points:
        return len(detected_points), output_file_path, color, current_id
 
    return 0, output_file_path, color, current_id

def get_last_id(csv_path):
    try:
        with open(csv_path, 'r') as csvfile:
            last_line = csvfile.readlines()[-1]
            last_id = int(last_line.split(',')[0])
            return last_id
    except (IndexError, FileNotFoundError):
        return 0

def map_points_matching(workingDir, outDir, point_threshold):
    print("Points matching:")
    outputTiffDir = ""
    inputTiffDir = ""
    if os.path.exists(outDir):
        inputTiffDir = os.path.join(outDir, "maps", "align")
        outputTiffDir = os.path.join(outDir, "maps", "pointMatching")
    else:
        inputTiffDir = os.path.join(workingDir, "data", "output", "maps", "align")
        outputTiffDir = os.path.join(workingDir, "data", "output", "maps", "pointMatching")

    pointTemplates = os.path.join(workingDir, "data", "input/templates/symbols/")
    copy_tiff_images(inputTiffDir, outputTiffDir)
    os.makedirs(outputTiffDir, exist_ok=True)

    coord_csv_path = os.path.join(outDir, 'maps', 'csvFiles', 'coordinates.csv')

    current_id = get_last_id(coord_csv_path) + 1

    with open(coord_csv_path, 'a', newline='') as coord_csvfile:
        coord_fieldnames = ['ID', 'File', 'Detection method', 'X_WGS84', 'Y_WGS84', 'template', 'Red', 'Green', 'Blue', 'georef']
        coord_writer = csv.DictWriter(coord_csvfile, fieldnames=coord_fieldnames)

        if current_id == 1:
            coord_writer.writeheader()

        for file in glob.glob(os.path.join(pointTemplates, '*.tif')):
            template_name = os.path.basename(file).rsplit('.', 1)[0]
            color = "#000000"
            # Updated color mapping including white for non-matching templates
            if template_name.startswith('b_'):
                color = '#0000FF'  # Blue
            elif template_name.startswith('a_'):
                color = '#FF0000'  # Red
            elif template_name.startswith('c_'):
                color = '#00FF00'  # Green
            #elif template_name.startswith('d_'):
            #    color = '#FFA500'  # Orange
           # elif template_name.startswith('e_'):
            #    color = '#FFFF00'  # Yellow
           # else:
            #    color = '#FFFFFF'  # White

            print(f"Processing template: {template_name}, Color: {color}")  # Debugging line to check the template and color

            for tiffile in glob.glob(os.path.join(outputTiffDir, '*.tif')):
                num_points, output_file_path, color_str, current_id = point_match(
                    tiffile, file, outputTiffDir, point_threshold, 1, template_name, color, coord_writer, current_id)

# Usage example:
#
# map_points_matching("D:/distribution_digitizer/", "D:/test/output_2024-07-12_08-18-21/", 0.75)
