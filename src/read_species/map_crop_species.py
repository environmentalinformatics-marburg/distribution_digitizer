"""
Author: Spaska Forteva
 Last modified on 2024-08-09 by Spaska Forteva:
 Description: This script processes images to extract species names from map symbols using OCR and template matching. 
 It includes functions for Levenshtein distance calculation, image cropping, symbol loading, and matching.
"""

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
import shutil

def levenshtein_ratio(s, t):
    """
    Calculate the Levenshtein distance between two strings and return a ratio of similarity.
    """
    if s == t:
        return 100.0
    elif len(s) == 0:
        return len(t)
    elif len(t) == 0:
        return len(s)
    
    # Initialize matrix rows
    v0 = [i for i in range(len(t) + 1)]
    v1 = [0] * (len(t) + 1)
    
    for i in range(len(s)):
        v1[0] = i + 1
        for j in range(len(t)):
            # Cost is 0 if characters match, 1 otherwise
            cost = 0 if s[i] == t[j] else 1
            v1[j + 1] = min(v1[j] + 1, v0[j + 1] + 1, v0[j] + cost)
        
        v0 = v1[:]
    
    return ((len(s) + len(t)) - v1[len(t)]) / (len(s) + len(t)) * 100

def cropImage(source_image, outdir, x, y, w, h, i):
    """
    Crop a portion of the image and save it as a new file.
    """
    img = np.array(PIL.Image.open(source_image))
    imgc = img.copy()
    
    # Adjust the y-coordinate and add some margin
    y = y + h + 30
    
    # Threshold the image to get a binary result
    thresholded = ((imgc > 120) * 255).astype(np.uint8)
    
    # Define the path for the cropped image
    cropedImagespecie = outdir + '_' + os.path.basename(source_image).rsplit('.', 1)[0] + i + '.tif'
    
    # Save the cropped image
    cv2.imwrite(cropedImagespecie, thresholded[y:(y + 150), x:(x + w), :])
    
    return cropedImagespecie

def load_symbols(symbol_dir):
    """
    Load all symbol images from a directory into a dictionary.
    """
    symbols = {}
    
    for symbol_file in glob.glob(os.path.join(symbol_dir, '*.tif')):
        symbol_name = os.path.basename(symbol_file).rsplit('.', 1)[0]
        symbols[symbol_name] = cv2.imread(symbol_file, cv2.IMREAD_GRAYSCALE)
    
    return symbols

def match_symbol(image, symbols):
    """
    Match a given image with a set of symbol templates and return the best match.
    """
    best_match = 'none'
    highest_score = 0

    for symbol_name, symbol_image in symbols.items():
        # Ensure the template is smaller than the image to match
        if symbol_image.shape[0] <= image.shape[0] and symbol_image.shape[1] <= image.shape[1]:
            # Template matching using normalized cross-correlation
            result = cv2.matchTemplate(image, symbol_image, cv2.TM_CCOEFF_NORMED)
            _, max_val, _, _ = cv2.minMaxLoc(result)
            
            # Update the best match if the score is higher
            if max_val > highest_score:
                highest_score = max_val
                best_match = symbol_name

    return best_match if highest_score > 0.5 else 'none'

def crop_specie(working_dir, out_dir, path_to_page, path_to_map, y, h, attempt=1):
    """
    Extract species names from a page image and associate them with map symbols.
    If nothing is found, retry with thresholding (max 3 attempts).
    """
    try:
        image = cv2.imread(path_to_page)

        # Preprocessing je nach Versuch
        if attempt == 1:
            print("[INFO] Versuch 1: Originalbild")
            rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        else:
            print(f"[INFO] Versuch {attempt}: mit Thresholding")
            gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
            gray = cv2.GaussianBlur(gray, (3, 3), 0)
            _, thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
            rgb = cv2.cvtColor(thresh, cv2.COLOR_GRAY2RGB)

        legend1 = 'distribution'
        d = pytesseract.image_to_data(rgb, output_type=Output.DICT)
        n_boxes = len(d['level'])
        specie = ''
        double_specie = ''

        symbols = load_symbols(os.path.join(working_dir, "data", "input", "templates", "symbols/"))
         
        for i in range(n_boxes - 2):
            (x1, y1, w1, h1, c1) = (d['left'][i], d['top'][i], d['width'][i], d['height'][i], d['conf'][i])
            text = d['text'][i].lstrip()
            pre = d['text'][i + 1].lstrip()

            if levenshtein_ratio(text, legend1) > 80:
                if pre == 'of':
                    if abs(y1 - (y + h)) < h:
                        candidate = d['text'][i + 2].lstrip()
                        if double_specie != candidate:
                            double_specie = candidate
                            symbol_crop = image[y1:y1 + h1 + 3, x1 - 100:x1]
                            gray_symbol_crop = cv2.cvtColor(symbol_crop, cv2.COLOR_BGR2GRAY)
                            matched_symbol = match_symbol(gray_symbol_crop, symbols)
                            matched_symbol = re.sub(r'\d+_', '', matched_symbol)
                            specie += "_" + candidate + "S" + matched_symbol
                            print(specie)

        specie = re.sub(r"[^\w\s]", "", specie)

        # Falls nichts gefunden: rekursiver Fallback (max 3 Versuche)
        if specie == '' and attempt < 3:
            print(f"[RETRY] Kein Ergebnis, versuche OCR erneut (Versuch {attempt+1}) ...")
            return crop_specie(working_dir, out_dir, path_to_page, path_to_map, y, h, attempt + 1)

        if specie == '':
            specie = 'notfounddistribution'

        if out_dir.endswith("/"):
            out_dir = out_dir.rstrip("/")
        if working_dir.endswith("/"):
            working_dir = working_dir.rstrip("/")

        if os.path.exists(out_dir):
            align_map = os.path.join(out_dir, "maps/align/", os.path.basename(path_to_map))
            map_new_name = os.path.join(out_dir, "maps/readSpecies/", os.path.basename(path_to_map).rsplit('.', 1)[0] + "_" + specie + ".tif")
        else:
            align_map = os.path.join(working_dir, "data/output/maps/align/", os.path.basename(path_to_map))
            map_new_name = os.path.join(working_dir, "data/output/maps/readSpecies/", os.path.basename(path_to_map).rsplit('.', 1)[0] + "_" + specie + ".tif")

        if os.path.isfile(align_map):
            shutil.copy(align_map, map_new_name)
        else:
            raise FileNotFoundError("File not found: " + align_map)

        return specie

    except Exception as e:
        return str(e)
