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
import re

import cv2
import numpy as np
import os
import csv
import time
from PIL import Image

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
  #while True:
   # cv2.imshow("Sheep", croped_image)
  #  cv2.waitKey(0)
  #  sys.exit() # to exit from all the processes
 
#  cv2.destroyAllWindows() 
        



# Example usage
# Assuming croped_image is your image (Image) or its path
#current_page_path = "D:/distribution_digitizer/data/input/pages/0064.tif" 
#image = cv2.imread(image_path)
#result = find_page_number(current_page_path, page_position=1)


# Function to match template and process the result
def match_template_tiff(previous_page_path, next_page_path, current_page_path, 
                        template_map_file, output_dir, output_page_records, 
                        records, threshold, page_position):
    """
    Find the maps, save them, and write the map coordinates in a CSV file.
    """
    try:
        print(current_page_path)
        print(template_map_file)
        
        # Open the TIFF file and template using PIL
        img = np.array(Image.open(current_page_path))
        imgc = img.copy()
        
        # Open the template map
        tmp = np.array(Image.open(template_map_file))
        h, w, c = tmp.shape 
        
        # Template Matching using cv2
        res = cv2.matchTemplate(img, tmp, cv2.TM_CCOEFF_NORMED)
        loc = np.where(res >= threshold)
        
        # Define lists to store X and Y coordinates
        lspointY = []
        lspointX = []
        
        count = 0
        font = cv2.FONT_HERSHEY_SIMPLEX
        page_number = find_page_number(current_page_path, page_position)
    
        for pt in zip(*loc[::-1]):
            # Check if the coordinates are already in the list
            if pt[0] not in lspointY and pt[1] not in lspointX:
                size = w * h * (2.54/400) * (2.54/400)
                
                # Save record details into the main records CSV file
                rows_records = [[str(page_number), previous_page_path, next_page_path, current_page_path, pt[0], pt[1], w, h, size, threshold, (time.time() - start_time)]]
                
                # Write the record into the CSV file
                is_empty = os.stat(records).st_size == 0
                with open(records, 'a', newline='') as csv_file:  
                    csvwriter = csv.writer(csv_file)
                    if is_empty:
                        csvwriter.writerow(fields)
                    csvwriter.writerows(rows_records)
                
                # Save the extracted map
                threshold_last = str(threshold).split(".")
                img_map_path = (str(page_number) + '-' + str(threshold_last[1]) + '_' +
                                os.path.basename(current_page_path).rsplit('.', 1)[0] + 
                                os.path.basename(template_map_file).rsplit('.', 1)[0] + '_' + str(count))
                
                cv2.imwrite(output_dir + img_map_path + '.tif', imgc[pt[1]:(pt[1] + h), pt[0]:(pt[0] + w), :])
                
                # Draw a rectangle around the matched region on the original image
                cv2.rectangle(imgc, pt, (pt[0] + w, pt[1] + h), (0, 255, 0), 2)  # Green rectangle with 2 px thickness
                
                # Save the page record
                rows = [[str(page_number), previous_page_path, next_page_path, current_page_path, output_dir + img_map_path + '.tif', pt[0], pt[1], w, h, size, threshold, (time.time() - start_time)]]
                csv_path = output_page_records + img_map_path + '.csv'
                with open(csv_path, 'w', newline='') as page_record:
                    pageCsvwriter = csv.writer(page_record)
                    pageCsvwriter.writerow(fields_page_record)
                    pageCsvwriter.writerows(rows)
                
                # Append the coordinates to avoid duplicates
                lspointX.extend(range(pt[1], pt[1] + h))
                lspointY.extend(range(pt[0], pt[0] + w))
                
                count += 1
    
        # For Tests - Save the image with the drawn rectangles
        #final_output_path = os.path.join(output_dir, 'matches_' + os.path.basename(current_page_path))
        #cv2.imwrite(final_output_path, imgc)
        #print(f"Image with drawn matches saved at {final_output_path}")
    
    except Exception as e:
        print("An error occurred in match_template_tiff:", e)


def match_template_images(previous_page_path, next_page_path, current_page_path, 
                          template_map_file, output_dir, output_page_records, 
                          records, threshold, page_position):
    try:
        print(current_page_path)
        print(template_map_file)

        # Lade das Bild als Graustufenbild
        img = np.array(Image.open(current_page_path).convert('L'))  # Bild im Graustufenmodus
        imgc = np.array(Image.open(current_page_path))  # Farbversion für Ausgabe

        # Lade die Vorlage
        template = np.array(Image.open(template_map_file))
        #h, w, c = tmp.shape
        
        # Binärbild durch Schwellenwertbildung erstellen
        _, binary = cv2.threshold(img, 128, 255, cv2.THRESH_BINARY_INV)
        
        # Debugging-Ausgaben
        print("Binary image shape:", binary.shape)  # Überprüfen der Form des binären Bildes
        print("Image dtype:", binary.dtype)  # Überprüfen des Datentyps des binären Bildes

        # Morphologische Operationen (optional)
        kernel = np.ones((5, 5), np.uint8)
        dilated = cv2.dilate(binary, kernel, iterations=2)
        eroded = cv2.erode(dilated, kernel, iterations=2)

        # Finde die Konturen im erodierten Bild
        contours, _ = cv2.findContours(eroded, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        # Ergebnisse für CSV speichern
        results = []
        template_h, template_w = template.shape[:2]
            
        # Definiere eine Toleranz für die Konturengrößen, basierend auf der Template-Größe
        tolerance = 0.5  # 50% Toleranz auf die Template-Größe
        min_w = int(template_w * (1 - tolerance))
        max_w = int(template_w * (1 + tolerance))
        min_h = int(template_h * (1 - tolerance))
        max_h = int(template_h * (1 + tolerance))
        
         # Liste, um bereits verarbeitete Bereiche zu speichern (um Überschneidungen zu verhindern)
        processed_areas = []

        # Funktion zur Überprüfung, ob ein neuer Bereich bereits bearbeitet wurde
        def is_overlapping(x, y, w, h, processed_areas):
            for (px, py, pw, ph) in processed_areas:
                if (x < px + pw and x + w > px and y < py + ph and y + h > py):
                    return True
            return False
        # Durchlaufe alle gefundenen Konturen
        for idx, contour in enumerate(contours):
            x, y, w, h = cv2.boundingRect(contour)
            size = w * h * (2.54 / 400) * (2.54 / 400)  # Berechnung der Kartengröße
            
            # Überprüfen, ob die Größe innerhalb der Toleranz liegt
            if min_w <= w <= max_w and min_h <= h <= max_h and not is_overlapping(x, y, w, h, processed_areas):
                   
                # Speichern der Aufzeichnung in der Haupt-CSV-Datei
                page_number = find_page_number(current_page_path, page_position)
                rows_records = [[str(page_number), previous_page_path, next_page_path, current_page_path, x, y, w, h, size, threshold, (time.time() - start_time)]]

                # CSV für alle Ergebnisse
                is_empty = os.stat(records).st_size == 0
                with open(records, 'a', newline='') as csv_file:
                    csvwriter = csv.writer(csv_file)
                    if is_empty:
                        csvwriter.writerow(fields)  # Hier sollte die Header-Liste definiert sein
                    csvwriter.writerows(rows_records)

                # Speichere die extrahierte Karte
                img_map_path = f"{page_number}_{os.path.basename(current_page_path).rsplit('.', 1)[0]}_{idx}"
                cv2.imwrite(os.path.join(output_dir, img_map_path + '.tif'), imgc[y:y+h, x:x+w])

                # Zeichne ein Rechteck um den gefundenen Bereich
                cv2.rectangle(imgc, (x, y), (x + w, y + h), (0, 255, 0), 2)

                # Speichere die Seitenaufzeichnung
                csv_path = os.path.join(output_page_records, img_map_path + '.csv')
                with open(csv_path, 'w', newline='') as page_record:
                    pageCsvwriter = csv.writer(page_record)
                    pageCsvwriter.writerow(fields_page_record)  # Diese Header-Liste sollte definiert sein
                    rows = [[str(page_number), previous_page_path, next_page_path, current_page_path, os.path.join(output_dir, img_map_path + '.tif'), x, y, w, h, size, threshold, (time.time() - start_time)]]
                    pageCsvwriter.writerows(rows)

        # Speichere das Bild mit den gezeichneten Rechtecken
        final_output_path = os.path.join(output_dir, 'matches_' + os.path.basename(current_page_path))
        cv2.imwrite(final_output_path, imgc)
        print(f"Image with drawn matches saved at {final_output_path}")

    except Exception as e:
        print("An error occurred in match_template_images:", e)

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
def main_template_matching(working_dir, outDir, threshold, page_position, modi):
  """
  Perform the main template matching process.

  Args:
  - working_dir (str): Working directory.
  - outDir (str) : Output directory
  - threshold (float): Threshold value for template matching.
  - page_position (int): The position of the page number. 1 for the top, 2 for the bottom.
  """
  try:
    # OUTPUT
    print("Working directory matching:")
    print(working_dir)
    output_dir = ""
    output_page_records = ""
    records = ""
    if(os.path.exists(outDir)):
      if outDir.endswith("/"):
        output_dir = outDir + "maps/matching/"
        output_page_records = outDir + "pagerecords/"
        records = outDir + "records.csv"
      else:
        output_dir = outDir + "/maps/matching/"
        output_page_records = outDir + "/pagerecords/"
        records = outDir + "/records.csv"
   
    print("Output directory matching:")
    print(output_dir)

    #page_position = 1
    print("Site number position:")
    print(page_position)
    #threshold=0.2
    # prepare the png directory
    # for the converted png images after the matching process 
    if working_dir.endswith("/"):
      output_png_dir = working_dir + "www/data/matching_png/"
      templates = working_dir+"data/input/templates/maps/"
      input_dir = working_dir + "data/input/pages/"
    else: 
      output_png_dir = working_dir + "/www/data/matching_png/"
      templates = working_dir+"/data/input/templates/maps/"
      input_dir = working_dir + "/data/input/pages/"
  
    print(templates)
    tif_files = sorted(glob.glob(input_dir + '*.tif'))
    
    # Start the matching in loop input templates and input pages 
    with open(records, 'w', newline='') as csv_file:  
 
      # Creating a csv writer object to write the map coordinats     
      csvwriter = csv.writer(csv_file)   

      # Iteriere über die Template-Dateien
      for template_map_file in glob.glob(templates + '*.tif'):
        # Iteriere über die TIFF-Dateien im input_dir
        for index, current_page_path in enumerate(sorted(glob.glob(input_dir + '*.tif'))):
    
          # Bestimme den Pfad der vorherigen Seite (falls vorhanden)
          previous_page_path = tif_files[index - 1] if index > 0 else 'None'
          print("prev",previous_page_path)
          print("current",current_page_path)
          # Bestimme den Pfad der nächsten Seite (falls vorhanden)
          next_page_path = tif_files[index + 1] if index < len(tif_files) - 1 else 'None'
          print("next", next_page_path)
          # Hier kannst du die Pfade an deine Funktion übergeben
          params = {
            "previous_page_path": previous_page_path,
            "next_page_path": next_page_path,
            "current_page_path": current_page_path,
            "template_map_file": template_map_file,
            "output_dir": output_dir,
            "output_page_records": output_page_records,
            "records": records,
            "threshold": threshold,
            "page_position": page_position
          }
          if modi == 1:
            match_template_tiff(**params)
          elif modi == 2:
            match_template_images(**params)
  except Exception as e:
        print("An error occurred in main_template_matching:", e)
#img = "D:/distribution_digitizer_11_01_2024//data/input/pages/0059.tif"      
#test = find_page_number(img,1)
#print(test)

#working_dir="D:/distribution_digitizer"
#outDir="D:/test/output_2024-10-04_11-57-39/"
#main_template_matching(working_dir, outDir,  0.2, 2, 1)

# Function to perform the main template matching in a loop
#main_template_matching(working_dir, 0.2, 1)
