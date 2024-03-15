"""
File: coords_to_csv.py
Author: Kai Richter
Date: 2023-11-12

Last modified on 2024-03-13 by Spaska Forteva:
  Addition of try
  
Description:
Script for initializing and appending csv files for coordinate extraction.

The function 'initialize_csv_file' defines the header of a long-format csv file for storing coordinates of symbols. If
the file 'coordinates.csv' does not exist in the defined output folder, a csv file with the columns headers "File" 
(name of input tif file), "Detection method" (Circle detection or Point Filtering), "X" (original x cooridnate) 
and "Y" (original y coordinate) are created.

The function 'append_to_csv_file' has ti be calles afterwards and appends the rows to the initialized csv file. 

This script is sourced in the main-functions of the scripts circle_detection.py and point_filtering.py



Commment: 
2023-11-12: @Spaska - append missing column names if needed. 
"""

# load library
import csv

# define functions for initializing csv file
def initialize_csv_file(output_dir, x, y):
  try:
    
    csv_file_path = os.path.join(output_dir, "coordinates.csv")
    if not os.path.exists(csv_file_path):
        with open(csv_file_path, mode='w', newline='') as csv_file:
            csv_writer = csv.writer(csv_file)
            csv_writer.writerow(['File', 'Detection method', x, y, 'georef'])
    return csv_file_path
  except Exception as e:
        print("An error occurred in initialize_csv_file:", e)
  # End of function

# define function for appending existing csv file
def append_to_csv_file(csv_file_path, coordinates, file_name, method, georef):
  try:
    
    with open(csv_file_path, mode='a', newline='') as csv_file:
        csv_writer = csv.writer(csv_file)
        csv_writer.writerows([(file_name, method, x, y, georef) for x, y in coordinates])
        
  except Exception as e:
        print("An error occurred in append_to_csv_file:", e)
  # End of function
