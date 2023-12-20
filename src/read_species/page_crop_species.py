# -*- coding: utf-8 -*-
"""
Description: This script edits book pages and crops the main spacies titles.
"""

__author__ = "Spaska Forteva"
__date__ = "24. September 2023"
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

    
# Function recognizing rows with keywords and special regex 
def mainPageCropSpecies(pagePath, words_to_find):
  
  # Load the image from the specified file path
  #pagePath = 'D:/distribution_digitizer/data/input/pages/0041.tif'
  #words_to_find = "_elma_litoralis"
  words = words_to_find.split("_")
  
  # Lambda-Funktion, um leere Zeichenfolgen aus der Liste zu entfernen.
  words = list(filter(lambda x: x != "", words))
 
  # Patter for special species
  pattern = r'\b\d{4}\b'
  print(words)
  # Load the image
  image = Image.open(pagePath)

  # Perform OCR
  extracted_text = pytesseract.image_to_string(image)
    
  # Extract text from the image
  extracted_data = pytesseract.image_to_data(image, output_type=pytesseract.Output.DICT)
  #print(extracted_data.keys())
  block_nums = {}
  # Iterate through the recognized words and print their coordinates in the lines
  for i in range(len(extracted_data['text'])):
      word = extracted_data['text'][i].strip()
      if word in words:
          if word not in block_nums:
              block_nums[word] = []
          block_nums[word].append(i)
  print(block_nums)
  
  all_results = []
  year_pattern = r'\b\d{4}\b'

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
      
  return all_results
  # 
#   def ist_wort(text):
#      # Überprüfen, ob der Text ein Wort ist und keine Sonderzeichen enthält
#      return bool(re.match(r'^[a-zA-Z0-9]+$', text)) and '|' not in text
#       if extracted_data['block_num'][start] == extracted_data['block_num'][i] :
#         print(extracted_data['text'][start])
#         satz = satz + "," + extracted_data['text'][start])
#     print(satz)
#     
# print("H")
# # Ergebnisse ausgeben
# for result in results:
#     print(f"Block_num {result[0]}: {result[1]}")
#     print("NEW") 
# 
# # Gewünschte block_num auswählen (z.B. block_num = 1)
# # Gewünschte block_num auswählen (z.B. block_nums = [16, 17, 18])
# 
# 
# # Liste für die Ergebnisse erstellen
# results = []
# 
# # Durch die ausgewählten block_nums iterieren und die Ergebnisse speichern
# for block_num in block_nums:
#     text_for_block = [extracted_data['text'][i].strip() for i in range(len(extracted_data['text'])) if extracted_data['block_num'][i] == block_num]
#     print(len(text_for_block))
#     if(len(text_for_block) < 50):
#       print(text_for_block)
#       results.append((block_num, ' '.join(text_for_block)))
# 
# 
# 
# result = '' 
# 
# 
# 
# 
#       if word:
#           x = extracted_data['left'][i]
#           y = extracted_data['top'][i]
#           width = extracted_data['width'][i]
#           height = extracted_data['height'][i]
#           conf = extracted_data['conf'][i]
#           line_num = extracted_data['block_num'][i]
#           
#           # A new block has started
#           if line_num != new_block and x > 400:
#             index = 0
#             result = result + " " + word
#           if line_num == new_block and index <5:
#             result = result + " " + word
#           if index == 5:
#             #print(result)
#             rowResults.append(result)
#             result = ''
#           new_block = line_num
#           index = index + 1
#           
#   return rowResults
# 
# 
# 
# 
# if len(words_to_find) > 0:
#               print(len(words_to_find))
#               print("words:")
#               print(words_to_find)
#               # Process the result when five words are reached
#               for listW in words_to_find:
#                 print(listW)
#                 #words = listW.split(" ")
#                 print(words)
#                 if len(words) > 0:
#                   print(words)
#                   print(result)
#                   if result.find(words) > 0:
#                     # Search for matches in the text
#                     match = re.search(year_pattern, result)
#                     if match:

