# import libraries
import numpy as np
import PIL
from PIL import Image
import cv2
import glob

"""
Circle detection method for finding white circles with dark edges using cv2.HoughCircles

Argument description:
tiffile:            input tiffile
outdir:             directory to store the output
blur:               value for Gaussian filter
min_dist:           minimum (expected) distance between centers of circles.
threshold_edge:     threshold for circle edge detection.
threshold_circles:  threshold for circle center detection. Low values will lead to many detections.
min_radius:         minimum (expected) radius of circles to detect
max_radius:         maximum (expected) radius of circles to detect
"""

# define function
def circle_detection(tiffile, outdir, blur, min_dist, threshold_edge, threshold_circles, min_radius, max_radius):
    
    # open fiffile containing the map and convert it to grayscale
    img = np.array(PIL.Image.open(tiffile))
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    # apply Gaussian blur to reduce noise
    gray_blur = cv2.GaussianBlur(gray, (blur, blur), 0)
    
    # detect circles using Hough Circle Transform
    circles = cv2.HoughCircles(
        gray_blur,
        cv2.HOUGH_GRADIENT,
        dp=1,
        minDist=min_dist,
        param1=threshold_edge,
        param2=threshold_circles,
        minRadius=min_radius,
        maxRadius=max_radius
    )
    
    # draw blue circles around the detected contours
    if circles is not None:
        circles = np.uint16(np.around(circles))
        for circle in circles[0, :]:
            # Draw the outer circle
            cv2.circle(img, (circle[0], circle[1]), circle[2], (0, 0, 255), 2)
    
    PIL.Image.fromarray(img, 'RGB').save(os.path.join(outdir, os.path.basename(tiffile)))
# end of function


"""
Application:
  
The following settings lead to the best detections so far for the map with the white circles.
I suggest to define them as default values in the App.

blur = 5
min_dist = 1
threshold_edge = 100
threshold_circles = 21
min_radius = 3
max_radius = 12
"""

# Apply the function
def mainCircleDetection(workingDir, blur, min_dist, threshold_edge, threshold_circles, min_radius, max_radius):
  inputDir = workingDir+"/data/output/maps/align/"
  ouputTifDir = workingDir+"/data/output/maps/circleDetection/"
  os.makedirs(ouputTifDir, exist_ok=True)
  print("inputDir = " + inputDir)
  print("ouputTifDir = " + ouputTifDir)
  print("blur = " + str(blur))
  print("min_dist = " + str(min_dist))
  print("threshold_edge = " + str(threshold_edge))
  print("threshold_circles = " + str(threshold_circles))
  print("min_radius = " + str(min_radius))
  print("max_radius = " + str(min_radius))
  
  ouputPngDir = workingDir+"/www/CircleDetection_png/"
  os.makedirs(ouputPngDir, exist_ok=True)
  
  for file in glob.glob(inputDir + '*.tif'):
    print(file)
    circle_detection(file, ouputTifDir, blur, min_dist, threshold_edge, threshold_circles, min_radius, max_radius)

