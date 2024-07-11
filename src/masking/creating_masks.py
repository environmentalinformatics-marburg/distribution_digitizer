import PIL
import numpy as np
import cv2
import os
import glob
from PIL import Image


def geomask(file, outputdir, n):
  try:
    #create black and white masks 
    image = np.array(PIL.Image.open(file))
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    ret, thresh = cv2.threshold(gray,120,255,cv2.THRESH_TOZERO_INV)
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (n,n))
    opening = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel, iterations=3)
    (thr, blackAndWhiteImage) = cv2.threshold(opening, 0, 255, cv2.THRESH_BINARY)
    orig_fn ='/content/drive/MyDrive/Output/new_mask1.tif'
    PIL.Image.fromarray(blackAndWhiteImage).save(os.path.join(outputdir, os.path.basename(file)))
  except Exception as e:
        print("An error occurred in geomask:", e)


# workingDir="D:/distribution_digitizer/"
# outDir="D:/test/output_2024-03-14_05-40-48/output_2024-03-14_05-54-08/"
def mainGeomaskB(workingDir, outDir, n):
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
    inputDir = outDir+"/maps/pointFiltering/"
    outputDir = outDir+"/masking_black/"
  
    # Create the output directory if it doesn't exist
    os.makedirs(outputDir, exist_ok=True)
  
    # Loop through TIFF files in the input directory
    for file in glob.glob(inputDir + '*.tif'):
      print(file)
      # call a geo-mask using the geomask function
      geomask(file, outputDir, n)
      
  except Exception as e:
        print("An error occurred in masking_black:", e)
  


def create_mask_from_csv(tiffile, csvfile, output_dir):
    # Load the TIF image to get its dimensions
    original_image = Image.open(tiffile)
    width, height = original_image.size
    
    # Create a black image (mask) with the same dimensions
    mask = np.zeros((height, width), dtype=np.uint8)

    # Read the CSV file and extract the points
    with open(csvfile, 'r') as file:
        reader = csv.DictReader(file)
        for row in reader:
            x = int(row['X_WGS84'])
            y = int(row['Y_WGS84'])
            # Draw a white point on the mask at the specified coordinates
            mask[y, x] = 255  # Assuming the coordinates are (x, y)

    # Create the output file path
    output_file = os.path.join(output_dir, os.path.basename(tiffile))
    
    # Save the mask as a TIF file
    mask_image = Image.fromarray(mask)
    mask_image.save(output_file)
