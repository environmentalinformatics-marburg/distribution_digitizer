#### Script for iteratively rectifying the georeferenced output GeoTIFF files from '5. Georeferencing'.

import sys
# Set path to proj.db file via the path to the conda environment currently in use
env = sys.prefix
proj = os.path.join(env, "Library/share/proj/")
os.environ['PROJ_LIB'] = proj

import rasterio
from osgeo import gdal, osr
import os, glob

def rectifying(input_raster, output_raster):
  
  # open source dataset
  src_ds = gdal.Open(input_raster)

  # define name of output raster
  output_raster, file_extension = os.path.splitext(output_raster)
  dst_path = output_raster + "_rectified.tif"
  
  # perform rectification using gdal.Warp()
  gdal.Warp(dst_path, src_ds)
  
  
def mainRectifying(workingDir):
  output= workingDir + "/data/output/rectifying/"
  os.makedirs(output, exist_ok=True) 
  inputdir = workingDir +"/data/output/georeferencing/masks/"
  
  for input_raster in glob.glob(inputdir + "*.tif"):
    print(input_raster)
    dst_layername = os.path.basename(input_raster)
    print(dst_layername)
    output_raster = output + dst_layername
    print(output_raster)
    rectifying(input_raster, output_raster)



