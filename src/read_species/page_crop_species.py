# ============================================================
# Script Author: [Spaska Forteva]
# Created On: 2023-24-09
# ============================================================
"""
Description: This script edits book pages and crops the main spacies titles.
"""

# start miniconda promt as admin 
# conda activate base
# conda install opencsv
# pip install matplotlib
# pip install pytesseract
#C:\ProgramData\miniconda3\python.exe -m pip install --upgrade pip

import cv2
import pytesseract
import re 
import matplotlib.pyplot as plt
# Schriftgröße noch mal prüfen mit tesa 
from PIL import Image 

from PIL import Image
import re

def find_specie_context_with_keyword(extracted_data, page_path, search_specie, keyword, keyword_top=None, keyword_bottom=None, middle=None):
    """
    This function searches for a species name and a year in the context of a given keyword in an image.

    Parameters:
    - page_path (str): The file path of the image.
    - search_specie (str): The species name to search for.
    - keyword (str): The keyword to locate in the image.
    - keyword_top (int or None): The number of lines above the keyword to consider.
    - keyword_bottom (int or None): The number of lines below the keyword to consider.
    - middle (bool): Flag indicating whether to search for the species name in the middle of the context.

    Returns:
    - specie_content (str): The content of the line containing the species name.
    """
    
    #page_path = 'D:/distribution_digitizer_11_01_2024/data/input/pages/0058.tif'
    #search_specie = "_bevani"
    #keyword = "Range"
    #keyword_top = 2
    specie_content = "none"
    # Load the image from the specified file path
    image = Image.open(page_path)

    # Get the width and height of the image
    image_width, image_height = image.size
    # Text extraction
    extracted_text = pytesseract.image_to_string(image)

    # Split the text into lines
    lines = extracted_text.split('\n')

    year_pattern = re.compile(r'\b\d{4}\b')  # Regular expression for a four-digit year
    search_specie = search_specie.strip(' ,.?!()[]{}_"\';')
    difference = 0
    if keyword_top is not None and keyword_top > 0:
        difference = -keyword_top
    elif keyword_bottom is not None and keyword_bottom > 0:  # Corrected syntax here
        difference = keyword_bottom
   
    # Iterate through each line and search for the keyword
    for line_num, line in enumerate(lines, start=0):
      if keyword in line:
        temp_line = lines[int(line_num + difference)]
        # Check if the species name and a year are present in the line before the keyword
        if search_specie in temp_line and year_pattern.search(temp_line):
          print(f'The string "{search_specie}" and a year were found in the line before "{keyword}" (Line {line_num - 1}):')
          specie_content = temp_line
         
          if middle:
            index_left = extracted_data['text'].index(specie_content.split()[0])
            # print(extracted_data['left'][index_left])
            # print(image_width/4)
            if int(extracted_data['left'][index_left]) > (image_width/6):
              print(f'Species name  "{temp_line}" was found in the middle')
              return temp_line
        
      elif search_specie in line and year_pattern.search(line):
        print(f'The string "{search_specie}" were found in the line (Line {line_num - 1}):')
        return line

    return specie_content

           
          
    
# Function recognizing rows with keywords and special regex 
def find_specie_context(previous_page_path, next_page_path, page_path="", words_to_find="", keyword=None, keyword_top=None, keyword_bottom=None, middle=None):
  
  # Load the image from the specified file path
  #page_path = 'D:/distribution_digitizer_11_01_2024/data/input/pages/0058.tif'
  #words_to_find = "_cinnara"
  
    # Load the image
  image = Image.open(page_path)
  # Perform OCR
  #extracted_text = pytesseract.image_to_string(image)

  words = words_to_find.split("_")
  
  # Lambda-Funktion, um leere Zeichenfolgen aus der Liste zu entfernen.
  words = list(filter(lambda x: x != "", words))

  # Patter for special species
  pattern = r'\b\d{4}\b'
  print(words)
    
  # Extract text from the image
  extracted_data = pytesseract.image_to_data(image, output_type=pytesseract.Output.DICT)
  all_results = []
  specie_content = "" 
  if(keyword is not None):
    print("if1")
    for search_specie in words:
      print(search_specie)
     
      specie_content = find_specie_context_with_keyword(extracted_data, page_path,
                        search_specie, keyword, keyword_top, keyword_bottom, middle)
      print(specie_content)
      if(specie_content != 'none'):
        all_results.append(specie_content)
        return all_results
      
      
    if  (specie_content == "none") and previous_page_path != 'None':
      print("if2")
      for search_specie in words:
        print(search_specie)
       
        specie_content = find_specie_context_with_keyword(extracted_data, previous_page_path,
                          search_specie, keyword, keyword_top, keyword_bottom, middle)
        print(specie_content)
        if(specie_content != 'none'):             
          all_results.append(specie_content)
          return all_results
      
    if (specie_content == "none") and next_page_path != 'None':
      print("if3")
      for search_specie in words:
        print(search_specie)
       
        specie_content = find_specie_context_with_keyword(extracted_data, next_page_path,
                          search_specie, keyword, keyword_top, keyword_bottom, middle)
        print(specie_content)
        if(specie_content != 'none'):
          all_results.append(specie_content)
          return all_resultseak
    
  if (keyword is None) or (specie_content == ""):
    print("if5")
    all_results = []
    #print(extracted_data.keys())
    block_nums = {}
    # Iterate through the recognized words and print their coordinates in the lines
    for i in range(len(extracted_data['text'])):
        word = extracted_data['text'][i].strip(' ,.?!()[]{}"\';')
        if word in words:
            if word not in block_nums:
                block_nums[word] = []
            block_nums[word].append(i)
            
      #print(extracted_data.keys())
    
    year_pattern = r'\b\d{4}\b'
    specie = ""
    for block in block_nums:
        # Initialisiere specie für jedes Blockelement
        specie = block
        
        # Neue Liste für jede Spezies erstellen
        specie_list = []
        
        # Iteriere über die Indizes in block_nums[block]
        for i in block_nums[block]:
            
            # Konvertiere i zu einem Integer
            i = int(i)
            start = i - 2
            lblock = i + 4
    
            # Verwende eine Liste, um Wörter zu sammeln
            words = []
    
            # Iteriere über den Bereich von start bis lblock
            for w in range(start, lblock):
                # Verwende nur eine Zeile für die Wortverarbeitung
                word = extracted_data['text'][w].strip().replace(",", "").replace("|", "")
                if len(word) > 1 and word.isalpha():
                  words.append(word)
    
            # Verwende ', ' zum Verbinden der Wörter
            specie_temp = specie + "; " + ' '.join(words)
    
            # Speichern Sie das aktuelle Wort
            # Search for matches in the text
            match = re.search(year_pattern, specie_temp)
            if match:
                current_word = match.group(0)
                print(current_word)
    
            # Füge das aktuelle specie_temp zur inneren Liste hinzu
            specie_list.append(specie_temp)
    
        # Füge die innere Liste zur äußeren Liste hinzu
       
        all_results.append(specie_list)
   
  if(len(all_results) == 0):
    all_results.append("te specie was not found")
  
  return all_results
 
#find_specie_context('None','None','D:/distribution_digitizer_11_01_2024/data/input/pages/0051.tif', "_indrani", "Range", 2, 0, True)
#find_specie_context('D:/distribution_digitizer_11_01_2024/data/input/pages/0058.tif', "_cinnara")
#find_specie_context('D:/distribution_digitizer_11_01_2024/data/input/pages/0058.tif', "_cinnara", "Range", keyword_top = 2, middle=True)
