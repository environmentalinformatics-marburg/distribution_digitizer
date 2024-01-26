"""
File: centroid_georeferencing.py
Author: Kai Richter
Date: 2023-11-12

Last modified on: 2023/11/06 by Kai Richter

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
import glob
import pandas as pd
import geopandas as gpd
from shapely.geometry import Point


def centroid_georef(gcppoints, input_csv, output_csv, output_shape):
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
    geometry = [Point(x, y) for x, y in zip(centroid_df['X_WGS84'], centroid_df['Y_WGS84'])]
    gdf = gpd.GeoDataFrame(centroid_df, geometry=geometry, crs='EPSG:4326')
    
    # Save the GeoDataFrame as a shapefile
    gdf.to_file(output_shape)


def mainCentroidGeoref(workingDir):
  g_dir = workingDir + "/data/input/templates/geopoints/"
  output_csv = workingDir + "/data/output/output_final.csv"
  output_shape_dir = workingDir + "/data/output/output_shape/"
  os.makedirs(output_shape_dir, exist_ok = True)
  output_shape = output_shape_dir + "output_final.shp"
  input_csv = workingDir + "/data/output/maps/csv_files/coordinates.csv"
  for gcp_points in glob.glob(g_dir + "*.points"):
    centroid_georef(gcp_points, input_csv, output_csv, output_shape)
