# ============================================================
# Script Author: [Spaska Forteva]
# Script Author: [Madhu Venkates]
# Created On: 2023-01-10
# ============================================================
"""
Description: This script edits book pages and creates map images using the matching method.
"""
 

# It is recommended the use of Snake Case for functions and variables, 
# for examples: find_page_number!

# Import libraries
import cv2
import PIL
from PIL import Image
import os.path
import glob
import numpy as np 
import csv  
import time
import os
import pytesseract
from pytesseract import Output
import shutil
import re
import sys
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
# Set path to tesseract.exe
pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"

# Optional: set tessdata prefix if needed
os.environ["TESSDATA_PREFIX"] = r"C:\Program Files\Tesseract-OCR\tessdata"
start_time = time.time()

# Define fields for the records CSV files
fields = ['page_number', 'previous_page_path', 'next_page_path', 'file_name',  'x', 'y', 'w', 'h', 'size', 'threshold', 'time']

# Define fields for the page records CSV files
fields_page_record = ['page_number','previous_page_path', 'next_page_path', 'file_name',  'map_name', 'x', 'y', 'w', 'h', 'size', 'threshold', 'time']   

# Input validation
# Consider using argparse to handle command-line arguments.


# Function to extract the page number from a specific region of an image
def find_page_number(image, page_position):
  """
  Extracts the page number from a specific region of an image based on the provided page position.

  Args:
  - image (PIL.Image.Image or str): The image or path to the image.
  - page_position (int): The position of the page number. 1 for the top, 2 for the bottom.

  Returns:
  - int value or 0: The extracted page number or 0 if not found.
  """
  # ...
  #image = "D:/distribution_digitizer_11_01_2024//data/input/pages/0059.tif" 
  #page_position = 1
  result = 0
  img = np.array(PIL.Image.open(image))
  imgc = img.copy()
  
  h, w, c = imgc.shape 
  h_temp= int(h/10)
  #page_position = 1
  # Determine the cropping dimensions based on page position
  page_position = int(page_position)
  if page_position == 1:    
    croped_image = imgc[0:h_temp, 0:w]
    # !Important  
    croped_image = cv2.bilateralFilter(croped_image, 9, 75, 75)
    d = pytesseract.image_to_data(croped_image, output_type=Output.DICT)
    for element in d['text']:
      if element.isdigit() and 0 < int(element) < 100:
        result = int(element)
        break
  elif page_position == 2:
    croped_image = imgc[h-h_temp:h, 0:w]
      # !Important  
    croped_image = cv2.bilateralFilter(croped_image, 9, 75, 75)
    d = pytesseract.image_to_data(croped_image, output_type=Output.DICT)
    for element in reversed(d['text']):
      if element.isdigit() and 0 < int(element) < 100:
        result = int(element)
        break

  #print(result)    
  # Return 0 if no suitable number is found
  return result

def filter_overlapping_matches(loc, res, w, h, iou_thresh=0.6):
    """
    Filter overlapping template matches using IoU (Intersection-over-Union).
    Keeps only the best (highest correlation) match for strongly overlapping regions.

    Args:
        loc (tuple): Result of np.where(res >= threshold)
        res (ndarray): Correlation matrix from cv2.matchTemplate
        w, h (int): Template width and height
        iou_thresh (float): Minimum IoU to treat two boxes as duplicates (0.6 = 60%)

    Returns:
        list of (x, y, score): Filtered matches
    """
    candidates = [(x, y, float(res[y, x])) for (x, y) in zip(loc[1], loc[0])]
    candidates.sort(key=lambda z: z[2], reverse=True)

    kept = []

    def iou(boxA, boxB):
        # box = (x, y, w, h)
        xA = max(boxA[0], boxB[0])
        yA = max(boxA[1], boxB[1])
        xB = min(boxA[0] + boxA[2], boxB[0] + boxB[2])
        yB = min(boxA[1] + boxA[3], boxB[1] + boxB[3])
        interArea = max(0, xB - xA) * max(0, yB - yA)
        boxAArea = boxA[2] * boxA[3]
        boxBArea = boxB[2] * boxB[3]
        iou_val = interArea / float(boxAArea + boxBArea - interArea + 1e-6)
        return iou_val

    for (x, y, score) in candidates:
        box = (x, y, w, h)
        duplicate = False
        for (kx, ky, ks) in kept:
            if iou(box, (kx, ky, w, h)) > iou_thresh:
                duplicate = True
                break
        if not duplicate:
            kept.append((x, y, score))

    return kept


def match_template(previous_page_path, next_page_path, current_page_path,
                   template_map_file, output_dir, output_page_records,
                   records, threshold, page_position, map_group="1"):
    """
    Template matching for maps.
    Saves results directly inside output/<i>/maps/matching and pagerecords.
    """
    try:
        print("🗺️ Page:", current_page_path)
        print("📌 Template:", template_map_file)

        start_time = time.time()
        img = np.array(Image.open(current_page_path))
        imgc = img.copy()

        tmp = np.array(Image.open(template_map_file))
        h, w, c = tmp.shape

        res = cv2.matchTemplate(img, tmp, cv2.TM_CCOEFF_NORMED)
        loc = np.where(res >= threshold)
        candidates = [(x, y, float(res[y, x])) for (x, y) in zip(loc[1], loc[0])]
        candidates.sort(key=lambda z: z[2], reverse=True)  # Sortiere nach Score (bester zuerst)
        
        if not candidates:
            return  # kein Treffer
        
        # Nur den besten behalten
        kept = [candidates[0]]
        saved_maps = []
        count = 0
        page_number = find_page_number(current_page_path, page_position)

        # --- output folders (already per map_group handled) ---
        os.makedirs(output_dir, exist_ok=True)
        os.makedirs(output_page_records, exist_ok=True)

        # --- Jetzt nur noch gefilterte Treffer verwenden ---
        for (x, y, score) in kept:
            size = w * h * (2.54 / 400) ** 2
            threshold_last = str(threshold).split(".")[-1]

            base_name = (
                f"{page_number}-thr{threshold_last}_"
                f"{os.path.basename(current_page_path).rsplit('.', 1)[0]}_"
                f"{os.path.basename(template_map_file).rsplit('.', 1)[0]}_"
                f"y{y}_x{x}_n{count}"
            )

            img_save_path = os.path.join(output_dir, base_name + ".tif")
            csv_save_path = os.path.join(output_page_records, base_name + ".csv")

            # --- Erweiterung: 10 % extra Höhe nach unten ---
            extra_h = int(h * 0.1)
            y_end = min(y + h + extra_h, imgc.shape[0])
            crop = imgc[y:y_end, x:x+w, :]
            cv2.imwrite(img_save_path, crop)
            cv2.rectangle(imgc, (x, y), (x+w, y+h), (0,255,0), 2)

            record_row = [
                page_number, previous_page_path, next_page_path, current_page_path,
                img_save_path, x, y, w, h, size, threshold,
                round(time.time() - start_time, 3), map_group
            ]

            # --- In die globale CSV schreiben ---
            is_empty = not os.path.exists(records) or os.stat(records).st_size == 0
            with open(records, 'a', newline='') as csv_file:
                writer = csv.writer(csv_file)
                if is_empty:
                    writer.writerow([
                        "page_number","previous_page","next_page","current_page",
                        "matched_image","x","y","w","h","size_cm2","threshold",
                        "duration_s","map_group"
                    ])
                writer.writerow(record_row)

            # --- Einzel-CSV für diesen Treffer ---
            with open(csv_save_path, 'w', newline='') as f:
                writer = csv.writer(f)
                writer.writerow([
                    "page_number","previous_page","next_page","current_page",
                    "matched_image","x","y","w","h","size_cm2","threshold",
                    "duration_s","map_group"
                ])
                writer.writerow(record_row)

            saved_maps.append((x, y))
            count += 1

    except Exception as e:
        print("❌ Error in match_template:", e)



def match_template_contours(previous_page_path, next_page_path, current_page_path,
                            template_map_file, output_dir, output_page_records,
                            records, threshold, page_position):
    """
    Find maps using contour detection, save them, and write coordinates in CSV files.
    """
    try:
        print(current_page_path)
        print(template_map_file)

        img = np.array(Image.open(current_page_path).convert('L'))
        imgc = np.array(Image.open(current_page_path))

        template = np.array(Image.open(template_map_file))

        _, binary = cv2.threshold(img, 128, 255, cv2.THRESH_BINARY_INV)

        kernel = np.ones((5, 5), np.uint8)
        dilated = cv2.dilate(binary, kernel, iterations=2)
        eroded = cv2.erode(dilated, kernel, iterations=2)

        contours, _ = cv2.findContours(eroded, cv2.RETR_EXTERNAL,
                                       cv2.CHAIN_APPROX_SIMPLE)

        template_h, template_w = template.shape[:2]

        tolerance = 0.2
        min_w = int(template_w * (1 - tolerance))
        max_w = int(template_w * (1 + tolerance))
        min_h = int(template_h * (1 - tolerance))
        max_h = int(template_h * (1 + tolerance))

        processed_areas = []

        def is_overlapping(x, y, w, h, processed_areas):
            for (px, py, pw, ph) in processed_areas:
                if (x < px + pw and x + w > px and
                    y < py + ph and y + h > py):
                    return True
            return False

        count = 0
        threshold_last = str(threshold).split(".")
        for idx, contour in enumerate(contours):
            x, y, w, h = cv2.boundingRect(contour)
            size = w * h * (2.54 / 400) * (2.54 / 400)

            if min_w <= w <= max_w and min_h <= h <= max_h and not is_overlapping(x, y, w, h, processed_areas):
                page_number = find_page_number(current_page_path, page_position)
                rows_records = [[str(page_number), previous_page_path,
                                 next_page_path, current_page_path,
                                 x, y, w, h, size, threshold,
                                 (time.time() - start_time)]]


                is_empty = os.stat(records).st_size == 0
                with open(records, 'a', newline='') as csv_file:
                    csvwriter = csv.writer(csv_file)
                    if is_empty:
                        csvwriter.writerow(fields)
                    csvwriter.writerows(rows_records)

                # ✅ Y-position at the very end of the filename
                img_map_path = (
                    str(page_number) + '-' + str(threshold_last[1]) + '__' +
                    os.path.basename(current_page_path).rsplit('.', 1)[0] +
                    os.path.basename(template_map_file).rsplit('.', 1)[0] +
                    '_' + str(count) +
                    '_y' + str(y)
                )

                cv2.imwrite(os.path.join(output_dir, img_map_path + '.tif'),
                            imgc[y:y+h, x:x+w])
                count += 1

                csv_path = os.path.join(output_page_records, img_map_path + '.csv')
                with open(csv_path, 'w', newline='') as page_record:
                    pageCsvwriter = csv.writer(page_record)
                    pageCsvwriter.writerow(fields_page_record)
                    rows = [[str(page_number), previous_page_path, next_page_path,
                             current_page_path,
                             os.path.join(output_dir, img_map_path + '.tif'),
                             x, y, w, h, size, threshold,
                             (time.time() - start_time)]]
                    pageCsvwriter.writerows(rows)

    except Exception as e:
        print("An error occurred in match_template_contours:", e)

# Beispielaufruf
# params = {
#     "previous_page_path": previous_page_path,
#     "next_page_path": next_page_path,
#     "current_page_path": current_page_path,
#     "template_map_file": template_map_file,
#     "output_dir": output_dir,
#     "output_page_records": output_page_records,
#     "records": records,
#     "threshold": threshold,
#     "page_position": page_position
# }
# match_template_images(**params)

#working_dir="D:/distribution_digitizer"
# Function to perform the main template matching in a loop

def main_template_matching(
    working_dir,
    outDir,
    threshold,
    page_position,
    matchingType,
    pageSel="1-1",
    nMapTypes=1
):
    """
    Perform template matching for each numeric map type (1, 2, 3, ...).
    Expected structure:
        data/input/templates/<type>/maps/
        output/<type>/maps/matching/
    """

    threshold = float(threshold)
    page_position = int(page_position)
    matchingType = int(matchingType)
    pageSel = str(pageSel).strip()

    try:
        # --- Normalize paths ---
        working_dir = working_dir.rstrip("/\\")
        outDir = outDir.rstrip("/\\")
        pages_dir = os.path.join(working_dir, "data", "input", "pages")
        templates_root = os.path.join(working_dir, "data", "input", "templates")

        # --- Prepare list of numeric map groups ---
        map_groups = [str(i) for i in range(1, int(nMapTypes) + 1)
                      if os.path.isdir(os.path.join(templates_root, str(i)))]
        if not map_groups:
            print(f"❌ No numeric template groups (1..{nMapTypes}) found in {templates_root}")
            return
        print(f"✅ Found template groups: {map_groups}")

        # --- Collect all pages ---
        tif_files = sorted(glob.glob(os.path.join(pages_dir, "*.tif")))
        if not tif_files:
            print(f"❌ No .tif pages found in {pages_dir}")
            return

        # --- Page selection ---
        if pageSel.upper() == "ALL" or pageSel == "":
            pages = tif_files
        elif pageSel.lower().endswith(".tif"):
            candidate = os.path.join(pages_dir, pageSel)
            pages = [candidate] if os.path.exists(candidate) else []
        elif "-" in pageSel:
            start, end = [int(x) for x in pageSel.split("-")]
            pages = tif_files[start - 1:end]
        else:
            raise ValueError(f"Invalid pageSel: {pageSel}")

        print(f"➡️ Processing {len(pages)} page(s)")

        # --- Matching loop over each map type ---
                # --- Matching loop over each map type ---
        for group in map_groups:
            print(f"\n🔍 Processing map type: {group}")

            maps_dir = os.path.join(templates_root, group, "maps")
            if not os.path.isdir(maps_dir):
                print(f"⚠️ No 'maps' directory found for group {group}")
                continue

            # Sammle alle Templates (*.tif) in diesem maps-Verzeichnis
            template_files = sorted(glob.glob(os.path.join(maps_dir, "*.tif")))
            if not template_files:
                print(f"⚠️ No .tif templates found in {maps_dir}")
                continue

            # Bereite Output-Struktur vor
            output_base = os.path.join(outDir, group)
            output_dir = os.path.join(output_base, "maps", "matching")
            output_page_records = os.path.join(output_base, "pagerecords")
            records = os.path.join(output_base, "records.csv")

            os.makedirs(output_dir, exist_ok=True)
            os.makedirs(output_page_records, exist_ok=True)

            # --- Alte Ergebnisse löschen, aber nur Dateien ---
            for folder in [output_dir, output_page_records]:
                for f in os.listdir(folder):
                    fp = os.path.join(folder, f)
                    if os.path.isfile(fp):
                        os.remove(fp)
            if os.path.exists(records):
                os.remove(records)

            print(f"📁 Output directory for map group {group}: {output_dir}")

            # --- Matching pro Template ---
                   # ============================================================
        # Optimierte Variante:
        # Jede Seite nur einmal öffnen und alle Template-Gruppen prüfen
        # ============================================================

        # --- Templates aller Gruppen vorab laden ---
        all_templates = {}
        for group in map_groups:
            maps_dir = os.path.join(templates_root, group, "maps")
            if not os.path.isdir(maps_dir):
                print(f"⚠️ No 'maps' directory found for group {group}")
                continue
            templates = sorted(glob.glob(os.path.join(maps_dir, "*.tif")))
            if not templates:
                print(f"⚠️ No .tif templates found in {maps_dir}")
                continue
            all_templates[group] = templates
            print(f"✅ {len(templates)} templates loaded for group {group}")

        if not all_templates:
            print("❌ No templates found in any group.")
            return

        # --- Output-Struktur vorbereiten ---
        for group in map_groups:
            base = os.path.join(outDir, group)
            os.makedirs(os.path.join(base, "maps", "matching"), exist_ok=True)
            os.makedirs(os.path.join(base, "pagerecords"), exist_ok=True)

        # --- Matching pro Seite (jede Seite einmal öffnen) ---
        for i, current_page_path in enumerate(pages):
            print(f"\n🗎 Processing page {os.path.basename(current_page_path)}")

            prev_path = pages[i - 1] if i > 0 else None
            next_path = pages[i + 1] if i < len(pages) - 1 else None

            # Seite einmal laden
            img = np.array(Image.open(current_page_path))
            imgc = img.copy()

            # Durch alle Gruppen und Templates iterieren
            for group, template_files in all_templates.items():
                output_base = os.path.join(outDir, group)
                output_dir = os.path.join(output_base, "maps", "matching")
                output_page_records = os.path.join(output_base, "pagerecords")
                records = os.path.join(output_base, "records.csv")

                for template_file in template_files:
                    print(f"🔍 Matching {os.path.basename(template_file)} (group {group})")

                    params = {
                        "previous_page_path": prev_path,
                        "next_page_path": next_path,
                        "current_page_path": current_page_path,
                        "template_map_file": template_file,
                        "output_dir": output_dir,
                        "output_page_records": output_page_records,
                        "records": records,
                        "threshold": threshold,
                        "page_position": page_position,
                        "map_group": group
                    }

                    if matchingType == 1:
                        match_template(**params)
                    elif matchingType == 2:
                        match_template_contours(**params)

        print("\n✅ Matching completed for all pages and map types.")

    except Exception as e:
        print("❌ Error in main_template_matching:", e)

#working_dir="D:/distribution_digitizer"
#outDir="D:/test/output_2025-11-07_14-01-05/"
#main_template_matching(working_dir, outDir,  0.18, 1, 1, "0043.tif", 2)
#main_template_matching(working_dir, outDir,  0.18, 1, 1, "1-2", 2)

