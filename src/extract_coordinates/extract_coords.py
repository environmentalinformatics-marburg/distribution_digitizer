"""
File: extract_coords.py
Author: Kai Richter
Date: 2023-11-13

Description:
Script for creating a csv file with centroid coordinates based on point shapefiles. 

The function 'extract_coords' reads a point shapefile, extracts the coordinates and returns them in a list. 

The function 'mainExtractCoords_CD' is for iteratively loop over all point shapefiles given out by poly_to_point.py script 
for Circle Detection. 

The function 'mainExtractCoords_PF' is for iteratively loop over all point shapefiles given out by poly_to_point.py script 
for Point Filtering. 
"""


# import library
import geopandas as gpd

# define function
def extract_coords(shapefile):

    # read the shapefile using geopandas
    gdf = gpd.read_file(shapefile)

    # extract coordinates from the geometry column
    coords = [(point.x, point.y) for point in gdf.geometry]
    
    # return the coordinate pairs
    return coords


# function to loop over extract_coords function for coordinates detected by Circle Detection 
def mainExtractCoords_CD(workingDir):
    input_folder = workingDir + "/data/output/final_output/circleDetection/"
    outputCsvDir = workingDir + "/data/output/final_output/circleDetection/"
    
    # initialize csv file for storing the cooridnates (if the file does not exist already)
    initialize_csv_file(outputCsvDir, "X_WGS84", "Y_WGS84")
    
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
    
    # initialize csv file for storing the cooridnates (if the file does not exist already)
    initialize_csv_file(outputCsvDir, "X_WGS84", "Y_WGS84")
    
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
                
