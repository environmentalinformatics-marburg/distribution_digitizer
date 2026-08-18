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
def find_specie_context_with_keyword(page_path, search_specie, keyword_page_Specie=None, keywordBefore=None, keywordThan=None, middle=None):
  """
  This function searches for a species name and a year in the context of a specified keyword in an image.

  Parameters:
  - page_path (str): The file path of the image.
  - search_specie (str): The species name to search for.
  - keyword_page_Specie (str): The keyword to locate in the image.
  - keywordBefore (int or None): The number of lines above the keyword to consider.
  - keywordThan (int or None): The number of lines below the keyword to consider.
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
      if keywordThan is not None:
        difference = -int(keywordThan)
      elif keywordBefore is not None:
        difference = int(keywordBefore)

      for line_num, line in enumerate(lines, start=0):
        line = line.replace('|', '') 
        line = line.replace("\\", "")
        line = line.strip("\\ ")
        if keyword_page_Specie in line:
          if(len(lines[int(line_num + difference)])) > 3:
            temp_line = lines[int(line_num + difference)]
            # Check if the species name and a year are present in the line before the keyword
            if search_specie in temp_line and year_pattern.search(temp_line):
              if middle:
                index_left = extracted_data['text'].index(temp_line.split()[0])
                maxPos = max(extracted_data['left'])
                if int(extracted_data['left'][index_left]) > (int(maxPos/4)/10):
                  #print(f"Spacie {search_specie} was FOUND in this line: {temp_line} in the middle. Keyword: {keyword_page_Specie}")
                  return temp_line
              else:
                _result = temp_line
                #print(f"The spacie {search_specie} was FOUND in this line: {temp_line} not in the middle. Keyword: {keyword_page_Specie}")
            else:
              continue
              #print(f"The spacie {search_specie} was not found in this line: {temp_line}. Keyword: {keyword_page_Specie}")

    elif keyword_page_Specie is None:
      _result = ""
      for line_num, line in enumerate(lines, start=0):
        if search_specie in line and year_pattern.search(line):
          line = line.replace('|', '') 
          line = line.replace("\\", "")
          line = line.strip("\\ ")
          if middle:
            index_left = extracted_data['text'].index(line.split()[0])
            maxPos = max(extracted_data['left'])
            #print(index_left)
            #print(maxPos)
            #print(line)
            #print(int(extracted_data['left'][index_left]))
            if int(extracted_data['left'][index_left]) > (int(maxPos/4)/10):
              #print(f"The spacie {search_specie} was FOUND in this line: {line} in the middle. No keyword")
              return line
          else:
            _result = line
            #print(f"The spacie {search_specie} was found in this line: {line} not the middle. No keyword")
        #else:
            #print(f"The spacie {search_specie} was not found in this line: {line}. No keyword")
  except IndexError as e:
    # Handle the "index out of bounds" error specifically
    print("Index out of bounds error:", e)
    return "Error IndexError"
  except Exception as e:
    # Handle other exceptions
    print("An error in find_specie_context_with_keyword occurred:", e)
    return "Error find_specie_context_with_keyword"
  return _result


# Function to find species context with a keyword
def find_species_context(page_path="", words_to_find="", previous_page_path=None, next_page_path=None, keyword_page_Specie=None, keywordBefore=None, keywordThan=None, middle=None):
  
  try:
    # Load the image
    image = Image.open(page_path)
    
    words = words_to_find.split("_")
    # Lambda function to remove empty strings from the list
    words = list(filter(lambda x: x != "", words))
    
    # Patter for special species
    pattern = r'\b\d{4}\b'
    
    # Map legends
    legend1 = 'distribution'
    legend2 = 'locality'
    
    # return result
    all_results = []
    
    specie_content = "" 
    
    if(middle==1): middle=True
    flag = 0
    
    for search_specie in words:
      #print(search_specie)
      if(legend1 in search_specie):
        search_specie = search_specie.replace(legend1, "")
        flag = 1
      if(legend2 in search_specie):
        search_specie = search_specie.replace(legend2, "")
        flag = 2
      specie_content = find_specie_context(page_path,
                        search_specie, keyword_page_Specie, keywordBefore, keywordThan, middle)
      if (len(specie_content) > 3):
        all_results.append((str(flag) + "_" + search_specie + "_" + specie_content))  # Here a string is formed of the flag and added instead of an index
        continue
  
      if (len(specie_content) == 0) and (previous_page_path is not None and previous_page_path != "None"):
        #print("if1")
        #print(previous_page_path)
        specie_content = find_specie_context(previous_page_path,
                            search_specie, keyword_page_Specie, keywordBefore, keywordThan, middle)
        if (len(specie_content) > 3): 
          all_results.append((str(flag) + "_" + search_specie + "_" + specie_content))  # Here a string is formed of the flag and added instead of an index
          continue
       
      if (len(specie_content) == 0) and (next_page_path is not None and next_page_path != "None"):
          #print("if2")
          #print(next_page_path)
          specie_content = find_specie_context(next_page_path,
                             search_specie, keyword_page_Specie, keywordBefore, keywordThan, middle)
          if (len(specie_content) > 3):
            all_results.append((str(flag) + "_" + search_specie + "_" + specie_content))  # Here a string is formed of the flag and added instead of an index
            continue
          
      if(len(specie_content) == 0):
        #print("if3")
        specie_content = find_specie_context_RegExReduce(page_path,
                            search_specie)
        if(specie_content is not None):
          all_results.append((str(flag) + "_" + search_specie + "_" + specie_content))  # Here a string is formed of the flag and added instead of an index
          continue
        
    if(len(all_results) == 0):
      all_results.append("the specie was not found")
    #print(all_results) 
    return all_results
  
  except Exception as e:
      print("An error occurred during find_species_context processing:")
      print(e)
      # Hier können Sie den Traceback oder weitere Informationen ausgeben, um den Fehler zu lokalisieren
      # print(traceback.format_exc())
      return "Error: An error occurred during find_species_context processing"


# Function to find species context with a given keyword
def find_specie_context(page_path, search_specie, keyword_page_Specie=None, keywordBefore=None, keywordThan=None, middle=None):
  try:
    _result = ""  # Initialize the result variable
    #page_path = 'D:/distribution_digitizer/data/input/pages/0146.tif'
    # Load the image from the specified file path
    image = Image.open(page_path)
  
    # Extract text from the image
    extracted_text = pytesseract.image_to_string(image)
  
    # Extract text data with detailed information
    extracted_data = pytesseract.image_to_data(image, output_type=pytesseract.Output.DICT)
  
    # Split the text into lines
    lines = extracted_text.split('\n')
    
    # Regular expression for a four-digit year
    year_pattern = re.compile(r'\b\d{4}\b')
    #search_specie = "_bakeri"
    # Remove unnecessary characters from the search_specie
    search_specie = search_specie.strip(' ,.?!()[]{}_"\';')
  
    # Initialize temp_line
    temp_line = ""
    
    # Iterate through each line and search for the keyword_page_Specie
    for line_num, line in enumerate(lines, start=0):
      if re.search(r"^\s*\".*\b" + legend1 + r"\b", line) or ("." in line) or (":" in line) or ("|" in line and not line.startswith("\"")):
        print(f"Found '\"' and 'distribution' in: {line}")
        continue
      
      if search_specie in line and year_pattern.search(line):
        line = line.replace('|', '') 
        line = line.replace("\\", "")
        line = line.strip("\\ ")
        
        if middle:
          index_left = extracted_data['text'].index(line.split()[0])
          maxPos = max(extracted_data['left'])
          if int(extracted_data['left'][index_left]) > (int(maxPos/4)/10):
            _result = line
            #if keyword_page_Specie is None:
            #    return _result
          else:
            _result = ''
                
        if keyword_page_Specie is not None:
          difference = 0
          difference = keywordThan if keywordThan > 0 else -keywordBefore
    
          if len(lines[int(line_num + difference)]) > 3:
            temp_line = lines[int(line_num + difference)]
          
          if keyword_page_Specie in temp_line:
            _result = line
      
        _result = line

    print("Start")
    print(len(_result))
    if len(_result) == 0:
      print("Start2")
      _result = find_specie_context_RegEx(lines, extracted_data, search_specie, keyword_page_Specie, keywordBefore, keywordThan, middle)

    print(_result)
    if len(_result) == 0:
      print("Start3")
      _result = find_common(lines, search_specie, keyword_page_Specie, keywordBefore, keywordThan, middle)
    
    return _result

  except Exception as e:
    print("An error occurred during find_specie_context processing:")
    print(e)
    return "Error find_specie_context"
      

# Function to find species context with a given keyword
def find_common(lines, search_specie, keyword_page_Specie=None, keywordBefore=None, keywordThan=None, middle=None):
  try:
    _result = ""
  
    # Split the text into lines
    lines = extracted_text.split('\n')
    
    # Regular expression for a four-digit year
    year_pattern = re.compile(r'\b\d{4}\b')
    
    # Remove unnecessary characters from the search_specie
    search_specie = search_specie.strip(' ,.?!()[]{}_"\';')
  
    # Initialize temp_line
    temp_line = ""
    
    # Iterate through each line and search for the keyword_page_Specie
    for line_num, line in enumerate(lines, start=0):
      _result = "\b" + legend1 + r"\b"
      if search_specie in line:
        line = line.replace('|', '') 
        line = line.replace("\\", "")
        line = line.strip("\\ ")
        _result = line
        if year_pattern.search(line):
          return line
  
    return _result

  except Exception as e:
    print("An error occurred during find_common processing:")
    print(e)
    return "Error find_common"



# Function to find species context with a given keyword
def find_specie_context_RegEx(lines, extracted_data, search_specie, keyword_page_Specie=None, keywordBefore=None, keywordThan=None, middle=None):
  """
  This function searches for a species name and a year in the context of a specified keyword in an image.

  Parameters:
  - page_path (str): The file path of the image.
  - search_specie (str): The species name to search for.
  - keyword_page_Specie (str): The keyword to locate in the image.
  - keywordBefore (int or None): The number of lines above the keyword to consider.
  - keywordThan (int or None): The number of lines below the keyword to consider.
  - middle (bool): Flag indicating whether the species name should be searched for in the middle of the context.

  Returns:
  - specie_content (str): The content of the line containing the species name.
  """
  try:
    #print("regEx")
    _result = ""  # Initialize the result variable
  
    # Regular expression for a four-digit year
   # year_pattern = re.compile(r'\(\D*\d{4}\)')
    #year_pattern = re.compile(r'\b(?:\(\D*\d{4}\)|\d{4})\b')
    year_pattern = re.compile(r'\b\d{4}\b')
    # Remove unnecessary characters from the search_specie
    search_specie = search_specie.strip(' ,.?!()[]{}_"\';')
    legend1 = 'distribution'
    legend2 = 'locality'
    # Initialize temp_line
    temp_line = ""
    
    # Iterate through each line and search for the keyword_page_Specie
    for line_num, line in enumerate(lines, start=0):
      
      if re.search(r"^\s*.*\b" + legend1 + r"\b", line) or ("." in line) or (":" in line):
        print(f"Found '\"' and 'distribution' in: {line}")
        continue
  
      if search_specie in line:
        line = line.replace('|', '') 
        line = line.replace("\\", "")
        line = line.strip("\\ ")
        _result = line
        if year_pattern.search(line):
          _result = line
          if middle:
            index_left = extracted_data['text'].index(line.split()[0])
            maxPos = max(extracted_data['left'])
            if int(extracted_data['left'][index_left]) > (int(maxPos/4)/10):
              #print(f"Spacie {search_specie} was FOUND in this line: {line} in the middle")
              _result = line
              if keyword_page_Specie is None: return _result
            else: return '' # Important when the spacie is not finded on this page, but is on the previous page
            
            if keyword_page_Specie is not None:
              difference = 0
              difference = keywordThan if keywordThan > 0 else -keywordBefore
          
              if(len(lines[int(line_num + difference)])) > 3:
                temp_line = lines[int(line_num + difference)]
              #print(difference)
              #print(temp_line)
              if keyword_page_Specie in temp_line:
                #print(f"The spacie {search_specie} was FOUND in this line: {line} in the middle and Keyword: {keyword_page_Specie}")
                return line # search_specie in the line and the line and in middle and and regEx year and has keyword
            
            return _result # search_specie in the line and the line and in middle and regEx year
         
          return _result # search_specie in the line and regEx year
          
    return _result
  except Exception as e:
      print("An error occurred during find_specie_context_RegEx processing:")
      print(e)
      # Hier können Sie den Traceback oder weitere Informationen ausgeben, um den Fehler zu lokalisieren
      # print(traceback.format_exc())
      return "Error find_specie_context_RegEx"


# Function to find species context with a given keyword
def find_specie_context_RegExReduce(page_path, search_specie):
  try:
    #print("regExRed")
    image = Image.open(page_path)
  
    # Extract text from the image
    extracted_text = pytesseract.image_to_string(image)
    year_pattern = re.compile(r'\b\d{4}\b')
    # Extract text data with detailed information
    #extracted_data = pytesseract.image_to_data(image, output_type=pytesseract.Output.DICT)
  
    # Split the text into lines
    lines = extracted_text.split('\n')
    # Remove unnecessary characters from the search_specie
    search_specie = search_specie.strip(' ,.?!()[]{}_"\';')
    _result = ""
    # Iterate through each line and search for the keyword_page_Specie
    for line_num, line in enumerate(lines, start=0):
      if search_specie in line:
        line = line.replace('|', '') 
        line = line.replace("\\", "")
        line = line.strip("\\ ")
        _result = line

        if year_pattern.search(_result):
          match = re.search(year_pattern, _result)
          erster_teil = _result[:match.start()].strip()
          year = match.group()
          #print("Erster Teil des Satzes:", erster_teil)
          #print("Jahr:", year)
          
          temp_result = re.split(year_pattern, _result)
          temp_result = temp_result[0].strip()
          return temp_result + year
        else:
          continue
    return _result

  except Exception as e:
      print("An error occurred during pageReadRpecies processing:")
      print(e)
      # Hier können Sie den Traceback oder weitere Informationen ausgeben, um den Fehler zu lokalisieren
      # print(traceback.format_exc())
      return "Error find_specie_context_RegExReduce"
# Test the function
#test = find_common(lines, "_bakeri", middle=True, keyword_page_Specie="Range", keywordThan=2)
#test = find_species_context('D:/distribution_digitizer/data/input/pages/0146.tif', "_bakeri", previous_page_path="D:/distribution_digitizer/data/input/pages/0146.tif", next_page_path="D:/distribution_digitizer/data/input/pages/0148.tif", middle=1, keyword_page_Specie="Range", keywordThan=2)#test = find_specie_context('D:/distribution_digitizer_11_01_2024/data/input/pages/0056.tif', "_thrax", middle=True, keyword_page_Specie="Range", keywordThan=2)
#test = find_specie_context('D:/distribution_digitizer/data/input/pages/0146.tif', "_bakeri", middle=True, keyword_page_Specie="Range", keywordBefore=0,keywordThan=2)
#test = find_specie_context_RegExReduce('D:/distribution_digitizer_11_01_2024/data/input/pages/0041.tif', "_litoralis")



# Angenommen, dein tessdata-Verzeichnis befindet sich unter "C:/Program Files/Tesseract-OCR/tessdata"
tessdata_path = "C:/Program Files/Tesseract-OCR/tessdata"

# Dann rufst du die Funktion get_words_info auf und übergibst den Bildpfad und den Pfad zum tessdata-Verzeichnis
words_info = get_words_info(image_path="D:/distribution_digitizer/www/data/pages/0146.png", tessdata_path=tessdata_path)


import cv2

import os

# Setze TESSDATA_PREFIX auf das Verzeichnis, in dem sich tessdata befindet
os.environ['TESSDATA_PREFIX'] = r'C:\Program Files\Tesseract-OCR\tessdata'

def get_words_info(image_path):
    """
    Get path to image and return dict with info about each word
    """
    # Load image using OpenCV
    image = cv2.imread(image_path)
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    # Apply thresholding or other preprocessing steps if necessary

    # Use a text detection method (e.g., OCR) to detect words
    # For example, you could use the detectText function from the pytesseract library
    detected_text = pytesseract.image_to_string(gray)

    # Dummy implementation - assuming all text is in a single line
    #detected_text = "This is some example text"

    # Split the detected text into words and extract information about each word
    words = detected_text.split()
    result = []

    for word in words:
        # Extract word position (bounding box)
        # For simplicity, assuming each word occupies a fixed width and height
        position = (0, 0, 100, 50)  # Example bounding box (x, y, width, height)

        # Create a dictionary with word information
        word_info = {
            'word': word,
            'position': position
        }
        result.append(word_info)

    return result

# Example usage

image_path = "D:/distribution_digitizer/data/input/pages/0146.tif"
words_info = get_words_info(image_path)
print(words_info)

def get_capitalized_words(words_info):
    """
    Get capitalized words from the list of word info dictionaries
    """
    capitalized_words = []

    for word_info in words_info:
        word = word_info['word']
        if word[0].isupper():  # Check if the first letter of the word is uppercase
            capitalized_words.append(word)

    return capitalized_words

# Beispielaufruf
capitalized_words = get_capitalized_words(words_info)
print(capitalized_words)
from tesserocr import PyTessBaseAPI, RIL
import os
import pytesseract
from tesserocr import PyTessBaseAPI, RIL

def get_words_info2(image_path, tessdata_path):
    """
    get path to image and path to tessdata and return dict with info about each word
    """
    # Setze den Pfad zum tessdata-Verzeichnis
    os.environ['TESSDATA_PREFIX'] = tessdata_path
    
    # Erstelle eine Instanz der PyTessBaseAPI
    with PyTessBaseAPI() as api:
        api.SetImageFile(image_path)
        api.Recognize()
        iter = api.GetIterator()
        level = RIL.WORD

        result = []

        while iter.Next(level):
            r = iter
            element = r.GetUTF8Text(level)
            word_attributes = {}

            if element:
                word_attributes['word'] = element
                word_attributes['position'] = r.BoundingBox(level)

            result.append(word_attributes)

        return result

# Beispielaufruf der Funktion
image_path = "D:/distribution_digitizer/data/input/pages/0146.tif"
tessdata_path = r'C:\Program Files\Tesseract-OCR\tessdata'
words_info2 = get_words_info2(image_path, tessdata_path)
print(words_info2)

import os
from tesserocr import PyTessBaseAPI, RIL, iterate_level

def get_bold_words_info(image_path, tessdata_path):
    """
    get path to image and path to tessdata and return dict with info about each bold word
    """
    # Setze den Pfad zum tessdata-Verzeichnis
    os.environ['TESSDATA_PREFIX'] = tessdata_path
    
    # Erstelle eine Instanz der PyTessBaseAPI
    with PyTessBaseAPI() as api:
        api.SetImageFile(image_path)
        api.Recognize()
        iter = api.GetIterator()
        level = RIL.WORD

        result = []

                it = self._api.GetIterator()
        level = tesserocr.RIL.WORD
            

        return result

import os
import pytesseract
from tesserocr import PyTessBaseAPI, RIL

def get_words_info2(image_path, tessdata_path):
    """
    get path to image and path to tessdata and return dict with info about each word
    """
    # Setze den Pfad zum tessdata-Verzeichnis
    os.environ['TESSDATA_PREFIX'] = tessdata_path
    
    # Erstelle eine Instanz der PyTessBaseAPI
    with PyTessBaseAPI() as api:
        api.SetImageFile(image_path)
        api.Recognize()
        iter = api.GetIterator()
        level = RIL.WORD

        result = []

        while iter.Next(level):
            r = iter
            element = r.GetUTF8Text(level)
            word_attributes = r.WordFontAttributes()
            print(word_attributes)
            base_line = r.BoundingBox(level)

            if element:
                word_attributes['word'] = element
                word_attributes['position'] = base_line

            result.append(word_attributes)

        return result

# Beispielaufruf der Funktion
image_path = "D:/distribution_digitizer/www/data/pages/0146.png"
tessdata_path = r'C:\Program Files\Tesseract-OCR\tessdata'
words_info2 = get_words_info2(image_path, tessdata_path)
print(words_info2)
