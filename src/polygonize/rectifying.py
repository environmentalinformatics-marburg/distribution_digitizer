"""
File: rectifying.py
Author: Kai Richter
Date: 2023-07-31
Last modified on 2023-11-10 by Kai Richter:
  Addition of functions mainRectifying_CD and mainRectifying_PF
Last modified on 2024-03-15 by Spaska Forteva:
  add try and error messages

Description: 
Script for iteratively rectifying the georeferenced output GeoTIFF files from '5. Georeferencing'.

The function 'rectifying' fills edges of input tif files with pixels of value "0", if the edges are warped and not straight.

The function 'mainRectifying' processes it for the output files of masked symbols. 

The function 'mainRectifying_CD' processes it for the output files of masked centroids detected by Circle Detection. 

The function 'mainRectifying_PF' processes it for the output files of masked centroids detected by Point Filtering. 
"""


#### Script for iteratively rectifying the georeferenced output GeoTIFF files from '5. Georeferencing'.

import sys

import rasterio
from osgeo import gdal, osr
import os, glob

def rectifying(input_raster, output_raster):
    # Öffnen des Quell-Datasets
    src_ds = gdal.Open(input_raster)
    if src_ds is None:
        print(f"Fehler beim Öffnen der Eingabedatei: {input_raster}")
        return
    
    # Bestimmen des Ausgabepfads
    output_raster, file_extension = os.path.splitext(output_raster)
    dst_path = output_raster + ".tif"
    
    # Überprüfen, ob das Zielverzeichnis vorhanden ist, andernfalls erstellen
    output_dir = os.path.dirname(dst_path)
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    try:
        # Ausführen der Rektifizierung mit gdal.Warp()
        dst_ds = gdal.Warp(dst_path, src_ds)
        dst_ds = None
        src_ds = None
        print(f"Rektifizierte Datei gespeichert: {dst_path}")
    except Exception as e:
        print(f"Fehler bei der Rektifizierung: {e}")

#input_raster = "D:/test/output_2024-07-12_08-18-21/georeferencing/maps/pointFiltering"


def mainRectifying_Map_PF(workingDir, outDir):
    try:
        output = os.path.join(outDir, "rectifying", "maps")
        os.makedirs(output, exist_ok=True) 
        inputdir = os.path.join(outDir, "georeferencing", "maps", "pointFiltering")
        print("Input Directory:", inputdir)
        
        # Adjusted glob.glob to correctly capture all TIFF files
        for input_raster in glob.glob(inputdir + "/*.tif"):
            print("Input TIFF:", input_raster)
            dst_layername = os.path.basename(input_raster)
            print("Destination Layer Name:", dst_layername)
            output_raster = os.path.join(output, dst_layername)
            print("Output Raster Path:", output_raster)
            # Assuming rectifying() is a function you have defined elsewhere
            rectifying(input_raster, output_raster)
    
    except Exception as e:
        print("An error occurred in mainRectifying_Map_PF:", e)
    # End of function


def mainRectifying(workingDir, outDir):
  try:
    output= outDir + "/rectifying/"
    os.makedirs(output, exist_ok=True) 
    inputdir = outDir +"/georeferencing/masks/"
    print(inputdir)
    for input_raster in glob.glob(inputdir + "*.tif"):
      print(input_raster)
      dst_layername = os.path.basename(input_raster)
      print(dst_layername)
      output_raster = output + dst_layername
      print(output_raster)
      rectifying(input_raster, output_raster)
  except Exception as e:
        print("An error occurred in mainRectifying:", e)
  # End of function


def mainRectifying_CD(workingDir, outDir):
  try:
    output= outDir + "/rectifying/circleDetection/"
    os.makedirs(output, exist_ok=True) 
    inputdir = outDir +"/georeferencing/masks/circleDetection/"
    
    for input_raster in glob.glob(inputdir + "*.tif"):
      print(input_raster)
      dst_layername = os.path.basename(input_raster)
      print(dst_layername)
      output_raster = output + dst_layername
      print(output_raster)
      rectifying(input_raster, output_raster)
  except Exception as e:
        print("An error occurred in mainRectifying_CD:", e)
  # End of function


def mainRectifying_PF(workingDir, outDir, nMapTypes=1):

    print(f"DEBUG Rectifying nMapTypes = {nMapTypes}")

    for i in range(1, nMapTypes + 1):

        print(f"\n=== Rectifying map type {i} ===")

        inputdir = os.path.join(
            outDir, str(i), "georeferencing", "masks", "pointFiltering"
        )

        output = os.path.join(
            outDir, str(i), "rectifying", "pointFiltering"
        )

        os.makedirs(output, exist_ok=True)

        print("Input directory:", inputdir)
        print("Output directory:", output)

        tif_files = glob.glob(os.path.join(inputdir, "*.tif"))

        if not tif_files:
            print("⚠️ No tif files found for rectifying")
            continue

        for input_raster in tif_files:
            print("Rectifying:", input_raster)

            dst_layername = os.path.basename(input_raster)
            output_raster = os.path.join(output, dst_layername)

            rectifying(input_raster, output_raster)

#mainRectifying_PF( "D:/distribution_digitizer/", "D:/test/output_2026-02-20_08-40-28/", 2)
