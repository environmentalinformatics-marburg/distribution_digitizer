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
            lines = [line.strip() for line in csvfile.readlines() if line.strip()]

        # Keine Datenzeilen? (nur header)
        if len(lines) <= 1:
            return 0

        # Letzte Zeile (unterste Datenzeile)
        last_line = lines[-1]

        first_value = last_line.split(',')[0].strip()

        # Falls versehentlich Text statt Zahl → ID = 0
        if not first_value.isdigit():
            return 0

        return int(first_value)

    except FileNotFoundError:
        return 0
    except Exception as e:
        print("get_last_id() error:", e)
        return 0


def map_points_matching(workingDir, outDir, point_threshold):
    print("Points matching:")

    # --- finde Ordner 1, 2, 3 ... im Output ---
    map_type_dirs = []
    for name in os.listdir(outDir):
        full = os.path.join(outDir, name)
        if os.path.isdir(full) and name.isdigit():
            map_type_dirs.append(full)

    if not map_type_dirs:
        print("⚠️ No map-type folders found in output/")
        return

    # --- jeden map-type Ordner einzeln verarbeiten ---
    for map_dir in map_type_dirs:
        map_type = os.path.basename(map_dir)  # "1", "2", "3", ...
        print(f"\n=== Processing map type folder: {map_type} ===")

        # Templates für diesen Typ:
        pointTemplates = os.path.join(workingDir, "data", "input", "templates", map_type, "symbols")

        print("TEMPLATE PATH:", pointTemplates)
        print("TEMPLATES FOUND:", glob.glob(os.path.join(pointTemplates, "*.tif")))

        inputTiffDir  = os.path.join(map_dir, "maps", "align")
        outputTiffDir = os.path.join(map_dir, "maps", "pointMatching")
        csvDir        = os.path.join(map_dir, "maps", "csvFiles")

        os.makedirs(outputTiffDir, exist_ok=True)
        os.makedirs(csvDir, exist_ok=True)

        copy_tiff_images(inputTiffDir, outputTiffDir)

        coord_csv_path = os.path.join(csvDir, "coordinates.csv")
        current_id = get_last_id(coord_csv_path) + 1

        with open(coord_csv_path, "a", newline="") as coord_csvfile:
            coord_fieldnames = [
                "ID", "File", "Detection method",
                "X_WGS84", "Y_WGS84", "template",
                "Red", "Green", "Blue", "georef"
            ]
            coord_writer = csv.DictWriter(coord_csvfile, fieldnames=coord_fieldnames)

            if current_id == 1:
                coord_writer.writeheader()

            # --- alle Templates für diesen map_type durchgehen ---
            for file in glob.glob(os.path.join(pointTemplates, "*.tif")):
                template_name = os.path.basename(file).rsplit(".", 1)[0]
                print(f"Processing template: {template_name} — {file}")

                # Default-Farbkodierung (optional)
                if template_name.startswith('b_'):
                    color = '#0000FF'
                elif template_name.startswith('a_'):
                    color = '#FF0000'
                elif template_name.startswith('c_'):
                    color = '#00FF00'
                else:
                    color = '#FFFFFF'

                # --- Matching auf alle align-TIFs anwenden ---
                for tiffile in glob.glob(os.path.join(outputTiffDir, "*.tif")):
                    num_points, output_file_path, color_str, current_id = point_match(
                        tiffile, file, outputTiffDir, point_threshold,
                        template_id=1,
                        template_name=template_name,
                        color=color,
                        coord_writer=coord_writer,
                        current_id=current_id
                    )

    print("\n✓ Point-matching completed for all map types.")



# Usage example:
#
#map_points_matching("D:/distribution_digitizer/", "D:/test/output_2025-11-28_14-08-49/", 0.75)
