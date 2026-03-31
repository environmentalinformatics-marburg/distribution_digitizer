# ============================================================
# File: mask_georeferencing.py
# Author: Spaska Forteva
# Modified on 2023/11/10 by Kai Richter
# Last modified on 2026/03/32 by Spaska Forteva:
#
# Description:
# This script performs georeferencing of raster images using
# Ground Control Points (GCPs).
#
# It transforms pixel-based image coordinates into real-world
# geographic coordinates (WGS84), enabling spatial analysis
# of detected features such as centroids and symbols.
#
# The script supports multiple processing variants:
# - maps (point filtering / circle detection)
# - masks (centroid masks)
#
# This step represents the transition from image space to
# geographic coordinate space.
# ============================================================
from osgeo import gdal, gdalconst
import string
from functools import reduce
import shutil
from osgeo import gdal, osr
import pandas as pd
import os, glob
import sys
#os.environ['PROJ_LIB'] = "C:/ProgramData/miniconda3/Library/share/proj"
#os.environ['PROJ_LIB'] = "C:/Users/user/miniconda3/Library/share/proj/"



# ------------------------------------------------------------
# Core georeferencing function using GCPs
# ------------------------------------------------------------
# Core idea:
# - Read Ground Control Points (GCPs)
# - Assign them to the raster image
# - Define spatial reference (WGS84)
#
# Output:
# - Georeferenced GeoTIFF file
#
# Important:
# - This does NOT yet warp the image
#   → only assigns spatial reference and GCPs
# ------------------------------------------------------------
def maskgeoreferencing(input_raster, output_raster, gcp_points):

    try:
        os.makedirs(output_raster, exist_ok=True)

        print("\n--- maskgeoreferencing ---")
        print("Input raster:", input_raster)
        print("GCP file:", gcp_points)

        # ---------- Read GCP file ----------
        f = pd.read_csv(gcp_points)

        required_cols = ['mapX','mapY','sourceX','sourceY']
        for col in required_cols:
            if col not in f.columns:
                print(f"⚠️ Missing column {col} in {gcp_points}")
                return

        df = f[required_cols].copy()

        # --------------------------------------------------------
        # Coordinate transformation (important!)
        # --------------------------------------------------------
        df['sourceY'] = df['sourceY'] * (-1)

        if df.empty:
            print("⚠️ No valid GCP points found")
            return

        # --------------------------------------------------------
        # Open input raster
        # --------------------------------------------------------
        src_ds = gdal.Open(input_raster)
        if src_ds is None:
            print("❌ Could not open raster")
            return

        out_file = os.path.join(output_raster, os.path.basename(input_raster))

        driver = gdal.GetDriverByName("GTiff")
        dst_ds = driver.CreateCopy(out_file, src_ds, 0)

        if dst_ds is None:
            print("❌ Could not create output file")
            return

        # --------------------------------------------------------
        # Create GCP list
        # --------------------------------------------------------
        gcp_list = []
        for _, row in df.iterrows():
            gcp = gdal.GCP(
                float(row.mapX),
                float(row.mapY),
                1,
                float(row.sourceX),
                float(row.sourceY)
            )
            gcp_list.append(gcp)

        if not gcp_list:
            print("⚠️ GCP list empty")
            return

        # --------------------------------------------------------
        # Define spatial reference system (WGS84)
        # --------------------------------------------------------
        srs = osr.SpatialReference()
        srs.ImportFromEPSG(4326)
        dest_wkt = srs.ExportToWkt()

        dst_ds.SetProjection(dest_wkt)
        dst_ds.SetGCPs(gcp_list, dest_wkt)

        print("✅ Georeferencing successful:", out_file)

    except Exception as e:
        print("❌ ERROR in maskgeoreferencing:", e)

    finally:
        try:
            dst_ds = None
        except:
            pass
        try:
            src_ds = None
        except:
            pass


# ------------------------------------------------------------
# Georeferencing maps (Point Filtering results)
# ------------------------------------------------------------
def mainmaskgeoreferencingMaps(workingDir, outDir):
  output_raster= os.path.join(outDir,"georeferencing", "maps","pointFiltering")
  os.makedirs(output_raster, exist_ok=True) 
  inputdir = os.path.join(outDir, "maps", "pointFiltering")
  g_dir = os.path.join(workingDir,"data", "input", "templates", "geopoints")
  
  for gcp_points in glob.glob(g_dir + "/*.points"):
    for input_raster in glob.glob(inputdir + "/*.tif"):
       maskgeoreferencing(input_raster, output_raster,gcp_points)

def mainmaskgeoreferencingMaps_CD(workingDir, outDir):
  output_raster = os.path.join(outDir,"georeferencing", "maps","circleDetection")
  os.makedirs(output_raster, exist_ok=True) 
  inputdir = os.path.join(outDir,"maps", "circleDetection")
  print("Output Directory:")
  print(output_raster)
  print("Input Directory:")
  print(inputdir)
  g_dir = os.path.join(workingDir,"data", "input", "templates", "geopoints")
  
  for gcp_points in glob.glob(g_dir + "/*.points"):
    for input_raster in glob.glob(inputdir + "/*.tif"):
       maskgeoreferencing(input_raster, output_raster,gcp_points)
       
def mainmaskgeoreferencingMasks(workingDir, outDir):      
  output_raster= os.path.join(outDir,"georeferencing", "masks")
  os.makedirs(output_raster, exist_ok=True) 
  inputdir = os.path.join(outDir,"masking_black")
  g_dir = os.path.join(workingDir,"data", "input", "templates", "geopoints")
  
  for gcp_points in glob.glob(g_dir + "/*.points"):
    for input_raster in glob.glob(inputdir + "/*.tif"):
       maskgeoreferencing(input_raster, output_raster,gcp_points)



# ------------------------------------------------------------
# Georeferencing maps (Circle Detection results)
# ------------------------------------------------------------
def mainmaskgeoreferencingMasks_CD(workingDir, outDir):      
  output_raster= os.path.join(outDir, "georeferencing", "masks", "circleDetection")
  os.makedirs(output_raster, exist_ok=True) 
  inputdir = os.path.join(outDir, "masking_black", "circleDetection")
  g_dir = os.path.join(workingDir,"data", "input", "templates", "geopoints")
  print("Output Directory:")
  print(output_raster)
  print("Input Directory:")
  print(g_dir)
  for gcp_points in glob.glob(g_dir + "/*.points"):
    print(gcp_points)
    for input_raster in glob.glob(inputdir + "/*.tif"):
       print(input_raster)
       maskgeoreferencing(input_raster, output_raster,gcp_points)
       

# ------------------------------------------------------------
# Georeferencing masks (generic)
# ------------------------------------------------------------
def mainmaskgeoreferencingMasks_PF(workingDir, outDir, nMapTypes=1):
    print("workingDir =", workingDir)
    print("Full GCP path =", os.path.join(workingDir, "data", "input", "templates", "1", "geopoints"))
    workingDir = workingDir.strip()  # ← entfernt unsichtbare Zeichen
    g_base = os.path.normpath(os.path.join(workingDir, "data", "input", "templates"))

    print(f"DEBUG: nMapTypes = {nMapTypes}")

    for i in range(1, nMapTypes + 1):

        print(f"\n=== Processing map type {i} ===")

        inputdir = os.path.join(outDir, str(i), "masking_black", "pointFiltering")
        output_raster = os.path.join(outDir, str(i), "georeferencing", "masks", "pointFiltering")
        g_dir = os.path.join(g_base, str(i),"geopoints")

        os.makedirs(output_raster, exist_ok=True)

        print("Input directory:", inputdir)
        print("GCP directory:", g_dir)
        print("Directory exists:", os.path.exists(g_dir))
        print("Directory listing:", os.listdir(g_dir) if os.path.exists(g_dir) else "does not exist")
        tif_files = glob.glob(os.path.join(inputdir, "*.tif"))
        gcp_files = glob.glob(os.path.join(g_dir, "*.points"))

        print("Found tif files:", tif_files)
        print("Found gcp files:", gcp_files)

        if not tif_files:
            print("⚠️ No tif files found")
            continue

        if not gcp_files:
            print("⚠️ No gcp files found")
            continue

        gcp_points = gcp_files[0]   # normalerweise nur eine Datei pro MapType

        for input_raster in tif_files:
            print("Processing:", input_raster)
            maskgeoreferencing(input_raster, output_raster, gcp_points)
                

#mainmaskgeoreferencingMasks_PF(" D:/distribution_digitizer/", "D:/test/output_2026-02-20_08-40-28/", 2)


