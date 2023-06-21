from osgeo import gdal, ogr, osr
import os,glob
os.environ['PROJ_LIB'] = "C:/ProgramData/miniconda3/Library/share/proj"

import numpy as np
import rasterio
from rasterio import plot
import os
from qgis.core import *
import os

def polygonize(input_raster, output_shape, dst_layername):
    
    input_raster = "D:/distribution_digitizer/data/output/georeferencing/georeferenced23_0069map_2_0__ladakensis_centralis_sculda_chitralensis_asiatica.tif"
    output_shape = "D:/distribution_digitizer/data/output/"
    dst_layername = "test55"
    #  get raster datasource
    src_ds = gdal.Open( input_raster )
    #
    srcband = src_ds.GetRasterBand(1)
    
    ## Shapefile available?
    driverName = "ESRI Shapefile"
    drv = ogr.GetDriverByName( driverName )
 
    dst_ds = drv.CreateDataSource( output_shape )

    sp_ref = osr.SpatialReference()
    sp_ref.SetFromUserInput('EPSG:4326')

    dst_layer = dst_ds.CreateLayer(dst_layername, srs = sp_ref )

    fld = ogr.FieldDefn("HA", ogr.OFTInteger)
    dst_layer.CreateField(fld)
    dst_field = dst_layer.GetLayerDefn().GetFieldIndex("HA")

    gdal.Polygonize( srcband, None, dst_layer, dst_field, [], callback=None )
    ##dst_ds.DeleteLayer('oilpalm77')
    #driver.DeleteDataSource(FileName)
    srcband = None
    src_ds = None
    dst_ds = None
    del src_ds
    del dst_ds
    #mask_ds = None


def mainPolygonize(workingDir):
  output= workingDir + "data/output/polygonize/"
  os.makedirs(output, exist_ok=True) 
  inputdir = workingDir +"data/output/georeferencing/masks/"
   
  for input_raster in glob.glob(inputdir + "*.tif"):
    dst_layername = os.path.basename(input_raster)
    output_shape = output + dst_layername
    polygonize(input_raster,output_shape, dst_layername)
