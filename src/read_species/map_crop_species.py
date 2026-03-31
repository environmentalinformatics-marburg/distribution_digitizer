"""
Author: Spaska Forteva
 Last modified on 2024-08-09 by Spaska Forteva:
 Description: This script processes images to extract species names from map symbols using OCR and template matching. 
 It includes functions for Levenshtein distance calculation, image cropping, symbol loading, and matching.
"""

import cv2
from PIL import Image
import os.path
import glob
import numpy as np
import csv
from pytesseract import Output
import pytesseract
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



def match_symbol(image, symbols):

    scores = {}

    for symbol_name, symbol_image in symbols.items():

        if (symbol_image.shape[0] > image.shape[0] or 
            symbol_image.shape[1] > image.shape[1]):
            continue

        result = cv2.matchTemplate(image, symbol_image, cv2.TM_CCOEFF_NORMED)
        _, max_val, _, _ = cv2.minMaxLoc(result)

        print(f"{symbol_name} → score={max_val:.3f}")

        scores[symbol_name] = max_val

    return scores
  
def match_symbol_on_map(full_image, symbols):

    gray_full = cv2.cvtColor(full_image, cv2.COLOR_BGR2GRAY)

    scores = {}

    for symbol_name, symbol_image in symbols.items():

        if (symbol_image.shape[0] > gray_full.shape[0] or 
            symbol_image.shape[1] > gray_full.shape[1]):
            continue

        result = cv2.matchTemplate(gray_full, symbol_image, cv2.TM_CCOEFF_NORMED)
        _, max_val, _, _ = cv2.minMaxLoc(result)

        scores[symbol_name] = max_val

    return scores
  
def assign_templates_global(all_scores):

    # 🔹 Sortiere nach Score (höchster zuerst)
    all_scores = sorted(all_scores, key=lambda x: x["score"], reverse=True)

    used_keys = set()
    used_colors = set()   # 🔥 NEU
    final_matches = []

    for row in all_scores:

        key = row["candidate"] + "_" + row["first_word"]
        color = row["color"]

        # ❌ gleiche candidate + legend doppelt
        if key in used_keys:
            continue

        # ❌ Farbe schon vergeben → überspringen
        if color in used_colors:
            continue

        # ✅ akzeptieren
        final_matches.append(row)
        used_keys.add(key)
        used_colors.add(color)

    # 🔥 FALLBACK (falls etwas leer bleibt)
    if len(final_matches) < len(set([r["candidate"] for r in all_scores])):

        print("[WARNING] Not enough unique colors → fallback aktiv")

        for row in all_scores:

            key = row["candidate"] + "_" + row["first_word"]

            if key in used_keys:
                continue

            final_matches.append(row)
            used_keys.add(key)

    return final_matches
  

def crop_specie(working_dir, out_dir, path_to_page, path_to_map, y, h, legend_list=None, symbol_list=None, attempt=1):

    print("Legend list received:", legend_list)
    print("Attempt:", attempt)

    try:
        
        loaded_symbols = {}
    
        if isinstance(symbol_list, list):
            for path in symbol_list:
                name = os.path.basename(path).rsplit('.', 1)[0]
                loaded_symbols[name] = cv2.imread(path, cv2.IMREAD_GRAYSCALE)
    
        elif isinstance(symbol_list, dict):
            loaded_symbols = symbol_list
    
        if not loaded_symbols:
            raise ValueError("No symbols provided or symbols empty")
    
        symbols = loaded_symbols
  
        if legend_list is None:
            legend_list = ['distribution']

        if isinstance(legend_list, str):
            legend_list = [legend_list]

        legend_list = [l.strip().lower() for l in legend_list]

        print("Legend list normalized:", legend_list)

        image = cv2.imread(path_to_page)

        if attempt == 1:
            print("[INFO] Versuch 1: Originalbild")
            rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        else:
            print(f"[INFO] Versuch {attempt}: mit Thresholding")

            gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
            gray = cv2.GaussianBlur(gray, (3, 3), 0)

            _, thresh = cv2.threshold(
                gray, 0, 255,
                cv2.THRESH_BINARY + cv2.THRESH_OTSU
            )

            rgb = cv2.cvtColor(thresh, cv2.COLOR_GRAY2RGB)

        d = pytesseract.image_to_data(rgb, output_type=Output.DICT)
        n_boxes = len(d['level'])

        specie = ''
        double_specie = ''

        # 🔥 NEU: Kandidaten + Scores sammeln
        candidates = []
        all_scores = []

        # -------------------------------
        # OCR scanning
        # -------------------------------
        for i in range(n_boxes):

            y1 = d['top'][i]
            h1 = d['height'][i]

            if d['text'][i].strip() == "":
                continue

            text = d['text'][i].strip().lower()

            for legend in legend_list:

                legend_words = legend.split()
                first_word = legend_words[0]
                last_word  = legend_words[-1]
            
                if levenshtein_ratio(text, first_word) > 70:

                    if i + len(legend_words) < n_boxes:
                        next_word = d['text'][i + len(legend_words)-1].strip().lower()

                    if next_word == last_word and abs(y1 - (y + h)) < h:

                        candidate = d['text'][i + len(legend_words)].strip()
                        print("candidate:", candidate)

                        if not candidate.isalpha():
                            continue

                        if double_specie != candidate:

                            double_specie = candidate
                            candidates.append(candidate)

                            symbol_crop = image[y1-20:y1 + h1 + 20, :]
                            gray_symbol_crop = cv2.cvtColor(symbol_crop, cv2.COLOR_BGR2GRAY)

                            scores_crop = match_symbol(gray_symbol_crop, symbols)
                            scores_map  = match_symbol_on_map(image, symbols)

                            print("----- COMBINED SCORES -----")

                            for name in scores_crop.keys():

                                sc_crop = scores_crop.get(name, 0)
                                sc_map  = scores_map.get(name, 0)
                                total = sc_crop + sc_map

                                print(f"{name:<10} crop={sc_crop:.3f} map={sc_map:.3f} → total={total:.3f}")

                                all_scores.append({
                                    "candidate": candidate,
                                    "template": name,
                                    "color": name.split("_")[0],
                                    "score": total,
                                    "first_word": first_word
                                })

                    break

        # 🔥 GLOBAL MATCHING
        print("=== GLOBAL MATCHING ===")

        final_matches = assign_templates_global(all_scores)


        # 🔥 Ergebnis bauen
        for match in final_matches:

            candidate = match["candidate"]
            template  = match["template"]
            first_word = match["first_word"]

            print("→ FINAL:", candidate, template)

            template_clean = re.sub(r'\d+_', '', template)
            template_clean = template_clean.replace("_", "Y")

            specie += "_" + candidate + "X" + first_word.lower() + "Y" + template_clean

        print("[FINAL RESULT]", specie)

        specie = re.sub(r"[^\w\s_\|]", "", specie)

        if specie == '' and attempt < 3:

            print(f"[RETRY] Versuch {attempt+1}")

            return crop_specie(
                working_dir,
                out_dir,
                path_to_page,
                path_to_map,
                y,
                h,
                legend_list,
                symbol_list,
                attempt + 1
            )

        if specie == '':
            specie = 'notfounddistribution'

        # -------------------------------
        # File handling (unchanged)
        # -------------------------------
        if out_dir.endswith("/"):
            out_dir = out_dir.rstrip("/")

        if working_dir.endswith("/"):
            working_dir = working_dir.rstrip("/")

        if os.path.exists(out_dir):

            align_map = os.path.join(
                out_dir,
                "maps/align/",
                os.path.basename(path_to_map)
            )

            map_new_name = os.path.join(
                out_dir,
                "maps/readSpecies/",
                os.path.basename(path_to_map).rsplit('.', 1)[0]
                + "_" + specie + ".tif"
            )

        else:

            align_map = os.path.join(
                working_dir,
                "data/output/maps/align/",
                os.path.basename(path_to_map)
            )

            map_new_name = os.path.join(
                working_dir,
                "data/output/maps/readSpecies/",
                os.path.basename(path_to_map).rsplit('.', 1)[0]
                + "_" + specie + ".tif"
            )

        if os.path.isfile(align_map):
            shutil.copy(align_map, map_new_name)
        else:
            raise FileNotFoundError("File not found: " + align_map)

        return specie

    except Exception as e:
        return str(e)
