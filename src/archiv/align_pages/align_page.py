# import the necessary packages
from pytesseract import Output
import pytesseract
import argparse
import cv2
import numpy as np
import math
import statistics
import os
from glob 
import glob

def align_page(pathToImage, outputdir):
  
  #pathToImage = "D:/distribution_digitizer/data/input/0060.tif"
  #outputdir = "D:/distribution_digitizer/data/input_align/"  
  # load the input image, convert it from BGR to RGB channel ordering,
  # and use Tesseract to localize each area of text in the input image
  image = cv2.imread(pathToImage)
  rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
  #cv2.imshow('img', rgb)

  d = pytesseract.image_to_data(rgb, output_type=Output.DICT)
  n_boxes = len(d['level'])
  angleDegrees = []
  
  for i in range(n_boxes):
    (x, y, w, h, c) = (d['left'][i], d['top'][i], d['width'][i], d['height'][i], d['conf'][i])
    text=d['text'][i].lstrip()
    
    if (text!='') & (w > 50) :
      #cv2.rectangle(image, (x, y), (x + w, y + h), (0, 255, 0), 2)
      (x1, y1) = (d['left'][i-1], d['top'][i-1])
      (x2, y2) = (d['left'][i], d['top'][i])
      # cv2.line(image, (x1, y1), (x2, y2), (0, 255, 0), 2)
      #cv2.line(image, (0, 500), (800, 500), (0, 0, 255), 2)
      p1 = (x1, y1)
      #print(p1)
      p2 = (x2, y2)
      #print(p2)
      angle = GetAngle(p1, p2)
      
      if -0.7<angle<0.7:
        angleDegrees.append(GetAngle (p1, p2))
    
  mean = statistics.mean(angleDegrees) 
  print(mean )
  rows,cols,channels= image.shape 
  M = cv2.getRotationMatrix2D((cols/2,rows/2),mean,1) 
  rotate_30 = cv2.warpAffine(image,M,(cols,rows)) 
  cv2.line(rotate_30, (0, 500), (1800, 500), (0, 0, 255), 2)
  cv2.line(rotate_30, (0, 2500), (1800, 2500), (0, 0, 255), 2)
  cv2.line(rotate_30, (0, 4500), (1800, 4500), (0, 0, 255), 2)
  cv2.imwrite(outputdir + str(os.path.basename(pathToImage)), rotate_30)
  #cv2.imwrite(outdir + str(os.path.basename(pathToImage) ))
             

def GetAngle(p1, p2):
  x1, y1 = p1
  x2, y2 = p2
  dX = x2 = x1
  dY = y2 - y1
  rads = math.atan2 (-dY, dX) #wrong for finding angle/declination?
  return math.degrees (rads)
  

workingDir="D:/distribution_digitizer/"

def align(workingDir):
  inputdir = workingDir+"data/input/"
  outputdir = workingDir+"data/input_align/"
  os.makedirs(outputdir, exist_ok=True)
 # print(glob.glob(inputdir + "*.tif"))
 
  #glob.glob(inputdir, *, recursive = False)
  
  for image in glob.glob(inputdir + '*.tif'):
    path = inputdir + os.path.basename(image)
    print(path)
    align_page(path ,outputdir)


#cv2.imshow('img', image)
#cv2.waitKey(0)
