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
import pandas as pd
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

      
def analyze_year_corrections(training_df):
    """
    Learn OCR year patterns from user-corrected training titles.

    Example:
        OCR:       (Linnaeus, | 758)
        Confirmed: (Linnaeus, 1758)

    Result:
        three_digit_year = True
    """

    corrected_rows = training_df[
        training_df["confirmed_text"].notna()
    ]

    total = 0
    three_digit_year = 0

    for _, row in corrected_rows.iterrows():

        ocr_text = str(row["ocr_text"])
        confirmed_text = str(row["confirmed_text"])

        # Correct four-digit year from confirmed title
        confirmed_year = re.search(
            r"\b(17|18|19|20)\d{2}\b",
            confirmed_text
        )

        if not confirmed_year:
            continue

        total += 1

        year = confirmed_year.group()

        # Last three digits of confirmed year
        last_three = year[1:]

        # Did OCR contain only these three digits?
        if re.search(
            rf"\b{re.escape(last_three)}\b",
            ocr_text
        ):
            three_digit_year += 1

    frequency = (
        three_digit_year / total
        if total > 0
        else 0
    )

    return {
        "three_digit_year": frequency >= 0.8,
        "frequency": frequency,
        "examples": total
    }
    
def find_species_context_loose(
    workingDir="",
    page_path="",
    search_specie="",
    previous_page_path=None,
    next_page_path=None,
    middle=None,
    legendKeywords=None
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
def find_species_context(workingDir="", page_path="", words_to_find="", previous_page_path=None, next_page_path=None, keyword_page_Specie=None, keyword_top=None, keyword_bottom=None, middle=None, legendKeywords=None):
    print(legendKeywords)
    # Normalize legend list (ONLY first word!)
    if legendKeywords is None:
        legendKeywords = ["distribution"]

    if isinstance(legendKeywords, str):
        legendKeywords = [legendKeywords]

    legendKeywords = [l.lower().strip().split()[0] for l in legendKeywords]
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

        for i, legend in enumerate(legendKeywords):
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
            legendKeywords
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
                legendKeywords
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
                legendKeywords
            )
            if (len(specie_content) > 3):
                all_results.append(str(flag) + "_" + str(legI) + "_" + search_specie + "_" + specie_content)
                continue

        if (len(specie_content) == 0):
            print("1 get_lines_last_check")
            specie_content = get_lines_last_check(page_path, search_specie, legendKeywords)
            if (len(specie_content) > 5):
                print(specie_content)
                all_results.append(str(flag) + "_" + str(legI) + "_" + search_specie + "_" + specie_content)
                continue
        if (len(specie_content) == 0) and (previous_page_path is not None and previous_page_path != "None"):
            print("2 get_lines_last_check previous_page_path")
            specie_content = get_lines_last_check(previous_page_path, search_specie, legendKeywords)
            if (len(specie_content) > 5):
                all_results.append(str(flag) + "_" + str(legI) + "_" + search_specie + "_" + specie_content)
                continue

        if (len(specie_content) == 0) and (next_page_path is not None and next_page_path != "None"):
            print("3 get_lines_last_check next_page_path")
            specie_content = get_lines_last_check(next_page_path, search_specie, legendKeywords)
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
                legendKeywords
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
middle=None, legendKeywords=None):
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
  
    if legendKeywords:
      if len(legendKeywords) > 0:
          legends.append(legendKeywords[0].split()[0])
      if len(legendKeywords) > 1:
          legends.append(legendKeywords[1].split()[0])
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

      
      words_in_line = re.findall(r'\b\w+\b', line.lower())

      match_found = any(
          similar(search_specie.lower(), w) > 0.75
          or search_specie.lower() in w
          or w in search_specie.lower()
          for w in words_in_line
      )
      
      if match_found:
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
          
                  if keyword_page_Specie is None:
                      return line
          
                  # 👉 HIER kommt deine neue Logik RICHTIG hin
                  if keyword_bottom is not None:
                      difference = keyword_bottom
                  elif keyword_top is not None:
                      difference = -keyword_top
                  else:
                      print("⚠️ No keyword context for:", line)
                      continue
          
                  target_index = int(line_num + difference)
          
                  if 0 <= target_index < len(lines):
                      temp_line = lines[target_index]
                  else:
                      continue
          
                  if any(similar(keyword_page_Specie.lower(), w.lower()) > 0.8 for w in temp_line.split()):
                      return line
          
                  # 👉 wenn keyword nicht passt → skip
                  continue
          
              else:
                  print("⚠️ middle check failed – but valid line found, returning anyway")
                  return line

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
def get_lines_last_check(image_path, search_specie, legendKeywords=None):
    try:
        """
        Get lines containing a specific search_specie, starting with a capital letter and containing a 4-digit year.
        """
        print("DEBUG ist in get_lines_last_check")
        search_specie = search_specie.strip(' ,.?!()[]{}_"\';')
        legends = []
        if legendKeywords:
          if len(legendKeywords) > 0:
              legends.append(legendKeywords[0].split()[0])
          if len(legendKeywords) > 1:
              legends.append(legendKeywords[1].split()[0])
        
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

   
# ------------------------------------------------------------
# Reads species titles from the training CSV.
#
# For structural title recognition, confirmed_text is preferred
# when available. Otherwise the original OCR text is used.
# ------------------------------------------------------------
def read_training_titles(training_csv):

    import csv

    training_titles = []

    with open(
        training_csv,
        "r",
        encoding="utf-8-sig",
        newline=""
    ) as file:

        reader = csv.DictReader(file)

        for row in reader:

            confirmed_text = (
                row.get("confirmed_text") or ""
            ).strip()

            ocr_text = (
                row.get("ocr_text") or ""
            ).strip()

            # Corrected title has priority
            if confirmed_text:
                title = confirmed_text
            else:
                title = ocr_text

            if title:
                training_titles.append(title)

    return training_titles


# ------------------------------------------------------------
# Analyses only the FIRST CHARACTER of all training titles.
#
# At this stage we deliberately learn only whether all titles
# start with:
# - an uppercase letter
# - a letter
# - something else
#
# More title structure will be added step by step later.
# ------------------------------------------------------------
def analyse_first_char(training_titles):

    if not training_titles:
        return None

    first_chars = [
        title.strip()[0]
        for title in training_titles
        if title and title.strip()
    ]

    if not first_chars:
        return None

    print("\n=======================================")
    print("FIRST CHARACTER ANALYSIS")
    print("=======================================")

    for title in training_titles:

        title = title.strip()

        if title:
            print(
                repr(title[0]),
                " -> ",
                title
            )

    # --------------------------------------------------------
    # Are ALL first characters letters?
    # --------------------------------------------------------

    all_letters = all(
        char.isalpha()
        for char in first_chars
    )

    # --------------------------------------------------------
    # Are ALL first characters uppercase letters?
    # --------------------------------------------------------

    all_upper = all(
        char.isalpha() and char.isupper()
        for char in first_chars
    )

    # --------------------------------------------------------
    # Create ONLY the first part of the future regex
    # --------------------------------------------------------

    if all_upper:

        regex_start = r"^[A-ZÀ-ÖØ-Þ]"

    elif all_letters:

        regex_start = r"^[A-Za-zÀ-ÖØ-öø-ÿ]"

    else:

        regex_start = None

    print("---------------------------------------")
    print("Number of titles:", len(first_chars))
    print("First characters:", first_chars)
    print("All are letters:", all_letters)
    print("All are uppercase:", all_upper)
    print("Learned regex start:", regex_start)
    print("=======================================\n")

    return regex_start   
  
  
def analyse_last_char(training_titles):
    """
    Analyse the last character of all training titles
    and determine the corresponding regex end.
    """

    if not training_titles:
        return None

    last_chars = [
        title.strip()[-1]
        for title in training_titles
        if title and title.strip()
    ]

    if not last_chars:
        return None

    print("\n=======================================")
    print("LAST CHARACTER ANALYSIS")
    print("=======================================")

    for title in training_titles:

        title = title.strip()

        if title:
            print(
                repr(title[-1]),
                " -> ",
                title
            )

    # --------------------------------------------------------
    # Check whether all titles have exactly the same
    # last character
    # --------------------------------------------------------

    same_last_char = (
        len(set(last_chars)) == 1
    )

    if same_last_char:

        last_char = last_chars[0]

        # re.escape is important for characters such as
        # ), ], ., *, etc.
        regex_end = (
            re.escape(last_char) + "$"
        )

    else:

        last_char = None
        regex_end = None

    print("---------------------------------------")
    print("Number of titles:", len(last_chars))
    print("Last characters:", last_chars)
    print("Same last character:", same_last_char)
    print("Learned last character:", last_char)
    print("Learned regex end:", regex_end)
    print("=======================================\n")

    return regex_end
  
def analyse_digit(training_titles, threshold=0.9):
    """
    Analyse whether digits occur in the training titles.

    If digits occur in at least `threshold` of all titles,
    digits are considered a characteristic title feature.
    """

    titles = [
        title.strip()
        for title in training_titles
        if title and title.strip()
    ]

    if not titles:
        return False

    # --------------------------------------------------------
    # Check every title
    # --------------------------------------------------------

    titles_with_digits = 0

    print("\n=======================================")
    print("DIGIT ANALYSIS")
    print("=======================================")

    for title in titles:

        has_digit = any(
            char.isdigit()
            for char in title
        )

        if has_digit:
            titles_with_digits += 1

        print(
            has_digit,
            " -> ",
            title
        )

    # --------------------------------------------------------
    # Frequency
    # --------------------------------------------------------

    frequency = (
        titles_with_digits / len(titles)
    )

    use_digits = (
        frequency >= threshold
    )

    print("---------------------------------------")
    print("Number of titles:", len(titles))
    print("Titles with digits:", titles_with_digits)
    print("Frequency:", round(frequency, 2))
    print("Use digits in regex:", use_digits)
    print("=======================================\n")

    return use_digits
  

def build_title_regex(
    regex_start,
    regex_end,
    use_digits=False,
    year_learning=None
):

    if not regex_start or not regex_end:
        return None

    # Remove $ because OCR may append text after the title
    regex_end_search = regex_end.rstrip("$")

    regex = regex_start
    regex += r".*?"

    if use_digits:

        # Training showed that Tesseract can lose
        # the first digit of a four-digit year
        if (
            year_learning
            and year_learning.get("three_digit_year", False)
        ):
            regex += r"\d{3,4}"
        else:
            regex += r"\d"

    regex += r".*?"
    regex += regex_end_search

    print("\nLEARNED REGEX:")
    print(regex)

    return re.compile(regex)

  
def test_title_regex_on_page(
    image_path,
    title_regex
):
    """
    OCR page line by line and return all lines matching
    the learned species-title regex, including coordinates.
    """

    image = cv2.imread(image_path)

    if image is None:
        print("Image could not be read:", image_path)
        return []

    gray = cv2.cvtColor(
        image,
        cv2.COLOR_BGR2GRAY
    )

    data = pytesseract.image_to_data(
        gray,
        output_type=pytesseract.Output.DICT
    )

    # --------------------------------------------------------
    # Reconstruct OCR lines including coordinates
    # --------------------------------------------------------

    lines = {}

    for i, text in enumerate(data["text"]):

        text = text.strip()

        if not text:
            continue

        line_key = (
            data["block_num"][i],
            data["par_num"][i],
            data["line_num"][i]
        )

        if line_key not in lines:
            lines[line_key] = {
                "words": [],
                "left": [],
                "top": [],
                "right": [],
                "bottom": []
            }

        x = data["left"][i]
        y = data["top"][i]
        w = data["width"][i]
        h = data["height"][i]

        lines[line_key]["words"].append(text)

        lines[line_key]["left"].append(x)
        lines[line_key]["top"].append(y)
        lines[line_key]["right"].append(x + w)
        lines[line_key]["bottom"].append(y + h)

    # --------------------------------------------------------
    # Test every OCR line
    # --------------------------------------------------------

    matches = []

    print("\n=======================================")
    print("REGEX TEST")
    print("Page:", image_path)
    print("Regex:", title_regex.pattern)
    print("=======================================\n")

    for line in lines.values():

        line_text = " ".join(
            line["words"]
        ).strip()
    
        regex_match = title_regex.match(line_text)
    
        if regex_match:
    
            # Only the part of the OCR line that matched the learned regex
            matched_text = regex_match.group(0).strip()
    
            x = min(line["left"])
            y = min(line["top"])
    
            x2 = max(line["right"])
            y2 = max(line["bottom"])
    
            w = x2 - x
            h = y2 - y
    
            match = {
                "text": matched_text,
                "x": x,
                "y": y,
                "w": w,
                "h": h
            }
    
            matches.append(match)
    
            print("MATCH:")
            print(matched_text)
            print(
                "x:", x,
                "y:", y,
                "w:", w,
                "h:", h
            )
            print()

    print("Total matches:", len(matches))

    return matches

def detect_species_titles_from_training(
    image_path,
    training_csv
):
    """
    Detect species titles on a page using a regex
    learned automatically from the training CSV.
    """

    # --------------------------------------------------------
    # Read complete training data
    # --------------------------------------------------------

    training_df = pd.read_csv(
        training_csv
    )

    # --------------------------------------------------------
    # Read titles for structural analysis
    # confirmed_text has priority over OCR text
    # --------------------------------------------------------

    training_titles = read_training_titles(
        training_csv
    )

    # Learn regex start
    regex_start = analyse_first_char(
        training_titles
    )

    # Learn regex end
    regex_end = analyse_last_char(
        training_titles
    )

    # Learn whether digits are characteristic
    use_digits = analyse_digit(
        training_titles,
        threshold=0.9
    )

    # --------------------------------------------------------
    # Learn OCR year errors from user corrections
    # --------------------------------------------------------

    year_learning = analyze_year_corrections(
        training_df
    )

    print("\nYEAR CORRECTION LEARNING:")
    print(year_learning)

    # --------------------------------------------------------
    # Build learned regex
    # --------------------------------------------------------

    title_regex = build_title_regex(
        regex_start,
        regex_end,
        use_digits,
        year_learning
    )

    # --------------------------------------------------------
    # Detect titles on page
    # --------------------------------------------------------

    matches = test_title_regex_on_page(
    image_path,
    title_regex
    )
    
    # --------------------------------------------------------
    # Apply OCR corrections learned from user training
    # --------------------------------------------------------
    
    for match in matches:
    
        original_text = match["text"]
    
        corrected_text = correct_learned_year_error(
            original_text,
            year_learning
        )
    
        if corrected_text != original_text:
    
            print("\nLEARNED OCR CORRECTION:")
            print("OCR:      ", original_text)
            print("Corrected:", corrected_text)
    
            match["text"] = corrected_text
    
    
    return matches

def correct_learned_year_error(text, year_learning):
    """
    Correct OCR year errors learned from user corrections.

    Example learned from training:
        | 758  -> 1758
        |775   -> 1775
    """

    if not text:
        return text

    if not year_learning:
        return text

    if not year_learning.get("three_digit_year", False):
        return text

    # --------------------------------------------------------
    # Look for a 3-digit year immediately before ')'
    #
    # Examples:
    #   | 758)
    #   |758)
    #   758)
    # --------------------------------------------------------

    pattern = r"(?<!\d)\|?\s*(\d{3})\s*\)"

    def replace_year(match):

        three_digits = match.group(1)

        # For the current learned pattern:
        # 758 -> 1758
        corrected_year = "1" + three_digits

        return corrected_year + ")"

    corrected_text = re.sub(
        pattern,
        replace_year,
        text
    )

    return corrected_text
