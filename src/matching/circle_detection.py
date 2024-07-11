import os
import numpy as np
from PIL import Image
import cv2
import glob
import csv

# Circle detection function
def circle_detection(tiffile, outdir, blur, min_dist, threshold_edge, threshold_circles, min_radius, max_radius, csv_file_path):
    """
    Detect circles in a TIFF file using Hough Circle Transform.

    Args:
    - tiffile: Input TIFF file path
    - outdir: Output directory to save modified images
    - blur: Gaussian blur parameter
    - min_dist: Minimum distance between detected circles
    - threshold_edge: Canny edge detection threshold
    - threshold_circles: Accumulator threshold for circle detection
    - min_radius: Minimum circle radius
    - max_radius: Maximum circle radius
    - csv_file_path: Path to the CSV file

    Returns:
    - centroids: List of centroid coordinates (x, y) with their colors
    - output_file: File path of the saved modified image
    """
    try:
        # Load TIFF file containing the map and convert it to grayscale
        img = np.array(Image.open(tiffile))
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        # Apply Gaussian blur to reduce noise
        gray_blur = cv2.GaussianBlur(gray, (blur, blur), 0)
        
        # Detect circles using Hough Circle Transform
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
        
        centroids = []  # Initialize a list to store centroid coordinates and colors
        
        # Define color ranges in BGR
        color_ranges = {
            'red': ((0, 0, 150), (100, 100, 255)),
            'blue': ((150, 0, 0), (255, 100, 100)),
            'green': ((0, 150, 0), (100, 255, 100)),
            'orange': ((238,154,0), (255,165,0))
        }
        
        color_map = {
            'red': '#FF0000',
            'blue': '#0000FF',
            'green': '#00FF00',
            'orange': '#FFa500',
            'purple': '#9370DB'
        }
        
        # Draw circles around the detected contours and mark the centroid position with a red dot
        if circles is not None:
            circles = np.uint16(np.around(circles))
            for circle in circles[0, :]:
                # Calculate centroid coordinates
                centroid_x = int(circle[0])
                centroid_y = int(circle[1])
                
                # Extract the circle region for color detection
                mask = np.zeros(gray.shape, dtype=np.uint8)
                cv2.circle(mask, (centroid_x, centroid_y), circle[2], 255, thickness=-1)
                mean_color = cv2.mean(img, mask=mask)[:3]
                
                # Determine the color of the circle
                color_detected = 'purple'
                for color_name, (lower, upper) in color_ranges.items():
                    if all(lower[i] <= mean_color[i] <= upper[i] for i in range(3)):
                        color_detected = color_name
                        break
                
                color_hex = color_map[color_detected]
                
                # Draw the circle with the detected color
                bgr_color = tuple(int(color_hex[i:i+2], 16) for i in (5, 3, 1))
                cv2.circle(img, (centroid_x, centroid_y), circle[2], bgr_color, 2)
                
                # Append centroid coordinates and color to the list
                centroids.append((centroid_x, centroid_y, color_hex))
        
        # Define output filename
        output_file = os.path.join(outdir, os.path.basename(tiffile))
        
        # Save the modified TIFF file
        Image.fromarray(img, 'RGB').save(output_file)
        
        return centroids, output_file
    
    except Exception as e:
        print(f"An error occurred in circle_detection: {e}")
        return [], ""

# Append centroids to CSV file
def append_to_csv(csv_file_path, centroids, filename, method, georef):
    """
    Append centroid coordinates to an existing CSV file.

    Args:
    - csv_file_path: File path of the CSV file
    - centroids: List of centroid coordinates (x, y) with their colors
    - filename: Input filename
    - method: Detection method ("circle_detection")
    - georef: Georeferenced status (0 = not georeferenced; 1 = georeferenced)

    Returns:
    - None
    """
    try:
        existing_centroids = set()
        with open(csv_file_path, 'r') as file:
            reader = csv.DictReader(file)
            for row in reader:
                existing_centroids.add((int(row['X_WGS84']), int(row['Y_WGS84']), row['color']))
        
        # Open the file in append mode and add the new lines
        with open(csv_file_path, 'a', newline='') as file:
            writer = csv.writer(file)
            for centroid in centroids:
                x, y, color = centroid
                double = "true" if (x, y, color) in existing_centroids else "false"
                writer.writerow([filename, method, x, y, color, len(centroids), georef, double])
    
    except Exception as e:
        print(f"An error occurred in append_to_csv: {e}")

# Main function for circle detection
def mainCircleDetection(workingDir, outDir, blur, min_dist, threshold_edge, threshold_circles, min_radius, max_radius):
    """
    Main function to perform circle detection on TIFF images using Hough Circle Transform.
    Saves modified images with circles drawn and appends centroid coordinates to CSV files.

    Args:
    - workingDir: Directory containing input TIFF images
    - outDir: Output directory to save modified images and CSV files
    - blur: Gaussian blur parameter
    - min_dist: Minimum distance between detected circles
    - threshold_edge: Canny edge detection threshold
    - threshold_circles: Accumulator threshold for circle detection
    - min_radius: Minimum circle radius
    - max_radius: Maximum circle radius

    Returns:
    - None
    """
    try:
        outputTifDir = os.path.join(outDir, "maps/circleDetection/")
        inputDir = os.path.join(outDir, "maps/pointFiltering/")
        outputCsvDir = os.path.join(outDir, "maps/csvFiles/")
        
        os.makedirs(outputTifDir, exist_ok=True)
        os.makedirs(outputCsvDir, exist_ok=True)
        
        # Initialize CSV file for storing the coordinates (if the file does not exist already)
        csv_file_path = os.path.join(outputCsvDir, "coordinats.csv")
        if not os.path.exists(csv_file_path):
            with open(csv_file_path, 'w', newline='') as file:
                writer = csv.writer(file)
                writer.writerow(['File', 'Detection method', 'X_WGS84', 'Y_WGS84', 'color', 'number_points', 'georef', 'double'])
        
        for file in glob.glob(inputDir + '*.tif'):
            print(file)
            # Call the circle_detection function and store the centroid list
            centroids, output_file = circle_detection(file, outputTifDir, blur, min_dist, threshold_edge, threshold_circles, min_radius, max_radius, csv_file_path)
            # Add centroids to the CSV file that has been initialized previously
            append_to_csv(csv_file_path, centroids, os.path.basename(file), "circle_detection", 0)
    
    except Exception as e:
        print(f"An error occurred in mainCircleDetection: {e}")

# Example usage:
# mainCircleDetection("input_directory", "output_directory", blur, min_dist, threshold_edge, threshold_circles, min_radius, max_radius)
