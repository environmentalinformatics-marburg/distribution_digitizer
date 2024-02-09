# ============================================================
# Script Author: [Spaska Forteva]
# Created On: 2023-24-09
# ============================================================

# Description: This script edits book pages and crops the main spacies titles.

# Required libraries
import cv2
import pytesseract
import re 
import matplotlib.pyplot as plt
from PIL import Image 

# Function to find species context with a given keyword
def find_specie_context_with_keyword(page_path, search_specie, keyword_page_Specie=None, keyword_top=None, keyword_bottom=None, middle=None):
  """
  This function searches for a species name and a year in the context of a specified keyword in an image.

  Parameters:
  - page_path (str): The file path of the image.
  - search_specie (str): The species name to search for.
  - keyword_page_Specie (str): The keyword to locate in the image.
  - keyword_top (int or None): The number of lines above the keyword to consider.
  - keyword_bottom (int or None): The number of lines below the keyword to consider.
  - middle (bool): Flag indicating whether the species name should be searched for in the middle of the context.

  Returns:
  - specie_content (str): The content of the line containing the species name.
  """
  _result = ""  # Initialize the result variable
  try:
    # Load the image from the specified file path
    image = Image.open(page_path)

    # Extract text from the image
    extracted_text = pytesseract.image_to_string(image)

    # Extract text data with detailed information
    extracted_data = pytesseract.image_to_data(image, output_type=pytesseract.Output.DICT)

    # Split the text into lines
    lines = extracted_text.split('\n')

    # Regular expression for a four-digit year
   # year_pattern = re.compile(r'\(\D*\d{4}\)')
    #year_pattern = re.compile(r'\b(?:\(\D*\d{4}\)|\d{4})\b')
    year_pattern = re.compile(r'\b\d{4}\b')
    # Remove unnecessary characters from the search_specie
    search_specie = search_specie.strip(' ,.?!()[]{}_"\';')

    # Initialize temp_line
    temp_line = ""
    
    # Iterate through each line and search for the keyword_page_Specie
    if keyword_page_Specie is not None:
      difference = 0
      if keyword_bottom is not None:
        difference = -int(keyword_bottom)
      elif keyword_top is not None:
        difference = int(keyword_top)

      for line_num, line in enumerate(lines, start=0):
        print(line)
        if keyword_page_Specie in line:
          print(line)
          if(len(lines[int(line_num + difference)])) > 3:
            temp_line = lines[int(line_num + difference)]
            print(temp_line)
            # Check if the species name and a year are present in the line before the keyword
            if search_specie in temp_line and year_pattern.search(temp_line):
              if middle:
                index_left = extracted_data['text'].index(temp_line.split()[0])
                maxPos = max(extracted_data['left'])
                if int(extracted_data['left'][index_left]) > (int(maxPos/4)/10):
                  print(f"Spacie {search_specie} was FOUND in this line: {temp_line} in the middle. Keyword: {keyword_page_Specie}")
                  return temp_line
              else:
                _result = temp_line
                print(f"The spacie {search_specie} was FOUND in this line: {temp_line} not in the middle. Keyword: {keyword_page_Specie}")
            else:
              print(f"The spacie {search_specie} was not found in this line: {temp_line}. Keyword: {keyword_page_Specie}")

    elif keyword_page_Specie is None:
      _result = ""
      for line_num, line in enumerate(lines, start=0):
        if search_specie in line and year_pattern.search(line):
          if middle:
            index_left = extracted_data['text'].index(line.split()[0])
            maxPos = max(extracted_data['left'])
            #print(index_left)
            #print(maxPos)
            #print(line)
            #print(int(extracted_data['left'][index_left]))
            if int(extracted_data['left'][index_left]) > (int(maxPos/4)/10):
              print(f"The spacie {search_specie} was FOUND in this line: {line} in the middle. No keyword")
              return line
          else:
            _result = line
            print(f"The spacie {search_specie} was found in this line: {line} not the middle. No keyword")
        #else:
            #print(f"The spacie {search_specie} was not found in this line: {line}. No keyword")
  except IndexError as e:
    # Handle the "index out of bounds" error specifically
    print("Index out of bounds error:", e)
  except Exception as e:
    # Handle other exceptions
    print("An error occurred:", e)

  return _result

# Function to find species context with a keyword
def find_species_context(page_path="", words_to_find="", previous_page_path=None, next_page_path=None, keyword_page_Specie=None, keyword_top=None, keyword_bottom=None, middle=None):
  
  # Load the image
  image = Image.open(page_path)
  words = words_to_find.split("_")
  # Lambda function to remove empty strings from the list
  words = list(filter(lambda x: x != "", words))
  
  # Patter for special species
  pattern = r'\b\d{4}\b'
  all_results = []
  
  specie_content = "" 
  
  if(middle==1): middle=True
  
  for search_specie in words:
    specie_content = find_specie_context( page_path,
                      search_specie, keyword_page_Specie, keyword_top, keyword_bottom, middle)
    if (len(specie_content) > 3):
      all_results.append(specie_content)
      return all_results

  if (len(specie_content) == 0) and (previous_page_path is not None):
    for search_specie in words:
      specie_content = find_specie_context( previous_page_path,
                        search_specie, keyword_page_Specie, keyword_top, keyword_bottom, middle)
      if(specie_content is not None):             
        all_results.append(specie_content)
        return all_results
    
  if (len(specie_content) == 0) and (next_page_path is not None):
    for search_specie in words:
      specie_content = find_specie_context( next_page_path,
                        search_specie, keyword_page_Specie, keyword_top, keyword_bottom, middle)
      if(specie_content is not None):
        all_results.append(specie_content)
        return all_results
    
  if(len(all_results) == 0):
    all_results.append("the specie was not found")
  return all_results



# Function to find species context with a given keyword
def find_specie_context(page_path, search_specie, keyword_page_Specie=None, keyword_top=None, keyword_bottom=None, middle=None):
  """
  This function searches for a species name and a year in the context of a specified keyword in an image.

  Parameters:
  - page_path (str): The file path of the image.
  - search_specie (str): The species name to search for.
  - keyword_page_Specie (str): The keyword to locate in the image.
  - keyword_top (int or None): The number of lines above the keyword to consider.
  - keyword_bottom (int or None): The number of lines below the keyword to consider.
  - middle (bool): Flag indicating whether the species name should be searched for in the middle of the context.

  Returns:
  - specie_content (str): The content of the line containing the species name.
  """
  _result = ""  # Initialize the result variable
  
  # Load the image from the specified file path
  image = Image.open(page_path)

  # Extract text from the image
  extracted_text = pytesseract.image_to_string(image)

  # Extract text data with detailed information
  extracted_data = pytesseract.image_to_data(image, output_type=pytesseract.Output.DICT)

  # Split the text into lines
  lines = extracted_text.split('\n')

  # Regular expression for a four-digit year
 # year_pattern = re.compile(r'\(\D*\d{4}\)')
  #year_pattern = re.compile(r'\b(?:\(\D*\d{4}\)|\d{4})\b')
  year_pattern = re.compile(r'\b\d{4}\b')
  # Remove unnecessary characters from the search_specie
  search_specie = search_specie.strip(' ,.?!()[]{}_"\';')

  # Initialize temp_line
  temp_line = ""
  
  # Iterate through each line and search for the keyword_page_Specie
  for line_num, line in enumerate(lines, start=0):
    _result = "" 
    if re.search(r"^\s*\".*\bdistribution\b", line) or ("." in line) or (":" in line) or ("|" in line and not line.startswith("\"")):
      print(f"Found '\"' and 'distribution' in: {line}")
      continue

    if search_specie in line:
      _result = line
      if year_pattern.search(line):
        _result = line
        if middle:
          index_left = extracted_data['text'].index(line.split()[0])
          maxPos = max(extracted_data['left'])
          if int(extracted_data['left'][index_left]) > (int(maxPos/4)/10):
            print(f"Spacie {search_specie} was FOUND in this line: {line} in the middle")
            _result = line
            if keyword_page_Specie is None: return _result
          else: return '' # Important when the spacie is not finded on this page, but is on the previous page
          if keyword_page_Specie is not None:
            difference = 0
            difference = keyword_bottom if keyword_bottom > 0 else -keyword_top
        
            if(len(lines[int(line_num + difference)])) > 3:
              temp_line = lines[int(line_num + difference)]
            #print(difference)
            #print(temp_line)
            if keyword_page_Specie in temp_line:
              print(f"The spacie {search_specie} was FOUND in this line: {line} in the middle and Keyword: {keyword_page_Specie}")
              return line # search_specie in the line and the line and in middle and and regEx year and has keyword
           
          return _result # search_specie in the line and the line and in middle and regEx year

        return _result # search_specie in the line and regEx year
  if(len(_result) == 0):
    _result = find_specie_context_RegExReduce(lines,search_specie, keyword_page_Specie=None, keyword_top=None, keyword_bottom=None, middle=None)
  return _result

# Function to find species context with a given keyword
def find_specie_context_RegExReduce(lines, search_specie, keyword_page_Specie=None, keyword_top=None, keyword_bottom=None, middle=None):
 
  _result = ""  # Initialize the result variable

  # Regular expression for a four-digit year
 # year_pattern = re.compile(r'\(\D*\d{4}\)')
  #year_pattern = re.compile(r'\b(?:\(\D*\d{4}\)|\d{4})\b')
  year_pattern = re.compile(r'\b\d{4}\b')
  # Remove unnecessary characters from the search_specie
  search_specie = search_specie.strip(' ,.?!()[]{}_"\';')

  # Initialize temp_line
  temp_line = ""
  
  # Iterate through each line and search for the keyword_page_Specie
  for line_num, line in enumerate(lines, start=0):
    _result = "" 
    if re.search(r"^\s*.*\bdistribution\b", line) or ("." in line) or (":" in line):
      print(f"Found '\"' and 'distribution' in: {line}")
      continue

    if search_specie in line:
      _result = line
      if year_pattern.search(line):
        _result = line
        if middle:
          index_left = extracted_data['text'].index(line.split()[0])
          maxPos = max(extracted_data['left'])
          if int(extracted_data['left'][index_left]) > (int(maxPos/4)/10):
            print(f"Spacie {search_specie} was FOUND in this line: {line} in the middle")
            _result = line
            if keyword_page_Specie is None: return _result
          else: return '' # Important when the spacie is not finded on this page, but is on the previous page
          if keyword_page_Specie is not None:
            difference = 0
            difference = keyword_bottom if keyword_bottom > 0 else -keyword_top
        
            if(len(lines[int(line_num + difference)])) > 3:
              temp_line = lines[int(line_num + difference)]
            #print(difference)
            #print(temp_line)
            if keyword_page_Specie in temp_line:
              print(f"The spacie {search_specie} was FOUND in this line: {line} in the middle and Keyword: {keyword_page_Specie}")
              return line # search_specie in the line and the line and in middle and and regEx year and has keyword
           
          return _result # search_specie in the line and the line and in middle and regEx year

        return _result # search_specie in the line and regEx year
  _result = line.replace('|', '')          
  return _result

# Test the function
#test = find_species_context('D:/distribution_digitizer_11_01_2024/data/input/pages/0057.tif', "_bada", previous_page_path='D:/distribution_digitizer_11_01_2024/data/input/pages/0056.tif', middle=1, keyword_page_Specie="Range", keyword_bottom=2)
#test = find_specie_context('D:/distribution_digitizer_11_01_2024/data/input/pages/0056.tif', "_thrax", middle=True, keyword_page_Specie="Range", keyword_bottom=2)
#test = find_specie_context('D:/distribution_digitizer_11_01_2024/data/input/pages/0051.tif', "_angulata", middle=True, keyword_page_Specie="Range", keyword_bottom=2)
#test = find_specie_context('D:/distribution_digitizer_11_01_2024/data/input/pages/0052.tif', "_leucocera", middle=True)
#test = find_specie_context('D:/distribution_digitizer_11_01_2024/data/input/pages/0053.tif', "_yerburyi", middle=True, keyword_page_Specie="Range", keyword_bottom=2)

#print(test)

# The keyword Range was not everytime perfekt interpreted, It was reader as anee 

#Coladenia indrani (Moore [1866])

#anee: From S.-E. Afghanistan and Pakistan throughout Indian subcontinent
#and Sri Lanka to Indo-China.
