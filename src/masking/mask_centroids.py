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



def MainMaskCentroids(workingDir):
    ## For output of circle_detection:
    # Define input and output directories
    inputDir = workingDir+"/data/output/maps/circleDetection/"
    outputDir = workingDir+"/data/output/masking_black/circleDetection/"
    
    # Create the output directory if it doesn't exist
    os.makedirs(outputDir, exist_ok=True)
    
    # Loop through TIFF files in the input directory
    for file in glob.glob(inputDir + '*.tif'):
        print(file)
        # call the function
        mask_centroids(file, outputDir)
    
    ## For output of point_filtering:    
    # Define input and output directories
    inputDir = workingDir+"/data/output/maps/pointFiltering/"
    outputDir = workingDir+"/data/output/masking_black/pointFiltering/"
    
    # Create the output directory if it doesn't exist
    os.makedirs(outputDir, exist_ok=True)
    
    # Loop through TIFF files in the input directory
    for file in glob.glob(inputDir + '*.tif'):
        print(file)
        # call the function
        mask_centroids(file, outputDir)

#MainMaskCentroids("C:/Users/user/Documents/MSc_Physische_Geographie/HiWi/distribution_digitizer")
