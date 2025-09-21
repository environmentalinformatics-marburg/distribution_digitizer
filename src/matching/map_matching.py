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

# Function to match template and process the result
def match_template(previous_page_path, next_page_path, current_page_path,
                   template_map_file, output_dir, output_page_records,
                   records, threshold, page_position):
    """
    Find the maps using template matching, save them, and write the map coordinates in CSV files.
    """
    try:
        print(current_page_path)
        print(template_map_file)

        img = np.array(Image.open(current_page_path))
        imgc = img.copy()

        tmp = np.array(Image.open(template_map_file))
        h, w, c = tmp.shape

        res = cv2.matchTemplate(img, tmp, cv2.TM_CCOEFF_NORMED)
        loc = np.where(res >= threshold)

        saved_maps = []
        count = 0
        page_number = find_page_number(current_page_path, page_position)

        for pt in zip(*loc[::-1]):
            x, y = pt[0], pt[1]

            too_close = any(abs(y - sy) < (h / 2) for sx, sy in saved_maps)

            if not too_close:
                size = w * h * (2.54/400) * (2.54/400)

                rows_records = [[str(page_number), previous_page_path, next_page_path,
                                 current_page_path, x, y, w, h, size,
                                 threshold, (time.time() - start_time)]]

                is_empty = os.stat(records).st_size == 0
                with open(records, 'a', newline='') as csv_file:
                    csvwriter = csv.writer(csv_file)
                    if is_empty:
                        csvwriter.writerow(fields)
                    csvwriter.writerows(rows_records)

                threshold_last = str(threshold).split(".")
                # ✅ Y-position at the very end of the filename
                img_map_path = (
                    str(page_number) + '-' + str(threshold_last[1]) + '__' +
                    os.path.basename(current_page_path).rsplit('.', 1)[0] +
                    os.path.basename(template_map_file).rsplit('.', 1)[0] +
                    '_' + str(count) +
                    '_y' + str(y)
                )

                cv2.imwrite(output_dir + img_map_path + '.tif',
                            imgc[y:(y + h), x:(x + w), :])

                cv2.rectangle(imgc, pt, (pt[0] + w, pt[1] + h),
                              (0, 255, 0), 2)

                rows = [[str(page_number), previous_page_path, next_page_path,
                         current_page_path, output_dir + img_map_path + '.tif',
                         x, y, w, h, size, threshold, (time.time() - start_time)]]
                csv_path = output_page_records + img_map_path + '.csv'
                with open(csv_path, 'w', newline='') as page_record:
                    pageCsvwriter = csv.writer(page_record)
                    pageCsvwriter.writerow(fields_page_record)
                    pageCsvwriter.writerows(rows)

                saved_maps.append((x, y))
                count += 1

    except Exception as e:
        print("An error occurred in match_template:", e)


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

def main_template_matching(working_dir, outDir, threshold, page_position, matchingType, pageSel="ALL"):
    """
    Perform the main template matching process.

    Args:
    - working_dir (str): Working directory
    - outDir (str): Output directory
    - threshold (float): Threshold value for template matching
    - page_position (int): The position of the page number. 1=top, 2=bottom
    - matchingType (int): 1 = template, 2 = contours
    - pageSel (str|int): "ALL" = all pages,
                         int = first N pages,
                         "start-end" = range of pages (inclusive),
                         "*.tif" = single page file
    """
    # --- sanitize Shiny inputs ---
    threshold = float(threshold)
    page_position = int(page_position)
    matchingType = int(matchingType)
    pageSel = str(pageSel).strip()

    #print("DEBUG threshold:", threshold, type(threshold))
    #print("DEBUG sNumberPosition:", page_position, type(page_position))
    #print("DEBUG matchingType:", matchingType, type(matchingType))
    #print("DEBUG pageSel raw:", pageSel, type(pageSel))
    

    try:
        # --- Output dirs ---
        if outDir.endswith("/"):
            output_dir = outDir + "maps/matching/"
            output_page_records = outDir + "pagerecords/"
            records = outDir + "records.csv"
        else:
            output_dir = outDir + "/maps/matching/"
            output_page_records = outDir + "/pagerecords/"
            records = outDir + "/records.csv"

        if working_dir.endswith("/"):
            templates = working_dir + "data/input/templates/maps/"
            input_dir = working_dir + "data/input/pages/"
        else:
            templates = working_dir + "/data/input/templates/maps/"
            input_dir = working_dir + "/data/input/pages/"

        tif_files = sorted(glob.glob(os.path.join(input_dir, '*.tif')))
        print("DEBUG input_dir:", input_dir)
        print("DEBUG number of tif files found:", len(tif_files))

        # Remove old matching results
        if os.path.exists(output_dir):
            shutil.rmtree(output_dir)
        os.makedirs(output_dir, exist_ok=True)

        # Remove old page records
        if os.path.exists(output_page_records):
            shutil.rmtree(output_page_records)
        os.makedirs(output_page_records, exist_ok=True)

        # Remove old records.csv
        if os.path.exists(records):
            os.remove(records)
            
        # --- collect all pages ---
        tif_files = sorted(glob.glob(os.path.join(input_dir, '*.tif')))

        # --- Page selection ---
        if str(pageSel).upper() == "ALL" or str(pageSel).strip() == "":
            # Case 1: All pages
            pages = tif_files
        
        elif str(pageSel).lower().endswith(".tif"):
            # Case 2: Exact filename
            candidate = os.path.join(input_dir, pageSel)
            if not os.path.exists(candidate):
                raise FileNotFoundError(f"❌ Page file not found: {candidate}")
            pages = [candidate]
        
        elif "-" in str(pageSel):
            # Case 3: Range "start-end"
            parts = str(pageSel).split("-")
            if len(parts) != 2 or not parts[0].isdigit() or not parts[1].isdigit():
                raise ValueError(f"❌ Invalid range format: {pageSel}")
        
            start = int(parts[0])
            end = int(parts[1])
            if start > end:
                raise ValueError(f"❌ Invalid range: start ({start}) > end ({end})")
        
            # Convert 1-based page numbers to 0-based indices
            pages = tif_files[start-1:end]
        
        else:
            raise ValueError(f"❌ Invalid pageSel argument: {pageSel}")

        print(f"➡️ Processing {len(pages)} page(s):")
        for p in pages:
            print("   ", p)

        # --- start matching ---
        with open(records, 'w', newline='') as csv_file:
            csvwriter = csv.writer(csv_file)

            for template_map_file in glob.glob(os.path.join(templates, '*.tif')):
                for index, current_page_path in enumerate(pages):
                    prev_path = pages[index - 1] if index > 0 else 'None'
                    next_path = pages[index + 1] if index < len(pages) - 1 else 'None'

                    print("prev", prev_path)
                    print("current", current_page_path)
                    print("next", next_path)

                    params = {
                        "previous_page_path": prev_path,
                        "next_page_path": next_path,
                        "current_page_path": current_page_path,
                        "template_map_file": template_map_file,
                        "output_dir": output_dir,
                        "output_page_records": output_page_records,
                        "records": records,
                        "threshold": threshold,
                        "page_position": page_position
                    }
                    if matchingType == 1:
                        match_template(**params)
                    elif matchingType == 2:
                        match_template_contours(**params)

    except Exception as e:
        print("❌ An error occurred in main_template_matching:", e)


#working_dir="D:/distribution_digitizer"
#outDir="D:/test/output_2025-09-18_13-08-43/"
#main_template_matching(working_dir, outDir,  0.18, 1, 1, "0088.tif")
#main_template_matching(working_dir, outDir,  0.18, 1, 2, "1-2")

