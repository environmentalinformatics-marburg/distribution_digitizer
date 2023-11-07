# import libraries
import os
import numpy as np
from PIL import Image
import cv2
import glob
import csv

# circle detection
def circle_detection(tiffile, outdir, blur, min_dist, threshold_edge, threshold_circles, min_radius, max_radius):
    img = np.array(Image.open(tiffile))
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    gray_blur = cv2.GaussianBlur(gray, (blur, blur), 0)

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

    centroids = []
    
    if circles is not None:
        circles = np.uint16(np.around(circles))
        for circle in circles[0, :]:
            cv2.circle(img, (circle[0], circle[1]), circle[2], (0, 0, 255), 2)

            centroid_x = int(circle[0])
            centroid_y = -int(circle[1])
            centroids.append((centroid_x, centroid_y))
            cv2.circle(img, (centroid_x, -centroid_y), 1, (139, 0, 0), -1)

    output_file = os.path.join(outdir, os.path.basename(tiffile))
    Image.fromarray(img, 'RGB').save(output_file)

    return centroids, output_file

# function for calling these functions
def mainCircleDetection(workingDir, blur, min_dist, threshold_edge, threshold_circles, min_radius, max_radius):
    inputDir = workingDir + "/data/output/maps/align/"
    outputTifDir = workingDir + "/data/output/maps/circleDetection/"
    os.makedirs(outputTifDir, exist_ok=True)

    outputCsvDir = workingDir + "/data/output/maps/csv_files/"
    os.makedirs(outputCsvDir, exist_ok=True)
    csv_file_path = initialize_csv_file(outputCsvDir)

    ouputPngDir = workingDir + "/www/CircleDetection_png/"
    os.makedirs(ouputPngDir, exist_ok=True)

    for file in glob.glob(inputDir + '*.tif'):
        print(file)
        centroids, output_file = circle_detection(file, outputTifDir, blur, min_dist, threshold_edge, threshold_circles, min_radius, max_radius)
        append_to_csv_file(csv_file_path, centroids, os.path.basename(file), "circle_detection")

#if __name__ == "__main__":
#    working_directory = "path_to_working_directory"
#    blur = 5
#    min_dist = 1
#    threshold_edge = 100
#    threshold_circles = 21
#    min_radius = 3
#    max_radius = 12
#    mainCircleDetection(working_directory, blur, min_dist, threshold_edge, threshold_circles, min_radius, max_radius)
