# ============================================================
# Script Author: [Spaska Forteva]
# Created On: 2023-11-18
# ============================================================
# Description: This script contains functions for processing images, extracting information using Tesseract OCR,
# and cropping specified regions from input images.

# Required libraries
import cv2
import PIL
from PIL import Image
import os.path
import glob
import numpy as np 
import csv  
import time
from pytesseract import Output
import pytesseract
import argparse
import math
import statistics
import os
import re
import shutil  # Importing shutil for file operations

def cropImage(source_image, outdir, x, y, w, h, i):
    """
    Crop the specified region from the input image and save it.

    Args:
    source_image (str): Path to the input image.
    outdir (str): Output directory for saving the cropped image.
    x, y, w, h (int): Coordinates and dimensions of the region to be cropped.
    i (str): Additional identifier for the output filename.

    Returns:
    str: Path to the saved cropped image.
    """
    # Load the image using PIL and convert it to a numpy array
    img = np.array(PIL.Image.open(source_image))

    # Copy the image to avoid modifying the original
    imgc = img.copy()
    y = y + h + 30  # Adjust the y-coordinate
    
    # Apply a threshold to the image to binarize it
    thresholded = ((imgc > 120) * 255).astype(np.uint8)
    
    # Define the filename for the cropped image
    cropedImagespecie = outdir + '_' + os.path.basename(source_image).rsplit('.', 1)[0] + i + '.tif'
    
    # Save the cropped image
    cv2.imwrite(cropedImagespecie, thresholded[y:(y + 150), x:(x + w), :])
    
    return cropedImagespecie

def crop_specie(working_dir, out_dir, path_to_page, path_to_map, y, h):
    """
    Detect the specified region from the input image, crop it, and save it.

    Args:
    working_dir (str): The working directory.
    out_dir (str): The output directory for saving the cropped image.
    path_to_page (str): Path to the input image.
    path_to_map (str): Path to the map image.
    y, h (int): Coordinates and dimensions of the region to be cropped.

    Returns:
    str: The name of the species found.
    """
    try:
        # Load the image and convert it to RGB
        image = cv2.imread(path_to_page)
        rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        
        legend1 = 'distribution'
        legend2 = 'locality'
        d = pytesseract.image_to_data(rgb, output_type=Output.DICT)
        n_boxes = len(d['level'])
        specie = ''
        double_specie = ''

        # Loop through the detected text boxes
        for i in range(n_boxes-2):
            (x1, y1, w1, h1, c1) = (d['left'][i], d['top'][i], d['width'][i], d['height'][i], d['conf'][i])
            text = d['text'][i].lstrip()
            pre = d['text'][i+1].lstrip()
            
            # Check for the specific legends and extract species name
            if (text == legend1 or text == legend2):
                if (pre == 'of'):
                    if(abs(y1 - (y + h)) < h):
                        if(double_specie != d['text'][i+2].lstrip()):
                            double_specie = (d['text'][i+2].lstrip())
                            if text == legend1:
                                specie = specie + "_" + (d['text'][i+2].lstrip()) + legend1
                            else:
                                specie = specie + "_" + (d['text'][i+2].lstrip()) + legend2
                        else:
                            continue
        
        # Clean up the species name
        specie = re.sub(r"[^\w\s]", "", specie)
        
        if (specie == ''):
            specie = 'notfounddistribution'
        
        align_map = ""
        map_new_name = ""
        
        # Construct the paths based on the output directory
        if(os.path.exists(out_dir)):
            if out_dir.endswith("/"):
                out_dir = out_dir.rstrip("/")
            align_map = os.path.join(out_dir, "maps/align/", os.path.basename(path_to_map))
            map_new_name = os.path.join(out_dir, "maps/readSpecies/", os.path.basename(path_to_map).rsplit('.', 1)[0] + "_" + specie + ".tif")
        else:
            if working_dir.endswith("/"):
                working_dir = working_dir.rstrip("/")
            align_map = os.path.join(working_dir, "data/output/maps/align/", os.path.basename(path_to_map))
            map_new_name = os.path.join(working_dir, "data/output/maps/readSpecies/", os.path.basename(path_to_map).rsplit('.', 1)[0] + "_" + specie + ".tif")
        
        # Copy the map file to the new location with the new name
        if os.path.isfile(align_map):
            shutil.copy(align_map, map_new_name)
        else:
            raise FileNotFoundError("File not found: " + align_map)
        
        return specie
    
    except Exception as e:
        return str(e)
