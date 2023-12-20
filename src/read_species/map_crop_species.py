# Author: Spaska Forteva
# Date: 18.12.2023
# Description: This script contains functions for processing images, extracting information using Tesseract OCR,
# and cropping specified regions from input images.

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


def cropImage(source_image, outdir, x, y, w, h, i):
    
    """
    Crop the specified region from the input image and save it.

    Args:
    source_image (str): Path to the input image.
    outdir (str): Output directory for saving the cropped image.
    x, y, w, h (int): Coordinates and dimensions of the region to be cropped.
    i (str): Additional identifier for the output filename.

    Returns:
    str: Path to the saved cropped image.
    """
    img = np.array(PIL.Image.open(source_image))

    imgc = img.copy()
    y=y+h+30
    
    #w=w+160
    thresholded=((imgc>120)*255).astype(np.uint8)
    #Image.fromarray(thresholded).show()
    cropedImageSpecies = outdir + '_' +os.path.basename(source_image).rsplit('.', 1)[0] + i + '.tif'
    print(cropedImageSpecies)
    cv2.imwrite(cropedImageSpecies, thresholded[ y:(y+150), x:(x + w),:])
    
    # Save
    #Image.fromarray(thresholded).save('result.png')
    # Adding custom options
    return cropedImageSpecies
  
  
#working_dir = "D:/distribution_digitizer/"
#mainTemplateMatching(working_dir, 0.99)

#crop_species("D:/distribution_digitizer/data/input/pages/0060.tif")

def crop_species(working_dir, path_to_page, path_to_map, x, y, w, h):
  
  # path_to_page = "D:/distribution_digitizer/data/input/pages/0060.tif"
  # outputdir = "D:/distribution_digitizer/data/input_align/"  
  # load the input image, convert it from BGR to RGB channel ordering,
  # and use Tesseract to localize each area of text in the input image
  image = cv2.imread(path_to_page)
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
          #print(path_to_page)
          #print(pathToCsv)
          species = species + "_" + (d['text'][i+2].lstrip())
          #print(str(x) , ",", str(x1))
          #print(str(y+h) , ",", str(y1))
          
    if (text == 'locality'):
      if (pre == 'of'):
        if( abs(y1 - (y+h)) < h ):
          #print(path_to_page)
          #print(pathToCsv)
          species = species + "_" + (d['text'][i+2].lstrip())
          #print(str(x) , ",", str(x1))
          #print(str(y+h) , ",", str(y1))
  
  output_png= working_dir + "/www/cropped_png/"
  os.makedirs(output_png, exist_ok=True)    
  if( species != ''):
    # rename the align maps
    # path_to_map = "D:/distribution_digitizer/data/output/maps/matching/27_0060map_1_0.tif"
    # working_dir = "D:/distribution_digitizer/"
    align_map = working_dir + "/data/output/maps/align/" + os.path.basename(path_to_map)
    map_new_name = working_dir + "/data/output/maps/align/" + os.path.basename(path_to_map).rsplit('.', 1)[0]  + "_" + species + ".tif"
    if os.path.isfile(align_map):
      os.rename(align_map, map_new_name)
      print (align_map)
    else:
      print ("File not exist")
     
    # rename the orign maps
    #if os.path.isfile(path_to_map):
      #os.rename(path_to_map, map_new_name)
     # map_new_name = path_to_map.rsplit('.', 1)[0]  + "_" + species + ".tif"
    #  os.rename(path_to_map, map_new_name)
     # print(map_new_name)
   # else:
     # print ("File not exist")
    return species
     
  #print("End")  


