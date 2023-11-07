### OLD POINT FILTERING ###

import cv2
import PIL
from PIL import Image
import os.path
import glob
import numpy as np 


#Edge and Contour Detection
def edge(tiffile, outdir, n, m):
  # Load image, grayscale, Otsu's threshold
  ig = np.array(PIL.Image.open(tiffile))
  gray = cv2.cvtColor(ig, cv2.COLOR_BGR2GRAY)
  gray = cv2.GaussianBlur(gray,(m,m),0)
  ret, thresh = cv2.threshold(gray,120,255,cv2.THRESH_TOZERO_INV)
  # Morph open using elliptical shaped kernel
  kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (n,n))
  opening = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel, iterations=3)
  #plot the mask
  contours, hierarchy = cv2.findContours(opening, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
  # draw all contours
  image = cv2.drawContours(ig, contours, -1, (0, 0, 255), 3)
  # show the image with the drawn contours
  PIL.Image.fromarray(image, 'RGB').save(os.path.join(outdir, os.path.basename(tiffile)))
 
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
  
  ouputPngDir = workingDir+"/www/pointFiltering_png/"
  os.makedirs(ouputPngDir, exist_ok=True)
  
  for file in glob.glob(inputDir + '*.tif'):
    print(file)
    edge(file, ouputTifDir, int(n), int(m))
  #fileName="D:/distribution_digitizer//data/output/align_maps\2_0060map_1_0.tif"
  #edge(fileName, ouputDir, 5, 9)
