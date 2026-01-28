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
        print("An error occurred in masking geomask:", e)
  
  
def mainGeomask(workingDir, outDir, n, nMapTypes=1):
    """
    Generate geographical masks for all TIFF files in the input directory.
    Processes multiple map types (1, 2, ...).

    Args:
        workingDir (str): Working directory containing input and output directories.
        outDir (str): Output directory (e.g., output_2025-09-26_13-16-11).
        n (int): Size parameter for the morphological structuring element.
        nMapTypes (int): Number of map types (1 or 2). Used to limit processing.
    """
    try:
        # --- Finde alle map-type Ordner ---
        map_type_dirs = []
        for name in os.listdir(outDir):
            full = os.path.join(outDir, name)
            if os.path.isdir(full) and name.isdigit():
                map_type_dirs.append(full)

        # --- Nur die ersten nMapTypes verarbeiten ---
        map_type_dirs = map_type_dirs[:int(nMapTypes)]

        if not map_type_dirs:
            print("⚠️ No map-type folders found in output/")
            return

        # --- Jeden map-type Ordner einzeln verarbeiten ---
        for map_dir in map_type_dirs:
            map_type = os.path.basename(map_dir)
            print(f"\n=== Processing map type folder: {map_type} ===")

            # Input und Output für diesen Typ
            inputDir = os.path.join(map_dir, "maps", "align")
            outputDir = os.path.join(map_dir, "masking")

            # Erstelle den Output-Ordner
            os.makedirs(outputDir, exist_ok=True)

            # --- Alle TIFs verarbeiten ---
            for file in glob.glob(os.path.join(inputDir, "*.tif")):
                print(f"Processing: {os.path.basename(file)}")
                geomask(file, outputDir, n)

        print("\n✓ Masking completed for all map types.")

    except Exception as e:
        print("An error occurred in mainGeomask:", e)
