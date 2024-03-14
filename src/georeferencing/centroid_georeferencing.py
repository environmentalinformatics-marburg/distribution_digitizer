"""
File: centroid_georeferencing.py
Author: Kai Richter
Date: 2023-11-12

Last modified on: 2024-03-14 by Spaska Forteva

Description:
Script for georeferencing the extracted coordinates of centroids mathematically (TO BE IMPROVED!!!)

The input is the file 'coordinate.csv', that contains the original centroid coordinates extracted from the maps.
The function 'centroid_georef' converts them into WGS84-coordinates through the calculation of transformation
coefficients based on the GCP points and appends them to new columns of the csv file. 
The output file is stored in /data/output/output_final.csv
Also, a point-shapefile is stored in /data/output/output_shape/
"""

### Georeference extracted centroid coordinates

# import libraries
import glob  # Importing glob to handle file path patterns
import pandas as pd  # Importing pandas for data manipulation
import geopandas as gpd  # Importing geopandas for geospatial data operations
from shapely.geometry import Point  # Importing Point from shapely.geometry for geometric operations


def centroid_georef(gcppoints, input_csv, output_csv, output_shape):
  
  try:
    # Read the gcp_point_map1.points file
    gcp_df = pd.read_csv(gcppoints)
    
    # Read the input_csv file containing ungeoreferenced centroid coordinates
    centroid_df = pd.read_csv(input_csv)
    
    # Calculate transformation coefficients
    m11 = (gcp_df['mapX'].max() - gcp_df['mapX'].min()) / (gcp_df['sourceX'].max() - gcp_df['sourceX'].min())
    m22 = (gcp_df['mapY'].max() - gcp_df['mapY'].min()) / (gcp_df['sourceY'].max() - gcp_df['sourceY'].min())
    b1 = gcp_df['mapX'].min() - m11 * gcp_df['sourceX'].min()
    b2 = gcp_df['mapY'].min() - m22 * gcp_df['sourceY'].min()
    
    # Apply the transformation to each centroid coordinate
    centroid_df['X_WGS84'] = m11 * centroid_df['X'] + b1
    centroid_df['Y_WGS84'] = m22 * centroid_df['Y'] + b2

    # Save the georeferenced centroid coordinates to the output_csv file
    centroid_df.to_csv(output_csv, index=False, sep=';')
    
    # Create a GeoDataFrame from the georeferenced DataFrame
    geometry = [Point(x, y) for x, y in zip(centroid_df['X_WGS84'], centroid_df['Y_WGS84'])]  # Create Point geometries from WGS84 coordinates
    gdf = gpd.GeoDataFrame(centroid_df, geometry=geometry, crs='EPSG:4326')  # Create a GeoDataFrame with WGS84 CRS
    
    # Save the GeoDataFrame as a shapefile
    gdf.to_file(output_shape)  # Saving the GeoDataFrame to a shapefile
  except Exception as e:
        print("An error occurred in mainCentroidGeoref:", e)


def mainCentroidGeoref(workingDir, outDir):
  
  try:
    g_dir = workingDir + "/data/input/templates/geopoints/"  # Define directory containing GCP points files
    output_csv = outDir + "/output_final.csv"  # Define path for output CSV file
    output_shape_dir = outDir + "/output_shape/"  # Define directory for output shapefiles
    os.makedirs(output_shape_dir, exist_ok = True)  # Create output directory if it doesn't exist
    output_shape = output_shape_dir + "output_final.shp"  # Define path for output shapefile
    input_csv = outDir + "/maps/csv_files/coordinates.csv"  # Define path for input CSV file
    for gcp_points in glob.glob(g_dir + "*.points"):  # Iterate over GCP points files
      centroid_georef(gcp_points, input_csv, output_csv, output_shape)  # Call centroid_georef function
  except Exception as e:
        print("An error occurred in mainCentroidGeoref:", e)
