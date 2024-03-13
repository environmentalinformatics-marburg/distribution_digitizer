# ============================================================
# Script Author: [Spaska Forteva]
# Created On: 2023-11-18
# ============================================================
# Description: This script contains functions for processing images, extracting information using Tesseract OCR,
# and cropping specified regions from input images.

# Required libraries
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
import re

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
    cropedImagespecie = outdir + '_' +os.path.basename(source_image).rsplit('.', 1)[0] + i + '.tif'
    #print(cropedImagespecie)
    cv2.imwrite(cropedImagespecie, thresholded[ y:(y+150), x:(x + w),:])
    
    # Save
    #Image.fromarray(thresholded).save('result.png')
    # Adding custom options
    return cropedImagespecie
  
  
#working_dir = "D:/distribution_digitizer/"
#mainTemplateMatching(working_dir, 0.99)

#crop_specie("D:/distribution_digitizer/data/input/pages/0060.tif")
def crop_specie(working_dir, out_dir, path_to_page, path_to_map, y, h):
  try:
      image = cv2.imread(path_to_page)
      rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
      
      legend1 = 'distribution'
      legend2 = 'locality'
      d = pytesseract.image_to_data(rgb, output_type=Output.DICT)
      n_boxes = len(d['level'])
      specie = ''
      double_specie = ''

      for i in range(n_boxes-2):
          (x1, y1, w1, h1, c1) = (d['left'][i], d['top'][i], d['width'][i], d['height'][i], d['conf'][i])
          text = d['text'][i].lstrip()
          
          pre = d['text'][i+1].lstrip()
          if (text == legend1 or text == legend2):
              
              if (pre == 'of'):
                  if( abs(y1 - (y+h)) < h ):
                      if(double_specie != d['text'][i+2].lstrip()):
                          double_specie = (d['text'][i+2].lstrip())
                          if text == legend1:
                              specie = specie + "_" + (d['text'][i+2].lstrip()) + legend1
                          else:
                              specie = specie + "_" + (d['text'][i+2].lstrip()) + legend2
                      else:
                          continue
      
      specie = re.sub(r"[^\w\s]", "", specie)
      
      if (specie == ''):
          specie = 'notfounddistribution'
      
      align_map = ""
      map_new_name = ""
      
      if(os.path.exists(out_dir)):
          if out_dir.endswith("/"):
            out_dir = out_dir.rstrip("/")
          align_map = os.path.join(out_dir, "maps/align/", os.path.basename(path_to_map))
          map_new_name = os.path.join(out_dir, "maps/align/", os.path.basename(path_to_map).rsplit('.', 1)[0]  + "_" + specie + ".tif")
         
      else:
          if working_dir.endswith("/"):
            working_dir = working_dir.rstrip("/")
          align_map = os.path.join(working_dir, "data/output/maps/align/", os.path.basename(path_to_map))
          map_new_name = os.path.join(working_dir, "data/output/maps/align/", os.path.basename(path_to_map).rsplit('.', 1)[0]  + "_" + specie + ".tif")
        
      
      if os.path.isfile(align_map):
          os.rename(align_map, map_new_name)
      else:
          raise FileNotFoundError("File not found: " + align_map)
      
      return specie
  
  except Exception as e:
      return str(e)
  #print("End")  
