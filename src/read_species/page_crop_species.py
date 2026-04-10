# ------------------------------------------------------------
# Author: Spaska Forteva
# Created on: 2023-09-24
# Last updated: 2026-03-31
#
# Description:
# This script extracts species title information from scanned
# book pages using Optical Character Recognition (OCR) and
# rule-based text analysis.
#
# It is designed to identify species descriptions associated
# with previously detected species names (e.g., from map legends)
# and to retrieve contextual information such as full species
# titles and publication years.
#
# The workflow includes:
# - OCR-based text extraction from page images
# - Line-wise text filtering and normalization
# - Context-aware search for species names
# - Extraction of relevant lines containing species titles
# - Fallback strategies across adjacent pages (previous/next)
# - Multiple matching strategies (direct match, regex-based,
#   and heuristic line reconstruction)
#
# This module complements the legend-based species detection
# by providing extended textual context from book pages,
# enabling more complete species identification and validation.
# ------------------------------------------------------------

# Required libraries
import cv2
import pytesseract
import re 
import matplotlib.pyplot as plt
from PIL import Image 
import os
import traceback

import pytesseract
import os

TESSERACT_EXE = "C:/Program Files/Tesseract-OCR/tesseract.exe"

if os.path.exists(TESSERACT_EXE):
    pytesseract.pytesseract.tesseract_cmd = TESSERACT_EXE
    print("Tesseract fixed to:", TESSERACT_EXE)
    
    
# ------------------------------------------------------------
# Reads a configuration value from a CSV file.
# Used to retrieve paths (e.g., Tesseract installation)
# required for OCR processing.
# ------------------------------------------------------------
def read_config(file_path, key):
    with open(file_path, 'r') as file:
        lines = file.readlines()
        headers = lines[0].strip().split(';')
        values = lines[1].strip().split(';')
        config = dict(zip(headers, values))
        return config.get(key, None)



# ------------------------------------------------------------
# Sets the TESSDATA_PREFIX environment variable once,
# based on a configuration file.
#
# Ensures that Tesseract OCR uses the correct language data
# directory without repeatedly resetting the environment.
# Includes safety checks for missing or invalid paths.
# ------------------------------------------------------------
# Use a global variable to track if TESSDATA_PREFIX is already set
tessdata_prefix_set = False

def set_tessdata_prefix_once(workingDir, key="tesserAct"):
    global tessdata_prefix_set

    if tessdata_prefix_set:
        print("TESSDATA_PREFIX already set – skipping")
        return

    config_file_path = os.path.join(workingDir, "config", "config.csv")

    try:
        with open(config_file_path, 'r') as config_file:
            lines = config_file.readlines()
            headers = lines[0].strip().split(';')
            values = lines[1].strip().split(';')
            config = dict(zip(headers, values))

        tess_path = config.get(key)

        # 🔑 ENTSCHEIDENDER GUARD
        if not tess_path or tess_path == "None":
            print("No Tesseract path in config – using existing setup")
            tessdata_prefix_set = True
            return

        if not os.path.exists(tess_path):
            print(f"Tesseract path does not exist: {tess_path} – skipping override")
            tessdata_prefix_set = True
            return

        os.environ['TESSDATA_PREFIX'] = os.path.join(tess_path, "tessdata")
        print("TESSDATA_PREFIX set to:", os.environ['TESSDATA_PREFIX'])

        tessdata_prefix_set = True

    except Exception as e:
        print("Failed to set TESSDATA_PREFIX, continuing safely")
        print(e)
        tessdata_prefix_set = True
        return

      
def find_species_context_loose(
    workingDir="",
    page_path="",
    search_specie="",
    previous_page_path=None,
    next_page_path=None,
    middle=None,
    legend_list=None
):
    print(f"LOOSE SEARCH for: {search_specie}")

    import pytesseract
    import re
    from PIL import Image

    def search_in_page(image_path, specie):
        candidates = []

        try:
            image = Image.open(image_path)
            text = pytesseract.image_to_string(image)

            for line in text.split("\n"):
                line_clean = line.strip()

                if len(line_clean) < 5:
                    continue

                if specie.lower() in line_clean.lower():

                    clean_line = (
                        line_clean
                        .replace(":", "")
                        .replace("|", "")
                        .replace("_", "")
                        .strip()
                    )

                    # ❌ Müll raus
                    if len(clean_line) > 120:
                        continue

                    if "syntype" in clean_line.lower():
                        continue

                    # 🧠 Scoring
                    score = 0

                    # ⭐ Jahr = wichtigstes Kriterium
                    if re.search(r'\b\d{4}\b', clean_line):
                        score += 5

                    # erste Position
                    pos = clean_line.lower().find(specie.lower())
                    if pos < 30:
                        score += 2

                    # typische Länge
                    if 3 <= len(clean_line.split()) <= 10:
                        score += 1

                    candidates.append((score, clean_line))

        except Exception as e:
            print("Error in loose search:", e)

        return candidates

    # -----------------------------------------
    # Sammeln
    # -----------------------------------------
    all_candidates = []

    all_candidates += search_in_page(page_path, search_specie)

    if previous_page_path and previous_page_path != "None":
        all_candidates += search_in_page(previous_page_path, search_specie)

    if next_page_path and next_page_path != "None":
        all_candidates += search_in_page(next_page_path, search_specie)

    if len(all_candidates) == 0:
        return ""

    # -----------------------------------------
    # 🔥 BESTE ZEILE WÄHLEN
    # -----------------------------------------

    # 1️⃣ zuerst alle mit Jahr
    with_year = [c for c in all_candidates if re.search(r'\b\d{4}\b', c[1])]

    if len(with_year) > 0:
        with_year.sort(key=lambda x: x[0], reverse=True)
        best = with_year[0][1]
    else:
        # 2️⃣ fallback: bester Score
        all_candidates.sort(key=lambda x: x[0], reverse=True)
        best = all_candidates[0][1]

    print("LOOSE BEST:", best)

    return best
# ------------------------------------------------------------
# Main function to extract species-related textual context
# from a given page and optionally from neighboring pages.
#
# Workflow:
# - Iterates over detected species names
# - Searches for matching text lines using OCR
# - Applies multiple fallback strategies:
#     1. Current page search
#     2. Previous page search
#     3. Next page search
#     4. Heuristic line reconstruction
#
# Encodes results including legend information and indices.
#
# Returns:
# A list of structured strings containing species names
# and their corresponding textual context.
# ------------------------------------------------------------
def find_species_context(workingDir="", page_path="", words_to_find="", previous_page_path=None, next_page_path=None, keyword_page_Specie=None, keyword_top=None, keyword_bottom=None, middle=None, legend_list=None):
    print(legend_list)
    # Normalize legend list (ONLY first word!)
    if legend_list is None:
        legend_list = ["distribution"]

    if isinstance(legend_list, str):
        legend_list = [legend_list]

    legend_list = [l.lower().strip().split()[0] for l in legend_list]
    set_tessdata_prefix_once(workingDir, key="tesserAct")

    image = Image.open(page_path)

    words = words_to_find.split("_")
    words = list(filter(lambda x: x != "", words))

    pattern = r'\b\d{4}\b'

    all_results = []
    specie_content = ""

    if (middle == 1):
        middle = True

    flag = 0
    leg1Index = 0
    leg2Index = 0
    legI = 0
    species_name = ""

    for search_specie in words:
        print(search_specie)

        matched_legend = None
        flag = 0

        for i, legend in enumerate(legend_list):
            legend_first_word = legend.split()[0]
            if legend_first_word in search_specie:
                search_specie = search_specie.split("X")[0]
                #print(search_specie)
                matched_legend = legend
                flag = i + 1
                legI += 1
                break

        # Start search
        specie_content = find_specie_context(
            page_path,
            search_specie,
            keyword_page_Specie,
            keyword_top,
            keyword_bottom,
            middle,
            legend_list
        )

        if (len(specie_content) > 3):
            all_results.append(f"{flag}_{legI}_{search_specie}_{specie_content}")
            continue

        if (len(specie_content) == 0) and (previous_page_path is not None and previous_page_path != "None"):
            specie_content = find_specie_context(
                previous_page_path,
                search_specie,
                keyword_page_Specie,
                keyword_top,
                keyword_bottom,
                middle,
                legend_list
            )
            if (len(specie_content) > 3):
                all_results.append(str(flag) + "_" + str(legI) + "_" + search_specie + "_" + specie_content)
                continue

        if (len(specie_content) == 0) and (next_page_path is not None and next_page_path != "None"):
            specie_content = find_specie_context(
                next_page_path,
                search_specie,
                keyword_page_Specie,
                keyword_top,
                keyword_bottom,
                middle,
                legend_list
            )
            if (len(specie_content) > 3):
                all_results.append(str(flag) + "_" + str(legI) + "_" + search_specie + "_" + specie_content)
                continue

        if (len(specie_content) == 0):
            print("1 get_lines_last_check")
            specie_content = get_lines_last_check(page_path, search_specie, legend_list)
            if (len(specie_content) > 5):
                print(specie_content)
                all_results.append(str(flag) + "_" + str(legI) + "_" + search_specie + "_" + specie_content)
                continue
        if (len(specie_content) == 0) and (previous_page_path is not None and previous_page_path != "None"):
            print("2 get_lines_last_check previous_page_path")
            specie_content = get_lines_last_check(previous_page_path, search_specie, legend_list)
            if (len(specie_content) > 5):
                all_results.append(str(flag) + "_" + str(legI) + "_" + search_specie + "_" + specie_content)
                continue

        if (len(specie_content) == 0) and (next_page_path is not None and next_page_path != "None"):
            print("3 get_lines_last_check next_page_path")
            specie_content = get_lines_last_check(next_page_path, search_specie, legend_list)
            if (len(specie_content) > 3):
                all_results.append(str(flag) + "_" + str(legI) + "_" + search_specie + "_" + specie_content)
                continue

        if len(specie_content) == 0:
            print("➡️ using loose fallback")
            specie_content = find_species_context_loose(
                workingDir,
                page_path,
                search_specie,
                previous_page_path,
                next_page_path,
                middle,
                legend_list
            )
            if (len(specie_content) > 3):
              all_results.append(str(flag) + "_" + str(legI) + "_" + search_specie + "_" + specie_content)
              continue

    return all_results



# ------------------------------------------------------------
# Searches for a species name within a page and extracts
# the corresponding text line containing contextual information.
#
# Applies multiple filtering rules to exclude legend lines
# and irrelevant text (e.g., distribution or locality entries).
#
# Optionally validates results based on:
# - Presence of a four-digit year
# - Relative position within the page (middle detection)
# - Proximity to additional keywords
#
# Returns:
# A cleaned line containing the species context, or an empty
# string if no valid match is found.
# ------------------------------------------------------------
def find_specie_context(page_path, search_specie, keyword_page_Specie=None, keyword_top=None, keyword_bottom=None, 
middle=None, legend_list=None):
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
    print("DEBUG ist in find_specie_contex")
    # Load the image from the specified file path
    image = Image.open(page_path)
  
    # Extract text from the image
    extracted_text = pytesseract.image_to_string(image)
  
    # Extract text data with detailed information
    extracted_data = pytesseract.image_to_data(image, output_type=pytesseract.Output.DICT)
  
    # Split the text into lines
    lines = extracted_text.split('\n')
    legends = []
  
    if legend_list:
      if len(legend_list) > 0:
          legends.append(legend_list[0].split()[0])
      if len(legend_list) > 1:
          legends.append(legend_list[1].split()[0])
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
      
      # 🔹 NEUE LOGIK GANZ OBEN
      if any(re.search(rf"\b{re.escape(kw)}\b", line) for kw in legends):
        #print("DEBUG keyword hit:", line)
        continue
  
      if re.search(r"^\s*\".*\b" + legends[0] + r"\b", line) or (":" in line) or ("|" in line and not line.startswith("\"")):
        continue
      if re.search(r"^\s*.*\b" + legends[1] + r"\b", line):
        continue
      if re.search(r"^\s*\b{re.escape(legends[0])}\b", line):
        continue
      if re.search(r"^\s*\b{re.escape(legends[1])}\b", line):
        continue
      if re.search(rf"\b{re.escape(legends[0])}\b", line):
        continue
      if re.search(r"\blocality\b", line, re.IGNORECASE):
        continue
      if re.search(r"\blocality of\b", line, re.IGNORECASE):  # Skip lines containing "locality of"
        continue

      
      if search_specie in line or any(similar(search_specie.lower(), w.lower()) > 0.8 for w in line.split()):
        print("Start", search_specie)
        line = line.replace('|', '') 
        line = line.replace("\\", "")
        line = line.strip("\\ ")
        line = line.strip("\\ ")
        line = line.replace('“', '').replace('”', '')
        if line.startswith("[") or line.startswith("]"):
          line = line[1:]
        #_result = line
            
        if re.search(r"\blocality\b", line, re.IGNORECASE):
          print(f"Originalwwww line: {_result}")

        if year_pattern.search(line):
          print("Bin mit Jahr")
          print(line)
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
    print("RETURN:", _result)

    # ❗ nur zurückgeben wenn Jahr vorhanden
    if _result and year_pattern.search(_result):
        return _result
    
    return ""

  except Exception as e:
    print("An error occurred during find_specie_context processing:")
    print(e)
    # Hier können Sie den Traceback oder weitere Informationen ausgeben, um den Fehler zu lokalisieren
    print(traceback.format_exc())
    print("RETURN Error:", _result)
    return ""


from difflib import SequenceMatcher

def similar(a, b):
    return SequenceMatcher(None, a, b).ratio()





    
# ------------------------------------------------------------
# Final fallback method for extracting species-related lines.
#
# Searches OCR text for lines containing the target keyword,
# applies heuristic rules to reconstruct meaningful text
# segments (e.g., capitalized names + year patterns),
# and filters out irrelevant legend or locality lines.
#
# Used when all previous matching strategies fail.
#
# Returns:
# A concatenated string of candidate lines containing species
# context information.
# ------------------------------------------------------------
def get_lines_last_check(image_path, search_specie, legend_list=None):
    try:
        """
        Get lines containing a specific search_specie, starting with a capital letter and containing a 4-digit year.
        """
        print("DEBUG ist in get_lines_last_check")
        search_specie = search_specie.strip(' ,.?!()[]{}_"\';')
        legends = []
        if legend_list:
          if len(legend_list) > 0:
              legends.append(legend_list[0].split()[0])
          if len(legend_list) > 1:
              legends.append(legend_list[1].split()[0])
        
        # Use pytesseract to extract text from the image
        extracted_text = pytesseract.image_to_string(image_path)
        
        # Initialize an empty list for the lines containing the search_specie
        lines_with_search_specie = []
        result_string = ""
        
        for line in extracted_text.split('\n'):
            # Skip lines containing specific search_specie or characters
            if (re.search(r"^\s*.*\b" + legends[0] + r"\b", line) or 
                ("=" in line) or
                re.search(r"^\s*\b{re.escape(legends[0])}\b", line) or
                re.search(r"^\s*\b{re.escape(legends[1])}\b", line) or
                re.search(r"\b{re.escape(legends[0])}\b", line) or
                legends[0] in line):
                continue

            if re.search(r"\blocality\b", line, re.IGNORECASE):
              continue
            if re.search(r"\blocality of\b", line, re.IGNORECASE):  # Skip lines containing "locality of"
              continue
            if re.search(r"\b{re.escape(legends[1])}\b", line, re.IGNORECASE):
              continue
            if re.search(r"\btype locality of\b", line, re.IGNORECASE):  # Skip lines containing "type locality of"
              continue
            
            search_specie_pos = line.lower().find(search_specie.lower())
            index_search_specie = 0
            
            if search_specie_pos > 3:
             
              line = line.replace(":", "")
              line = line.replace("<!>", "")
              line = line.replace("|", "")
              line = line.replace(",", "")
              line = line.replace(")", "").replace('(', '')
              line = line.replace('“', '').replace('”', '')
              line = line.replace("_", "")
              if line.startswith("-"):
                line = line.replace("-", "")
                              
              line_split = line[:search_specie_pos+len(search_specie)].split()
              if search_specie in line_split:
                  index_search_specie = line_split.index(search_specie)
              
              if(index_search_specie > 1):
                  print("in if >1")
                  prev_word = line_split[index_search_specie-1]
                  prev_prev_word = line_split[index_search_specie-2]
                  if (prev_prev_word and prev_prev_word[0].isupper()) or (prev_word and prev_word[0].isupper()):
                      print("in if große buchstabe")
                      year_match = re.search(r'\b\d{2,4}[a-z]?\b', line)
                      index_prev_prev_word = line.lower().find(prev_prev_word.lower())
                      
                      if year_match:
                          print("in if year")
                          year = year_match.group(0)
                          index_year = line.index(year)
                          word_between = line[index_prev_prev_word:index_year+len(year)]
                          if index_year != -1 and index_year > index_prev_prev_word:
                              word_between = line[index_prev_prev_word:index_year+len(year)]
                          else:
                              word_between = line[index_prev_prev_word:]
                          word_between = word_between.replace("|", "")
                          lines_with_search_specie.append(word_between)
                      else:
                          word_between = line[index_prev_prev_word:search_specie_pos + len(search_specie)]
                          if(len(line) > 3) and len(lines_with_search_specie) == 0:
                              lines_with_search_specie.append(word_between) 
                  else:
                      line = line.replace("|", "")
                      line = line.replace("_", "")
                      word_between = line[:search_specie_pos + len(search_specie)]
                      if(len(line) > 3) and len(lines_with_search_specie) == 0:
                          lines_with_search_specie.append(word_between)
                           
                  if(index_search_specie == 1):
                      print("index_search_specie == 1")
                      prev_word = line_split[index_search_specie-1]
                      if (prev_word and prev_word[0].isupper()):
                          print("pre word große buchstabe")
                          year_match = re.search(r'\b\d{2,4}[a-z]?\b', line)
                          index_prev_word = line.lower().find(prev_word.lower())
                          if year_match:
                              year = year_match.group(0)
                              index_year = line.index(year)
                              word_between = line[index_prev_word:index_year+len(year)]
                              word_between = word_between.replace("|", "")
                              lines_with_search_specie.append(word_between)
                          else:
                              word_between = line[index_prev_word:search_specie_pos + len(search_specie)]
                              if(len(line) > 3) and len(lines_with_search_specie) == 0:
                                  lines_with_search_specie.append(word_between)
              else:
                  print("in else")
                  line = line.replace("|", "")
                  line = line.replace("_", "")
                  word_between = line[:search_specie_pos + len(search_specie)]
                  if(len(line) > 3) and len(lines_with_search_specie) == 0:
                      lines_with_search_specie.append(word_between)
        print(lines_with_search_specie)
        if len(lines_with_search_specie) == 0:
            return ""
        
        # ⭐ beste Zeile wählen
        with_year = [l for l in lines_with_search_specie if re.search(r'\b\d{4}[a-z]?\b', l)]
        
        if len(with_year) > 0:
            return with_year[0]
        
        # fallback
        return lines_with_search_specie[0]
    
    except Exception as e:
        print("An error occurred during get_lines_last_check processing:")
        print(e)
        # Here you can print traceback or additional information to locate the error
        print(traceback.format_exc())
        return ""

      
      
     
