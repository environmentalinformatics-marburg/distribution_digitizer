"""



Last modified on 2023/11/10 by Kai Richter:
  Addition of functions mainmaskgeoreferencingMasks_CD and mainmaskgeoreferencingMasks_PF
"""


from osgeo import gdal, gdalconst
import string
from functools import reduce
import shutil
from osgeo import gdal, osr
import pandas as pd
import os,glob
#os.environ['PROJ_LIB'] = "C:/ProgramData/miniconda3/Library/share/proj"
#os.environ['PROJ_LIB'] = "C:/Users/user/miniconda3/Library/share/proj/"

import sys
# Set path to proj.db file via the path to the conda environment currently in use
env = sys.prefix
proj = os.path.join(env, "Library/share/proj/")
os.environ['PROJ_LIB'] = proj

# Working with the Input GCP points from the csv file and then rearranging them according to the function
def maskgeoreferencing(input_raster,output_raster,gcp_points):
  os.makedirs(output_raster, exist_ok=True) 
  f=pd.read_csv(gcp_points)
  keep_col = ['mapX','mapY','sourceX', 'sourceY', 'enable', 'dX','dY', 'residual']
  #['mapX','mapY','sourceX', 'sourceY', 'enable', 'dX','dY', 'residual']
  new_f = f[keep_col]
  df = new_f.drop(columns=['enable','dX', 'dY', 'residual'])
  col=['mapX','mapY', 'sourceX','sourceY']
  modified_df = df[col]
  modified_df['sourceY'] = modified_df['sourceY']*(-1)
  gcp_list=[]
  # Create a copy of the original file and save it as the output filename:
  out_file= output_raster + 'georeferenced' + os.path.basename(input_raster) 
  src_ds = gdal.Open(input_raster)
  format = "GTiff"
  driver = gdal.GetDriverByName(format)  
  # Open destination dataset
  dst_ds = driver.CreateCopy(out_file, src_ds, 0)
  for index, rows in modified_df.iterrows():
   gcps = gdal.GCP(rows.mapX, rows.mapY, 1, rows.sourceX, rows.sourceY )
   gcp_list.append(gcps)
   
  # Get raster projection
  srs = osr.SpatialReference()
  srs.ImportFromEPSG(4326) # WGS84 (EPSG:4326)
  #srs.ImportFromProj4("+proj=aea +lat_1=15 +lat_2=65 +lat_0=30 +lon_0=95 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m no_defs") 
  dest_wkt = srs.ExportToWkt()
  
  # Set projection
  dst_ds.SetProjection(dest_wkt)
  dst_ds.SetGCPs(gcp_list, dest_wkt)
  dst_ds = None
  src_ds = None

#workingDir="D:/BB/distribution_digitizer/"

#workingDir = "D:/distribution_digitizer-main"

def mainmaskgeoreferencingMaps(workingDir):
  output_raster= workingDir + "/data/output/georeferencing/maps/pointFiltering/"
  os.makedirs(output_raster, exist_ok=True) 
  inputdir = workingDir +"/data/output/maps/pointFiltering/"
  g_dir = workingDir + "/data/input/templates/geopoints/"
  for gcp_points in glob.glob(g_dir + "*.points"):
    for input_raster in glob.glob(inputdir + "*.tif"):
       maskgeoreferencing(input_raster, output_raster,gcp_points)

def mainmaskgeoreferencingMaps_CD(workingDir):
  output_raster= workingDir + "/data/output/georeferencing/maps/circleDetection/"
  os.makedirs(output_raster, exist_ok=True) 
  inputdir = workingDir +"/data/output/maps/circleDetection/"
  g_dir = workingDir + "/data/input/templates/geopoints/"
  for gcp_points in glob.glob(g_dir + "*.points"):
    for input_raster in glob.glob(inputdir + "*.tif"):
       maskgeoreferencing(input_raster, output_raster,gcp_points)
       
def mainmaskgeoreferencingMasks(workingDir):      
  output_raster= workingDir + "/data/output/georeferencing/masks/"
  os.makedirs(output_raster, exist_ok=True) 
  inputdir = workingDir +"/data/output/masking_black/"
  #inputdir = workingDir +"/data/output/masking/"
  g_dir = workingDir + "/data/input/templates/geopoints/"
  for gcp_points in glob.glob(g_dir + "*.points"):
    for input_raster in glob.glob(inputdir + "*.tif"):
       maskgeoreferencing(input_raster, output_raster,gcp_points)

def mainmaskgeoreferencingMasks_CD(workingDir):      
  output_raster= workingDir + "/data/output/georeferencing/masks/circleDetection/"
  os.makedirs(output_raster, exist_ok=True) 
  inputdir = workingDir +"/data/output/masking_black/circleDetection/"
  #inputdir = workingDir +"/data/output/masking/"
  g_dir = workingDir + "/data/input/templates/geopoints/"
  for gcp_points in glob.glob(g_dir + "*.points"):
    for input_raster in glob.glob(inputdir + "*.tif"):
       maskgeoreferencing(input_raster, output_raster,gcp_points)

def mainmaskgeoreferencingMasks_PF(workingDir):      
  output_raster= workingDir + "/data/output/georeferencing/masks/pointFiltering/"
  os.makedirs(output_raster, exist_ok=True) 
  inputdir = workingDir +"/data/output/masking_black/pointFiltering/"
  #inputdir = workingDir +"/data/output/masking/"
  g_dir = workingDir + "/data/input/templates/geopoints/"
  for gcp_points in glob.glob(g_dir + "*.points"):
    for input_raster in glob.glob(inputdir + "*.tif"):
       maskgeoreferencing(input_raster, output_raster,gcp_points)
