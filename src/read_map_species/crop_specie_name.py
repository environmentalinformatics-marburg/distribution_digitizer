import cv2
import PIL
from PIL import Image
import os.path
import glob
import numpy as np 
import csv  
import time


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


