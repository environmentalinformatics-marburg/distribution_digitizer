# ============================================================
# Script Author: [Spaska Forteva]
# Script Author: [Madhu Venkates]
# Created On: 2023-01-10
# Description: This script edits book pages and creates map images using the matching method.
# ============================================================


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
fields_page_record = ['page_number','previous_page_path', 'next_page_path', 'file_name',  'map_name', 'x', 'y', 'w', 'h', 'size', 'threshold', 'time', 'map_group']   

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
                   template_map_files, output_dir, output_page_records,
                   records, threshold, page_position, map_group="1"):
    """
    Detects and extracts map regions from a page image using template matching
    with normalized cross-correlation, supporting multiple templates.

    For each page, the function performs template matching against a list of
    reference map templates. Each template is matched independently, and
    only the best non-overlapping match per template is retained.

    The procedure is as follows:
    1. The current page image is loaded once and converted to a NumPy array.
    2. The page number is extracted from a predefined region (top or bottom)
       using OCR.
    3. For each template image:
       - Normalized cross-correlation (cv2.TM_CCOEFF_NORMED) is computed.
       - All candidate matches above the given threshold are collected.
       - Candidates are sorted by correlation score (descending).
       - A vertical distance (Y-axis) filter is applied to prevent saving
         multiple maps that are spatially too close to each other.
         The tolerance is defined as 25% of the template height.
       - The first candidate that satisfies the Y-distance constraint
         is selected as the valid match for this template.
    4. The detected map region is cropped from the page image,
       slightly extended in vertical direction to preserve borders.
    5. Each extracted map is saved as an individual image file.
    6. Metadata for each detected map is written to:
       - a global records CSV file (appended incrementally), and
       - a per-map CSV file stored alongside the extracted image.

    The function does not attempt to detect multiple instances of the same
    template on a single page; at most one map per template is saved.

    Args:
        previous_page_path (str): Path to the previous page image (or 'None').
        next_page_path (str): Path to the next page image (or 'None').
        current_page_path (str): Path to the current page image.
        template_map_files (list[str]): List of template image paths used for
            template matching.
        output_dir (str): Directory where extracted map images are saved.
        output_page_records (str): Directory for per-map CSV record files.
        records (str): Path to the global records CSV file.
        threshold (float): Minimum correlation score required for a match
            to be considered.
        page_position (int): Page number position indicator
            (1 = top of page, 2 = bottom of page).
        map_group (str): Identifier of the current map group (e.g. "1", "2", ...).

    Returns:
        None

    Notes:
        - Each template contributes at most one extracted map per page.
        - The Y-distance filtering prevents duplicate detections caused by
          overlapping or highly similar templates.
        - File names include page number, threshold, template name, and
          spatial coordinates to ensure traceability.
        - The function assumes that output directories already exist.
    """

    try:
        print("🗺️ Page:", current_page_path)

        start_time = time.time()
        img = np.array(Image.open(current_page_path))
        imgc = img.copy()

        page_number = find_page_number(current_page_path, page_position)

        os.makedirs(output_dir, exist_ok=True)
        os.makedirs(output_page_records, exist_ok=True)

        saved_y_markers = []   # <-- THIS is the key
        count = 0

        # ------------------------------------------------------------
        # Loop over ALL templates
        # ------------------------------------------------------------
        for template_map_file in template_map_files:
            print("📌 Template:", template_map_file)

            tmp = np.array(Image.open(template_map_file))
            h, w, c = tmp.shape

            res = cv2.matchTemplate(img, tmp, cv2.TM_CCOEFF_NORMED)
            loc = np.where(res >= threshold)

            candidates = [(x, y, float(res[y, x]))
                          for (x, y) in zip(loc[1], loc[0])]
            
            #print(f"   DEBUG: {len(candidates)} raw candidates found")

            # zeige die besten 10 Kandidaten (y + score)
            for i, (xx, yy, sc) in enumerate(
                    sorted(candidates, key=lambda z: z[2], reverse=True)[:10]
                ):
                print(f"     cand[{i}]: y={yy}, score={sc:.3f}")
                
            if not candidates:
                continue

            # best match only
            candidates.sort(key=lambda z: z[2], reverse=True)
            y_tol = int(h * 0.25)
            chosen = None
            
            for (x, y, score) in candidates:
                #print(f"   DEBUG: checking candidate y={y} against saved_y_markers={saved_y_markers}")
            
                too_close = False
                for y_prev in saved_y_markers:
                    if abs(y - y_prev) <= y_tol:
                        too_close = True
                        break
            
                if not too_close:
                    chosen = (x, y, score)
                    break  # ← erster gültiger Treffer reicht
            
            if chosen is None:
                print("⚠️ No suitable candidate found after Y-filtering")
                continue
            
            x, y, score = chosen


            # ------------------------------------------------------------
            # SAVE map
            # ------------------------------------------------------------
            saved_y_markers.append(y)

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

            extra_h = int(h * 0.1)
            y_end = min(y + h + extra_h, imgc.shape[0])
            crop = imgc[y:y_end, x:x + w, :]

            cv2.imwrite(img_save_path, crop)

            record_row = [
                page_number, previous_page_path, next_page_path, current_page_path,
                img_save_path, x, y, w, h, size, threshold,
                round(time.time() - start_time, 3), map_group
            ]

            is_empty = not os.path.exists(records) or os.stat(records).st_size == 0
            with open(records, 'a', newline='') as csv_file:
                writer = csv.writer(csv_file)
                if is_empty:
                    #writer.writerow([
                    #    "page_number","previous_page","next_page","current_page",
                    #    "matched_image","x","y","w","h","size_cm2",
                    #    "threshold","duration_s","map_group"
                    #])
                    writer.writerow(fields_page_record)
                writer.writerow(record_row)

            with open(csv_save_path, 'w', newline='') as f:
                writer = csv.writer(f)
                #writer.writerow([
                #    "page_number","previous_page","next_page","current_page",
                #    "matched_image","x","y","w","h","size_cm2",
                #    "threshold","duration_s","map_group"
                #])
                writer.writerow(fields_page_record)
                writer.writerow(record_row)

            #print(f"💾 Saved map at y={y}")
            count += 1
            #print(f"🧪 DEBUG SUMMARY for page {os.path.basename(current_page_path)}")
            #print(f"    saved_y_markers = {saved_y_markers}")
    except Exception as e:
        print("❌ Error in match_template:", e)




def match_template_contours(previous_page_path, next_page_path, current_page_path,
                            template_map_files, output_dir, output_page_records,
                            records, threshold, page_position, map_group="1"):
    """
    Detects and extracts map regions from a page image using contour-based detection,
    supporting multiple reference templates.

    This function is an extension of the original contour-based matching approach.
    Instead of using a single template, it iterates over a list of template images
    and applies identical contour detection logic for each template.

    The procedure is as follows:
    1. The current page is converted to grayscale and binarized.
    2. Morphological operations (dilation and erosion) are applied to enhance contours.
    3. External contours are detected on the processed image.
    4. For each template:
       - The template dimensions define acceptable width/height ranges
         (using a fixed tolerance).
       - Contours whose bounding boxes match the template size constraints
         are considered potential map candidates.
       - Overlapping detections are filtered to avoid duplicate map extraction.
    5. Valid map regions are cropped, saved as individual image files,
       and documented in both a global records CSV and per-map CSV files.

    The function does not modify the underlying contour detection logic or
    size heuristics compared to the original implementation; it only extends
    it to handle multiple templates in a single run.

    Args:
        previous_page_path (str): Path to the previous page image (or 'None').
        next_page_path (str): Path to the next page image (or 'None').
        current_page_path (str): Path to the current page image.
        template_map_files (list[str]): List of template image paths used to
            define expected map dimensions.
        output_dir (str): Directory where extracted map images are saved.
        output_page_records (str): Directory for per-map CSV record files.
        records (str): Path to the global records CSV file.
        threshold (float): Threshold value (kept for consistency with template
            matching; not directly used in contour detection).
        page_position (int): Page number position indicator
            (1 = top of page, 2 = bottom of page).
        map_group (str): Identifier of the current map group (e.g. "1", "2", ...).

    Returns:
        None

    Notes:
        - Each page image is processed once; contours are reused for all templates.
        - Map extraction is based solely on geometric constraints derived
          from template dimensions.
        - Output directories must already exist; this function does not
          create or remove directories.
        - The naming convention of output files includes page number,
          template identifier, and vertical (y) position for traceability.
    """

    try:
        print("🗺️ Page:", current_page_path)

        img_gray = np.array(Image.open(current_page_path).convert("L"))
        img_color = np.array(Image.open(current_page_path))

        page_number = find_page_number(current_page_path, page_position)
        count = 0

        # ------------------------------------------------------------
        # Preprocess page (robust, book-independent)
        # ------------------------------------------------------------
        binary = cv2.adaptiveThreshold(
            img_gray,
            255,
            cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            cv2.THRESH_BINARY_INV,
            31,
            5
        )

        kernel = np.ones((3, 3), np.uint8)
        processed = cv2.morphologyEx(
            binary,
            cv2.MORPH_CLOSE,
            kernel,
            iterations=1
        )

        contours, _ = cv2.findContours(
            processed,
            cv2.RETR_EXTERNAL,
            cv2.CHAIN_APPROX_SIMPLE
        )

        print(f"🧪 DEBUG: {len(contours)} contours found on page")

        processed_areas = []

        def is_overlapping(x, y, w, h):
            for (px, py, pw, ph) in processed_areas:
                if (x < px + pw and x + w > px and
                    y < py + ph and y + h > py):
                    return True
            return False

        # ------------------------------------------------------------
        # Loop over ALL templates (size reference only)
        # ------------------------------------------------------------
        for template_map_file in template_map_files:
            print("📌 Template:", template_map_file)

            template = np.array(Image.open(template_map_file))
            th, tw = template.shape[:2]

            # ✅ Dynamic size constraints (KEY PART)
            min_w = int(tw * 0.75)
            min_h = int(th * 0.75)
            max_w = int(tw * 1.40)
            max_h = int(th * 1.40)

            print(f"   ↳ size filter: "
                  f"w=[{min_w},{max_w}], h=[{min_h},{max_h}]")

            for contour in contours:
                x, y, w, h = cv2.boundingRect(contour)

                # DEBUG (can be commented out later)
                # print(f"DEBUG contour w={w}, h={h}")

                # --- 1) too small → reject
                if w < min_w or h < min_h:
                    continue

                # --- 2) too large → reject
                if w > max_w or h > max_h:
                    continue

                # --- 3) overlapping → reject
                if is_overlapping(x, y, w, h):
                    continue

                # ✅ ACCEPT contour
                processed_areas.append((x, y, w, h))

                size = w * h * (2.54 / 400) ** 2
                threshold_last = str(threshold).split(".")[-1]

                base_name = (
                    f"{page_number}-thr{threshold_last}_"
                    f"{os.path.basename(current_page_path).rsplit('.', 1)[0]}_"
                    f"{os.path.basename(template_map_file).rsplit('.', 1)[0]}_"
                    f"y{y}_x{x}_n{count}"
                )

                img_path = os.path.join(output_dir, base_name + ".tif")
                csv_path = os.path.join(output_page_records, base_name + ".csv")

                cv2.imwrite(img_path, img_color[y:y+h, x:x+w])

                record_row = [
                    page_number,
                    previous_page_path,
                    next_page_path,
                    current_page_path,
                    img_path,
                    x, y, w, h,
                    size,
                    threshold,
                    round(time.time() - start_time, 3),
                    map_group
                ]

                is_empty = not os.path.exists(records) or os.stat(records).st_size == 0
                with open(records, "a", newline="") as f:
                    writer = csv.writer(f)
                    if is_empty:
                        writer.writerow(fields_page_record)
                    writer.writerow(record_row)

                with open(csv_path, "w", newline="") as f:
                    writer = csv.writer(f)
                    writer.writerow(fields_page_record)
                    writer.writerow(record_row)

                print(f"💾 Saved map: w={w}, h={h}, y={y}")
                count += 1

        if count == 0:
            print("⚠️ No maps found on this page.")

    except Exception as e:
        print("❌ Error in match_template_contours:", e)


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

            prev_path = pages[i - 1] if i > 0 else 'None'
            next_path = pages[i + 1] if i < len(pages) - 1 else 'None'

            # Seite einmal laden
            img = np.array(Image.open(current_page_path))
            imgc = img.copy()

            # Durch alle Gruppen und Templates iterieren
            for group, template_files in all_templates.items():
                output_base = os.path.join(outDir, group)
                output_dir = os.path.join(output_base, "maps", "matching")
                output_page_records = os.path.join(output_base, "pagerecords")
                records = os.path.join(output_base, "records.csv")

                # for template_file in template_files:
                #     print(f"🔍 Matching {os.path.basename(template_file)} (group {group})")
                # 
                params = {
                    "previous_page_path": prev_path,
                    "next_page_path": next_path,
                    "current_page_path": current_page_path,
                    "template_map_files": template_files,
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
#outDir="D:/test/output_2026-01-28_16-17-41/"
##main_template_matching(working_dir, outDir,  0.18, 1, 1, "0043.tif", 2)
#main_template_matching(working_dir, outDir,  0.18, 1, 2, "1-1", 2)
