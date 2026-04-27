"""
Author: Spaska Forteva
Last updated: 2026-03-31

Description:
This script is part of the Distribution Digitizer workflow and is designed to
automatically extract species names from scanned distribution maps.

The approach combines Optical Character Recognition (OCR) and template matching
to identify relationships between legend entries and corresponding map symbols.
Species names are detected from text regions located below map legends, using
robust string matching (Levenshtein similarity) to handle OCR inaccuracies.

For each detected species candidate, symbol matching is performed both locally
(on cropped regions) and globally (on the full map). The results are combined
and resolved through a global assignment strategy to ensure consistent and
unique mapping between species and symbol classes (colors).

The final output is an encoded representation of species–symbol associations,
which is appended to the map filename for downstream spatial processing steps.
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


# ------------------------------------------------------------
# Computes the similarity between two strings using the
# Levenshtein distance.
# This function is used to robustly match OCR-extracted text
# against predefined legend keywords (e.g., "distribution of"),
# tolerating typical OCR errors.
# Returns a similarity score in percent (0–100).
# ------------------------------------------------------------
def levenshtein_ratio(s, t):
    """
    Calculate the Levenshtein distance between two strings and return a ratio of similarity.
    """
    # Exact match → maximum similarity
    if s == t:
        return 100.0

    # Edge cases: one string empty
    elif len(s) == 0:
        return len(t)
    elif len(t) == 0:
        return len(s)
    
    # Initialize distance matrix rows
    v0 = [i for i in range(len(t) + 1)]
    v1 = [0] * (len(t) + 1)
    
    # Iterate over characters of first string
    for i in range(len(s)):
        v1[0] = i + 1

        # Iterate over characters of second string
        for j in range(len(t)):

            # Substitution cost (0 = same, 1 = different)
            cost = 0 if s[i] == t[j] else 1

            # Compute minimum edit operation (insert, delete, substitute)
            v1[j + 1] = min(
                v1[j] + 1,
                v0[j + 1] + 1,
                v0[j] + cost
            )
        
        # Copy current row → previous row
        v0 = v1[:]
    
    # Convert distance to similarity ratio
    return ((len(s) + len(t)) - v1[len(t)]) / (len(s) + len(t)) * 100


# ------------------------------------------------------------
# Crops a region of interest from the input image, typically
# located below a detected legend entry where species names
# are expected.
# Applies thresholding to enhance text visibility and stores
# the cropped image as a TIFF file.
# Returns the file path of the saved cropped image.
# ------------------------------------------------------------
def cropImage(source_image, outdir, x, y, w, h, i):
    """
    Crop a portion of the image and save it as a new file.
    """

    # Load image as numpy array
    img = np.array(PIL.Image.open(source_image))
    imgc = img.copy()
    
    # Shift cropping area below legend entry (heuristic offset)
    y = y + h + 30
    
    # Apply simple thresholding to enhance text contrast
    thresholded = ((imgc > 120) * 255).astype(np.uint8)
    
    # Build output file path (unique per crop)
    cropedImagespecie = (
        outdir + '_' +
        os.path.basename(source_image).rsplit('.', 1)[0] +
        i + '.tif'
    )
    
    # Crop fixed-height region below legend and save
    cv2.imwrite(
        cropedImagespecie,
        thresholded[y:(y + 150), x:(x + w), :]
    )
    
    return cropedImagespecie


# ------------------------------------------------------------
# Performs template matching on a cropped image region.
# Each provided symbol template is compared against the input
# image using normalized cross-correlation.
# Used to identify the most likely symbol associated with a
# detected species label.
# Returns a dictionary of matching scores per symbol.
# ------------------------------------------------------------
def match_symbol(image, symbols):

    scores = {}

    # Iterate over all symbol templates
    for symbol_name, symbol_image in symbols.items():

        # Skip if template is larger than image (invalid case)
        if (
            symbol_image.shape[0] > image.shape[0] or
            symbol_image.shape[1] > image.shape[1]
        ):
            continue

        # Perform template matching
        result = cv2.matchTemplate(
            image,
            symbol_image,
            cv2.TM_CCOEFF_NORMED
        )

        # Extract best match score
        _, max_val, _, _ = cv2.minMaxLoc(result)

        # Store score per symbol
        scores[symbol_name] = max_val

    return scores
  

# ------------------------------------------------------------
# Performs template matching on the full map image.
# Provides a global context of symbol occurrences across the
# entire map, complementing local (cropped) matching results.
# Returns a dictionary of matching scores per symbol.
# ------------------------------------------------------------
def match_symbol_on_map(full_image, symbols):

    # Convert full map to grayscale for matching
    gray_full = cv2.cvtColor(full_image, cv2.COLOR_BGR2GRAY)

    scores = {}

    for symbol_name, symbol_image in symbols.items():

        # Skip invalid cases (template larger than image)
        if (
            symbol_image.shape[0] > gray_full.shape[0] or
            symbol_image.shape[1] > gray_full.shape[1]
        ):
            continue

        result = cv2.matchTemplate(
            gray_full,
            symbol_image,
            cv2.TM_CCOEFF_NORMED
        )

        _, max_val, _, _ = cv2.minMaxLoc(result)

        scores[symbol_name] = max_val

    return scores
  

# ------------------------------------------------------------
# Resolves symbol assignments globally to ensure consistent
# and unique mapping between detected species and symbols.
#
# Strategy:
# - Sort all candidate-template pairs by score (descending)
# - Assign each species only once
# - Ensure each color (symbol class) is used only once
#
# Fallback:
# - If not all species could be assigned uniquely,
#   relax the color constraint and assign remaining ones
#
# Returns a list of final matched assignments.
# ------------------------------------------------------------
def assign_templates_global(all_scores):

    # Sort by highest combined score first
    all_scores = sorted(
        all_scores,
        key=lambda x: x["score"],
        reverse=True
    )

    used_keys = set()     # tracks candidate+legend uniqueness
    used_colors = set()   # ensures color uniqueness
    final_matches = []

    for row in all_scores:

        key = row["candidate"] + "_" + row["first_word"]
        color = row["color"]

        # Skip if same candidate+legend already assigned
        if key in used_keys:
            continue

        # Skip if color already used
        if color in used_colors:
            continue

        # Accept assignment
        final_matches.append(row)
        used_keys.add(key)
        used_colors.add(color)

    # Fallback: allow duplicate colors if needed
    if len(final_matches) < len(set([r["candidate"] for r in all_scores])):

        print("[WARNING] Not enough unique colors → fallback active")

        for row in all_scores:

            key = row["candidate"] + "_" + row["first_word"]

            if key in used_keys:
                continue

            final_matches.append(row)
            used_keys.add(key)

    return final_matches
  

# ------------------------------------------------------------
# Main function for extracting species names and assigning
# corresponding map symbols from scanned map pages.
#
# Workflow:
# 1. Load symbol templates
# 2. Extract region below map (ROI)
# 3. Perform OCR to detect legend entries
# 4. Identify candidate species names
# 5. Perform local (crop) and global (map) template matching
# 6. Combine scores and assign symbols globally
# 7. Encode results into filename-safe string
# 8. Copy and rename map file with encoded metadata
#
# Includes retry logic with image preprocessing (thresholding)
# to improve OCR robustness.
#
# Returns:
# Encoded species–symbol assignment string
# ------------------------------------------------------------

def crop_specie(
    working_dir,
    out_dir,
    path_to_page,
    path_to_map,
    y,
    h,
    legendKeywords=None,
    symbol_list=None,
    next_map_y=None,
    num_colors=0,
    attempt=1
):

    print("Legend list received:", legendKeywords)
    print("Attempt:", attempt)

    try:
        # ----------------------------------------------------
        # Load symbol templates
        # ----------------------------------------------------
        loaded_symbols = {}
        
        if isinstance(symbol_list, list):
            for path in symbol_list:
                name = os.path.basename(path).rsplit('.', 1)[0]
                loaded_symbols[name] = cv2.imread(
                    path,
                    cv2.IMREAD_GRAYSCALE
                )
    
        elif isinstance(symbol_list, dict):
            loaded_symbols = symbol_list
    
        if not loaded_symbols:
            raise ValueError("No symbols provided or symbols empty")
    
        symbols = loaded_symbols
  
        # ----------------------------------------------------
        # Normalize legend keywords
        # ----------------------------------------------------
        if legendKeywords is None:
            legendKeywords = ['distribution']

        if isinstance(legendKeywords, str):
            legendKeywords = [legendKeywords]

        legendKeywords = [l.strip().lower() for l in legendKeywords]

        # ----------------------------------------------------
        # Load full page image
        # ----------------------------------------------------
        full_image = cv2.imread(path_to_page)

        # ----------------------------------------------------
        # Define region of interest (below map)
        # ----------------------------------------------------
        
        if next_map_y is None:
            margin = -5   # single map
        else:
            margin = -10  # multiple maps → more separation
        print("#### DEBUG Margin: ", margin)
        roi_y_start = y + h + margin
        roi_y_start = max(0, roi_y_start)
        print("#### DEBUG Y Start: ", roi_y_start)
        # Avoid cutting into next map
        page_height = full_image.shape[0]
        map_bottom = y + h
        
        # 1. nächste Map vorhanden → sauber begrenzen
        if next_map_y is not None and next_map_y > roi_y_start:
            gap = next_map_y - map_bottom
            # 🔥 FALL: nächste Map ist zu weit weg
            if gap > h:
              y_end = map_bottom + int(h / 2)
            else:
              y_end = next_map_y - 10
            print("#### 1 IF DEBUG Y End: ", y_end)
        # 2. keine nächste Map und unten kein Platz mehr → letzte Map
        elif page_height - map_bottom < h:
            y_end = page_height - 10
            print("#### 2 ELIF DEBUG y_end: ", y_end)
        # 3. sonst → Standardbereich
        else:
            y_end = y + h + int(h / 2)

            if num_colors >= 2:
                print("#### SPECIAL: many colors → extend ROI")
                y_end = map_bottom + int(h * 1.5)
        
            if num_colors >= 5:
                print("#### SPECIAL: very many colors → extend more")
                y_end = map_bottom + int(h * 1.8)
            print("#### 3 ELSE DEBUG y_end: ", y_end)
            print("#### 3 next_map_y: ", next_map_y)
        
        roi = full_image[roi_y_start:y_end, :]
        
        image = roi.copy()

        # ----------------------------------------------------
        # 🔥 IMAGE WAHL (GANZ WICHTIG!)
        # ----------------------------------------------------
        if attempt == 3:
            print("[INFO] Attempt 3: using FULL MAP")
            image = cv2.imread(path_to_map)
        
        else:
            # dein bisheriger ROI Code
            roi = full_image[roi_y_start:y_end, :]
            image = roi.copy()

        # ----------------------------------------------------
        # OCR preprocessing (retry mechanism)
        # ----------------------------------------------------
        if attempt == 1:
            rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        else:
            print(f"[INFO] Attempt {attempt}: using thresholding")

            gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
            gray = cv2.GaussianBlur(gray, (3, 3), 0)

            _, thresh = cv2.threshold(
                gray, 0, 255,
                cv2.THRESH_BINARY + cv2.THRESH_OTSU
            )

            rgb = cv2.cvtColor(thresh, cv2.COLOR_GRAY2RGB)

        # ----------------------------------------------------
        # OCR execution
        # ----------------------------------------------------
        d = pytesseract.image_to_data(rgb, output_type=Output.DICT)
        n_boxes = len(d['level'])

        specie = ''
        double_specie = ''

        candidates = []
        all_scores = []
        canditates_aktual_temp = []

        # Perform global template matching once (optimization)
        global_scores_map = match_symbol_on_map(image, symbols)
        
        # ----------------------------------------------------
        # OCR parsing loop
        # ----------------------------------------------------
        for i in range(n_boxes):

            y1 = d['top'][i]
            h1 = d['height'][i]

            if d['text'][i].strip() == "":
                continue

            text = d['text'][i].strip().lower()
            
            crop_cache = {}

            # Compare OCR tokens with legend keywords
            for legend in legendKeywords:

                legend_words = legend.split()
                first_word = legend_words[0]
                last_word  = legend_words[-1]
            
                # Match first word using Levenshtein similarity
                if levenshtein_ratio(text, first_word) > 70:

                    # Validate last word position
                    if i + len(legend_words) < n_boxes:
                        next_word = d['text'][i + len(legend_words)-1].strip().lower()
                    
                    if next_word == last_word:

                        # Extract candidate species name
                        candidate = d['text'][i + len(legend_words)].strip()

                        if not candidate.isalpha():
                            continue

                        # Avoid duplicates
                        if double_specie != candidate:

                            canditates_aktual_temp.append({
                                "candidate": candidate,
                                "first_word": first_word
                            })

                            double_specie = candidate
                            candidates.append(candidate)

                            # ------------------------------------------------
                            # Local crop for symbol detection
                            # ------------------------------------------------
                            symbol_crop = image[y1-20:y1 + h1 + 20, :]
                            
                            if (
                                symbol_crop.shape[0] < 20 or
                                symbol_crop.shape[1] < 20
                            ):
                                continue

                            gray_symbol_crop = cv2.cvtColor(
                                symbol_crop,
                                cv2.COLOR_BGR2GRAY
                            )

                            # Cache matching results for identical crop sizes
                            crop_key = gray_symbol_crop.shape
                            
                            if crop_key in crop_cache:
                                scores_crop = crop_cache[crop_key]
                            else:
                                scores_crop = match_symbol(
                                    gray_symbol_crop,
                                    symbols
                                )
                                crop_cache[crop_key] = scores_crop
                                
                            scores_map = global_scores_map

                            # Combine local + global scores
                            for name in scores_crop.keys():

                                sc_crop = scores_crop.get(name, 0)
                                sc_map  = scores_map.get(name, 0)
                                total = sc_crop + sc_map

                                all_scores.append({
                                    "candidate": candidate,
                                    "template": name,
                                    "color": name.split("_")[0],
                                    "score": total,
                                    "first_word": first_word
                                })

                    break

        # ----------------------------------------------------
        # Global assignment step
        # ----------------------------------------------------
        print("=== GLOBAL MATCHING ===")

        final_matches = assign_templates_global(all_scores)

        # Ensure no candidate is lost (important fix)
        matched_candidates = set([m["candidate"] for m in final_matches])

        for c in canditates_aktual_temp:
            cname = c["candidate"]

            if cname not in matched_candidates:
                final_matches.append({
                    "candidate": cname,
                    "template": "unknown",
                    "color": "unknown",
                    "score": 0,
                    "first_word": c["first_word"]
                })
        
        # ----------------------------------------------------
        # Build encoded output string
        # ----------------------------------------------------
        for match in final_matches:

            candidate = match["candidate"]
            template  = match["template"]
            first_word = match["first_word"]

            # Clean template name
            template_clean = re.sub(r'\d+_', '', template)
            template_clean = template_clean.replace("_", "Y")

            specie += "_" + candidate + "X" + first_word.lower() + "Y" + template_clean

        print("[FINAL RESULT]", specie)

        # Remove invalid filename characters
        specie = re.sub(r"[^\w\s_\|]", "", specie)

        # ----------------------------------------------------
        # Retry logic if no candidates found
        # ----------------------------------------------------
        if (len(candidates) == 0 or specie.strip() == "") and attempt < 3:

            print(f"[RETRY] Attempt {attempt+1}")

            return crop_specie(
                working_dir,
                out_dir,
                path_to_page,
                path_to_map,
                y,
                h,
                legendKeywords,
                symbol_list,
                next_map_y,
                num_colors,
                attempt + 1
            )

        # ----------------------------------------------------
        # Fallback: assign unknown if matching failed
        # ----------------------------------------------------
        if len(final_matches) < len(set(candidates)):
            print("[INFO] fallback → not enough matches")
        
            final_matches = []
            for c in candidates:
                final_matches.append({
                    "candidate": c,
                    "template": "unknown",
                    "legend": legendKeywords[0]
                })

        # ----------------------------------------------------
        # File handling and renaming
        # ----------------------------------------------------
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

        # Copy and rename file
        if os.path.isfile(align_map):
            shutil.copy(align_map, map_new_name)
        else:
            raise FileNotFoundError("File not found: " + align_map)

        return specie

    except Exception as e:
        return str(e)
