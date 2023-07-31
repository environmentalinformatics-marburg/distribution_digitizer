from osgeo import gdal, ogr, osr
import os,glob
#os.environ['PROJ_LIB'] = "C:/ProgramData/miniconda3/Library/share/proj"
#os.environ['PROJ_LIB'] = "C:/Users/user/miniconda3/Library/share/proj/"

import sys
# Set path to proj.db file via the path to the conda environment currently in use
env = sys.prefix
proj = os.path.join(env, "Library/share/proj/")
os.environ['PROJ_LIB'] = proj

import numpy as np
import rasterio
from rasterio import plot
import os
#from qgis.core import *
#import os
from affine import Affine

def polygonize(input_raster, output_shape, dst_layername):
  
    #input_raster = "D:/distribution_digitizer/data/output/georeferencing/georeferenced23_0069map_2_0__ladakensis_centralis_sculda_chitralensis_asiatica.tif"
    #output_shape = "D:/distribution_digitizer/data/output/"
    #dst_layername = "test55"
    #  get raster datasource
    src_ds = gdal.Open( input_raster )
    #
    srcband = src_ds.GetRasterBand(1)
    
    ## Shapefile available?
    driverName = "ESRI Shapefile"
    drv = ogr.GetDriverByName( driverName )
    
    extension = "_rectified.tif"
    output_shape = output_shape.replace(extension, "")
    
    dst_ds = drv.CreateDataSource( output_shape )
    
    # get affine transformation matrix
    transform = src_ds.GetGeoTransform()
    affine = Affine(transform[1], transform[2], transform[0], transform[4], transform[5], transform[3])
    
    sp_ref = osr.SpatialReference()
    sp_ref.SetFromUserInput('EPSG:4326')

    extension = "_rectified.tif"
    dst_layername = dst_layername.replace(extension, "")
    dst_layer = dst_ds.CreateLayer(dst_layername, srs = sp_ref )
    
    fld = ogr.FieldDefn("HA", ogr.OFTInteger)
    dst_layer.CreateField(fld)
    dst_field = dst_layer.GetLayerDefn().GetFieldIndex("HA")
    
    gdal.Polygonize( srcband, None, dst_layer, dst_field, [], callback=None )
    
    # loop over polygon features and filter polygons with 'HA' value of 255 to just keep the distribution extents
    extracted_features = []
    layer = dst_ds.GetLayer()
    for feature in layer:
        ha_value = feature.GetField("HA")
        if ha_value == 255:
            extracted_features.append(feature.Clone())

    # create new layer and save the filtered features
    dst_layer = dst_ds.CreateLayer(dst_layername + "_filtered", srs=sp_ref)
    dst_layer.CreateField(fld)
    for feature in extracted_features:
        dst_layer.CreateFeature(feature)
        feature.Destroy()
    
    ##dst_ds.DeleteLayer('oilpalm77')
    #driver.DeleteDataSource(FileName)
    srcband = None
    src_ds = None
    dst_ds = None
    del src_ds
    del dst_ds
    #mask_ds = None


#workingDir="D:/BB/distribution_digitizer/"

def mainPolygonize(workingDir):
  output= workingDir + "/data/output/polygonize/"
  os.makedirs(output, exist_ok=True) 
  inputdir = workingDir +"/data/output/rectifying/"
  
  for input_raster in glob.glob(inputdir + "*.tif"):
    print(input_raster)
    dst_layername = os.path.basename(input_raster)
    print(dst_layername)
    output_shape = output + dst_layername
    print(output_shape)
    polygonize(input_raster, output_shape, dst_layername)
