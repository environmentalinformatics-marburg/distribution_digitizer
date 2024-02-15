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

  print(result)    
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

  Args:
  - current_page_path (str): Path to the TIFF file.
  - template_map_file (str): Path to the template map file.
  - output_dir (str): Output directory for the map images.
  - output_page_records (str): Output directory for page records.
  - records (str): Path to the main records CSV file.
  - threshold (float): Threshold value for template matching.
  - page_position (int): The position of the page number. 1 for the top, 2 for the bottom.
  """
  #current_page_path = "D:/distribution_digitizer/data/input/pages/0064.tif"
  #template_map_file = "D:/distribution_digitizer/data/input/templates/maps/map_1.tif"
  print(current_page_path)
  print(template_map_file)
  
  # user the PIL library to open the tiffile
  img = np.array(PIL.Image.open(current_page_path))
  imgc = img.copy()
  
  # user the PIL library to open the template map
  tmp = np.array(PIL.Image.open(template_map_file))
  # read the width and heigth from template maps
  h, w, c = tmp.shape 

  # Template Matching Function from package cv2
  res = cv2.matchTemplate(img, tmp, cv2.TM_CCOEFF_NORMED)
  # Adjust this threshold value to suit you, you may need some trial runs (critical!)
  loc = np.where(res >= threshold)
  
  # define an empty lists to store a range from X and Y coordinates
  lspointY = []
  lspointX = []
  
  count = 0
  font = cv2.FONT_HERSHEY_SIMPLEX
  page_number = find_page_number(current_page_path, page_position)
  #print(page_number)

  for pt in zip(*loc[::-1]):
    # check that the coords are not already in the list, if they are then skip the match
    if pt[0] not in lspointY and pt[1] not in lspointX:
      
        # draw a yellow boundary around a match- USE this just for tests!
        #rect = cv2.rectangle(img, pt, (pt[0] + h, pt[1] + w), (0, 0, 0), 3)
        size = w * h * (2.54/400 ) *( 2.54/400 )
        
        # put text with the information values - USE this just for tests!
        #cv2.putText(rect, "{:.1f}cm^2".format(size), (pt[0] + h, pt[1] + w), font, 4,0, 0, 255), 3)
        #cv2.imwrite('rect.png',rect)
        
        # data rows of csv file   
        rows_records = 0
        # WRITE the fields and rows values into the main records csv file
        rows_records = [[str(page_number),previous_page_path, next_page_path ,current_page_path, pt[0], pt[1], w, h ,size, threshold, (time.time() - start_time)]]   
        with open(records, 'a', newline='') as csv_file:  
          # creating a csv writer object   
          csvwriter = csv.writer(csv_file) 
          #if count == 0: 
          csvwriter.writerow(fields)
          ## writing the rows
          csvwriter.writerows(rows_records)
          
        # print(output_dir) 
        threshold_last=str(threshold).split(".")
        #print(threshold_last[1])
        
        img_map_path = (str(page_number) + '-' + str(threshold_last[1]) + '_' +
        os.path.basename(current_page_path).rsplit('.', 1)[0] + 
        os.path.basename(template_map_file).rsplit('.', 1)[0] + '_' + str(count))
        
        cv2.imwrite(output_dir + img_map_path + '.tif', imgc[ pt[1]:(pt[1] + h), pt[0]:(pt[0] + w),:])
        #print(output_dir + img_map_path + '.tif', imgc[ pt[1]:(pt[1] + h), pt[0]:(pt[0] + w),:])
       
        
        # WRITE the fields and rows values into the page record csv file
        row = 0
        rows = [[str(page_number), previous_page_path, next_page_path, current_page_path, output_dir + img_map_path + '.tif', pt[0], pt[1], 
          w, h ,size, threshold, (time.time() - start_time)]]  
        csv_path = output_page_records + img_map_path + '.csv'
        with open(csv_path, 'w', newline='') as page_record:  
          ## creating a csv writer object   
          pageCsvwriter = csv.writer(page_record)  
          pageCsvwriter.writerow(fields_page_record)
          ## writing the rows
          pageCsvwriter.writerows(rows)
              
        ## append a range from first y coord to x + width
        for k in range((pt[1]), ((pt[1])+h), 1):
	          lspointX.append(k)
        ## append a range from first y coord to y + high
        for i in range((pt[0]), ((pt[0])+w), 1):
            lspointY.append(i)
        count += 1
    else:
        continue
    
  print(template_map_file)
  print(current_page_path)
  print("--- %s seconds ---" % (time.time() - start_time))
  PIL.Image.fromarray(img, 'RGB').save(os.path.join(current_page_path))



#working_dir="D:/distribution_digitizer_11_01_2024/"
# Function to perform the main template matching in a loop
def main_template_matching(working_dir, threshold, page_position):
  """
  Perform the main template matching process.

  Args:
  - working_dir (str): Working directory.
  - threshold (float): Threshold value for template matching.
  - page_position (int): The position of the page number. 1 for the top, 2 for the bottom.
  """
  # ...
  # OUTPUT
  print("Working directory matching:")
  print(working_dir)
  
  output_dir = working_dir + "/data/output/maps/matching/"
  print("Out directory:")
  print(output_dir)
  os.makedirs(output_dir, exist_ok=True)
  
  #page_position = 1
  print("Site number position:")
  print(page_position)
  #threshold=0.2
  # prepare the png directory
  # for the converted png images after the matching process 
  output_png_dir = working_dir + "/www/matching_png/"
  os.makedirs(output_png_dir, exist_ok=True)

  # page_records csv file with the map coordinats
  output_page_records = working_dir + "/data/output/pagerecords/"
  os.makedirs(output_page_records, exist_ok=True)
  # files = glob.glob(output_page_records)
  #for f in files:
    #os.remove(f)
  records = working_dir + "/data/output/records.csv"
  # input dirs
  templates = working_dir+"/data/input/templates/maps/"
  input_dir = working_dir + "/data/input/pages/"
  tif_files = sorted(glob.glob(input_dir + '*.tif'))
  
  

  # Start the matching in loop input templates and input pages 
  with open(records, 'w', newline='') as csv_file:  
    
    # Creating a csv writer object to write the map coordinats     
    csvwriter = csv.writer(csv_file)   
      
    #for template_map_file in glob.glob(templates + '*.tif'): 
     # for tif_ffile in glob.glob(input_dir +'*.tif'): 
      #  match_template_tiff(tif_ffile, template_map_file, output_dir, 
       #   output_page_records, records, threshold, page_position)

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
        match_template_tiff(**params)
        
        
#img = "D:/distribution_digitizer_11_01_2024//data/input/pages/0059.tif"      
#test = find_page_number(img,1)
#print(test)

#working_dir="D:/distribution_digitizer_11_01_2024/"
# Function to perform the main template matching in a loop
#main_template_matching(working_dir, 0.2, 1)
