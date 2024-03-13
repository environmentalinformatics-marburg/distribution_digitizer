# -*- coding: utf-8 -*-
"""
Description: This script edits maps and creates geo-masked images.
"""
__author__ = "Spaska Forteva"
__date__ = "24. August 2022"

import PIL
import numpy as np
import cv2
import os
import glob
from PIL import Image


def geomask(file, outputdir, n):
  """
  Generate a geo-masked image by applying a series of image processing operations.

  Args:
      file (str): Path to the input image file.
      outputdir (str): Directory where the output image will be saved.
      n (int): Size parameter for the morphological structuring element.

  Returns:
      None
  """
  try:
      # Create black and white masks
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
      
      # Save the processed image
      PIL.Image.fromarray(blackAndWhiteImage).save(os.path.join(outputdir, os.path.basename(file)))
      
      # Get coordinates of non-black pixels
      indices = np.where(blackAndWhiteImage!= [0])
      coordinates = zip(indices[0], indices[1])
      print(coordinates)

  except Exception as e:
        print("An error occurred in geomask:", e)
  
  
def mainGeomask(workingDir, outDir, n):
  """
  Generate geographical masks for all TIFF files in the input directory.

  Args:
      workingDir (str): Working directory containing input and output directories.
      n (int): Size parameter for the morphological structuring element.

  Returns:
      None
  """
    
  try:
      # Define input and output directories
      inputDir = outDir+"/maps/align/"
      outputDir = outDir+"/masking/"
      
      # Create the output directory if it doesn't exist
      os.makedirs(outputDir, exist_ok=True)
      
      # Loop through TIFF files in the input directory
      for file in glob.glob(inputDir + '*.tif'):
        print(file)
        # call a geo-mask using the geomask function
        geomask(file, outputDir, n)
        
  except Exception as e:
        print("An error occurred in mainGeomask:", e)
