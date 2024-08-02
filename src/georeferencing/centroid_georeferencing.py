import glob
import pandas as pd
import geopandas as gpd
from shapely.geometry import Point

def centroid_georef(gcppoints, input_csv, output_csv, output_shape):
    try:
        # Read GCP points
        gcp_df = pd.read_csv(gcppoints)

        # Read input CSV file containing centroid coordinates
        centroid_df = pd.read_csv(input_csv)

        # Calculate transformation coefficients
        m11 = (gcp_df['mapX'].max() - gcp_df['mapX'].min()) / (gcp_df['sourceX'].max() - gcp_df['sourceX'].min())
        m22 = (gcp_df['mapY'].max() - gcp_df['mapY'].min()) / (gcp_df['sourceY'].max() - gcp_df['sourceY'].min())
        b1 = gcp_df['mapX'].min() - m11 * gcp_df['sourceX'].min()
        b2 = gcp_df['mapY'].min() - m22 * gcp_df['sourceY'].min()

        # Apply the transformation to each centroid coordinate
        centroid_df['X_WGS84'] = m11 * centroid_df['X_WGS84'] + b1
        centroid_df['Y_WGS84'] = m22 * centroid_df['Y_WGS84'] + b2

        # Rename columns to avoid long names (max 10 characters in Shapefile)
        centroid_df.rename(columns={'X_WGS84': 'X', 'Y_WGS84': 'Y'}, inplace=True)

        # Save the georeferenced centroid coordinates to the output_csv file
        centroid_df.to_csv(output_csv, index=False, sep=',')

        # Create a GeoDataFrame from the georeferenced DataFrame
        geometry = [Point(x, y) for x, y in zip(centroid_df['X'], centroid_df['Y'])]
        gdf = gpd.GeoDataFrame(centroid_df, geometry=geometry, crs='EPSG:4326')

        # Save the GeoDataFrame as a shapefile
        gdf.to_file(output_shape)
    
    except Exception as e:
        print("An error occurred in centroid_georef:", e)

def mainCentroidGeoref(workingDir, outDir):
    try:
        g_dir = workingDir + "/data/input/templates/geopoints/"
        output_csv = outDir + "/output_final.csv"
        output_shape_dir = outDir + "/output_shape/"
        os.makedirs(output_shape_dir, exist_ok=True)
        output_shape = output_shape_dir + "output_final.shp"
        input_csv = outDir + "/maps/csvFiles/coordinates.csv"
        
        for gcp_points in glob.glob(g_dir + "*.points"):
            centroid_georef(gcp_points, input_csv, output_csv, output_shape)
    
    except Exception as e:
        print("An error occurred in mainCentroidGeoref:", e)

# Beispiel-Aufruf
#workingDir = "D:/distribution_digitizer"
#outDir = "D:/test/output_2024-07-12_08-18-21"
#mainCentroidGeoref(workingDir, outDir)
