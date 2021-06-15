# -*- coding: utf-8 -*-
"""
Created on Fri Jun 11 16:05:44 2021

@author: venkates
"""
import cv2
import PIL
from PIL import Image
import os.path
import glob
import numpy as np 

def pixelmatch(tiffile, file, outputpcdir, pixel_threshold):
  img = np.array(PIL.Image.open(tiffile))
  tmp = np.array(PIL.Image.open(file))
  w, h, c = tmp.shape
  res = cv2.matchTemplate(img, tmp, cv2.TM_CCOEFF_NORMED)
# Adjust this threshold value to suit you, you may need some trial runs (critical!)
  threshold = pixel_threshold
  loc = np.where(res >= threshold)
# create empty lists to append the coord of the
  lspoint = []
  lspoint2 =[]
  font = cv2.FONT_HERSHEY_SIMPLEX
  for pt in zip(*loc[::-1]):
    # check that the coords are not already in the list, if they are then skip the match
     if pt[0] not in lspoint and pt[1] not in lspoint2:
         # draw a blue boundary around a match
          rect = cv2.rectangle(img, pt, (pt[0] + h, pt[1] + w), (0, 0, 255), 3)
          for i in range(((pt[0])-9), ((pt[0])+9), 1):
			## append the x cooord
                 lspoint.append(i)
          for k in range(((pt[1])-9), ((pt[1])+9), 1):
			## append the y coord
                 lspoint.append(k)
     else:
           continue   
  PIL.Image.fromarray(img, 'RGB').save(os.path.join(outputpcdir, os.path.basename(tiffile)))

def mainpixelmatching(workingDir, pixel_threshold):
  pixel_templates = workingDir+"/data/templates/pixels/"
  inputpcdir = workingDir + "/data/output/"
  outputpcdir = workingDir + "/data/output/pixeltemp/"
  for tiffile in glob.glob(inputpcdir + '*.tif'):
    for file in glob.glob(pixel_templates + '*.tif'): 
        pixelmatch(tiffile, file, outputpcdir, pixel_threshold)
