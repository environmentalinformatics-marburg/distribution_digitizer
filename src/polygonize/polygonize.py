# # ============================================================
# File: polygonize.py
# Author: Spaska Forteva
# ============================================================
# Polygonization and centroid extraction
# ============================================================
# This script converts raster-based detection results into
# structured geospatial vector data.
#
# Core functionality:
# - Raster → polygon conversion (GDAL)
# - Centroid extraction from colored regions
# - Coordinate transformation (pixel → real world)
# - Attribute assignment (color, template, species)
#
# Output:
# - Shapefiles (vector GIS data)
# - CSV files (tabular data)
#
# Role in workflow:
# - Final step: computer vision → GIS integration
# ============================================================


from osgeo import gdal, ogr, osr
import os
import glob
import numpy as np
import cv2
import csv

# Beispielhafte Farbbereiche (HSV) für rote, grüne und blaue Kreise
color_ranges = [

    # RED
    (np.array([0, 100, 100]), np.array([10, 255, 255])),
    (np.array([170, 100, 100]), np.array([180, 255, 255])),

    # BLUE
    (np.array([100, 100, 100]), np.array([130, 255, 255])),

    # GREEN
    (np.array([40, 100, 100]), np.array([80, 255, 255])),

    # YELLOW
    (np.array([20, 100, 100]), np.array([35, 255, 255])),

    # ORANGE
    (np.array([10, 100, 100]), np.array([20, 255, 255])),

    # PURPLE / MAGENTA
    (np.array([130, 50, 50]), np.array([160, 255, 255]))
]

# ------------------------------------------------------------
# Polygonize raster → vector
# ------------------------------------------------------------
# Converts raster pixels (e.g. binary masks or centroids)
# into vector polygons using GDAL.
#
# Key idea:
# - Each connected pixel region becomes a polygon.
# - Only relevant pixels (value = 255) are kept.
#
# Output:
# - Shapefile with filtered polygons (foreground only)
#
# Role in workflow:
# - Transition from image processing → GIS vector data
# ------------------------------------------------------------
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


# ------------------------------------------------------------
# Batch polygonization (general)
# ------------------------------------------------------------
# Processes all rectified raster files and converts them
# into shapefiles.
#
# Key idea:
# - Loop over all TIFFs in rectifying folder
# - Apply polygonize() per file
#
# Output:
# - polygonize/*.shp
#
# Role in workflow:
# - Generic polygonization step after rectifying
# ------------------------------------------------------------
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


# ------------------------------------------------------------
# Polygonization for maps (Point Filtering)
# ------------------------------------------------------------
# Converts rectified map images (not masks) into polygons.
#
# Key idea:
# - Works on full maps instead of centroid masks
# - Used for map-level vectorization
#
# Output:
# - polygonize/maps/*.shp
#
# Role in workflow:
# - Optional map-level vector extraction
# ------------------------------------------------------------
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


# ------------------------------------------------------------
# Match RGB color → template name
# ------------------------------------------------------------
# Assigns a detected centroid color to a template.
#
# Key idea:
# - Simple threshold-based color classification
# - Maps color → symbol template
#
# Role in workflow:
# - Links visual detection to semantic symbol type
# ------------------------------------------------------------
def match_color_to_template(r, g, b, template_list):
    # einfache Farbklassifikation
    if r > 200 and g < 100 and b < 100:
        color_name = "red"
    elif g > 200 and r < 100 and b < 100:
        color_name = "green"
    elif b > 200 and r < 100 and g < 100:
        color_name = "blue"
    elif r > 200 and g > 200 and b < 100:
        color_name = "yellow"
    elif r > 200 and g > 100 and b < 50:
        color_name = "orange"
    elif r > 200 and b > 200:
        color_name = "magenta"
    else:
        color_name = "unknown"

    # passenden Template suchen (erster Treffer reicht)
    for t in template_list:
        if color_name in t.lower():
            return t

    return "unknown"
  
  
# ------------------------------------------------------------
# Extract centroids + create shapefile + CSV
# ------------------------------------------------------------
# Detects colored regions, extracts centroids,
# converts them to georeferenced coordinates,
# and stores results in shapefile + CSV.
#
# Key steps:
# - Detect colors (HSV)
# - Find contours → centroids
# - Convert pixel → real-world coordinates
# - Assign template + species
#
# Output:
# - Shapefile (points)
# - CSV (attributes)
#
# Role in workflow:
# - Core step: image detection → geospatial data
# ------------------------------------------------------------
def create_centroid_mask_and_csv(outDir, workingDir, image_path, color_ranges, output_shapefile_path, output_csv_path, map_id):
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
        coords_data = []

        coordinates_csv_path = os.path.join(
            outDir,              # ← WICHTIG!
            str(map_id),
            "maps",
            "csvFiles",
            "coordinates.csv"
        )
        
        if os.path.exists(coordinates_csv_path):
            with open(coordinates_csv_path, 'r') as f:
                reader = csv.DictReader(f)
                coords_data = list(reader)
        else:
            print("WARNING: coordinates.csv not found:", coordinates_csv_path)
        template_dir = os.path.join(workingDir, "data/input/templates", str(map_id),"symbols")
        template_list = [
            os.path.splitext(f)[0]
            for f in os.listdir(template_dir)
              if f.endswith(".tif")
        ]
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
                cv2.circle(centroid_mask, (cx, cy), 1, color.tolist(), -1)

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
        layer.CreateField(ogr.FieldDefn("template", ogr.OFTString))
        layer.CreateField(ogr.FieldDefn("specie", ogr.OFTString))  
        layer.CreateField(ogr.FieldDefn("File", ogr.OFTString))

        # Extract the basename of the TIFF file
        file_basename = os.path.basename(image_path)

        # Prepare the CSV file
        with open(output_csv_path, mode='a', newline='') as csv_file:
            fieldnames = ['ID', 'Local_X', 'Local_Y', 'Real_X', 'Real_Y', 'Red', 'Green', 'Blue', 'template', 'File','specie']
            writer = csv.DictWriter(csv_file, fieldnames=fieldnames)

            # Save centroids and colors to the shapefile and CSV file
            for i, (cx, cy) in enumerate(centroids):
                # Calculate georeferenced coordinates
                x = geotransform[0] + cx * geotransform[1] + cy * geotransform[2]
                y = geotransform[3] + cx * geotransform[4] + cy * geotransform[5]

                point = ogr.Geometry(ogr.wkbPoint)
                point.AddPoint(x, y)
                r = int(colors[i][0])
                g = int(colors[i][1])
                
                b = int(colors[i][2])
                template_name = match_color_to_template(r, g, b, template_list)
                species_name = find_species_match(
                    local_coords[i][0],
                    local_coords[i][1],
                    template_name,
                    file_basename,
                    coords_data
                )
                
                if not species_name:
                  species_name = None
                print(species_name)
                feature = ogr.Feature(layer.GetLayerDefn())
                feature.SetGeometry(point)

                feature.SetField("ID", i)
                # Ensure that the color channels are integers
                feature.SetField("Red", int(colors[i][0]))
                feature.SetField("Green", int(colors[i][1]))
                feature.SetField("Blue", int(colors[i][2]))
                feature.SetField("Local_X", local_coords[i][0])
                feature.SetField("Local_Y", local_coords[i][1])
                feature.SetField("template", template_name)
                feature.SetField("File", file_basename)
                feature.SetField("specie", species_name)
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
                    'template': template_name,
                    'specie': species_name,
                    'File': file_basename
                })

        # Close the shapefile
        shape_data = None
    
    except Exception as e:
        print(f"An error occurred: {e}")
 # End of function



# ------------------------------------------------------------
# Match centroid → species
# ------------------------------------------------------------
# Finds species name for a detected centroid
# using previously extracted coordinate data.
#
# Matching criteria:
# - template (symbol type)
# - file name (map)
#
# Role in workflow:
# - Connects detection results with species info
# ------------------------------------------------------------
def find_species_match(lx, ly, template, file_name, coords_data, threshold=25):
    """
    Find matching species from coordinates data using:
    - template
    - file_name
    - nearest coordinates
    """

    best_match = None
    best_dist = float("inf")

    template = str(template).lower()
    file_name = str(file_name).lower()

    for row in coords_data:
        try:
            row_template = str(row["template"]).lower()
            row_template_clean = row_template.split("_")[0]

            template_clean = str(template).lower().split("_")[0]
            if row_template_clean != template_clean:
                continue
            if str(row["File"]).lower() != file_name:
                continue

            #cx = float(row["X_WGS84"])
            #cy = float(row["Y_WGS84"])

           # d = ((lx - cx)**2 + (ly - cy)**2) ** 0.5

            #if d < threshold and d < best_dist:
            #    best_dist = d
              #best_match = row
            return row.get("species", "unknown")

        except:
            continue

    if best_match:
        return best_match.get("species", "unknown")

    return "unknown"
  
def mainPolygonize_PF(workingDir, outDir, nMapTypes):

    for map_id in range(1, int(nMapTypes) + 1):

        collect_rectified_points_to_csv(outDir, map_id)
  
# ------------------------------------------------------------
# Main polygonize workflow (Point Filtering)
# ------------------------------------------------------------
# Processes all rectified centroid masks and converts
# them into georeferenced point data.
#
# Key idea:
# - Loop over map types (1..n)
# - Extract centroids
# - Save shapefile + CSV per map type
#
# Output:
# - polygonize/pointFiltering/*.shp
# - csvFiles/centroids_colors_pf.csv
#
# Role in workflow:
# - Final step: structured GIS-ready dataset
# ------------------------------------------------------------
def mainPolygonize_PF_alt(workingDir, outDir, nMapTypes):
    """
    Polygonize for multiple map types.
    Each map type gets its own shapefiles AND its own CSV.
    """
    try:

        for map_id in range(1, int(nMapTypes) + 1):

            inputdir = os.path.join(
                outDir, str(map_id),
                "rectifying", "pointFiltering"
            )

            output = os.path.join(
                outDir, str(map_id),
                "polygonize", "pointFiltering"
            )

            output_csv_path = os.path.join(
                outDir, str(map_id),
                "polygonize", "csvFiles",
                "centroids_colors_pf.csv"
            )

            os.makedirs(output, exist_ok=True)
            os.makedirs(os.path.dirname(output_csv_path), exist_ok=True)

            # CSV neu erzeugen pro MapType
            if not os.path.isfile(output_csv_path):
                with open(output_csv_path, 'w', newline='') as csvfile:
                    csvwriter = csv.writer(csvfile)
                    csvwriter.writerow([
                        'ID',
                        'Local_X', 'Local_Y',
                        'Real_X', 'Real_Y',
                        'Red', 'Green', 'Blue', 
                        'template',
                        'File',
                        'specie'
                    ])

            print(f"\nProcessing MapType {map_id}")
            print(f"Input: {inputdir}")
            print(f"Output CSV: {output_csv_path}")

            if not os.path.exists(inputdir):
                print("Directory does not exist:", inputdir)
                continue

            for image_file in os.listdir(inputdir):

                if not image_file.endswith(".tif"):
                    continue

                image_path = os.path.join(inputdir, image_file)

                output_shapefile_path = os.path.join(
                    output,
                    f"{os.path.splitext(image_file)[0]}.shp"
                )

                create_centroid_mask_and_csv(
                    outDir, 
                    workingDir,
                    image_path,
                    color_ranges,
                    output_shapefile_path,
                    output_csv_path,
                    map_id
                    
                )

    except Exception as e:
        print(f"Error in mainPolygonize_PF:", e)
        
        
def collect_rectified_points_to_csv(outDir, map_id):

    inputdir = os.path.join(
        outDir, str(map_id),
        "rectifying", "pointFiltering"
    )

    output_csv_path = os.path.join(
        outDir, str(map_id),
        "polygonize", "csvFiles",
        "centroids_colors_pf.csv"
    )

    os.makedirs(os.path.dirname(output_csv_path), exist_ok=True)

    print(f"\nCollecting CSVs for MapType {map_id}")
    print(f"Input: {inputdir}")
    print(f"Output: {output_csv_path}")

    all_rows = []
    global_id = 0

    for file in os.listdir(inputdir):

        if not file.endswith("_points.csv"):
            continue

        csv_path = os.path.join(inputdir, file)

        print("Reading:", csv_path)

        with open(csv_path, "r") as f:
            reader = csv.DictReader(f)

            for row in reader:

                try:
                    lx = float(row["Local_X"])
                    ly = float(row["Local_Y"])

                    image_file = row["File"]
                    image_path = os.path.join(inputdir, image_file)

                    # Georeferenz holen
                    dataset = gdal.Open(image_path)
                    geotransform = dataset.GetGeoTransform()

                    real_x = geotransform[0] + lx * geotransform[1] + ly * geotransform[2]
                    real_y = geotransform[3] + lx * geotransform[4] + ly * geotransform[5]

                    all_rows.append({
                        "ID": global_id,
                        "Local_X": lx,
                        "Local_Y": ly,
                        "Real_X": real_x,
                        "Real_Y": real_y,
                        "Red": int(row["Red"]),
                        "Green": int(row["Green"]),
                        "Blue": int(row["Blue"]),
                        "template": row["template"],
                        "File": image_file,
                        "specie": row["specie"]
                    })

                    global_id += 1

                except Exception as e:
                    print("Error processing row:", e)

    # CSV schreiben
    if not all_rows:
        print("⚠️ No data found!")
        return

    with open(output_csv_path, "w", newline="") as f:

        writer = csv.DictWriter(f, fieldnames=all_rows[0].keys())
        writer.writeheader()
        writer.writerows(all_rows)

    print(f"✅ Final CSV saved: {output_csv_path}")
