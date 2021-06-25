# -*- coding: utf-8 -*-
"""
Created on Mon Jun 21 11:01:17 2021

@author: venkates
"""
from osgeo import gdal, gdalconst
import string
from functools import reduce
import shutil
from osgeo import gdal, osr
import pandas as pd
import os,glob

# Working with the Input GCP points from the csv file and then rearranging them according to the function
def georeferencing(input_raster,output_raster,gcp_points):
  f=pd.read_csv(gcp_points)
  keep_col = ['mapX','mapY','pixelX', 'pixelY', 'enable', 'dX','dY', 'residual']
  new_f = f[keep_col]
  df = new_f.drop(columns=['enable','dX', 'dY', 'residual'])
  col=['mapX','mapY', 'pixelX','pixelY']
  modified_df = df[col]
  modified_df['pixelY'] = modified_df['pixelY']*(-1)
  gcp_list=[]
# Create a copy of the original file and save it as the output filename:
  out_file= output_raster + 'modified' + os.path.basename(input_raster) 
  shutil.copy(input_raster, out_file)
# Open the output file for writing for writing:
  ds = gdal.Open(out_file, gdalconst.GA_Update)
# Set spatial reference:
  sr = osr.SpatialReference()
  #sr.ImportfromESCP() for using ESCP
  sr.ImportFromProj4("+proj=aea +lat_1=15 +lat_2=65 +lat_0=30 +lon_0=95 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m no_defs") 
# GCP coordinates list  
  for index, rows in modified_df.iterrows():
   gcps = gdal.GCP(rows.mapX, rows.mapY, 1, rows.pixelX,rows.pixelY )
   gcp_list.append(gcps)
# Final Project
  wkt = ds.GetProjection()
  gcpcount = ds.GetGCPCount( )
  ds.SetGCPs( gcp_list, wkt )

#Clear the output file if it is opened anywhere else
  ds=None
  
def maingeoreferencing(workingDir):
 output_raster= workingDir + "data/output/georeferencing/"
 inputdir = workingDir +"data/output/pixelc/"
 g_dir = workingDir + "data/templates/geopoints/"
 for gcp_points in glob.glob(g_dir + "*.tif.points"):
    for input_raster in glob.glob(inputdir + "*.tif"):
      georeferencing(input_raster, output_raster,gcp_points)
