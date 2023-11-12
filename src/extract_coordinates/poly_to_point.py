"""
Author: Kai Richter
added on: 2023/11/10
last modified: 2023/11/10
"""

# import libraries
import os
import geopandas as gpd


## convert polygons to points
def poly_to_point(input_shapefile, output_shapefile):
    # Read the input shapefile
    gdf = gpd.read_file(input_shapefile)

    # Initialize a list to store the centroid points
    centroid_points = []

    # Iterate through the polygons and calculate the centroid points
    for index, row in gdf.iterrows():
        polygon = row['geometry']
        centroid = polygon.centroid
        centroid_points.append(centroid)

    # Create a GeoDataFrame from the centroid points
    gdf_points = gpd.GeoDataFrame(geometry=centroid_points, crs=gdf.crs)

    # Save the GeoDataFrame as a shapefile
    gdf_points.to_file(output_shapefile)



def MainPolyToPoint_CD(workingDir):
    input_folder = workingDir + "/data/output/polygonize/circleDetection/"
    output_folder = workingDir + "/data/output/final_output/CircleDetection/"
    os.makedirs(output_folder, exist_ok=True) 
    # Iterate over subfolders in the input folder
    for subdir, dirs, files in os.walk(input_folder):
        for file in files:
            if file.endswith('_filtered.shp'):
                # Input shapefile path
                input_shapefile = os.path.join(subdir, file)

                # Create output subfolder structure in the output folder
                relative_path = os.path.relpath(input_shapefile, input_folder)
                output_subfolder = os.path.join(output_folder, os.path.dirname(relative_path))
                os.makedirs(output_subfolder, exist_ok=True)

                # Output shapefile path
                output_shapefile = os.path.join(output_folder, relative_path.replace('.shp', '_points.shp'))

                # Convert polygons to points
                poly_to_point(input_shapefile, output_shapefile)


def MainPolyToPoint_PF(workingDir):
    input_folder = workingDir + "/data/output/polygonize/pointFiltering/"
    output_folder = workingDir + "/data/output/final_output/pointFiltering/"
    os.makedirs(output_folder, exist_ok=True) 
    # Iterate over subfolders in the input folder
    for subdir, dirs, files in os.walk(input_folder):
        for file in files:
            if file.endswith('_filtered.shp'):
                # Input shapefile path
                input_shapefile = os.path.join(subdir, file)

                # Create output subfolder structure in the output folder
                relative_path = os.path.relpath(input_shapefile, input_folder)
                output_subfolder = os.path.join(output_folder, os.path.dirname(relative_path))
                os.makedirs(output_subfolder, exist_ok=True)

                # Output shapefile path
                output_shapefile = os.path.join(output_folder, relative_path.replace('.shp', '_points.shp'))

                # Convert polygons to points
                poly_to_point(input_shapefile, output_shapefile)


