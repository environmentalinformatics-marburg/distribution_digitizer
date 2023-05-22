import numpy as np
import cv2
import numpy as np
from osgeo import gdal
import csv
import os
import glob

def geopointextract(tiffile, geofile,  outputcsv, n):
  #workingDir="D:/distribution_digitizer/"
  ##inputdir = workingDir + "/data/output/georeferencing/georeferenced2_0060map_1_0.tif"
 # outputcsv = workingDir + "/data/output/mask/georecords.csv"
  #geofile = workingDir + "data/input/templates/geopoints/gcp_point_map1.points"
 # n=5
  fields =[ "Filename", 'Centroid X', 'Centroid Y']
  filename = outputcsv
  img = gdal.Open(tiffile)
  geoimg = gdal.Open(geofile)
  gt = geoimg.GetGeoTransform()
  img=np.array(img.GetRasterBand(1).ReadAsArray())
  ret, thresh = cv2.threshold(img,120,255,cv2.THRESH_TOZERO_INV)
  kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(n,n))
  opening = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel, iterations=3)
  contours, hierarchy = cv2.findContours(opening, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
  with open(filename, 'a', newline='') as csvfile:   
  # creating a csv writer object   
    csvwriter = csv.writer(csvfile)   
# writing the fields   
    csvwriter.writerow(fields)   
    for c in contours:
  # calculate moments for each contour
     M = cv2.moments(c)
  # calculate x,y coordinate of center
     cX = int(M["m10"] / M["m00"])
     cY = int(M["m01"] / M["m00"])
     x_pixel = cX
     y_line = cY
     x_geo = gt[0] + x_pixel * gt[1] + y_line * gt[2]
     y_geo = gt[3] + x_pixel * gt[4] + y_line * gt[5]
     rows = [[tiffile, x_geo, y_geo]] 
# writing the data rows   
     csvwriter.writerows(rows)
     
workingDir="D:/distribution_digitizer/"
def maingeopointextract(workingDir,n):
  inputdir = workingDir + "/data/output/georeferencing/"
  outputcsv = workingDir + "/data/output/mask/georecords.csv"
  geofiledir = workingDir + "data/output/templates/geopoints/"
  for tiffile in glob.glob(inputdir +'*.tif'): 
   for geofile in glob.glob(geofiledir + '*.tif'):
        geopointextract(tiffile, geofile, outputcsv, n)

