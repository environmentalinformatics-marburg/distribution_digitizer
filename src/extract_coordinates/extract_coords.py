"""
File: extract_coords.py
Author: Kai Richter
Date: 2023-11-13

Description:
Script for creating a csv file with centroid coordinates based on point shapefiles. 

The function 'extract_coords' reads a point shapefile, extracts the coordinates and returns them in a list. 

The function 'mainExtractCoords_CD' is for iteratively loop over all point shapefiles given out by poly_to_point.py script 
for Circle Detection. The csv file is stored in /data/output/final_output/circleDetection/coordinates.csv

The function 'mainExtractCoords_PF' is for iteratively loop over all point shapefiles given out by poly_to_point.py script 
for Point Filtering. The csv file is stored in /data/output/final_output/pointFiltering/coordinates.csv

The output csv file has 5 columns:
  File                input filename
  Detection method    "point_filtering" or "circle_detection"
  X_WGS84             georeferenced x coordinate
  Y_WGS84             georeferenced y coordinate
  georef              Information if coordinates are georeferenced: 0 = not georeferenced; 1 = georeferenced. 
                      In this case, 1 will be set, as the georeferenced coordinates are given in. 
"""


# import libraries
import os
import csv
import geopandas as gpd

# define function to append coordinates to CSV file
def append_to_csv_file(file_path, coords, filename, detection_method, georef):
    with open(file_path, 'a', newline='') as csvfile:
        csv_writer = csv.writer(csvfile)
        for x, y in coords:
            csv_writer.writerow([filename, detection_method, x, y, georef])

# define function to initialize CSV file
def initialize_csv_file(file_path, *header):
    if not os.path.exists(file_path):
        with open(file_path, 'w', newline='') as csvfile:
            csv_writer = csv.writer(csvfile)
            csv_writer.writerow(["File", "Detection method", "X_WGS84", "Y_WGS84", "georef"])
            if header:
                csv_writer.writerow(header)

# define function to extract coordinates from a shapefile
def extract_coords(shapefile):
    gdf = gpd.read_file(shapefile)
    coords = [(point.x, point.y) for point in gdf.geometry]
    return coords

#workingDir = "D:/distribution_digitizer/"

# function to loop over extract_coords function for coordinates detected by Circle Detection
def mainExtractCoords_CD(workingDir):
    input_folder = workingDir + "/data/output/final_output/circleDetection/"
    outputCsvDir = workingDir + "/data/output/final_output/circleDetection/"

    # initialize csv file for storing the coordinates (if the file does not exist already)
    initialize_csv_file(outputCsvDir)

    # define csv filepath
    csv_file_path = outputCsvDir + "coordinates.csv"

    # iterate over subfolders in the input folder
    for subdir, dirs, files in os.walk(input_folder):
        for file in files:
            if file.endswith('_points.shp'):
                # input shapefile path
                input_shapefile = os.path.join(input_folder, subdir, file)

                # call the function
                coords = extract_coords(input_shapefile)

                # append them to csv file
                append_to_csv_file(csv_file_path, coords, os.path.basename(file), "circle_detection", 1)


# function to loop over extract_coords function for coordinates detected by Point Filtering
def mainExtractCoords_PF(workingDir):
    input_folder = workingDir + "/data/output/final_output/pointFiltering/"
    outputCsvDir = workingDir + "/data/output/final_output/pointFiltering/"

    # initialize csv file for storing the coordinates (if the file does not exist already)
    initialize_csv_file(outputCsvDir)

    # define csv filepath
    csv_file_path = outputCsvDir + "coordinates.csv"

    # iterate over subfolders in the input folder
    for subdir, dirs, files in os.walk(input_folder):
        for file in files:
            if file.endswith('_points.shp'):
                # input shapefile path
                input_shapefile = os.path.join(input_folder, subdir, file)

                # call the function
                coords = extract_coords(input_shapefile)

                # append them to csv file
                append_to_csv_file(csv_file_path, coords, os.path.basename(file), "point_filtering", 1)

# Call the functions
mainExtractCoords_CD(workingDir)
mainExtractCoords_PF(workingDir)
