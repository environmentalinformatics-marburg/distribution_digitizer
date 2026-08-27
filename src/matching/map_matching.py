# ============================================================
# Script Author: Spaska Forteva
# Script Author: Madhu Venkatesh
# Created On: 2023-01-10
# Last updated on: 2026-03-31 (improved matching workflow and structure)

# Description:
# This script processes scanned book pages to automatically detect,
# extract, and save map regions using two alternative approaches:
#
# 1. Template Matching:
#    - Uses normalized cross-correlation to locate map regions
#      based on predefined template images.
#
# 2. Contour-Based Detection:
#    - Identifies map regions by detecting contours that match
#      expected template dimensions.
#
# The script supports multiple map types (groups), processes pages
# sequentially, and stores extracted maps together with metadata
# in structured CSV files.
#
# The output is used in further steps of the Distribution Digitizer
# workflow (e.g., georeferencing, point detection, polygonization).
# ============================================================

# ------------------------------------------------------------
# Import required libraries
# ------------------------------------------------------------
# OpenCV (cv2): image processing and template matching
# PIL: image loading and format handling
# numpy: array operations
# pytesseract: OCR for page number detection
# csv: writing structured output
# glob/os: file system operations
# shutil: file copying and cleanup
# re: string processing
# time: performance measurement
# sys: console encoding handling
# ------------------------------------------------------------
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
import pandas as pd
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

# ------------------------------------------------------------
# Configure Tesseract OCR
# ------------------------------------------------------------
# Ensure that the correct path to the Tesseract executable
# and tessdata directory is set. This is required for reliable
# OCR-based page number detection.
# ------------------------------------------------------------
# Set path to tesseract.exe
pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"

# Optional: set tessdata prefix if needed
os.environ["TESSDATA_PREFIX"] = r"C:\Program Files\Tesseract-OCR\tessdata"


start_time = time.time()
# Last successfully detected printed page number
previous_printed_page_number = None
previous_scan_number = None

# Define fields for the records CSV files
fields = ['page_number', 'previous_page_path', 'next_page_path', 'file_name',  'x', 'y', 'w', 'h', 'size', 'threshold', 'time']

# Define fields for the page records CSV files
fields_page_record = ['page_number','previous_page_path', 'next_page_path', 'file_name',  'map_name', 'x', 'y', 'w', 'h', 'size', 'threshold', 'time', 'map_group']   



def find_page_number_conventional(image, page_position):
    """
    Conventional page-number detection.

    Searches either the upper or lower 10% of the page,
    depending on page_position.

    Args:
        image (str): Path to the page image.
        page_position (int): 1 = top, 2 = bottom.

    Returns:
        int: Detected page number, or 0 if none was found.
    """

    result = 0

    img = np.array(PIL.Image.open(image))
    imgc = img.copy()

    h, w, c = imgc.shape
    h_temp = int(h / 10)

    page_position = int(page_position)

    # --------------------------------------------------------
    # Page number at top
    # --------------------------------------------------------

    if page_position == 1:

        croped_image = imgc[0:h_temp, 0:w]

        croped_image = cv2.bilateralFilter(
            croped_image,
            9,
            75,
            75
        )

        d = pytesseract.image_to_data(
            croped_image,
            output_type=Output.DICT
        )

        for element in d["text"]:

            if element.isdigit() and 0 < int(element) < 100:
                result = int(element)
                break

    # --------------------------------------------------------
    # Page number at bottom
    # --------------------------------------------------------

    elif page_position == 2:

        croped_image = imgc[h-h_temp:h, 0:w]

        croped_image = cv2.bilateralFilter(
            croped_image,
            9,
            75,
            75
        )

        d = pytesseract.image_to_data(
            croped_image,
            output_type=Output.DICT
        )

        for element in reversed(d["text"]):

            if element.isdigit() and 0 < int(element) < 100:
                result = int(element)
                break

    return result
# ------------------------------------------------------------
# Extract page number from scanned page
# ------------------------------------------------------------
# This function crops a small region (top or bottom of the page),
# applies smoothing (bilateral filter), and uses OCR to detect
# numeric values.
#
# Only numbers within a reasonable range (1–99) are accepted,
# which reduces noise from OCR misdetections.
#
# This step is essential for naming outputs and maintaining
# correct page references in downstream processing.
# ------------------------------------------------------------
def find_page_number(
    image_path,
    page_position,
    page_number_training_data=None
):

    global previous_printed_page_number
    global previous_scan_number

    # ========================================================
    # 1. TRAINING-BASED DETECTION
    # ========================================================

    if (
        page_number_training_data is not None
        and not page_number_training_data.empty
    ):

        page_number = find_page_number_from_training_data(
            image_path,
            page_number_training_data
        )

        if page_number is not None:

            filename = os.path.basename(image_path)
            match = re.search(r"(\d+)", filename)

            # A complete page number was detected.
            # Remember it for the next consecutive scan.
            if match and len(str(page_number)) >= 2:

                previous_printed_page_number = int(page_number)
                previous_scan_number = int(match.group(1))

                print(
                    f"Previous state updated: "
                    f"scan={previous_scan_number}, "
                    f"printed page={previous_printed_page_number}"
                )

            print(
                f"✅ Page number from training data: "
                f"{page_number}"
            )

            return page_number

        print(
            "⚠️ Training-based detection failed. "
            "Trying conventional detection."
        )

    # ========================================================
    # 2. CONVENTIONAL DETECTION
    # ========================================================

    page_number = find_page_number_conventional(
        image_path,
        page_position
    )

    if page_number not in (None, 0):

        page_number = infer_page_number_from_previous(
            image_path,
            page_number
        )

        print(
            f"✅ Page number from conventional detection: "
            f"{page_number}"
        )

        return page_number

    # ========================================================
    # 3. NOTHING FOUND
    # ========================================================

    print("⚠️ No page number detected.")

    return None
  
def find_page_number_from_training_data(
    image_path,
    training,
    margin_x=0.003,
    margin_y=0.003
):
    """
    Detect the printed page number using trained page-number positions.

    The training CSV contains relative coordinates of manually selected
    page-number regions:

        x_relative
        y_relative
        width_relative
        height_relative
        confirmed_text

    Several spatial position groups may occur in a book, for example
    page numbers at the bottom-left and bottom-right.

    The function:
      1. reads the training data,
      2. creates spatial groups from the trained positions,
      3. builds one OCR search region for each group,
      4. performs OCR only inside these trained regions,
      5. returns the best detected numeric page number.
    """

    import os
    import re
    import cv2
    import pandas as pd
    import pytesseract

   
    # Load current page
    image = cv2.imread(image_path)
    global previous_printed_page_number
    global previous_scan_number
    if image is None:
        print(f"Could not read page: {image_path}")
        return None

    # Work with the already loaded training data
    training = training.copy()
    
    required_columns = [
        "x_relative",
        "y_relative",
        "width_relative",
        "height_relative"
    ]

    for column in required_columns:
        if column not in training.columns:
            print(
                f"Missing column in page-number training data: "
                f"{column}"
            )
            return None

    # Remove incomplete rows
    training = training.dropna(
        subset=required_columns
    )

    if len(training) == 0:
        print("No valid page-number training regions found.")
        return None


    # ---------------------------------------------------------
    # 2. Remove training rows without a confirmed page number
    # ---------------------------------------------------------

    if "confirmed_text" in training.columns:

        training["confirmed_text"] = (
            training["confirmed_text"]
            .astype(str)
            .str.strip()
        )

        training = training[
            training["confirmed_text"].str.fullmatch(r"\d+")
        ]

    if len(training) == 0:
        print("No confirmed numeric page-number examples found.")
        return None


    # ---------------------------------------------------------
    # 3. Create spatial position groups
    #
    # Regions belong to the same group when their centres are
    # close to each other.
    #
    # Example for the current book:
    #
    #     group 1 -> bottom-left
    #     group 2 -> bottom-right
    #
    # No left/right position is hard-coded.
    # ---------------------------------------------------------

    training = training.copy()

    training["center_x"] = (
        training["x_relative"] +
        training["width_relative"] / 2
    )

    training["center_y"] = (
        training["y_relative"] +
        training["height_relative"] / 2
    )

    groups = []

    # Relative distance threshold.
    # 0.15 is large enough to combine slightly varying
    # selections but keeps left/right positions separate.
    cluster_distance = 0.15

    for _, row in training.iterrows():

        assigned = False

        for group in groups:

            dx = abs(
                row["center_x"] -
                group["center_x"]
            )

            dy = abs(
                row["center_y"] -
                group["center_y"]
            )

            if (
                dx <= cluster_distance and
                dy <= cluster_distance
            ):

                group["rows"].append(row)

                # Recalculate current group centre
                group["center_x"] = sum(
                    r["center_x"]
                    for r in group["rows"]
                ) / len(group["rows"])

                group["center_y"] = sum(
                    r["center_y"]
                    for r in group["rows"]
                ) / len(group["rows"])

                assigned = True
                break

        if not assigned:

            groups.append({
                "center_x": row["center_x"],
                "center_y": row["center_y"],
                "rows": [row]
            })


    print(
        f"Page-number training: "
        f"{len(groups)} position group(s) found."
    )


    # ---------------------------------------------------------
    # 4. Original image dimensions
    # ---------------------------------------------------------

    image_height, image_width = image.shape[:2]

    candidates = []


    # ---------------------------------------------------------
    # 5. OCR each trained position group
    # ---------------------------------------------------------

    for group_index, group in enumerate(groups, start=1):

        rows = group["rows"]

        # -----------------------------------------------------
        # Bounding region covering all training examples
        # in this spatial group
        # -----------------------------------------------------

        # -----------------------------------------------------
        # Average trained position and size
        # -----------------------------------------------------
        
        center_x = sum(
            r["center_x"]
            for r in rows
        ) / len(rows)
        
        center_y = sum(
            r["center_y"]
            for r in rows
        ) / len(rows)
        
        mean_width = sum(
            r["width_relative"]
            for r in rows
        ) / len(rows)
        
        mean_height = sum(
            r["height_relative"]
            for r in rows
        ) / len(rows)
        
        
        # -----------------------------------------------------
        # Build OCR region around trained position
        # -----------------------------------------------------
        
        x_min = center_x - mean_width / 2
        x_max = center_x + mean_width / 2
        
        y_min = center_y - mean_height / 2
        y_max = center_y + mean_height / 2

        # -----------------------------------------------------
        # Add small safety margin
        # -----------------------------------------------------

        x_min = max(
            0.0,
            x_min - margin_x
        )

        y_min = max(
            0.0,
            y_min - margin_y
        )

        x_max = min(
            1.0,
            x_max + margin_x
        )

        y_max = min(
            1.0,
            y_max + margin_y
        )


        # -----------------------------------------------------
        # Convert relative coordinates to image pixels
        # -----------------------------------------------------

        x1 = int(
            round(x_min * image_width)
        )

        y1 = int(
            round(y_min * image_height)
        )

        x2 = int(
            round(x_max * image_width)
        )

        y2 = int(
            round(y_max * image_height)
        )


        crop = image[
            y1:y2,
            x1:x2
        ]

        if crop.size == 0:
            continue


        # -----------------------------------------------------
        # Prepare crop for OCR
        # -----------------------------------------------------

        if len(crop.shape) == 3:

            gray = cv2.cvtColor(
                crop,
                cv2.COLOR_BGR2GRAY
            )

        else:
            gray = crop


        # Page numbers are usually small.
        # Enlargement improves OCR considerably.
        gray = cv2.resize(
            gray,
            None,
            fx=3,
            fy=3,
            interpolation=cv2.INTER_CUBIC
        )

        # -----------------------------------------------------
        # First OCR: digits only
        # -----------------------------------------------------
        
        text = pytesseract.image_to_string(
            gray,
            config="--psm 7 -c tessedit_char_whitelist=0123456789"
        ).strip()
        
        
        # -----------------------------------------------------
        # Second OCR if first OCR seems incomplete
        # -----------------------------------------------------
        
        
        if len(text) < 2:
        
            text_free = pytesseract.image_to_string(
                gray,
                config="--psm 7"
            ).strip()
        
            print(
                f"Page-number alternative OCR: "
                f"'{text}' -> '{text_free}'"
            )
        
            if text_free and not text_free.isdigit():
        
                text_free = correct_page_number_chars(
                    text_free,
                    text
                )
        
            if text_free.isdigit() and len(text_free) >= 2:
                text = text_free



        
        # Correct known OCR character errors
        if text and not text.isdigit():
            text = correct_page_number_chars(text)
        # Keep raw OCR for diagnostics
        print(
            f"Page-number group {group_index}: "
            f"OCR='{text}' "
            f"region=({x_min:.3f}, {y_min:.3f}) - "
            f"({x_max:.3f}, {y_max:.3f})"
        )

        # First try learned OCR corrections
        corrected = correct_page_number_from_training(
            text,
            training
        )
        
        if corrected is not None:
        
            candidates.append({
                "number": int(corrected),
                "raw_text": text,
                "group": group_index,
                "length": len(corrected)
            })
        
            continue
        # -----------------------------------------------------
        # Extract numeric candidate
        # -----------------------------------------------------

        numbers = re.findall(
            r"\d+",
            text
        )

        for number in numbers:

            try:

                candidates.append({
                    "number": int(number),
                    "raw_text": text,
                    "group": group_index,
                    "length": len(number)
                })

            except ValueError:
                pass


    # ---------------------------------------------------------
    # 6. No page number found
    # ---------------------------------------------------------

    if len(candidates) == 0:

        print(
            "No page number detected in trained regions."
        )

        return None


    # ---------------------------------------------------------
    # 7. Select best candidate
    #
    # For now prefer the candidate containing the most digits.
    # Usually only one of the trained positions contains a
    # page number on a particular page.
    # ---------------------------------------------------------

    candidates.sort(
        key=lambda c: c["length"],
        reverse=True
    )

    best = candidates[0]

    print(
        f"Detected page number: {best['number']} "
        f"(group {best['group']}, "
        f"OCR='{best['raw_text']}')"
    )

    return best["number"]


from difflib import SequenceMatcher


def correct_page_number_from_training(ocr_text, training):

    ocr_text = str(ocr_text).strip()

    best_match = None
    best_score = 0

    for _, row in training.iterrows():

        trained_ocr = str(row["ocr_text"]).strip()
        confirmed = str(row["confirmed_text"]).strip()

        # Only valid confirmed page numbers
        if not confirmed.isdigit():
            continue

        score = SequenceMatcher(
            None,
            ocr_text,
            trained_ocr
        ).ratio()

        if score > best_score:
            best_score = score
            best_match = confirmed

    # Only accept reasonably similar OCR results
    if best_match is not None and best_score >= 0.7:

        print(
            f"Training correction: "
            f"'{ocr_text}' -> '{best_match}' "
            f"(similarity={best_score:.2f})"
        )

        return best_match

    return None
  
  
# ------------------------------------------------------------
# Remove duplicate template matches using IoU filtering
# ------------------------------------------------------------
# Template matching often produces multiple overlapping detections
# for the same object. This function keeps only the best match
# (highest correlation score) within overlapping regions.
#
# IoU (Intersection-over-Union) is used to measure overlap between
# bounding boxes.
#
# Result:
# Cleaner detection with fewer redundant map extractions.
# ------------------------------------------------------------
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


def infer_page_number_from_previous(
    image_path,
    detected_number
):
    """
    Infer an incomplete page number from the previous printed
    page number, but only for directly consecutive scan files.

    Example:
        previous scan: 0074.tif -> printed page 70
        current scan:  0075.tif -> OCR detects only 7

        expected page = 71
        7 matches the beginning of 71

        result = 7199
    """

    global previous_printed_page_number
    global previous_scan_number

    # Current scan number from filename
    filename = os.path.basename(image_path)
    match = re.search(r"(\d+)", filename)

    if not match:
        return detected_number

    current_scan_number = int(match.group(1))

    # --------------------------------------------------------
    # No previous information yet
    # --------------------------------------------------------

    if (
        previous_printed_page_number is None
        or previous_scan_number is None
    ):
        return detected_number

    # --------------------------------------------------------
    # Scans must be directly consecutive
    # --------------------------------------------------------

    if current_scan_number != previous_scan_number + 1:
        return detected_number

    # --------------------------------------------------------
    # We only infer from an incomplete single digit
    # --------------------------------------------------------

    if detected_number is None:
        return detected_number

    detected_text = str(detected_number)

    if len(detected_text) != 1:
        return detected_number

    # Expected printed page
    expected = previous_printed_page_number + 1
    expected_text = str(expected)

    # Does detected digit fit the expected page?
    if expected_text.startswith(detected_text):

        inferred = int(f"{expected}99")

        print(
            f"⚠️ Incomplete page number '{detected_number}' "
            f"inferred from previous page "
            f"{previous_printed_page_number} -> {inferred}"
        )

        return inferred

    return detected_number
  
  
# ------------------------------------------------------------
# Template-based map extraction
# ------------------------------------------------------------
# Core idea:
# Detect map regions on a scanned page by comparing it with
# predefined template images.
#
# Key steps:
# - Perform template matching using normalized cross-correlation
# - Collect all matches above a given threshold
# - Sort candidates by similarity score
# - Apply spatial filtering (Y-distance constraint) to avoid
#   duplicate detections of the same map
# - Extract and save the best match per template
#
# Important design decisions:
# - Only ONE match per template is kept (robust and predictable)
# - Y-distance filtering prevents overlapping maps being saved twice
# - Output filenames encode full traceability (page, template, position)
#
# Output:
# - Cropped map images (.tif)
# - Global CSV (records.csv)
# - Per-map CSV files (for modular processing)
#
# This function is the backbone of the "matching" stage in the
# Distribution Digitizer pipeline.
# ------------------------------------------------------------
def match_template(previous_page_path, next_page_path, current_page_path,
                   template_map_files, output_dir, output_page_records,
                   records, threshold, page_position, page_number_training_data,
                   map_group="1"):
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
        print("Page:", current_page_path)
        start_time = time.time()
        # Last successfully detected printed page number

        img = np.array(Image.open(current_page_path))
        imgc = img.copy()
        img_gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        page_number = find_page_number(
            current_page_path,
            page_position,
            page_number_training_data
        )

        os.makedirs(output_dir, exist_ok=True)
        os.makedirs(output_page_records, exist_ok=True)

        saved_y_markers = []   # <-- THIS is the key
        count = 0

        # ------------------------------------------------------------
        # Loop over ALL templates
        # ------------------------------------------------------------
        for template_map_file, tmp in template_map_files:
            print("Template:", template_map_file)

           # tmp = np.array(Image.open(template_map_file))
            h, w, c = tmp.shape

            tmp_gray = cv2.cvtColor(tmp, cv2.COLOR_BGR2GRAY)
            res = cv2.matchTemplate(img_gray, tmp_gray, cv2.TM_CCOEFF_NORMED)
            loc = np.where(res >= threshold)

            candidates = [(x, y, float(res[y, x]))
                          for (x, y) in zip(loc[1], loc[0])]
            
                
            if not candidates:
                continue

            # best match only
            candidates = sorted(candidates, key=lambda z: z[2], reverse=True)
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
                #print("No suitable candidate found after Y-filtering")
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

            #print(f"Saved map at y={y}")
            count += 1
            #print(f"DEBUG SUMMARY for page {os.path.basename(current_page_path)}")
            #print(f"    saved_y_markers = {saved_y_markers}")
    except Exception as e:
        print("Error in match_template:", e)



def match_template_border(previous_page_path, next_page_path, current_page_path,
                          template_map_files, output_dir, output_page_records,
                          records, threshold, page_position, page_number_training_data, map_group="1"):

    try:
        print(" Page (BORDER MULTI):", current_page_path)
        start_time_local = time.time()

        img_color = np.array(Image.open(current_page_path))
        img_gray = cv2.cvtColor(img_color, cv2.COLOR_BGR2GRAY)

        page_number = find_page_number(
            current_page_path,
            page_position,
            page_number_training_data
        )

        count = 0
        processed_areas = []
        saved_y_markers = []

        # ------------------------------------------------------------
        # EDGE DETECTION
        # ------------------------------------------------------------
        edges = cv2.Canny(img_gray, 50, 150)

        kernel = np.ones((3, 3), np.uint8)
        edges = cv2.dilate(edges, kernel, iterations=1)

        contours, _ = cv2.findContours(
            edges,
            cv2.RETR_EXTERNAL,
            cv2.CHAIN_APPROX_SIMPLE
        )

        print(f"DEBUG: {len(contours)} contours found")

        # ------------------------------------------------------------
        # Overlap check
        # ------------------------------------------------------------
        def is_overlapping(x, y, w, h):
            for (px, py, pw, ph) in processed_areas:
                if (x < px + pw and x + w > px and
                    y < py + ph and y + h > py):
                    return True
            return False

        # ------------------------------------------------------------
        # MAIN LOOP (ALLE Kandidaten prüfen!)
        # ------------------------------------------------------------
        for contour in contours:

            x, y, w, h = cv2.boundingRect(contour)

            # ---------------- SIZE ----------------
            if w < 200 or h < 200:
                continue

            area = w * h
            img_area = img_gray.shape[0] * img_gray.shape[1]

            if area < img_area * 0.02:
                continue

            # ---------------- OVERLAP ----------------
            if is_overlapping(x, y, w, h):
                continue

            # ---------------- Y FILTER ----------------
            y_tol = int(h * 0.25)
            if any(abs(y - y_prev) <= y_tol for y_prev in saved_y_markers):
                continue

            # ------------------------------------------------------------
            #  BORDER VALIDATION (KERN)
            # ------------------------------------------------------------
            roi_edges = edges[y:y+h, x:x+w]

            inner_contours, _ = cv2.findContours(
                roi_edges,
                cv2.RETR_EXTERNAL,
                cv2.CHAIN_APPROX_SIMPLE
            )

            if not inner_contours:
                continue

            # größte innere Kontur
            largest = max(inner_contours, key=cv2.contourArea)
            largest_area = cv2.contourArea(largest)

            bbox_area = w * h

            border_ratio = largest_area / (bbox_area + 1e-6)
 
            # ------------------------------------------------------------
            # 🆕 RECTANGLE CHECK
            # ------------------------------------------------------------
            epsilon = 0.02 * cv2.arcLength(largest, True)
            approx = cv2.approxPolyDP(largest, epsilon, True)
            
            # bounding box der approximierten Kontur
            x2, y2, w2, h2 = cv2.boundingRect(approx)
            
            # Verhältnis zur ursprünglichen Map-Box
            width_ratio = w2 / float(w)
            height_ratio = h2 / float(h)
            
            # dein Filter
            if width_ratio < 0.7 or height_ratio < 0.7:
                continue
            # nur fast-rechteckige Konturen erlauben
            if len(approx) < 4 or len(approx) > 6:
                continue
            # DAS ist dein entscheidender Filter
            if border_ratio < 0.6:
                continue

            # optional: nicht zu komplex
            epsilon = 0.02 * cv2.arcLength(largest, True)
            approx = cv2.approxPolyDP(largest, epsilon, True)

            if len(approx) > 15:
                continue

            # ------------------------------------------------------------
            # ACCEPT
            # ------------------------------------------------------------
            processed_areas.append((x, y, w, h))
            saved_y_markers.append(y)

            size = w * h * (2.54 / 400) ** 2
            threshold_last = str(threshold).split(".")[-1]

            base_name = (
                f"{page_number}-thr{threshold_last}_"
                f"{os.path.basename(current_page_path).rsplit('.', 1)[0]}_"
                f"border_"
                f"y{y}_x{x}_n{count}"
            )

            img_path = os.path.join(output_dir, base_name + ".tif")
            csv_path = os.path.join(output_page_records, base_name + ".csv")

            crop = img_color[y:y+h, x:x+w]
            cv2.imwrite(img_path, crop)

            record_row = [
                page_number,
                previous_page_path,
                next_page_path,
                current_page_path,
                img_path,
                x, y, w, h,
                size,
                threshold,
                round(time.time() - start_time_local, 3),
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

            count += 1

        if count == 0:
            print("No maps found on this page.")

    except Exception as e:
        print("rror in match_template_border:", e)
# ------------------------------------------------------------
# Contour-based map detection (alternative approach)
# ------------------------------------------------------------
# Instead of matching pixel patterns, this method detects map regions
# based on geometric properties (size and shape).
#
# Key steps:
# - Convert image to binary (adaptive thresholding)
# - Enhance structures using morphological operations
# - Detect contours (external boundaries)
# - Filter contours based on template size ranges
#
# Advantages:
# - Works even if template matching fails (e.g., low contrast)
# - More robust to variations in map appearance
#
# Limitations:
# - Less precise than template matching
# - Depends strongly on thresholding and morphology parameters
#
# This method is useful as a fallback or alternative detection strategy.
# ------------------------------------------------------------
def match_template_contours(previous_page_path, next_page_path, current_page_path,
                            template_map_files, output_dir, output_page_records,
                            records, threshold, page_position, page_number_training_data, 
                            map_group="1"):
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
        print(" Page:", current_page_path)

        start_time_local = time.time()

        img_color = np.array(Image.open(current_page_path))
        img_gray = cv2.cvtColor(img_color, cv2.COLOR_BGR2GRAY)

        page_number = find_page_number(
            current_page_path,
            page_position,
            page_number_training_data
        )

        count = 0
        processed_areas = []
        saved_y_markers = []

        # ------------------------------------------------------------
        # Preprocessing
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

        print(f"🧪 DEBUG: {len(contours)} contours found")

        # ------------------------------------------------------------
        # Overlap check
        # ------------------------------------------------------------
        def is_overlapping(x, y, w, h):
            for (px, py, pw, ph) in processed_areas:
                if (x < px + pw and x + w > px and
                    y < py + ph and y + h > py):
                    return True
            return False

        # ------------------------------------------------------------
        # Loop over templates (same structure as match_template)
        # ------------------------------------------------------------
        for template_map_file, template in template_map_files:

            template_gray = cv2.cvtColor(template, cv2.COLOR_BGR2GRAY)
            th, tw = template_gray.shape

            # Template-based reference metrics
            template_std = np.std(template_gray)
            template_edges = cv2.Canny(template_gray, 50, 150)
            template_edge_density = np.sum(template_edges > 0) / (tw * th)

            min_w = int(tw * 0.75)
            min_h = int(th * 0.75)
            max_w = int(tw * 1.40)
            max_h = int(th * 1.40)

            for contour in contours:

                x, y, w, h = cv2.boundingRect(contour)

                # ----------------------------------------------------
                # SIZE FILTER
                # ----------------------------------------------------
                if w < min_w or h < min_h:
                    continue
                if w > max_w or h > max_h:
                    continue

                # ----------------------------------------------------
                # ASPECT RATIO
                # ----------------------------------------------------
                ratio = w / float(h)
                if ratio < 0.6 or ratio > 2.5:
                    continue

                # ----------------------------------------------------
                # AREA FILTER
                # ----------------------------------------------------
                area = w * h
                img_area = img_gray.shape[0] * img_gray.shape[1]

                if area < img_area * 0.01:
                    continue
                if area > img_area * 0.6:
                    continue

                # ----------------------------------------------------
                # COMPACTNESS
                # ----------------------------------------------------
                contour_area = cv2.contourArea(contour)
                extent = contour_area / float(w * h)

                if extent < 0.4:
                    continue

                # ----------------------------------------------------
                # OVERLAP
                # ----------------------------------------------------
                if is_overlapping(x, y, w, h):
                    continue

                # ----------------------------------------------------
                # Y FILTER
                # ----------------------------------------------------
                y_tol = int(h * 0.25)
                too_close = False

                for y_prev in saved_y_markers:
                    if abs(y - y_prev) <= y_tol:
                        too_close = True
                        break

                if too_close:
                    continue

                # ----------------------------------------------------
                # 🆕 TEMPLATE-BASED CONTENT FILTER
                # ----------------------------------------------------
                roi = img_gray[y:y+h, x:x+w]

                roi_std = np.std(roi)

                edges = cv2.Canny(roi, 50, 150)
                roi_edge_density = np.sum(edges > 0) / (w * h)

                std_ratio = roi_std / (template_std + 1e-6)
                edge_ratio = roi_edge_density / (template_edge_density + 1e-6)

                # 🔥 entscheidender Filter, für später mit anderen Bücher, kann man aus der konfig lesen
                USE_CONTENT_FILTER = False
                if USE_CONTENT_FILTER:
                  if std_ratio < 0.2 or edge_ratio < 0.2:
                    continue

                # ----------------------------------------------------
                # ACCEPT
                # ----------------------------------------------------
                processed_areas.append((x, y, w, h))
                saved_y_markers.append(y)

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

                # SAME crop behaviour as template matching
                extra_h = int(h * 0.1)
                y_end = min(y + h + extra_h, img_color.shape[0])

                crop = img_color[y:y_end, x:x + w]
                cv2.imwrite(img_path, crop)

                record_row = [
                    page_number,
                    previous_page_path,
                    next_page_path,
                    current_page_path,
                    img_path,
                    x, y, w, h,
                    size,
                    threshold,
                    round(time.time() - start_time_local, 3),
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

                count += 1

        if count == 0:
            print("⚠️ No maps found on this page.")

    except Exception as e:
        print("❌ Error in match_template_contours:", e)


def correct_page_number_chars(ocr_text, numeric_text):
    """
    Correct non-digit OCR characters while keeping digits
    already detected by the numeric OCR.

    Examples:
        numeric OCR = "4", free OCR = "Al" -> "41"
        numeric OCR = "7", free OCR = "7I" -> "71"
    """

    global page_number_ocr_corrections

    free_text = str(ocr_text).strip()
    numeric_text = str(numeric_text).strip()

    result = ""
    numeric_index = 0

    for char in free_text:

        # -------------------------------------------------
        # Digit found by free OCR -> keep it
        # -------------------------------------------------
        if char.isdigit():
            result += char

            if (
                numeric_index < len(numeric_text)
                and numeric_text[numeric_index] == char
            ):
                numeric_index += 1

            continue

        # -------------------------------------------------
        # If numeric OCR still has a detected digit,
        # prefer that digit
        # -------------------------------------------------
        if numeric_index < len(numeric_text):
            result += numeric_text[numeric_index]
            numeric_index += 1
            continue

        # -------------------------------------------------
        # Otherwise try known character correction
        # -------------------------------------------------
        corrected_char = None

        if page_number_ocr_corrections is not None:

            match = page_number_ocr_corrections[
                page_number_ocr_corrections["ocr_char"] == char
            ]

            if not match.empty:
                corrected_char = str(
                    match.iloc[0]["correct_char"]
                )

        if corrected_char is not None:
            result += corrected_char

    print(
        f"Page-number combined OCR: "
        f"numeric='{numeric_text}', "
        f"free='{free_text}' -> '{result}'"
    )

    return result
  
  
# ------------------------------------------------------------
# Main workflow controller for template matching
# ------------------------------------------------------------
# This function orchestrates the entire matching process:
#
# 1. Loads all page images
# 2. Loads templates for each map group
# 3. Iterates over pages
# 4. Applies matching (template or contour-based)
#
# Key optimization:
# - Each page is loaded only ONCE into memory
# - All templates across all groups are applied to that page
#   → significantly reduces I/O overhead
#
# Flexible features:
# - Supports multiple map types (groups)
# - Allows page selection (single page, range, or ALL)
# - Switch between matching methods:
#     1 = template matching
#     2 = contour-based detection
#
# Output structure:
# output/<group>/
#   ├── maps/matching/
#   ├── pagerecords/
#   └── records.csv
#
# This function connects the input data with the full
# Distribution Digitizer processing pipeline.
# ------------------------------------------------------------

def main_template_matching(
    workingDir,
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
        workingDir = workingDir.rstrip("/\\")
        outDir = outDir.rstrip("/\\")
        pages_dir = os.path.join(workingDir, "data", "input", "pages")
        templates_root = os.path.join(workingDir, "data", "input", "templates")
        # ------------------------------------------------------------
        # Load page-number training data
        # ------------------------------------------------------------
        
        page_number_training_file = os.path.join(
            workingDir,
            "training",
            "page_number_training_data.csv"
        )
        
        print("DEBUG training file:", page_number_training_file)
        print("DEBUG exists:", os.path.exists(page_number_training_file))
        
        # ------------------------------------------------------------
        # Load page-number OCR corrections
        # ------------------------------------------------------------
        
        page_number_corrections_file = os.path.join(
            workingDir,
            "training",
            "page_number_ocr_corrections.csv"
        )
        
        print(
            "DEBUG page-number corrections file:",
            page_number_corrections_file
        )
        print(
            "DEBUG exists:",
            os.path.exists(page_number_corrections_file)
        )
        
        global page_number_ocr_corrections
        
        if os.path.exists(page_number_corrections_file):
        
            page_number_ocr_corrections = pd.read_csv(
                page_number_corrections_file,
                dtype=str,
                keep_default_na=False
            )
        
            print(
                f"✅ Page-number OCR corrections loaded: "
                f"{len(page_number_ocr_corrections)} correction(s)"
            )
        
        else:
        
            page_number_ocr_corrections = None
        
            print(
                "⚠️ No page-number OCR corrections found."
            )
        
        
        
        
        
        
        
        
        if os.path.exists(page_number_training_file):
        
            page_number_training_data = pd.read_csv(
                page_number_training_file
            )
        
            print(
                f"✅ Page-number training data loaded: "
                f"{len(page_number_training_data)} examples"
            )
        
        else:
        
            page_number_training_data = None
        
            print(
                "⚠️ No page-number training data found. "
                "Using conventional page-number detection."
    )
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

        # --- Setup output folders and clean previous results ---
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
        
        # --- Load templates into memory for faster matching ---
        all_templates = {}

        for group in map_groups:
            maps_dir = os.path.join(templates_root, group, "maps")
        
            if not os.path.isdir(maps_dir):
                print(f"⚠️ No 'maps' directory found for group {group}")
                continue
        
            templates = sorted(glob.glob(os.path.join(maps_dir, "*.tif")))
        
            # ✅ FIRST: check if templates exist
            if not templates:
                print(f"⚠️ No .tif templates found in {maps_dir}")
                continue
        
            # ✅ THEN: load them
            loaded_templates = []
            for t in templates:
                try:
                    img = np.array(Image.open(t))
                    loaded_templates.append((t, img))
                except:
                    continue
        
            all_templates[group] = loaded_templates
        
            print(f"✅ {len(loaded_templates)} templates loaded for group {group}")

        if not all_templates:
            print("❌ No templates found in any group.")
            return

       # --- Create and organize output folders for storing results ---
        for group in map_groups:
            base = os.path.join(outDir, group)
            os.makedirs(os.path.join(base, "maps", "matching"), exist_ok=True)
            os.makedirs(os.path.join(base, "pagerecords"), exist_ok=True)

       # --- Process matching per page to avoid repeated image loading ---
       
        for i, current_page_path in enumerate(pages):
            print(f"\n🗎 Processing page {os.path.basename(current_page_path)}")

            prev_path = pages[i - 1] if i > 0 else 'None'
            next_path = pages[i + 1] if i < len(pages) - 1 else 'None'

            # Load page only once and reuse it for all template groups
            # → avoids repeated disk I/O and improves performance
            img = np.array(Image.open(current_page_path))
            

            # Iterate over all template groups and apply matching for each template
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
                    "page_number_training_data": page_number_training_data,
                    "map_group": group
                     }

                if matchingType == 1:
                    match_template(**params)
                elif matchingType == 2:
                    match_template_contours(**params)
                elif matchingType == 3:
                    match_template_border(**params)

        print("\n✅ Matching completed for all pages and map types.")

    except Exception as e:
        print("❌ Error in main_template_matching:", e)



#workingDir="D:/distribution_digitizer"
#outDir="D:/test/output_2026-01-28_16-17-41/"
##main_template_matching(workingDir, outDir,  0.18, 1, 1, "0043.tif", 2)
#main_template_matching(workingDir, outDir,  0.18, 1, 2, "1-1", 2)
