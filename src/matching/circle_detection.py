"""
File: circle_detection.py
Author: Kai Richter
Last modified on 2023-11-10 by Kai Richter:
  Addition of functions mainRectifying_CD and mainRectifying_PF

Description: 
Script for detecting circles on a tif file.

function 'circle_detection':
First, the file is opened and a blur filter is applied.
After that, the main step is performed by calling the HoughCircles function. The input parameters are set as arguments
respectively in the UI of the digitizer. 
Then, a blue circles are drawn around the detected symbols and the pixels representing the centroids of the circles 
are marked with red color. The positions of the centroids coordinates are saved as well. Lastly, the modiified tif files
are written out and the centroids are returned. 

function 'mainCircleDetection':
This function calls the 'circle_detection' and specifies the input and output directories. The function 'append_to_csv_file'
contained in script 'coords_to_csv.py' is called to store the extracted centroid coordinates in a csv file. 

The output csv file has 5 columns:
  File                input filename
  Detection method    "point_filtering" or "circle_detection". In this case, "circle_detection" will be set. 
  X_WGS84             georeferenced x coordinate
  Y_WGS84             georeferenced y coordinate
  georef              Information if coordinates are georeferenced: 0 = not georeferenced; 1 = georeferenced. 
                      In this case, 0 will be set, as the extracted coordinates are not georeferenced. 
"""


# import libraries
import os
import numpy as np
from PIL import Image
import cv2
import glob
import csv

# circle detection
def circle_detection(tiffile, outdir, blur, min_dist, threshold_edge, threshold_circles, min_radius, max_radius):
    
    # open fiffile containing the map and convert it to grayscale
    img = np.array(Image.open(tiffile))
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    # apply Gaussian blur to reduce noise
    gray_blur = cv2.GaussianBlur(gray, (blur, blur), 0)
    
    # detect circles using Hough Circle Transform
    circles = cv2.HoughCircles(
        gray_blur,
        cv2.HOUGH_GRADIENT,
        dp=1,
        minDist=min_dist,
        param1=threshold_edge,
        param2=threshold_circles,
        minRadius=min_radius,
        maxRadius=max_radius
    )
    
    # initialize a list to store centroid coordinates
    centroids = []
    
    # draw blue circles around the detected contours and mark the centroid position with a red color
    if circles is not None:
        circles = np.uint16(np.around(circles))
        for circle in circles[0, :]:
            # draw the outer circle
            cv2.circle(img, (circle[0], circle[1]), circle[2], (0, 0, 255), 2)
            
            # calculate centroid coordinates
            centroid_x = int(circle[0])
            centroid_y = -int(circle[1])
            
            # append centroid coordinates to the list
            centroids.append((centroid_x, centroid_y))
            
            # draw a small red dot at the centroid position
            cv2.circle(img, (centroid_x, -centroid_y), 1, (139, 0, 0), -1)
    
    # define output filename
    output_file = os.path.join(outdir, os.path.basename(tiffile))
    
    # write out modified tif file
    Image.fromarray(img, 'RGB').save(output_file)

    return centroids, output_file
# End of function



# function for calling circle_detection
def mainCircleDetection(workingDir, outDir, blur, min_dist, threshold_edge, threshold_circles, min_radius, max_radius):
    outputTifDir = ""
    inputDir = ""
    
    if(os.path.exists(outDir)):
      if outDir.endswith("/"):
        inputDir = outDir + "maps/align/"
        outputTifDir = outDir + "maps/circleDetection/"
        outputCsvDir = outDir + "maps/csv_files/"
      else:
        inputDir = outDir + "/maps/align/"
        outputTifDir = outDir + "maps/circleDetection/"
        outputCsvDir = outDir + "/maps/csv_files/"
    else:
      if working_dir.endswith("/"):
        inputDir = working_dir + "data/output/maps/align/"
        outputTifDir = workingDir + "data/output/maps/circleDetection/"
        outputCsvDir = workingDir + "data/output/maps/csv_files/"
      else: 
        inputDir = working_dir + "/data/output/maps/align/"
        outputTifDir = workingDir + "/data/output/maps/circleDetection/"
        outputCsvDir = workingDir + "/data/output/maps/csv_files/"
    
   
    #os.makedirs(outputTifDir, exist_ok=True)

    
    #os.makedirs(outputCsvDir, exist_ok=True)
    # initialize csv file for storing the cooridnates (if the file does not exist already)
    csv_file_path = initialize_csv_file(outputCsvDir, "X", "Y")

    ouputPngDir = workingDir + "/www/CircleDetection_png/"
    #os.makedirs(ouputPngDir, exist_ok=True)

    for file in glob.glob(inputDir + '*.tif'):
        #print(file)
        # call the function and store the centroid list
        centroids, output_file = circle_detection(file, outputTifDir, blur, min_dist, threshold_edge, threshold_circles, min_radius, max_radius)
        # add centroids to the csv file that has been initialized previously
        append_to_csv_file(csv_file_path, centroids, os.path.basename(file), "circle_detection", 0)
