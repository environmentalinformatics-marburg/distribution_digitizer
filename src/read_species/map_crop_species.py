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
    v0 = [i for i in range(len(t) + 1)]
    v1 = [0] * (len(t) + 1)
    for i in range(len(s)):
        v1[0] = i + 1
        for j in range(len(t)):
            cost = 0 if s[i] == t[j] else 1
            v1[j + 1] = min(v1[j] + 1, v0[j + 1] + 1, v0[j] + cost)
        v0 = v1[:]
    return ((len(s) + len(t)) - v1[len(t)]) / (len(s) + len(t)) * 100

def cropImage(source_image, outdir, x, y, w, h, i):
    img = np.array(PIL.Image.open(source_image))
    imgc = img.copy()
    y = y + h + 30
    thresholded = ((imgc > 120) * 255).astype(np.uint8)
    cropedImagespecie = outdir + '_' + os.path.basename(source_image).rsplit('.', 1)[0] + i + '.tif'
    cv2.imwrite(cropedImagespecie, thresholded[y:(y + 150), x:(x + w), :])
    return cropedImagespecie

def load_symbols(symbol_dir):
    symbols = {}
    for symbol_file in glob.glob(os.path.join(symbol_dir, '*.tif')):
        symbol_name = os.path.basename(symbol_file).rsplit('.', 1)[0]
        symbols[symbol_name] = cv2.imread(symbol_file, cv2.IMREAD_GRAYSCALE)
    return symbols

def match_symbol(image, symbols):
    best_match = 'none'
    highest_score = 0

    for symbol_name, symbol_image in symbols.items():
        if symbol_image.shape[0] <= image.shape[0] and symbol_image.shape[1] <= image.shape[1]:
            result = cv2.matchTemplate(image, symbol_image, cv2.TM_CCOEFF_NORMED)
            _, max_val, _, _ = cv2.minMaxLoc(result)
            if max_val > highest_score:
                highest_score = max_val
                best_match = symbol_name

    return best_match if highest_score > 0.5 else 'none'

def crop_specie(working_dir, out_dir, path_to_page, path_to_map, y, h):
    try:
        image = cv2.imread(path_to_page)
        rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

        legend1 = 'distribution'
        d = pytesseract.image_to_data(rgb, output_type=Output.DICT)
        n_boxes = len(d['level'])
        specie = ''
        double_specie = ''

        symbols = load_symbols(os.path.join(working_dir, "data", "input", "templates", "symbols/"))
         
        for i in range(n_boxes - 2):
            #print(d['text'][i].lstrip())
            (x1, y1, w1, h1, c1) = (d['left'][i], d['top'][i], d['width'][i], d['height'][i], d['conf'][i])
            text = d['text'][i].lstrip()
            pre = d['text'][i + 1].lstrip()

            if levenshtein_ratio(text, legend1) > 80:# Use Levenshtein ratio with a threshold of 80
                #print(text)
                if pre == 'of':
                    if abs(y1 - (y + h)) < h:
                        if double_specie != d['text'][i + 2].lstrip():
                            double_specie = d['text'][i + 2].lstrip()
                            symbol_crop = image[y1:y1 + h1 + 3, x1 - 100:x1]
                            gray_symbol_crop = cv2.cvtColor(symbol_crop, cv2.COLOR_BGR2GRAY)
                            symbol_crop_path = os.path.join(out_dir, f"symbol_crop_{i}.tif")
                            cv2.imwrite(symbol_crop_path, symbol_crop)
                            matched_symbol = match_symbol(gray_symbol_crop, symbols)
                            matched_symbol = re.sub(r'\d+_', '', matched_symbol)
                            specie += "_" + d['text'][i + 2].lstrip() + "S" + matched_symbol
                            print(specie)
                        else:
                            continue

        specie = re.sub(r"[^\w\s]", "", specie)

        if specie == '':
            specie = 'notfounddistribution'

        align_map = ""
        map_new_name = ""

        if os.path.exists(out_dir):
            if out_dir.endswith("/"):
                out_dir = out_dir.rstrip("/")
            align_map = os.path.join(out_dir, "maps/align/", os.path.basename(path_to_map))
            map_new_name = os.path.join(out_dir, "maps/readSpecies/", os.path.basename(path_to_map).rsplit('.', 1)[0] + "_" + specie + ".tif")
        else:
            if working_dir.endswith("/"):
                working_dir = working_dir.rstrip("/")
            align_map = os.path.join(working_dir, "data/output/maps/align/", os.path.basename(path_to_map))
            map_new_name = os.path.join(working_dir, "data/output/maps/readSpecies/", os.path.basename(path_to_map).rsplit('.', 1)[0] + "_" + specie + ".tif")

        if os.path.isfile(align_map):
            shutil.copy(align_map, map_new_name)
        else:
            raise FileNotFoundError("File not found: " + align_map)

        return specie

    except Exception as e:
        return str(e)
