"""
File: poly_to_point.py
Author: Kai Richter
Date: 2023-11-10

Last modified on 2024-03-13 by Spaska Forteva:
  add try
Description: 
Script for converting the polygons representing georeferenced centroids of detected symbols into point-shapefiles. 

In the function 'poly_to_point', the center coordinate of every polygon is calulated and stored in a list. 
Based on this list, a GeoDataFrame with the crs of the input shapefile is created and saved. 

function 'MainPolyToPoint_CD': Creates point-shapefiles for polygonized output of centroid masks detected by Circle Detection. 
  
function 'MainPolyToPoint_PF': Creates point-shapefiles for polygonized output of centroid masks detected by Point Filtering. 



Comment:
2023-11-12: Remains to be binded into the UI (app.R). 
"""

# import libraries
import os
import geopandas as gpd


## convert polygons to points
def poly_to_point(input_shapefile, output_shapefile):
  try:
    
    # read the input shapefile
    gdf = gpd.read_file(input_shapefile)
    
    # initialize a list to store the centroid points
    centroid_points = []
    
    # iterate through the polygons and calculate the centroid points (center coordinate of the polygon)
    for index, row in gdf.iterrows():
        polygon = row['geometry']
        centroid = polygon.centroid
        centroid_points.append(centroid)
    
    # create a GeoDataFrame from the centroid points
    gdf_points = gpd.GeoDataFrame(geometry=centroid_points, crs=gdf.crs)
    
    # save the GeoDataFrame as a shapefile
    gdf_points.to_file(output_shapefile)
    
  except Exception as e:
        print("An error occurred in poly_to_point:", e)
  # End of function


#workingDir="D:/distribution_digitizer/"
def main_circle_detection(workingDir, outDir):
  try:
    
    input_folder = outDir + "/polygonize/circleDetection/"
    output_folder = outDir + "/final_output/circleDetection/"
    os.makedirs(output_folder, exist_ok=True) 
    
    # Iterate over subfolders in the input folder
    for subdir, dirs, files in os.walk(input_folder):
        for file in files:
            if file.endswith('_filtered.shp'):
                # Input shapefile path
                input_shapefile = os.path.join(subdir, file)
  
                # Create output subfolder structure in the output folder
                relative_path = os.path.relpath(input_shapefile, input_folder)
                output_subfolder = os.path.join(output_folder, os.path.dirname(relative_path))
                os.makedirs(output_subfolder, exist_ok=True)
  
                # Output shapefile path
                output_shapefile = os.path.join(output_folder, relative_path.replace('.shp', '_points.shp'))
  
                # Convert polygons to points
                poly_to_point(input_shapefile, output_shapefile)
                
  except Exception as e:
        print("An error occurred in main_circle_detection:", e)
  # End of function


def main_point_filtering(workingDir, outDir):
  try:
    
    input_folder = outDir + "/polygonize/pointFiltering/"
    output_folder = outDir + "/final_output/pointFiltering/"
    os.makedirs(output_folder, exist_ok=True) 
    # Iterate over subfolders in the input folder
    for subdir, dirs, files in os.walk(input_folder):
        for file in files:
            if file.endswith('_filtered.shp'):
                # Input shapefile path
                input_shapefile = os.path.join(subdir, file)

                # Create output subfolder structure in the output folder
                relative_path = os.path.relpath(input_shapefile, input_folder)
                output_subfolder = os.path.join(output_folder, os.path.dirname(relative_path))
                os.makedirs(output_subfolder, exist_ok=True)

                # Output shapefile path
                output_shapefile = os.path.join(output_folder, relative_path.replace('.shp', '_points.shp'))

                # Convert polygons to points
                poly_to_point(input_shapefile, output_shapefile)
                
  except Exception as e:
        print("An error occurred in main_point_filtering:", e)
  # End of function


