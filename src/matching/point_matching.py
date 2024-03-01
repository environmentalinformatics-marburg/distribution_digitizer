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
import shutil

def pointmatch(tiffile, file, outputpcdir, point_threshold):
  img = np.array(PIL.Image.open(tiffile))
  tmp = np.array(PIL.Image.open(file))
  w, h, c = tmp.shape
  res = cv2.matchTemplate(img, tmp, cv2.TM_CCOEFF_NORMED)
# Adjust this threshold value to suit you, you may need some trial runs (critical!)
  threshold = point_threshold
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
  PIL.Image.fromarray(img, 'RGB').save(os.path.join(outputpcdir , os.path.basename(tiffile)))
  #cv2.imwrite(outputpcdir + os.path.basename(tiffile).rsplit('.', 1)[0] + '.tif',img)
  
  
# only for tests
# workingDir = "D:/distribution_digitizer"

def mainPointMatching(workingDir, outDir, point_threshold):
  print("Points matching:")
  #print(working_dir)
  outputTiffDir = ""
  if(os.path.exists(outDir)):
    if outDir.endswith("/"):
      outputTiffDir = outDir + "maps/align/"
    else:
      outputTiffDir = outDir + "/maps/align/"
  else:
    if working_dir.endswith("/"):
      outputTiffDir = workingDir + "/data/output/maps/align/"
    else: 
      outputTiffDir = workingDir + "/data/output/maps/align/"
  

  #os.makedirs(outputTiffDir, exist_ok=True)
  pointTemplates = workingDir+"/data/input/templates/symbols/"
  
  # create out directory for the result images as png
  ouputPngDir = workingDir+"/www/data/pointMatching_png/"
  #os.makedirs(ouputPngDir, exist_ok=True)
  #print(outputTiffDir)
  #print(ouputPngDir)
  
  for tiffile in glob.glob(outputTiffDir + '*.tif'):
    for file in glob.glob(pointTemplates + '*.tif'): 
        pointmatch(tiffile, file, outputTiffDir, point_threshold)

