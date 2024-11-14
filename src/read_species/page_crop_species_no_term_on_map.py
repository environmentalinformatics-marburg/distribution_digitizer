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



# Function to find species title with simpler approach
def find_species_title(page_path, keyword_page_specie="", middle=0, keyword_top=0, keyword_bottom = 0):
    """
    This function searches for a species title based on a simpler approach:
    It finds the keyword, then checks two lines above it for a species title that contains a year.

    Parameters:
    - page_path (str): The file path of the image.
    - keyword_page_specie (str): The keyword to locate in the image (default is "Type").
    - keyword_top (int): The number of lines above the keyword to consider for the title.

    Returns:
    - title_content (str): The content of the line matching the species title pattern.
    """
    try:
        # Initialize result variable
        title_content = ""

        # Load the image from the specified file path
        image = Image.open(page_path)
    
        # Extract text from the image
        extracted_text = pytesseract.image_to_string(image)
    
        # Split the text into lines no " " lines with strip()
        lines = [line for line in extracted_text.split('\n') if line.strip()]
      
        # Regular expression for a 3 or 4-digit year within parentheses
        year_pattern = re.compile(r'\b\d{3,4}\b')

        # Iterate through each line to find the keyword
        for line_num, line in enumerate(lines):
            if year_pattern.search(line) and line[0].isupper():
                target_line_num = line_num
                title_content = line
                keyword_line_num = 0
                if keyword_page_specie != "":
                  if keyword_bottom > 0:
                      keyword_line_num = line_num + keyword_bottom
                  elif keyword_top > 0:
                      keyword_line_num = line_num - keyword_top
                  keyword_line = lines[keyword_line_num].strip()
                  if keyword_page_specie in keyword_line:
                    title_content = line
                    print(line)
                  
                 
        #print(title_content)
        return title_content  # Return empty if no title found

    except Exception as e:
        print("An error occurred during find_species_title processing:")
        print(e)
        print(traceback.format_exc())
        return "Error in function find_species_title"


      
      
# Test the function
test = find_species_title('D:/distribution_digitizer/data/input/pages/0144.tif', keyword_page_specie="Type", keyword_top=0, keyword_bottom=2, middle=0)

