import PIL
import numpy as np
import cv2
import os
import glob
from PIL import Image


def geomask(file, outputdir, n):
#create black and white masks 
  image = np.array(PIL.Image.open(file))
  gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
  ret, thresh = cv2.threshold(gray,120,255,cv2.THRESH_TOZERO_INV)
  kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (n,n))
  opening = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel, iterations=3)
  (thr, blackAndWhiteImage) = cv2.threshold(opening, 0, 255, cv2.THRESH_BINARY)
  orig_fn ='/content/drive/MyDrive/Output/new_mask1.tif'
  PIL.Image.fromarray(blackAndWhiteImage).save(os.path.join(outputdir, os.path.basename(file)))


#workingDir="D:/distribution_digitizer/"
def mainGeomaskB(workingDir, n):
  """
  Generate geographical masks for all TIFF files in the input directory.

  Args:
      workingDir (str): Working directory containing input and output directories.
      n (int): Size parameter for the morphological structuring element.

  Returns:
      None
  """
  # Define input and output directories
  inputDir = workingDir+"/data/output/maps/pointFiltering/"
  outputDir = workingDir+"/data/output/masking_black/"
  
  # Create the output directory if it doesn't exist
  os.makedirs(outputDir, exist_ok=True)
  
  # Define output directories for the list overview
  outputPngDir = workingDir+"/www/masking_black_png/"
  
  # Create the output directory if it doesn't exist
  os.makedirs(outputPngDir, exist_ok=True)
  
  # Loop through TIFF files in the input directory
  for file in glob.glob(inputDir + '*.tif'):
    print(file)
    # call a geo-mask using the geomask function
    geomask(file, outputDir, n)

