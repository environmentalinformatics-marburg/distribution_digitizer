"""
File: point_filtering.py
Author: Spaska Forteva

Last modified on 2023-11-10 by Kai Richter:
  - Addition of centroid detection in function 'edge' 
  - Addition of function calls for initializing and appending a long-format csv file in the function 
  'mainPointFiltering'.
  
Description: 
Script for detecting symbols on a tif file through edge and contour detection. 
"""


import cv2
import PIL
from PIL import Image
import os.path
import glob
import numpy as np 


# Edge and Contour Detection
def edge(tiffile, outdir, n, m):
    # Load image, grayscale, Otsu's threshold
    ig = np.array(PIL.Image.open(tiffile))
    gray = cv2.cvtColor(ig, cv2.COLOR_BGR2GRAY)
    gray = cv2.GaussianBlur(gray, (m, m), 0)
    ret, thresh = cv2.threshold(gray, 120, 255, cv2.THRESH_TOZERO_INV)
    # Morph open using elliptical shaped kernel
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (n, n))
    opening = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel, iterations=3)
    # Plot the mask
    contours, hierarchy = cv2.findContours(opening, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
    
    # Draw contours and centroids
    
    centroids = []
    
    image = ig.copy()  # Create a copy of the original image
    for contour in contours:
        # draw the contour
        image = cv2.drawContours(image, [contour], -1, (0, 0, 255), 3)
        # calculate the centroid of the contour
        M = cv2.moments(contour)
        if M["m00"] != 0:
            cX = int(M["m10"] / M["m00"])
            cY = int(M["m01"] / M["m00"])
            # append centroids data frame
            centroids.append((cX, cY))
            # draw a red pixel at the centroid
            image[cY, cX] = (139, 0, 0)
    
    # Save the image with contours and centroids
    output_file = os.path.join(outdir, os.path.basename(tiffile))
    PIL.Image.fromarray(image, 'RGB').save(output_file)
    
    return centroids, output_file

#m = int(input(' Enter the value of Guassian filter or press enter for 9' )or 9)
#n=int(input(' Enter the value of kernel filter or press enter for 5' )or 5)
#input_tif = str(input("Enter the Input directory /..../"))
#for tiffile in glob.glob(input_tif + "*.tif"):
 #   edge(tiffile,input_tif,n,m)

#workingDir="D:/distribution_digitizer/"
#n=5
#m=9
#mainpointclassification( n, m)
def mainPointFiltering(workingDir, n, m):
  inputDir = workingDir+"/data/output/maps/align/"
  ouputTifDir = workingDir+"/data/output/maps/pointFiltering/"
  os.makedirs(ouputTifDir, exist_ok=True)
  print(inputDir)
  print(ouputTifDir)
  print(n)
  print(m)
  
  outputCsvDir = workingDir + "/data/output/maps/csv_files/"
  os.makedirs(outputCsvDir, exist_ok=True)
  # initialize csv file for storing the cooridnates (if the file does not exist already)
  csv_file_path = initialize_csv_file(outputCsvDir)  
  
  ouputPngDir = workingDir+"/www/pointFiltering_png/"
  os.makedirs(ouputPngDir, exist_ok=True)
  
  for file in glob.glob(inputDir + '*.tif'):
    print(file)
    centroids, output_file = edge(file, ouputTifDir, int(n), int(m))
    # add centroids to the csv file that has been initialized previously
    append_to_csv_file(csv_file_path, centroids, os.path.basename(file), "point_filtering")

  #fileName="D:/distribution_digitizer//data/output/align_maps\2_0060map_1_0.tif"
  #edge(fileName, ouputDir, 5, 9)
