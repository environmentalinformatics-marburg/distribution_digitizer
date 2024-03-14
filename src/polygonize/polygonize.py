"""
File: polygonize.py
Author: Spaska Forteva

Last modified on :
  2023-11-10 by Kai Richter
  Addition of functions mainPolygonize_CD and mainPolygonize_PF
  2024-03-14 by Spaska Forteva
  Addition the param outDir in mainPolygonize
  
Description: 
Script for polygonizing the rectified output of georeferenced tif files. 

Function 'polygonize': Polygonizes the pixels of an input tif file. The relevant pixels representing the symbols or the 
symbol centroids are filtered and written out. 
  
Function 'mainPolygonize': Polygonizes the georeferenced masks containing detected symbols. 

Function 'mainPolygonize_CD': Polygonizes the georeferenced masks containing centroids detected by Circle Detection.

Function 'mainPolygonize_PF': Polygonizes the georeferenced masks containing centroids detected by Point Filtering.
"""


from osgeo import gdal, ogr, osr
import os
import glob
import sys
import numpy as np
import rasterio

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
    
    extension = "_rectified.tif"
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

    output= outDir + "/polygonize/"
    inputdir = outDir +"/rectifying/"
    
    for input_raster in glob.glob(inputdir + "*.tif"):
        print(input_raster)
        dst_layername = os.path.basename(input_raster)
        print(dst_layername)
        output_shape = output + dst_layername
        print(output_shape)
        polygonize(input_raster, output_shape, dst_layername)


def mainPolygonize_CD(workingDir, outDir):
    """
    Executes the polygonize function for georeferenced masks containing centroids detected by Circle Detection.

    Args:
        workingDir (str): Directory containing the input raster images.
        outDir (str): Output directory to save the polygonized shapefiles.

    Returns:
        None
    """
    output= outDir + "/polygonize/circleDetection/"
    inputdir = outDir +"/rectifying/circleDetection/"
    
    for input_raster in glob.glob(inputdir + "*.tif"):
        print(input_raster)
        dst_layername = os.path.basename(input_raster)
        print(dst_layername)
        output_shape = output + dst_layername
        print(output_shape)
        polygonize(input_raster, output_shape, dst_layername)


def mainPolygonize_PF(workingDir, outDir):
    """
    Executes the polygonize function for georeferenced masks containing centroids detected by Point Filtering.

    Args:
        workingDir (str): Directory containing the input raster images.
        outDir (str): Output directory to save the polygonized shapefiles.

    Returns:
        None
    """
    output= outDir + "/polygonize/pointFiltering/"
    inputdir = outDir +"/rectifying/pointFiltering/"
    for input_raster in glob.glob(inputdir + "*.tif"):
        print(input_raster)
        dst_layername = os.path.basename(input_raster)
        print(dst_layername)
        output_shape = output + dst_layername
        print(output_shape)
        polygonize(input_raster, output_shape, dst_layername)
