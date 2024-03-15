"""
File: geo_points_extraction.py
Author: Kai Richter
Date: 2023-11-12

Last modified on: 2024-03-14 by Spaska Forteva

Description:
This script extracts georeferenced centroid coordinates from raster images.

It utilizes OpenCV and GDAL libraries for image processing and geospatial operations.

"""


import numpy as np
import cv2
import numpy as np
from osgeo import gdal
import csv
import os
import glob

def geopointextract(tiffile, geofile, outputcsv, n):
  try:
    
    # Open the raster image file
    img = gdal.Open(tiffile)
    
    # Open the georeferenced image file
    geoimg = gdal.Open(geofile)
    
    # Get the geotransformation parameters
    gt = geoimg.GetGeoTransform()
    
    # Read the raster image as a NumPy array
    img = np.array(img.GetRasterBand(1).ReadAsArray())
    
    # Apply image processing to extract features
    ret, thresh = cv2.threshold(img, 120, 255, cv2.THRESH_TOZERO_INV)
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (n, n))
    opening = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel, iterations=3)
    
    # Find contours in the processed image
    contours, hierarchy = cv2.findContours(opening, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
    
    # Open the output CSV file
    with open(outputcsv, 'a', newline='') as csvfile:   
      # Create a CSV writer object   
      csvwriter = csv.writer(csvfile)   
      
      # Write the header fields   
      csvwriter.writerow(["Filename", 'Centroid X', 'Centroid Y'])   
      
      # Iterate over contours to calculate centroids and write to CSV
      for c in contours:
        # Calculate moments for each contour
        M = cv2.moments(c)
        
        # Calculate centroid coordinates
        cX = int(M["m10"] / M["m00"])
        cY = int(M["m01"] / M["m00"])
        
        # Convert pixel coordinates to geographic coordinates
        x_pixel = cX
        y_line = cY
        x_geo = gt[0] + x_pixel * gt[1] + y_line * gt[2]
        y_geo = gt[3] + x_pixel * gt[4] + y_line * gt[5]
        
        # Write the data row to the CSV file
        csvwriter.writerows([[tiffile, x_geo, y_geo]])
        
  except Exception as e:
        print("An error occurred in geopointextract:", e)
  # End of function
     
     
# Function to extract georeferenced centroid coordinates from multiple raster images
def maingeopointextract(workingDir, outDir, n):
  try:
      
    inputdir = outDir + "/georeferencing/masks/"
    outputcsv = outDir + "/georecords.csv"
    geofiledir = workingDir + "data/input/templates/geopoints/"
    
    # Iterate over raster images in the input directory
    for tiffile in glob.glob(inputdir + '*.tif'): 
      # Iterate over georeferenced images in the georeferenced image directory
      for geofile in glob.glob(geofiledir + '*.tif'):
        print(tiffile)
        
        # Call geopointextract function to extract centroid coordinates
        geopointextract(tiffile, geofile, outputcsv, 5)
      
  except Exception as e:
        print("An error occurred in maingeopointextract:", e)
  # End of function
