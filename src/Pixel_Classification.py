import cv2
import PIL
from PIL import Image
import os.path
import glob
import numpy as np 
from google.colab.patches import cv2_imshow

#Edge and Contour Detection
def edge(tiffile,outdir,n,m):
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
  
m = int(input(' Enter the value of Guassian filter or press enter for 9' )or 9)
n=int(input(' Enter the value of kernel filter or press enter for 5' )or 5)
input_tif = str(input("Enter the Input directory /..../"))
for tiffile in glob.glob(input_tif + "*.tif"):
    edge(tiffile,input_tif,n,m)
