# ============================================================
# File: point_matching.py
# Author: Spaska Forteva
# Last updated on: 2026-03-31
#
# Description:
# This script detects and extracts point symbols (e.g., species
# occurrence markers) from previously aligned distribution maps.
#
# The detection is based on template matching using predefined
# symbol templates (e.g., red, blue, green markers).
#
# Core functionality:
# - Detect symbol locations using normalized cross-correlation
# - Apply non-maximum suppression to remove duplicate detections
# - Validate uncertain detections using partial matching
# - Assign colors and template labels to detected points
# - Store results as CSV (coordinates + attributes)
# - Visualize detections directly on the map image
#
# The output is used for further processing steps such as:
# - polygonization
# - spatial analysis
# - georeferencing
#
# Key design goals:
# - Robust detection across varying image quality
# - Avoid duplicate detections
# - Maintain full traceability (template, color, position)
# ============================================================

import cv2
import os
import glob
import numpy as np
import csv
import shutil

# ------------------------------------------------------------
# Define color mapping for each symbol type
# ------------------------------------------------------------
# Each template is associated with a specific color.
# This mapping is used to:
# - visualize detected points on the map
# - store RGB values in the output CSV
# ------------------------------------------------------------
COLOR_MAP = {
    "red": "#FF0000",
    "green": "#00FF00",
    "blue": "#0000FF",
    "yellow": "#FFFF00",
    "orange": "#FFA500",
    "magenta": "#FF00FF"
}


# ------------------------------------------------------------
# Copy aligned map images into working directory
# ------------------------------------------------------------
# This step ensures that:
# - original aligned images remain unchanged
# - point detection is performed on a working copy
#
# This avoids accidental overwriting of previous results
# and enables reproducibility of the workflow.
# ------------------------------------------------------------
def copy_tiff_images(input_dir, output_dir):

    os.makedirs(output_dir, exist_ok=True)

    for file in os.listdir(input_dir):
        if file.endswith(".tif"):
            shutil.copyfile(
                os.path.join(input_dir, file),
                os.path.join(output_dir, file)
            )
            

# ------------------------------------------------------------
# Non-Maximum Suppression (NMS)
# ------------------------------------------------------------
# Purpose:
# Template matching often produces multiple overlapping detections
# for the same symbol. This function removes redundant detections
# and keeps only the strongest (most relevant) ones.
#
# Method:
# - Sort bounding boxes by position
# - Iteratively remove overlapping boxes based on overlap threshold
#
# Result:
# - Cleaner and more reliable point detections
# - Reduced false positives and duplicates
# ------------------------------------------------------------
def non_max_suppression_fast(points, overlapThresh):

    if len(points) == 0:
        return []

    if points.dtype.kind == "i":
        points = points.astype("float")

    pick = []

    x1 = points[:,0]
    y1 = points[:,1]
    x2 = x1 + points[:,2]
    y2 = y1 + points[:,3]

    area = (x2-x1+1)*(y2-y1+1)

    idxs = np.argsort(y2)

    while len(idxs) > 0:

        last = len(idxs)-1
        i = idxs[last]

        pick.append(i)

        xx1 = np.maximum(x1[i], x1[idxs[:last]])
        yy1 = np.maximum(y1[i], y1[idxs[:last]])
        xx2 = np.minimum(x2[i], x2[idxs[:last]])
        yy2 = np.minimum(y2[i], y2[idxs[:last]])

        w = np.maximum(0, xx2-xx1+1)
        h = np.maximum(0, yy2-yy1+1)

        overlap = (w*h)/area[idxs[:last]]

        idxs = np.delete(
            idxs,
            np.concatenate(([last], np.where(overlap>overlapThresh)[0]))
        )

    return points[pick].astype("int")
  

# ------------------------------------------------------------
# Convert HEX color to RGB format
# ------------------------------------------------------------
# Required for OpenCV visualization and CSV storage.
# ------------------------------------------------------------
def hex_to_rgb(hex_color):

    hex_color = hex_color.lstrip('#')

    return tuple(
        int(hex_color[i:i+2],16) for i in (0,2,4)
    )
    

# ------------------------------------------------------------
# Detect symbol points using template matching
# ------------------------------------------------------------
# Core idea:
# Identify occurrences of a given symbol template within a map
# using normalized cross-correlation.
#
# Key steps:
# - Convert map and template to grayscale
# - Apply Gaussian smoothing to reduce noise
# - Perform template matching (cv2.matchTemplate)
# - Extract candidate locations above threshold
#
# Additional robustness:
# - Partial matching check allows detection of slightly degraded symbols
# - Non-maximum suppression removes duplicate detections
# - Spatial filtering avoids overlapping detections across templates
#
# Output:
# - Draw detected points on the map image
# - Store coordinates and attributes in CSV
#
# Important design decisions:
# - Only one detection per spatial neighborhood is kept
# - Better matches replace weaker ones
# - Color and template type are stored for later analysis
# ------------------------------------------------------------
def point_match(img_color, template_path, threshold, template_name, color, coord_writer, current_id, used_points,tiffile):

    img_gray = cv2.cvtColor(img_color, cv2.COLOR_BGR2GRAY)
    img_gray = cv2.GaussianBlur(img_gray, (3,3), 0)
    #kernel = np.ones((3,3), np.uint8)
    #img_gray = cv2.morphologyEx(img_gray, cv2.MORPH_OPEN, kernel)
   
    tmp_gray = cv2.imread(template_path, cv2.IMREAD_GRAYSCALE)
    tmp_gray = cv2.GaussianBlur(tmp_gray, (3,3), 0)
    h,w = tmp_gray.shape[:2]

    res = cv2.matchTemplate(img_gray, tmp_gray, cv2.TM_CCOEFF_NORMED)

    loc = np.where(res >= threshold)

    # zusätzlich: knapp darunter prüfen
    loc_partial = np.where((res >= threshold - 0.1) & (res < threshold))

    points = []

    for pt in zip(*loc[::-1]):
        x, y = pt
    
        if partial_match_ok(img_gray, tmp_gray, x, y, w, h, min_ratio=0.6):
            points.append([x, y, w, h])

    points = np.array(points)

    nms_points = non_max_suppression_fast(points,0.3)

    red,green,blue = hex_to_rgb(color)

    detected = 0

    for (x,y,w,h) in nms_points:

        center_x = x + w//2
        center_y = y + h//2

        score = res[y,x]

        skip=False
        replace_index=-1

        for i,(px,py,ps) in enumerate(used_points):

            if abs(center_x-px)<10 and abs(center_y-py)<10:

                if score>ps:
                    replace_index=i
                else:
                    skip=True

                break

        if skip:
            continue

        if replace_index>=0:
            used_points[replace_index]=(center_x,center_y,score)
        else:
            used_points.append((center_x,center_y,score))

        radius=min(w,h)//4

        cv2.circle(img_color,(center_x,center_y),int(radius),(blue,green,red),-1)

        coord_writer.writerow({
            "ID":current_id,
            "File": tiffile,
            "Detection method":"point_matching",
            "X_WGS84":center_x,
            "Y_WGS84":center_y,
            "template":template_name,
            "Red":red,
            "Green":green,
            "Blue":blue,
            "georef":0
        })

        current_id+=1
        detected+=1

    return img_color,detected,current_id


# ------------------------------------------------------------
# Validate uncertain matches using pixel comparison
# ------------------------------------------------------------
# Purpose:
# Allow detection of symbols that are slightly degraded or noisy.
#
# Method:
# - Compare template with image patch
# - Compute pixel-wise difference
# - Calculate ratio of matching pixels
#
# Result:
# - Improves robustness of detection
# - Reduces false negatives in low-quality scans
# ------------------------------------------------------------
def partial_match_ok(img_gray, tmp_gray, x, y, w, h, min_ratio=0.6):
    
    patch = img_gray[y:y+h, x:x+w]

    if patch.shape != tmp_gray.shape:
        return False

    # Differenzbild
    diff = cv2.absdiff(patch, tmp_gray)

    # kleine Unterschiede ignorieren
    _, diff_bin = cv2.threshold(diff, 30, 255, cv2.THRESH_BINARY_INV)

    # Anteil der passenden Pixel
    match_ratio = np.sum(diff_bin > 0) / (w * h)

    return match_ratio >= min_ratio
  
  
# ------------------------------------------------------------
# Main workflow: point detection for all map types
# ------------------------------------------------------------
# This function orchestrates the complete point matching process.
#
# Workflow:
# 1. Iterate over all map types (groups)
# 2. Load symbol templates for each group
# 3. Process all aligned map images
# 4. Detect symbol points for each template
# 5. Store results in CSV and visualize detections
#
# Key optimizations:
# - Reuse aligned maps (no re-loading from earlier stages)
# - Avoid duplicate detections using spatial filtering
# - Incremental CSV writing for large datasets
#
# Output structure:
# output/<type>/maps/pointMatching/
# output/<type>/maps/csvFiles/coordinates.csv
#
# Each detected point contains:
# - spatial position (X, Y)
# - template type
# - color information
# - detection method
#
# This step transforms raster-based symbol information
# into structured point data for further geospatial analysis.
# ------------------------------------------------------------
def map_points_matching(workingDir,outDir,threshold,nMapTypes=1):

    print("Points matching")

    map_type_dirs=[]

    for name in os.listdir(outDir):

        full=os.path.join(outDir,name)

        if os.path.isdir(full) and name.isdigit():
            map_type_dirs.append(full)

    map_type_dirs = map_type_dirs[:int(nMapTypes)]

    for map_dir in map_type_dirs:

        map_type=os.path.basename(map_dir)

       # print("Processing map type:",map_type)

        pointTemplates=os.path.join(
            workingDir,
            "data","input","templates",
            map_type,
            "symbols"
        )

        inputTiffDir=os.path.join(map_dir,"maps","align")
        outputTiffDir=os.path.join(map_dir,"maps","pointMatching")
        csvDir=os.path.join(map_dir,"maps","csvFiles")

        os.makedirs(outputTiffDir,exist_ok=True)
        os.makedirs(csvDir,exist_ok=True)

        copy_tiff_images(inputTiffDir,outputTiffDir)

        coord_csv_path=os.path.join(csvDir,"coordinates.csv")

        with open(coord_csv_path,"a",newline="") as coord_csvfile:

            coord_fieldnames=[
                "ID","File","Detection method",
                "X_WGS84","Y_WGS84","template",
                "Red","Green","Blue","georef"
            ]

            coord_writer=csv.DictWriter(coord_csvfile,fieldnames=coord_fieldnames)

            if coord_csvfile.tell()==0:
                coord_writer.writeheader()

            current_id=1

            for tiffile in glob.glob(os.path.join(outputTiffDir,"*.tif")):

                print("Processing map:",tiffile)

                img_color=cv2.imread(tiffile)

                used_points=[]

                for file in glob.glob(os.path.join(pointTemplates,"*.tif")):

                    template_name=os.path.basename(file).rsplit(".",1)[0]

                    color_name=template_name.split("_")[0].lower()

                    color=COLOR_MAP.get(color_name,"#FFFFFF")

                    img_color,num_points,current_id = point_match(
                        img_color,
                        file,
                        threshold,
                        template_name,
                        color,
                        coord_writer,
                        current_id,
                        used_points,
                        os.path.basename(tiffile)
                    )


                base=os.path.basename(tiffile).replace(".tif","")

                #new_name=f"{base}_{name_part}.tif"
                new_name = base + ".tif"
                cv2.imwrite(
                    os.path.join(outputTiffDir,new_name),
                    img_color
                )

                #os.remove(tiffile)

    print("✓ Point matching completed")
