import PIL
import numpy as np
import cv2
import os
import glob
from PIL import Image

#source_python("D:/distribution_digitizer_students/src/masking.py")


def geomask(file, outputdir, n):
  #create black and white masks
  image = np.array(PIL.Image.open(file))
  grayImage = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
  ret, thresh = cv2.threshold(grayImage,125,255,cv2.THRESH_TOZERO_INV)
  kernel1 = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (n,n))
  #kernel1 = cv2.getStructuringElement(cv2.MORPH_RECT, (n,n))
  #kernel1 = cv2.getStructuringElement(cv2.MORPH_CROSS, (n,n))
  opening = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel1, iterations=3)
  #closing = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel1, iterations=3)
  #gradient = cv2.morphologyEx(img, cv2.MORPH_GRADIENT, kernel1)
  (thr, blackAndWhiteImage) = cv2.threshold(opening, 0, 255, cv2.THRESH_BINARY_INV)
  PIL.Image.fromarray(blackAndWhiteImage).save(os.path.join(outputdir, os.path.basename(file)))
  indices = np.where(blackAndWhiteImage!= [0])
  #coordinates = zip(indices[0], indices[1])
  #print(coordinates)


#maingeomask("D:/Results/", 5)
#workingDir="D:/Results/"
#maingeomask(workingDir, 5)

#workingDir="D:/distribution_digitizer/"
def maingeomask(workingDir, n):
  inputdir = workingDir+"/data/output/maps/align/"
  outputdir = workingDir+"/data/output/masking/"
  os.makedirs(outputdir, exist_ok=True)
  for file in glob.glob(inputdir + '*.tif'):
    geomask(file, outputdir, 5)
