from osgeo import gdal, ogr, osr
import os
import glob
import numpy as np
import cv2
import csv

# Beispielhafte Farbbereiche (HSV) für rote, grüne und blaue Kreise
color_ranges = [
    (np.array([0, 70, 50]), np.array([10, 255, 255])),     # Rot
    (np.array([170, 70, 50]), np.array([180, 255, 255])),  # Rot
    (np.array([35, 70, 50]), np.array([85, 255, 255])),    # Grün
    (np.array([100, 70, 50]), np.array([140, 255, 255]))   # Blau
]

def polygonize(input_raster, output_shape, dst_layername):
    """
    Polygonizes the pixels of an input raster image and filters relevant pixels representing symbols or symbol centroids.
    
    Args:
        input_raster (str): Path to the input raster image.
        output_shape (str): Path to save the output shapefile.
        dst_layername (str): Name of the output layer.
    
    Returns:
        None
    """
    try:
        src_ds = gdal.Open(input_raster)  # Open the input raster datasource
        srcband = src_ds.GetRasterBand(1)  # Get the raster band
        
        # Check if shapefile available
        driverName = "ESRI Shapefile"
        drv = ogr.GetDriverByName(driverName)
        
        extension = "_rectified.tif"
        output_shape = output_shape.replace(extension, "")
        
        dst_ds = drv.CreateDataSource(output_shape)  # Create a new shapefile
        
        sp_ref = osr.SpatialReference()
        sp_ref.SetFromUserInput('EPSG:4326')
        
        dst_layername = dst_layername.replace(extension, "")
        dst_layer = dst_ds.CreateLayer(dst_layername, srs=sp_ref)  # Create a new layer
        
        fld = ogr.FieldDefn("HA", ogr.OFTInteger)
        dst_layer.CreateField(fld)
        dst_field = dst_layer.GetLayerDefn().GetFieldIndex("HA")
        
        gdal.Polygonize(srcband, None, dst_layer, dst_field, [], callback=None)  # Polygonize the raster
        
        # Loop over polygon features and filter relevant polygons
        extracted_features = []
        layer = dst_ds.GetLayer()
        for feature in layer:
            ha_value = feature.GetField("HA")
            if ha_value == 255:
                extracted_features.append(feature.Clone())
        
        # Create new layer and save the filtered features
        dst_layer = dst_ds.CreateLayer(dst_layername + "_filtered", srs=sp_ref)
        dst_layer.CreateField(fld)
        for feature in extracted_features:
            dst_layer.CreateFeature(feature)
            feature.Destroy()
        
        srcband = None
        src_ds = None
        dst_ds = None
    
    except Exception as e:
        print("An error occurred in polygonize:", e)
    # End of function

# Function to execute polygonize function for multiple raster images
def mainPolygonize(workingDir, outDir):
    """
    Executes the polygonize function for all raster images in the given directory.

    Args:
        workingDir (str): Directory containing the input raster images.
        outDir (str): Output directory to save the polygonized shapefiles.

    Returns:
        None
    """
    try:
        output= os.path.join(outDir, "polygonize")
        inputdir = os.path.join(outDir, "rectifying")
        
        for input_raster in glob.glob(os.path.join(inputdir, "*.tif")):
            print(input_raster)
            dst_layername = os.path.basename(input_raster)
            print(dst_layername)
            output_shape = os.path.join(output, dst_layername)
            print(output_shape)
            polygonize(input_raster, output_shape, dst_layername)
    except Exception as e:
        print("An error occurred in mainPolygonize:", e)
    # End of function

# Function to execute polygonize function for multiple raster images
def mainPolygonize_Map_PF(workingDir, outDir):
    """
    Executes the polygonize function for all raster images in the given directory.

    Args:
        workingDir (str): Directory containing the input raster images.
        outDir (str): Output directory to save the polygonized shapefiles.

    Returns:
        None
    """
    try:
        output= os.path.join(outDir, "polygonize", "maps")
        os.makedirs(output, exist_ok=True) 
        inputdir = os.path.join(outDir, "rectifying", "maps")
        
        for input_raster in glob.glob(os.path.join(inputdir, "*.tif")):
            print(input_raster)
            dst_layername = os.path.basename(input_raster)
            print(dst_layername)
            output_shape = os.path.join(output, dst_layername)
            print(output_shape)
            polygonize(input_raster, output_shape, dst_layername)
    except Exception as e:
        print("An error occurred in mainPolygonize_Map_PF:", e)
    # End of function

def create_centroid_mask_and_csv(image_path, color_ranges, output_shapefile_path, output_csv_path):
    """
    Processes an image to identify specific colored regions, calculates the centroids of these regions, 
    and stores the results in both a shapefile and a CSV file. The centroids are saved with their 
    georeferenced positions and color information.

    Args:
        image_path (str): The path to the input image to be processed.
        color_ranges (list): A list of color ranges (in HSV values) that define the colors to be identified in the image.
        output_shapefile_path (str): The path to the output shapefile where the centroids will be saved.
        output_csv_path (str): The path to the output CSV file where the centroids and their attributes will be saved.

    Returns:
        None
    """
    try:
        # Load image
        img = cv2.imread(image_path)
        hsv_img = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)

        # Create an empty mask
        final_mask = np.zeros(img.shape[:2], dtype="uint8")

        for color_range in color_ranges:
            # Create a mask for each color range
            lower, upper = color_range
            mask = cv2.inRange(hsv_img, lower, upper)

            # Add the mask to the final mask
            final_mask = cv2.bitwise_or(final_mask, mask)

        # Find contours
        contours, _ = cv2.findContours(final_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        # Create a new mask for the centroids
        centroid_mask = np.zeros_like(img)

        # Lists for centroids coordinates and colors
        centroids = []
        colors = []
        local_coords = []

        # Calculate centroids and draw them as points on the new mask
        for contour in contours:
            M = cv2.moments(contour)
            if M["m00"] != 0:
                cx = int(M["m10"] / M["m00"])
                cy = int(M["m01"] / M["m00"])
                centroids.append((cx, cy))
                color = img[cy, cx]
                colors.append([color[2], color[1], color[0]])  # Convert from BGR to RGB
                local_coords.append((cx, cy))
                cv2.circle(centroid_mask, (cx, cy), 3, color.tolist(), -1)

        # Extract georeferenced information
        dataset = gdal.Open(image_path)
        geotransform = dataset.GetGeoTransform()
        spatial_ref = osr.SpatialReference()
        spatial_ref.ImportFromWkt(dataset.GetProjection())

        # Create shapefile
        driver = ogr.GetDriverByName("ESRI Shapefile")
        if os.path.exists(output_shapefile_path):
            driver.DeleteDataSource(output_shapefile_path)
        shape_data = driver.CreateDataSource(output_shapefile_path)
        layer = shape_data.CreateLayer("centroids", spatial_ref, ogr.wkbPoint)

        # Add attribute fields
        layer.CreateField(ogr.FieldDefn("ID", ogr.OFTInteger))
        layer.CreateField(ogr.FieldDefn("Red", ogr.OFTInteger))
        layer.CreateField(ogr.FieldDefn("Green", ogr.OFTInteger))
        layer.CreateField(ogr.FieldDefn("Blue", ogr.OFTInteger))
        layer.CreateField(ogr.FieldDefn("Local_X", ogr.OFTInteger))
        layer.CreateField(ogr.FieldDefn("Local_Y", ogr.OFTInteger))
        layer.CreateField(ogr.FieldDefn("File", ogr.OFTString))

        # Extract the basename of the TIFF file
        file_basename = os.path.basename(image_path)

        # Prepare the CSV file
        with open(output_csv_path, mode='a', newline='') as csv_file:
            fieldnames = ['ID', 'Local_X', 'Local_Y', 'Real_X', 'Real_Y', 'Red', 'Green', 'Blue', 'File']
            writer = csv.DictWriter(csv_file, fieldnames=fieldnames)

            # Save centroids and colors to the shapefile and CSV file
            for i, (cx, cy) in enumerate(centroids):
                # Calculate georeferenced coordinates
                x = geotransform[0] + cx * geotransform[1] + cy * geotransform[2]
                y = geotransform[3] + cx * geotransform[4] + cy * geotransform[5]

                point = ogr.Geometry(ogr.wkbPoint)
                point.AddPoint(x, y)

                feature = ogr.Feature(layer.GetLayerDefn())
                feature.SetGeometry(point)
                feature.SetField("ID", i)
                # Ensure that the color channels are integers
                feature.SetField("Red", int(colors[i][0]))
                feature.SetField("Green", int(colors[i][1]))
                feature.SetField("Blue", int(colors[i][2]))
                feature.SetField("Local_X", local_coords[i][0])
                feature.SetField("Local_Y", local_coords[i][1])
                feature.SetField("File", file_basename)
                layer.CreateFeature(feature)
                feature = None

                # Write to the CSV file
                writer.writerow({
                    'ID': i,
                    'Local_X': local_coords[i][0],
                    'Local_Y': local_coords[i][1],
                    'Real_X': x,
                    'Real_Y': y,
                    'Red': colors[i][2],
                    'Green': colors[i][1],
                    'Blue': colors[i][0],
                    'File': file_basename
                })

        # Close the shapefile
        shape_data = None
    
    except Exception as e:
        print(f"An error occurred: {e}")
 # End of function


def mainPolygonize_CD(workingDir, outDir):
    """
    Executes the polygonize function for georeferenced masks containing centroids detected by Circle Detection.

    Args:
        workingDir (str): Directory containing the input raster images.
        outDir (str): Output directory to save the polygonized shapefiles.

    Returns:
        None
    """
    try:
        output = os.path.join(outDir, "polygonize", "circleDetection")
        inputdir = os.path.join(outDir, "rectifying", "circleDetection")
        output_csv_path = os.path.join(outDir, "polygonize", "csvFiles", "centroids_colors_cd.csv")

        # Erstelle das Verzeichnis, falls es noch nicht existiert
        os.makedirs(os.path.dirname(output_csv_path), exist_ok=True)

        # Überprüfe, ob die Datei existiert, und erstelle sie falls nicht
        if not os.path.isfile(output_csv_path):
            with open(output_csv_path, 'w', newline='') as csvfile:
                # Initialisiere den CSV-Schreiber
                csvwriter = csv.writer(csvfile)
                # Schreibe die Kopfzeile
                csvwriter.writerow(['ID','Local_X', 'Local_Y', 'Real_X', 'Real_Y', 'Red', 'Green', 'Blue', 'File'])

        print(f"Die Datei wurde erstellt oder existiert bereits: {output_csv_path}")

        # Schleife durch alle Bilder im Verzeichnis
        for image_file in os.listdir(inputdir):
            image_path = os.path.join(inputdir, image_file)
            if os.path.isfile(image_path):
                output_shapefile_path = os.path.join(output, f"{os.path.splitext(image_file)[0]}.shp")
                create_centroid_mask_and_csv(image_path, color_ranges, output_shapefile_path, output_csv_path)
                
    except Exception as e:
        print(f"Ein Fehler ist aufgetreten: {e}")
  # End of function

def mainPolygonize_PF(workingDir, outDir):
    """
    Executes the polygonize function for georeferenced masks containing centroids detected by Circle Detection.

    Args:
        workingDir (str): Directory containing the input raster images.
        outDir (str): Output directory to save the polygonized shapefiles.

    Returns:
        None
    """
    try:
        output = os.path.join(outDir, "polygonize", "pointFiltering")
        inputdir = os.path.join(outDir, "rectifying", "pointFiltering")
        output_csv_path = os.path.join(outDir, "polygonize", "csvFiles", "centroids_colors_pf.csv")

        # Erstelle das Verzeichnis, falls es noch nicht existiert
        os.makedirs(os.path.dirname(output_csv_path), exist_ok=True)

        # Überprüfe, ob die Datei existiert, und erstelle sie falls nicht
        if not os.path.isfile(output_csv_path):
            with open(output_csv_path, 'w', newline='') as csvfile:
                # Initialisiere den CSV-Schreiber
                csvwriter = csv.writer(csvfile)
                # Schreibe die Kopfzeile
                csvwriter.writerow(['ID','Local_X', 'Local_Y', 'Real_X', 'Real_Y', 'Red', 'Green', 'Blue', 'File'])

        print(f"Die Datei wurde erstellt oder existiert bereits: {output_csv_path}")

        # Schleife durch alle Bilder im Verzeichnis
        for image_file in os.listdir(inputdir):
            image_path = os.path.join(inputdir, image_file)
            if os.path.isfile(image_path):
                output_shapefile_path = os.path.join(output, f"{os.path.splitext(image_file)[0]}.shp")
                create_centroid_mask_and_csv(image_path, color_ranges, output_shapefile_path, output_csv_path)
                
    except Exception as e:
        print(f"Ein Fehler ist aufgetreten: {e}")
  # End of function
