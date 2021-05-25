import cv2
import PIL
from PIL import Image
import os.path
import glob
import numpy as np 


#Edge and Contour Detection
def edge(tiffile, outdir, n, m):
  # Load image, grayscale, Otsu's threshold
  print(tiffile)
  
  ig = np.array(PIL.Image.open(tiffile))
  gray = cv2.cvtColor(ig, cv2.COLOR_BGR2GRAY)
  gray = cv2.GaussianBlur(gray,(m,m),0)
  ret, thresh = cv2.threshold(gray,120,255,cv2.THRESH_TOZERO_INV)
  # Morph open using elliptical shaped kernel
  kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (n,n))
  opening = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel, iterations=3)
 
#m = int(input(' Enter the value of Guassian filter or press enter for 9' )or 9)
#n=int(input(' Enter the value of kernel filter or press enter for 5' )or 5)
#input_tif = str(input("Enter the Input directory /..../"))
#for tiffile in glob.glob(input_tif + "*.tif"):
 #   edge(tiffile,input_tif,n,m)
 
def mainpixelclassification(workingDir,  n, m):
  inputdir = workingDir+"/data/output/"
  ouputdir = workingDir+"/data/pixelc/"
  for file in glob.glob(inputdir + '*.tif'):
        edge(file, ouputdir, n, m)
