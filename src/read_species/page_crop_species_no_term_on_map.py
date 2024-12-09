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
import pandas as pd

os.environ['TESSDATA_PREFIX'] = "C:/Program Files/Tesseract-OCR/tessdata/"


def find_species_context(page_path, keyword_page_specie="", keyword_top=0, keyword_bottom=0):
    """
    This function searches for unique species titles, extracts only the unique part of each title, 
    and finds the Y-Pixel position of the first word in each unique title.

    Parameters:
    - page_path (str): The file path of the image.
    - keyword_page_specie (str): The keyword to locate in the image (default is "Type").
    - keyword_top (int): The number of lines above the keyword to consider for the title.

    Returns:
    - title_contents (list): A list of dictionaries containing unique titles, line numbers, and Y-Pixel positions.
    """
    keyword_top = int(keyword_top)  # Sicherstellen, dass es ein Integer ist
    keyword_bottom = int(keyword_bottom)  # Sicherstellen, dass es ein Integer ist
   
    try:
        # Initialize result list and set for uniqueness
        title_contents = []
        found_titles = set()  # Set to track unique titles

        # Load the image from the specified file path
        image = Image.open(page_path)
    
        # Extract text from the image using image_to_string
        extracted_text = pytesseract.image_to_string(image)
    
        # Extract detailed data using image_to_data for position information
        extracted_data = pytesseract.image_to_data(image, output_type=pytesseract.Output.DICT)
    
        # Regular expression for a 3 or 4-digit year within parentheses
        year_pattern = re.compile(r'\b\d{3,4}\b')

        # Split the text into lines (ignoring empty lines)
        lines = [line for line in extracted_text.split('\n') if line.strip()]
        
        # Iterate through each line to find the keyword and check the surrounding context
        for line_num, line in enumerate(lines):
            if year_pattern.search(line) and line[0].isupper():  # If a line contains a year and starts with an uppercase letter
                keyword_line_num = 0
                if keyword_page_specie != "":
                    if keyword_bottom > 0:
                        keyword_line_num = line_num + keyword_bottom
                    elif keyword_top > 0:
                        keyword_line_num = line_num - keyword_top
                    
                    # Ensure we're within bounds of the lines list
                    if 0 <= keyword_line_num < len(lines):
                        keyword_line = lines[keyword_line_num].strip()
                        if keyword_page_specie in keyword_line:
                            # Split the line into words and remove the repeated beginning part
                            words = line.split()
                            unique_part = " ".join(words[1:])  # Skipping the first word if common
                            print(unique_part)
                            # Check for uniqueness of the unique part of the title
                            if unique_part not in found_titles:
                                # Add to set to ensure it's not duplicated
                                found_titles.add(unique_part)
                                
                                # Extract the first word of the unique part for Y-Position
                                first_unique_word = words[1] if len(words) > 1 else words[0]
                                
                                # Find the Y-Pixel position of the first word in image_to_data
                                for i, word in enumerate(extracted_data['text']):
                                    if word.strip() == first_unique_word:
                                        y_position = extracted_data['top'][i]
                                        title_contents.append({
                                            'title': line,
                                            'line_number': line_num,
                                            'y': y_position,
                                            'file_name':page_path
                                        })
                                        #print(f"Found unique title: {unique_part}, Line: {line_num}, Y-Pixel Position of First Unique Word: {y_position}")
                                        break  # Stop after finding the first unique word's Y-position
        df = pd.DataFrame(title_contents)
        return df  # Return list of unique titles with the Y-Pixel position of the first word

    except Exception as e:
        print(f"An error occurred: {e}")
        return []




# Test the function
#test = find_species_context('D:/distribution_digitizer/data/input/pages/0081.tif', keyword_page_specie="Type", keyword_top=0, keyword_bottom=2)

