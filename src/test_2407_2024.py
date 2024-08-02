

from osgeo import gdal, ogr, osr
import os
import glob

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
        # Open the input raster datasource
        src_ds = gdal.Open(input_raster)  
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
        
        # Polygonize the raster
        gdal.Polygonize(srcband, None, dst_layer, dst_field, [], callback=None)
        
        # Optional: Print feature count
        print(f"Number of features in {output_shape}: {dst_layer.GetFeatureCount()}")
        
        # Cleanup
        srcband = None
        src_ds = None
        dst_ds = None
    
    except Exception as e:
        print("An error occurred in polygonize:", e)

def mainPolygonize(input_dir, output_dir):
    """
    Executes the polygonize function for all raster images in the given directory.

    Args:
        input_dir (str): Directory containing the input raster images.
        output_dir (str): Output directory to save the polygonized shapefiles.

    Returns:
        None
    """
    try:
        os.makedirs(output_dir, exist_ok=True)
        
        for input_raster in glob.glob(os.path.join(input_dir, "*.tif")):
            print(f"Processing: {input_raster}")
            dst_layername = os.path.basename(input_raster)
            output_shape = os.path.join(output_dir, dst_layername.replace('.tif', '.shp'))
            polygonize(input_raster, output_shape, dst_layername)
    
    except Exception as e:
        print("An error occurred in mainPolygonize:", e)

# Beispielhafte Pfade (anpassen nach Bedarf)
input_dir = "D:/test/output_2024-07-12_08-18-21/rectifying/circleDetection/"
output_dir = "D:/test/output_2024-07-12_08-18-21/polygonize/circleDetection"
mainPolygonize(input_dir, output_dir)



import cv2
import geopandas as gpd
import pandas as pd
from osgeo import gdal

def extract_colors_and_centroids(image_path, shapefile_path, output_csv):
    # Laden des Bildes
    img = cv2.imread(image_path)
    
    # Shapefile laden
    gdf = gpd.read_file(shapefile_path)
    
    centroids = []
    colors = []
    
    # Umrechnen der Geometriekoordinaten in Pixelkoordinaten
    def coord_to_pixel(coord, transform):
        x, y = coord
        px = int((x - transform[0]) / transform[1])
        py = int((y - transform[3]) / transform[5])
        return px, py

    # Transformationsmatrix des Geotiffs
    src = gdal.Open(image_path)
    transform = src.GetGeoTransform()

    for geom in gdf.geometry:
        if geom.geom_type == 'Polygon' or geom.geom_type == 'MultiPolygon':
            if geom.geom_type == 'MultiPolygon':
                # Iteriere über die Polygone in MultiPolygon
                geoms = geom.geoms
            else:
                geoms = [geom]
            
            for poly in geoms:
                centroid = poly.centroid
                centroids.append((centroid.x, centroid.y))
                px, py = coord_to_pixel((centroid.x, centroid.y), transform)
                
                # Farbe an der Position des Zentroids extrahieren
                if 0 <= px < img.shape[1] and 0 <= py < img.shape[0]:
                    color = img[py, px]
                    # Konvertiere BGR (OpenCV) nach RGB
                    color = color[::-1]
                    colors.append(color.tolist())
                else:
                    colors.append([0, 0, 0])  # Default color if out of bounds
    
    # Überprüfen der extrahierten Zentroiden und Farben
    print(f"Anzahl der extrahierten Zentroiden: {len(centroids)}")
    print(f"Anzahl der extrahierten Farben: {len(colors)}")
    
    # Speichern der Zentren und Farben in einer CSV-Datei
    df = pd.DataFrame(centroids, columns=['Longitude', 'Latitude'])
    df['Color'] = colors
    df.to_csv(output_csv, index=False)

# Beispielhafte Pfade (anpassen nach Bedarf)
image_path = "D:/test/output_2024-07-12_08-18-21/rectifying/circleDetection/geor64-2_0069map_1_0_centre_rectified.tif"
shapefile_path = "D:/test/output_2024-07-12_08-18-21/polygonize/circleDetection/geor64-2_0069map_1_0_centre_rectified.shp"
output_csv = "D:/test/output_2024-07-12_08-18-21/centroids_with_colors.csv"
extract_colors_and_centroids(image_path, shapefile_path, output_csv)




import cv2
import numpy as np
import geopandas as gpd
import pandas as pd
from osgeo import gdal

def extract_colors_and_centroids(image_path, shapefile_path, output_csv):
    # Laden des Bildes
    img = cv2.imread(image_path)
    
    # Shapefile laden
    gdf = gpd.read_file(shapefile_path)
    
    centroids = []
    colors = []
    
    # Umrechnen der Geometriekoordinaten in Pixelkoordinaten
    def coord_to_pixel(coord, transform):
        x, y = coord
        px = int((x - transform[0]) / transform[1])
        py = int((y - transform[3]) / transform[5])
        return px, py

    # Transformationsmatrix des Geotiffs
    src = gdal.Open(image_path)
    transform = src.GetGeoTransform()

    # Erstellen einer Kopie des Bildes zum Zeichnen der Punkte
    img_with_points = img.copy()
    
    for geom in gdf.geometry:
        if geom.geom_type == 'Polygon' or geom.geom_type == 'MultiPolygon':
            if geom.geom_type == 'MultiPolygon':
                # Iteriere über die Polygone in MultiPolygon
                geoms = geom.geoms
            else:
                geoms = [geom]
            
            for poly in geoms:
                centroid = poly.centroid
                centroids.append((centroid.x, centroid.y))
                px, py = coord_to_pixel((centroid.x, centroid.y), transform)
                
                # Farbe an der Position des Zentroids extrahieren
                if 0 <= px < img.shape[1] and 0 <= py < img.shape[0]:
                    color = img[py, px]
                    color = color[::-1]  # Konvertiere BGR nach RGB
                    colors.append(color.tolist())
                    
                    # Zeichnen des Punktes auf dem Bild
                    cv2.circle(img_with_points, (px, py), 5, color.tolist(), -1)
                else:
                    colors.append([0, 0, 0])  # Default color if out of bounds
    
    # Überprüfen der extrahierten Zentroiden und Farben
    print(f"Anzahl der extrahierten Zentroiden: {len(centroids)}")
    print(f"Anzahl der extrahierten Farben: {len(colors)}")
    
    # Speichern der Zentren und Farben in einer CSV-Datei
    df = pd.DataFrame(centroids, columns=['Longitude', 'Latitude'])
    df['Color'] = colors
    df.to_csv(output_csv, index=False)
    
    # Speichern des Bildes mit den eingezeichneten Punkten
    cv2.imwrite("D:/test/output_2024-07-12_08-18-21/visualized_points.png", img_with_points)

# Beispielhafte Pfade (anpassen nach Bedarf)
image_path = "D:/test/output_2024-07-12_08-18-21/georeferencing/masks/circleDetection/geor64-2_0069map_1_0_centre.tif"
shapefile_path = "D:/test/output_2024-07-12_08-18-21/polygonize/circleDetection/geor64-2_0069map_1_0_centre/geor64-2_0069map_1_0_centre.shp"
output_csv = "D:/test/output_2024-07-12_08-18-21/centroids_with_colors.csv"
extract_colors_and_centroids(image_path, shapefile_path, output_csv)







def create_shapefile_with_colors(shapefile_path, output_shapefile, csv_file):
    # Original Shapefile laden
    gdf = gpd.read_file(shapefile_path)
    
    # CSV-Datei mit Zentroiden und Farben laden
    df = pd.read_csv(csv_file)
    
    # Farben in RGB zerlegen
    df['Color_R'] = df['Color'].apply(lambda x: eval(x)[0])
    df['Color_G'] = df['Color'].apply(lambda x: eval(x)[1])
    df['Color_B'] = df['Color'].apply(lambda x: eval(x)[2])
    
    # Farben als Attribute zum GeoDataFrame hinzufügen
    gdf['Color_R'] = df['Color_R']
    gdf['Color_G'] = df['Color_G']
    gdf['Color_B'] = df['Color_B']
    
    # Neues Shapefile speichern
    gdf.to_file(output_shapefile, driver='ESRI Shapefile')

# Beispielhafte Pfade (anpassen nach Bedarf)
output_shapefile = "D:/test/output_2024-07-12_08-18-21/polygonize/circleDetection/geor64-2_0069map_1_0_centre/geor64-2_0069map_1_0_centre_with_colors.shp"
create_shapefile_with_colors(shapefile_path, output_shapefile, output_csv)



