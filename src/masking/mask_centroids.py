"""
File: mask_centroids.py
Author: Kai Richter
Date: 2023-11-10

Description: 
Script for masking the red marked pixels representing centroids detected by Circle Detection and Point Filtering. 

function 'mask_centroids': The red pixels represnting the centroids are masked. The output is the input for georeferencing.

function 'MainMaskCentroids': Functions for looping over all files that should be processed. 
"""


### Mask drawn centroids

def mask_centroids(tiffile, outdir):
  try:
    img = np.array(Image.open(tiffile))
    
    # Define the exact red color used in circle detection
    red_color_lower = np.array([139, 0, 0], dtype=np.uint8)
    red_color_upper = np.array([139, 0, 0], dtype=np.uint8)
    
    # Create a binary mask by filtering out only the exact red color range
    mask = cv2.inRange(img, red_color_lower, red_color_upper)
    
    # Save the centroid mask as a TIFF file in the specified outdir
    outfile = os.path.basename(tiffile)
    output_filepath = os.path.join(outdir, outfile)
    cv2.imwrite(output_filepath, mask)
    
  except Exception as e:
        print("An error occurred in mainGeomask:", e)




def MainMaskCentroids(workingDir, outDir):
  try:

    # Joining input directory path
    inputDir = os.path.join(outDir, "maps", "circleDetection")
    
    # Joining output directory path
    outputDir = os.path.join(outDir, "masking_black","circleDetection")
    
    # Loop through TIFF files in the input directory
    for file in glob.glob(inputDir + '*.tif'):
        print(file)
        if os.path.exists(file):
             # call the function
            mask_centroids(file, outputDir)
        else:
          print("Die Datei existiert nicht:", output_file_path)
      
   
    # Joining input directory path
    inputDir = os.path.join(outDir, "maps", "pointFiltering")
    
    # Joining output directory path
    outputDir = os.path.join(outDir, "masking_black","pointFiltering")
    # Loop through TIFF files in the input directory
    for file in glob.glob(inputDir + '*.tif'):
        print(file)
        if os.path.exists(file):
             # call the function
            mask_centroids(file, outputDir)
        else:
          print("Die Datei existiert nicht:", output_file_path)
        # call the function
        mask_centroids(file, outputDir)

  except Exception as e:
        print("An error occurred in MainMaskCentroids:", e)


#MainMaskCentroids("C:/Users/user/Documents/MSc_Physische_Geographie/HiWi/distribution_digitizer")
