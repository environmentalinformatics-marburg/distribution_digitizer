import cv2
import PIL
from PIL import Image
import os.path
import glob
import numpy as np 
import csv  
import time
from pytesseract import Output
import pytesseract
import argparse
import math
import statistics
import os


def cropImage(sourceImage, outdir, x, y, w, h, i):
    
    img = np.array(PIL.Image.open(sourceImage))

    imgc = img.copy()
    y=y+h+30
    
    #w=w+160
    thresholded=((imgc>120)*255).astype(np.uint8)
    #Image.fromarray(thresholded).show()
    cropedImageSpecies = outdir + '_' +os.path.basename(sourceImage).rsplit('.', 1)[0] + i + '.tif'
    print(cropedImageSpecies)
    cv2.imwrite(cropedImageSpecies, thresholded[ y:(y+150), x:(x + w),:])
    
    # Save
    #Image.fromarray(thresholded).save('result.png')
    # Adding custom options
    return cropedImageSpecies
  
  
#workingDir = "D:/distribution_digitizer/"
#mainTemplateMatching(workingDir, 0.99)

#cropSpacies("D:/distribution_digitizer/data/input/pages/0060.tif")

def cropSpacies(workingDir, pathToPage, pathToMap, x, y, w, h):
  
  # pathToPage = "D:/distribution_digitizer/data/input/pages/0060.tif"
  # outputdir = "D:/distribution_digitizer/data/input_align/"  
  # load the input image, convert it from BGR to RGB channel ordering,
  # and use Tesseract to localize each area of text in the input image
  image = cv2.imread(pathToPage)
  rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
  #cv2.imshow('img', rgb)

  d = pytesseract.image_to_data(rgb, output_type=Output.DICT)
  n_boxes = len(d['level'])
  species = ''
   
  for i in range(n_boxes-2):
    (x1, y1, w1, h1, c1) = (d['left'][i], d['top'][i], d['width'][i], d['height'][i], d['conf'][i])
    text=d['text'][i].lstrip()
    pre = d['text'][i+1].lstrip()
    if (text == 'distribution'):
      if (pre == 'of'):
        if( abs(y1 - (y+h)) < h ):
          #print(pathToPage)
          #print(pathToCsv)
          species = species + "_" + (d['text'][i+2].lstrip())
          #print(str(x) , ",", str(x1))
          #print(str(y+h) , ",", str(y1))
          
    if (text == 'locality'):
      if (pre == 'of'):
        if( abs(y1 - (y+h)) < h ):
          #print(pathToPage)
          #print(pathToCsv)
          species = species + "_" + (d['text'][i+2].lstrip())
          #print(str(x) , ",", str(x1))
          #print(str(y+h) , ",", str(y1))
     
  if( species != ''):
    # rename the align maps
    # pathToMap = "D:/distribution_digitizer/data/output/maps/matching/27_0060map_1_0.tif"
    # workingDir = "D:/distribution_digitizer/"
    alignMap = workingDir + "/data/output/maps/align/" + os.path.basename(pathToMap)
    mapNewName = workingDir + "/data/output/maps/align/" + os.path.basename(pathToMap).rsplit('.', 1)[0]  + "_" + species + ".tif"
    if os.path.isfile(alignMap):
      os.rename(alignMap, mapNewName)
      print (alignMap)
    else:
      print ("File not exist")
     
    # rename the orign maps
    #if os.path.isfile(pathToMap):
      #os.rename(pathToMap, mapNewName)
     # mapNewName = pathToMap.rsplit('.', 1)[0]  + "_" + species + ".tif"
    #  os.rename(pathToMap, mapNewName)
     # print(mapNewName)
   # else:
     # print ("File not exist")
    return species
     
  #print("End")  


