import numpy as np
from PIL import Image
import cv2
import csv
import os
import glob

def get_dominant_color(image, mask):
    """
    Determine the dominant color within the masked area of an image.
    """
    masked_img = cv2.bitwise_and(image, image, mask=mask)
    color_sum = np.sum(masked_img, axis=(0, 1))
    num_pixels = np.sum(mask > 0)
    
    if num_pixels == 0:
        return (0, 0, 0)  # Return black if no pixels

    avg_color = color_sum / num_pixels
    return tuple(avg_color.astype(int))

def color_to_name(color):
    """
    Convert BGR color to a named color category.
    """
    color_ranges = {
        'red': ((0, 0, 150), (100, 100, 255)),
        'blue': ((150, 0, 0), (255, 100, 100)),
        'green': ((0, 150, 0), (100, 255, 100)),
        'orange': ((0, 150, 238), (100, 165, 255)),
        'magenta': ((200, 0, 150), (255, 100, 255))
    }
    
    for color_name, (lower, upper) in color_ranges.items():
        if all(lower[i] <= color[i] <= upper[i] for i in range(3)):
            return color_name

    return 'none'

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
    - centroids: List of centroid coordinates (x, y) with their color distributions
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
        
        centroids = []  # Initialize a list to store centroid coordinates and color distributions
        
        # Define color ranges in BGR
        color_ranges = {
            'red': ((0, 0, 150), (100, 100, 255)),
            'blue': ((150, 0, 0), (255, 100, 100)),
            'green': ((0, 150, 0), (100, 255, 100)),
            'orange': ((0, 150, 238), (100, 165, 255)),
            'magenta': ((200, 0, 150), (255, 100, 255))
        }
        
        # Color map for drawing circles
        color_map = {
            'red': (0, 0, 255),
            'blue': (255, 0, 0),
            'green': (0, 255, 0),
            'orange': (0, 165, 255),
            'magenta': (255, 0, 165)
        }
        
        # Default circle color (for new circles)
        default_color = (255, 0, 165)  # Magenta in BGR
        
        # Draw circles around the detected contours and mark the centroid position with the detected or default color
        if circles is not None:
            circles = np.uint16(np.around(circles))
            for circle in circles[0, :]:
                # Calculate centroid coordinates
                centroid_x = int(circle[0])
                centroid_y = int(circle[1])
                radius = int(circle[2])
                
                # Extract the circle region for color detection
                mask = np.zeros(gray.shape, dtype=np.uint8)
                cv2.circle(mask, (centroid_x, centroid_y), radius, 255, thickness=-1)
                
                # Get dominant color within the circle
                dominant_color = get_dominant_color(img, mask)
                color_name = color_to_name(dominant_color)
                
                # Determine the color to draw the circle
                circle_color = color_map.get(color_name, default_color)
                
                # Draw the circle with the detected color or default color
                cv2.circle(img, (centroid_x, centroid_y), radius, circle_color, 2)
                
                # Append centroid coordinates and color to the list
                centroids.append((
                    centroid_x, centroid_y,
                    circle_color[2], circle_color[1], circle_color[0]  # BGR format for CSV
                ))
        
        # Define output filename
        output_file = os.path.join(outdir, os.path.basename(tiffile))
        
        # Save the modified TIFF file
        Image.fromarray(img).save(output_file)
        
        return centroids, output_file
    
    except Exception as e:
        print(f"An error occurred in circle_detection: {e}")
        return [], ""

def append_to_csv(next_id, csv_file_path, filename, centroids, method, georef):
    """
    Append centroid coordinates to an existing CSV file.

    Args:
    - next_id: Next available ID for CSV entry
    - csv_file_path: File path of the CSV file
    - centroids: List of centroid coordinates (x, y) with their color distributions
    - filename: Input filename
    - method: Detection method ("circle_detection")
    - georef: Georeferenced status (0 = not georeferenced; 1 = georeferenced)

    Returns:
    - None
    """
    try:
        # Open the file in append mode and add the new lines
        with open(csv_file_path, 'a', newline='') as file:
            writer = csv.writer(file)
            for centroid in centroids:
                x, y, blue, green, red = centroid
                writer.writerow([next_id, filename, method, x, y, "none", blue, green, red, 0])
                next_id += 1  # Increment the ID for each centroid
    
    except Exception as e:
        print(f"An error occurred in append_to_csv: {e}")

def get_last_id(csv_path):
    try:
        with open(csv_path, 'r') as csvfile:
            # Skip the header line
            next(csvfile)
            # Get the last line and retrieve the ID
            last_line = csvfile.readlines()[-1]
            last_id = int(last_line.split(',')[0])
            return last_id
    except (IndexError, FileNotFoundError, ValueError):
        return 0

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
        csv_file_path = os.path.join(outputCsvDir, "coordinates.csv")
        if not os.path.exists(csv_file_path):
            with open(csv_file_path, 'w', newline='') as file:
                writer = csv.writer(file)
                writer.writerow(['ID', 'File', 'Detection method', 'X_WGS84', 'Y_WGS84', 'template', 'Blue', 'Green', 'Red', 'georef'])
        
        for file in glob.glob(os.path.join(inputDir, '*.tif')):
            print(f"Processing file: {file}")
            
            # Call the circle_detection function and store the centroid list
            centroids, output_file = circle_detection(file, outputTifDir, blur, min_dist, threshold_edge, threshold_circles, min_radius, max_radius, csv_file_path)
            
            if centroids:  # Check if any centroids were detected
                # Generate unique ID for the new CSV entry
                next_id = get_last_id(csv_file_path) + 1
                
                # Add centroids to the CSV file
                append_to_csv(next_id, csv_file_path, os.path.basename(file), centroids, "circle_detection", 0)

    except Exception as e:
        print(f"An error occurred in mainCircleDetection: {e}")
