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
import os
import traceback
os.environ['TESSDATA_PREFIX'] = "C:/Program Files/Tesseract-OCR/tessdata/"

# Function to find species context with a keyword
def find_species_context(page_path="", words_to_find="", previous_page_path=None, next_page_path=None, keyword_page_Specie=None, keyword_top=None, keyword_bottom=None, middle=None):
  # Load the image
  image = Image.open(page_path)
  
  words = words_to_find.split("_")
  # Lambda function to remove empty strings from the list
  words = list(filter(lambda x: x != "", words))
  
  # Patter for special species
  pattern = r'\b\d{4}\b'
  
  # Map legends
  legend1 = 'distribution'
  #legend2 = 'locality'
  
  # return result
  all_results = []
  
  specie_content = "" 
  
  if(middle==1): middle=True
  flag = 0
  leg1Index = 0
  leg2Index = 0
  legI = 0
  for search_specie in words:
    #print(search_specie)
    if(legend1 in search_specie):
      search_specie = search_specie.replace(legend1, "")
      flag = 1
      leg1Index = leg1Index+1
      legI = leg1Index
    #if(legend2 in search_specie):
    #  search_specie = search_specie.replace(legend2, "")
    #  flag = 2
    #  leg2Index = leg2Index+1
    #  legI = leg2Index
    #print(search_specie) 
    
    
    # Start search
    specie_content = find_specie_context(page_path,
                      search_specie, keyword_page_Specie, keyword_top, keyword_bottom, middle)
    #print("HHH")
    
    print("if aktuelle")
    print(specie_content)
    if (len(specie_content) > 3):

      all_results.append((str(flag) + "_" + str(legI) + "_" + search_specie + "_" + specie_content))  # Here a string is formed of the flag and added instead of an index
      continue
    
    # print("if2 prev")
    # print(specie_content)
    if (len(specie_content) == 0) and (previous_page_path is not None and previous_page_path != "None"):
      print("if1")
      #print(previous_page_path)
      specie_content = find_specie_context(previous_page_path,
                          search_specie, keyword_page_Specie, keyword_top, keyword_bottom, middle)
      if (len(specie_content) > 3): 
        all_results.append((str(flag) + "_" + str(legI) + "_" + search_specie + "_" + specie_content))  # Here a string is formed of the flag and added instead of an index
        continue
      
      
    #print(specie_content) 
    # print("if3 next")
    if (len(specie_content) == 0) and (next_page_path is not None and next_page_path != "None"):
      print("if3")
      #print(next_page_path)
      specie_content = find_specie_context(next_page_path,
                           search_specie, keyword_page_Specie, keyword_top, keyword_bottom, middle)
      if (len(specie_content) > 3):
        all_results.append((str(flag) + "_" + str(legI) + "_" + search_specie + "_" + specie_content))  # Here a string is formed of the flag and added instead of an index
        continue
      
      
    #print(specie_content)    
    #print("if4 get_lines_last_check")
    #if(len(specie_content) == 0):
    #  print("if3")
    #  specie_content = find_specie_context_RegExReduce(page_path,
                          #search_specie)
    #  if(specie_content is not None):
     #   all_results.append((str(flag) + "_" + search_specie + "_" + specie_content))  # Here a string is formed of the flag and added instead of an index
     #   continue
    if(len(specie_content) == 0):
      specie_content = get_lines_last_check(page_path,search_specie)
      #print("hhh")
      if(len(specie_content) > 5):
        print(specie_content)
        all_results.append((str(flag)+ "_" + str(legI) + "_" + search_specie + "_" + specie_content))  # Here a string is formed of the flag and added instead of an index
        continue
    
    #print(specie_content)    
    print("if5 pre get_lines_last_check")  
    if (len(specie_content) == 0) and (previous_page_path is not None and previous_page_path != "None"):
      print("if1")
      #print(previous_page_path)
      specie_content = get_lines_last_check(previous_page_path,
                          search_specie)
      if (len(specie_content) > 5): 
        all_results.append((str(flag) + "_" + str(legI) + "_" + search_specie + "_" + specie_content))  # Here a string is formed of the flag and added instead of an index
        continue
      
      
    #print(specie_content)    
    print("if6 next get_lines_last_check")
    if (len(specie_content) == 0) and (next_page_path is not None and next_page_path != "None"):
      print("if6")
      #print(next_page_path)
      specie_content = get_lines_last_check(next_page_path,
                           search_specie)
      if (len(specie_content) > 3):
        all_results.append((str(flag) + "_" + str(legI) + "_" + search_specie + "_" + specie_content))  # Here a string is formed of the flag and added instead of an index
        continue 
      
  if(len(all_results) == 0):
    all_results = "Not found"
   
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
  try:
    _result = ""  # Initialize the result variable

    # Load the image from the specified file path
    image = Image.open(page_path)
  
    # Extract text from the image
    extracted_text = pytesseract.image_to_string(image)
  
    # Extract text data with detailed information
    extracted_data = pytesseract.image_to_data(image, output_type=pytesseract.Output.DICT)
  
    # Split the text into lines
    lines = extracted_text.split('\n')
    legend1 = 'distribution'
    # legend2 = 'locality'
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
      ###
      if re.search(r"^\s*\bdistribution\b", line):
        continue
      if re.search(r"^\s*\".*\b" + legend1 + r"\b", line) or (":" in line) or ("|" in line and not line.startswith("\"")):
        continue
      if re.search(r"^\s*.*\b" + "type locality" + r"\b", line):
        continue
      if re.search(r"^\s*\bdistribution\b", line):
        continue
      if re.search(r"^\s*\btype locality\b", line):
        continue
      if re.search(r"\bdistribution\b", line):
        continue
      if "distribution" in line:
        continue
      if re.search(r"\blocality of\b", line):  # Skip lines containing "locality of"
        continue
      if re.search(r"\blocality\b", line, re.IGNORECASE):
        continue
      if re.search(r"\blocality of\b", line, re.IGNORECASE):  # Skip lines containing "locality of"
        continue
      if re.search(r"\btype locality\b", line, re.IGNORECASE):
        continue
      if re.search(r"\btype locality of\b", line, re.IGNORECASE):  # Skip lines containing "type locality of"
        continue
        
      if search_specie in line:
        line = line.replace('|', '') 
        line = line.replace("\\", "")
        line = line.strip("\\ ")
        line = line.strip("\\ ")
        line = line.replace('“', '').replace('”', '')
        if line.startswith("[") or line.startswith("]"):
          line = line[1:]
        _result = line
              
        if re.search(r"\blocality\b", line, re.IGNORECASE):
          print(f"Originalwwww line: {_result}")
        print(f"Original line: {_result}")
        #print("214")
        #print( _result )
        #print("214")
        ###  
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
                #print(f"The spacie {search_specie} was FOUND in this line: {line} in the middle and Keyword: {keyword_page_Specie}")
                return line # search_specie in the line and the line and in middle and and regEx year and has keyword

            return _result # search_specie in the line and the line and in middle and regEx year

          return _result # search_specie in the line and regEx year
    #if(len(_result) == 0):
    #  _result = find_specie_context_RegEx(lines, extracted_data, search_specie, keyword_page_Specie, keyword_top, keyword_bottom, middle)
    #print(_result) 
    return _result

  except Exception as e:
    print("An error occurred during find_specie_context processing:")
    print(e)
    # Hier können Sie den Traceback oder weitere Informationen ausgeben, um den Fehler zu lokalisieren
    print(traceback.format_exc())
    return "Error in function find_specie_context"


# Function to find species context with a given keyword
def find_specie_context_RegEx(lines, extracted_data, search_specie, keyword_page_Specie=None, keyword_top=None, keyword_bottom=None, middle=None):
  
  try:
    print("regEx")
    _result = ""  # Initialize the result variable
  
    # Regular expression for a four-digit year
   # year_pattern = re.compile(r'\(\D*\d{4}\)')
    #year_pattern = re.compile(r'\b(?:\(\D*\d{4}\)|\d{4})\b')
    year_pattern = re.compile(r'\b\d{4}\b')
    # Remove unnecessary characters from the search_specie
    search_specie = search_specie.strip(' ,.?!()[]{}_"\';')
    legend1 = 'distribution'
    #legend2 = 'locality'
    # Initialize temp_line
    temp_line = ""
    
    # Iterate through each line and search for the keyword_page_Specie
    for line_num, line in enumerate(lines, start=0):
      #_result = "\b" + legend1 + r"\b"
      
      if re.search(r"^\s*.*\b" + legend1 + r"\b", line) or (r"^\s*.*\b" + "type locality" + r"\b", line):
        #print(f"Found '\"' and 'distribution' in: {line}")
        continue
  
      if search_specie in line:
        line = line.replace('|', '') 
        line = line.replace("\\", "")
        line = line.strip("\\ ")
        line = line.replace('“', '').replace('”', '')
        _result = line
        year_match = year_pattern.search(line)

        _result = line
        if year_match:
          year = year_match.group(0)
          index_year = line.index(year)
          _result = line[:index_year+ len(year)]
          if middle:
            index_left = extracted_data['text'].index(line.split()[0])
            maxPos = max(extracted_data['left'])
            if int(extracted_data['left'][index_left]) > (int(maxPos/4)/10):
              #print(f"Spacie {search_specie} was FOUND in this line: {line} in the middle")
              if keyword_page_Specie is None: return _result
            else: return '' # Important when the spacie is not finded on this page, but is on the previous page
            
            if keyword_page_Specie is not None:
              difference = 0
              difference = keyword_bottom if keyword_bottom > 0 else -keyword_top
          
              if(len(lines[int(line_num + difference)])) > 3:
                temp_line = lines[int(line_num + difference)]

              if keyword_page_Specie in temp_line:
                #print(f"The spacie {search_specie} was FOUND in this line: {line} in the middle and Keyword: {keyword_page_Specie}")
                return _result # search_specie in the line and the line and in middle and and regEx year and has keyword
            
            return _result # search_specie in the line and the line and in middle and regEx year
         
          return _result # search_specie in the line and regEx year
    print(_result)      
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
    print("RegExReduce")
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
    legend1 = 'distribution'
    #legend2 = 'locality'
    # Iterate through each line and search for the keyword_page_Specie
    for line_num, line in enumerate(lines, start=0):
      if re.search(r"^\s*.*\b" + legend1 + r"\b", line):# or ("." in line) or (":" in line):
        #print(f"Found '\"' and 'distribution' in: {line}")
        continue
      if re.search(r"^\s*.*\b" + "type locality" + r"\b", line):
        #print(f"Found '\"' and 'distribution' in: {line}")
        continue
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
    print(_result)
    return _result

  except Exception as e:
      print("An error occurred during find_specie_context_RegExReduce processing:")
      print(e)
      # Hier können Sie den Traceback oder weitere Informationen ausgeben, um den Fehler zu lokalisieren
      # print(traceback.format_exc())
      return "Error find_specie_context_RegExReduce"
    
    

def get_lines_last_check(image_path, keyword):
    try:
        """
        Get lines containing a specific keyword, starting with a capital letter and containing a 4-digit year.
        """
        keyword = keyword.strip(' ,.?!()[]{}_"\';')
        legend1 = 'distribution'
        #legend2 = 'locality'
        
        # Use pytesseract to extract text from the image
        extracted_text = pytesseract.image_to_string(image_path)
        
        # Initialize an empty list for the lines containing the keyword
        lines_with_keyword = []
        result_string = ""
        
        # Iterate through each line and search for the keyword_page_Specie
        for line in extracted_text.split('\n'):
            # Skip lines containing specific keywords or characters
            if (re.search(r"^\s*.*\b" + legend1 + r"\b", line) or 
                ("=" in line) or
                re.search(r"^\s*\bdistribution\b", line) or
                re.search(r"^\s*\btype locality\b", line) or
                re.search(r"\bdistribution\b", line) or
                "distribution" in line):
                continue
            if re.search(r"\blocality\b", line, re.IGNORECASE):
              continue
            if re.search(r"\blocality of\b", line, re.IGNORECASE):  # Skip lines containing "locality of"
              continue
            if re.search(r"\btype locality\b", line, re.IGNORECASE):
              continue
            if re.search(r"\btype locality of\b", line, re.IGNORECASE):  # Skip lines containing "type locality of"
              continue
        
            keyword_pos = line.lower().find(keyword.lower())
            index_keyword = 0
            
            if keyword_pos > 3:
                line = line.replace(":", "")
                line = line.replace("<!>", "")
                line = line.replace("|", "")
                line = line.replace(",", "")
                line = line.replace(")", "").replace('(', '')
                line = line.replace('“', '').replace('”', '')
                line = line.replace("_", "")
                if line.startswith("-"):
                  line = line.replace("-", "")
                                
                line_split = line[:keyword_pos+len(keyword)].split()
                if keyword in line_split:
                    index_keyword = line_split.index(keyword)
                
                if(index_keyword > 1):
                    prev_word = line_split[index_keyword-1]
                    prev_prev_word = line_split[index_keyword-2]
                    if (prev_prev_word and prev_prev_word[0].isupper()) or (prev_word and prev_word[0].isupper()):
                        year_match = re.search(r'\b\d{2,4}[a-z]?\b', line)
                        index_prev_prev_word = line.lower().find(prev_prev_word.lower())
                        
                        if year_match:
                            year = year_match.group(0)
                            index_year = line.index(year)
                            word_between = line[index_prev_prev_word:index_year+len(year)]
                            if index_year != -1 and index_year > index_prev_prev_word:
                                word_between = line[index_prev_prev_word:index_year+len(year)]
                            else:
                                word_between = line[index_prev_prev_word:]
                            word_between = word_between.replace("|", "")
                            lines_with_keyword.append(word_between)
                        else:
                            word_between = line[index_prev_prev_word:keyword_pos + len(keyword)]
                            if(len(line) > 3) and len(lines_with_keyword) == 0:
                                lines_with_keyword.append(word_between) 
                    else:
                        line = line.replace("|", "")
                        line = line.replace("_", "")
                        word_between = line[:keyword_pos + len(keyword)]
                        if(len(line) > 3) and len(lines_with_keyword) == 0:
                            lines_with_keyword.append(word_between)
                             
                    if(index_keyword == 1):
                        prev_word = line_split[index_keyword-1]
                        if (prev_word and prev_word[0].isupper()):
                            year_match = re.search(r'\b\d{2,4}[a-z]?\b', line)
                            index_prev_word = line.lower().find(prev_word.lower())
                            if year_match:
                                year = year_match.group(0)
                                index_year = line.index(year)
                                word_between = line[index_prev_word:index_year+len(year)]
                                word_between = word_between.replace("|", "")
                                lines_with_keyword.append(word_between)
                            else:
                                word_between = line[index_prev_word:keyword_pos + len(keyword)]
                                if(len(line) > 3) and len(lines_with_keyword) == 0:
                                    lines_with_keyword.append(word_between)
                else:
                    line = line.replace("|", "")
                    line = line.replace("_", "")
                    word_between = line[:keyword_pos + len(keyword)]
                    if(len(line) > 3) and len(lines_with_keyword) == 0:
                        lines_with_keyword.append(word_between)
                 
        if(len(lines_with_keyword) > 0):
            result_string = ' SSS '.join(lines_with_keyword)
        print(result_string)
        return result_string
    
    except Exception as e:
        print("An error occurred during get_lines_last_check processing:")
        print(e)
        # Here you can print traceback or additional information to locate the error
        print(traceback.format_exc())
        return "Error get_lines_last_check"

      
      
      
      
# Test the function
#test = find_species_context('D:/distribution_digitizer/data/input/pages/01.tif', "_stoliczkana", previous_page_path="D:/distribution_digitizer/data/input/pages/0198.tif", next_page_path="D:/distribution_digitizer/data/input/pages/0200.tif", middle=1, keyword_page_Specie="Range", keyword_bottom=2)#test = find_specie_context('D:/distribution_digitizer_11_01_2024/data/input/pages/0056.tif', "_thrax", middle=True, keyword_page_Specie="Range", keyword_bottom=2)
#test = find_specie_context('D:/distribution_digitizer/data/input/pages/0294.tif', "_yopala", middle=True, keyword_page_Specie="Range", keyword_bottom=2)
#test = find_specie_context('D:/distribution_digitizer/data/input/pages/0125.tif', "_tirichmirensis", middle=True)
#test = find_specie_context_RegExReduce('D:/distribution_digitizer_11_01_2024/data/input/pages/0041.tif', "_litoralis")
#test = find_species_context('D:/distribution_digitizer/data/input/pages/0125.tif', "_tirichmirensis", previous_page_path="D:/distribution_digitizer/data/input/pages/0124.tif", next_page_path="D:/distribution_digitizer/data/input/pages/0126.tif", middle=1, keyword_page_Specie="Range", keyword_bottom=2)
#test = find_specie_context('D:/distribution_digitizer/data/input/pages/0214.tif', "_sakaii", middle=True, keyword_page_Specie="Range", keyword_bottom=2)
#test = get_lines_last_check('D:/distribution_digitizer/data/input/pages/0294.tif', "_jarmanai")
#print(test)

# The keyword Range was not everytime perfekt interpreted, It was reader as anee 

#Coladenia indrani (Moore [1866])

#anee: From S.-E. Afghanistan and Pakistan throughout Indian subcontinent
#and Sri Lanka to Indo-China.
