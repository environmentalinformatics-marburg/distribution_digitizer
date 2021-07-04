import PIL
import numpy as np
import cv2
import os
import glob
from PIL import Image


def geomask(file, outputdir, n):
#create black and white masks 
  print("here")
  image = np.array(PIL.Image.open(file))
  gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
  ret, thresh = cv2.threshold(gray,120,255,cv2.THRESH_TOZERO_INV)
  kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5,5))
  opening = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel, iterations=3)
  (thr, blackAndWhiteImage) = cv2.threshold(opening, 0, 255, cv2.THRESH_BINARY)
  orig_fn ='/content/drive/MyDrive/Output/new_mask1.tif'
  PIL.Image.fromarray(blackAndWhiteImage).save(os.path.join(outputdir, os.path.basename(file)))


def maingeomask(workingDir, n):
  inputdir = workingDir+"data/output/classification/filtering/"
  outputdir = workingDir+"data/output/mask/non_georeferenced_masks/"
  os.makedirs(outputdir, exist_ok=True)
  for file in glob.glob(inputdir + '*.tif'):
        print("hi")
        geomask(file, outputdir, n)
