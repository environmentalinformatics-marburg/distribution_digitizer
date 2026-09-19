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
import csv
import math
import hashlib
import statistics
import base64
import uuid
import json


def calibration_srs(crs):
    if crs and crs.startswith("base64:"):
        crs = base64.b64decode(crs[7:]).decode("utf-8")
    srs = osr.SpatialReference()
    if not crs or srs.SetFromUserInput(crs) != 0:
        raise ValueError("Invalid calibration CRS")
    # GCP mapX/mapY and GDAL rasters use X/Y, including lon/lat for EPSG:4326.
    srs.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER)
    if not (srs.IsProjected() or srs.IsGeographic()):
        raise ValueError("Calibration requires a projected or geographic CRS")
    return srs


def points_hash(path):
    with open(path, "rb") as stream:
        return hashlib.sha256(stream.read()).hexdigest()


def finite_xy(x, y):
    values = float(x), float(y)
    if not all(math.isfinite(v) for v in values):
        raise ValueError("X and Y corrections must be finite numbers")
    return values


def read_calibration_config(working_dir):
    path = os.path.join(working_dir, "config", "config.csv")
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8-sig", newline="") as stream:
        return dict(csv.reader(stream, delimiter=";", quoting=csv.QUOTE_NONE))


def configured_correction(config, map_type):
    prefix = "georefCalibration_" + str(map_type) + "_"
    if str(config.get(prefix + "enabled", "false")).lower() != "true":
        return None
    return {key: config.get(prefix + key) for key in ("x", "y", "crs", "gcpHash")}


def validate_correction(correction, crs, points):
    if correction is None:
        return 0.0, 0.0
    xy = finite_xy(correction["x"], correction["y"])
    if not calibration_srs(crs).IsSame(calibration_srs(correction["crs"])):
        raise ValueError("Calibration CRS differs from the GCP CRS; recalibrate this map type")
    if correction.get("gcpHash") != points_hash(points):
        raise ValueError("GCP file changed since calibration; recalibrate this map type")
    return xy


def calibration_context(working_dir, map_type):
    if not str(map_type).isdigit():
        raise ValueError("Select a map type")
    paths = glob.glob(os.path.join(working_dir, "data", "input", "templates",
                                   str(map_type), "geopoints", "*.points"))
    if len(paths) != 1:
        raise ValueError("Calibration requires exactly one .points file in this map type's geopoints folder")
    path = paths[0]
    for encoding in ("utf-8-sig", "cp1252"):
        try:
            frame = pd.read_csv(path, comment="#", encoding=encoding)
            break
        except UnicodeDecodeError:
            continue
    values = frame[["mapX", "mapY", "sourceX", "sourceY"]].astype(float)
    if len(values) < 3 or not all(math.isfinite(v) for v in values.to_numpy().flat):
        raise ValueError("The .points file needs at least three finite GCPs")
    gcps = [gdal.GCP(row.mapX, row.mapY, 1, row.sourceX, -row.sourceY)
            for row in values.itertuples()]
    affine = gdal.GCPsToGeoTransform(gcps)
    if affine is None or abs(affine[1] * affine[5] - affine[2] * affine[4]) == 0:
        raise ValueError("The .points file does not define a valid two-dimensional transformation")
    # Legacy files may omit CRS; an explicitly invalid declaration is not legacy.
    with open(path, encoding="utf-8", errors="replace") as stream:
        for line in stream:
            if line.startswith("#CRS:"):
                calibration_srs(line[5:].strip())
    crs = read_crs_from_points(path)
    srs = calibration_srs(crs)
    return {"points": path, "crs": crs, "gcpHash": points_hash(path),
            "units": srs.GetAngularUnitsName() if srs.IsGeographic() else srs.GetLinearUnitsName(),
            "name": srs.GetName()}


def calibration_raster(path, context):
    ds = gdal.Open(path)
    if ds is None or ds.GetGeoTransform(can_return_null=True) is None:
        raise ValueError("Select a rectified geospatial TIFF")
    if not calibration_srs(ds.GetProjection()).IsSame(calibration_srs(context["crs"])):
        raise ValueError("TIFF CRS differs from the current .points CRS; rerun georeferencing")
    metadata = ds.GetMetadataItem("DD_CALIBRATION")
    baseline = json.loads(metadata) if metadata else None
    if baseline is not None:
        validate_correction(baseline, context["crs"], context["points"])
    return ds, baseline or {"x": 0.0, "y": 0.0}


def calibration_initial(path, context):
    ds, baseline = calibration_raster(path, context)
    return {"x": float(baseline["x"]), "y": float(baseline["y"])}


def calibration_center(ds, baseline, x, y):
    gt = ds.GetGeoTransform()
    return (gt[0] + ds.RasterXSize * gt[1] / 2 + ds.RasterYSize * gt[2] / 2 + x - float(baseline["x"]),
            gt[3] + ds.RasterXSize * gt[4] / 2 + ds.RasterYSize * gt[5] / 2 + y - float(baseline["y"]))


def calibration_move(path, context, x, y, east, north):
    """Convert a local metre displacement to a native-CRS translation at the centre."""
    x, y = finite_xy(x, y)
    east, north = finite_xy(east, north)
    ds, baseline = calibration_raster(path, context)
    cx, cy = calibration_center(ds, baseline, x, y)
    native, wgs = calibration_srs(context["crs"]), calibration_srs("EPSG:4326")
    lon, lat, _ = osr.CoordinateTransformation(native, wgs).TransformPoint(cx, cy)
    local = calibration_srs(f"+proj=aeqd +lat_0={lat} +lon_0={lon} +datum=WGS84 +units=m")
    nx, ny, _ = osr.CoordinateTransformation(local, native).TransformPoint(east, north)
    nx, ny = finite_xy(x + nx - cx, y + ny - cy)
    return {"x": nx, "y": ny}


def calibration_preview(path, context, x, y):
    """Translate in the GCP CRS, then warp a bounded preview to Leaflet's Mercator."""
    x, y = finite_xy(x, y)
    ds, baseline = calibration_raster(path, context)
    # A VRT avoids loading the original large raster or modifying it on disk.
    shifted = gdal.Translate("", ds, format="VRT")
    gt = list(ds.GetGeoTransform())
    gt[0] += x - float(baseline["x"])
    gt[3] += y - float(baseline["y"])
    shifted.SetGeoTransform(gt)
    warped = gdal.Warp("", shifted, format="MEM", dstSRS="EPSG:3857",
                       width=900, height=900, dstAlpha=True, srcNodata=0)
    if warped is None:
        raise ValueError("Could not project this TIFF for OpenStreetMap")
    gt = warped.GetGeoTransform()
    transform = osr.CoordinateTransformation(calibration_srs("EPSG:3857"), calibration_srs("EPSG:4326"))
    west, north, _ = transform.TransformPoint(gt[0], gt[3])
    east, south, _ = transform.TransformPoint(gt[0] + 900 * gt[1], gt[3] + 900 * gt[5])
    if not all(math.isfinite(v) for v in (west, south, east, north)) or max(abs(north), abs(south)) > 85.0512:
        raise ValueError("Overlay is outside the OpenStreetMap latitude range")
    name = "/vsimem/calibration_" + uuid.uuid4().hex + ".png"
    try:
        png = gdal.Translate(name, warped, format="PNG", outputType=gdal.GDT_Byte)
        if png is None:
            raise ValueError("Could not render overlay")
        png = None
        data = bytes(gdal.VSIGetMemFileBuffer_unsafe(name))
        return {"uri": "data:image/png;base64," + base64.b64encode(data).decode("ascii"),
                "bounds": [[south, west], [north, east]]}
    finally:
        gdal.Unlink(name)
        gdal.Unlink(name + ".aux.xml")


def calibration_summary(paths, xs, ys, context):
    if len(paths) != 3 or len(set(os.path.realpath(p) for p in paths)) != 3 or len(xs) != 3 or len(ys) != 3:
        raise ValueError("Save positions for three different training maps")
    pairs = [finite_xy(x, y) for x, y in zip(xs, ys)]
    x, y = statistics.median(v[0] for v in pairs), statistics.median(v[1] for v in pairs)
    # Compare differences in local metres, including angular/feet-based CRSs.
    # Warn above 5 km or 25% of the median movement, whichever is greater.
    distances, movements = [], []
    native, wgs = calibration_srs(context["crs"]), calibration_srs("EPSG:4326")
    for path, (dx, dy) in zip(paths, pairs):
        ds, baseline = calibration_raster(path, context)
        cx, cy = calibration_center(ds, baseline, 0, 0)
        lon, lat, _ = osr.CoordinateTransformation(native, wgs).TransformPoint(cx, cy)
        local = calibration_srs(f"+proj=aeqd +lat_0={lat} +lon_0={lon} +datum=WGS84 +units=m")
        transform = osr.CoordinateTransformation(native, local)
        mx, my, _ = transform.TransformPoint(cx + x, cy + y)
        tx, ty, _ = transform.TransformPoint(cx + dx, cy + dy)
        distances.append(math.hypot(tx - mx, ty - my))
        movements.append(math.hypot(mx, my))
    if not all(math.isfinite(v) for v in distances + movements):
        raise ValueError("Correction is outside this CRS's valid extent")
    spread = max(distances)
    return {"x": x, "y": y, "spreadMetres": spread,
            "warning": spread > max(5000, 0.25 * statistics.median(movements))}
#os.environ['PROJ_LIB'] = "C:/ProgramData/miniconda3/Library/share/proj"
#os.environ['PROJ_LIB'] = "C:/Users/user/miniconda3/Library/share/proj/"


def read_crs_from_points(gcp_points):
    """
    Read CRS information from a QGIS .points file.

    If the file contains a '#CRS:' line, this CRS is used.
    For older .points files without CRS information,
    EPSG:4326 is used as fallback to preserve the old workflow.
    """

    for encoding in ["utf-8", "cp1252"]:

        try:
            with open(gcp_points, "r", encoding=encoding) as f:

                for line in f:

                    if line.startswith("#CRS:"):

                        crs_wkt = line.replace("#CRS:", "", 1).strip()

                        srs = osr.SpatialReference()

                        if srs.SetFromUserInput(crs_wkt) == 0:
                            print("GCP CRS found:", srs.GetName())
                            return srs.ExportToWkt()

            # Datei konnte gelesen werden,
            # aber keine CRS-Zeile gefunden
            break

        except UnicodeDecodeError:
            continue

    # --------------------------------------------------------
    # Fallback for old .points files
    # --------------------------------------------------------
    print("⚠️ No CRS information found in .points file.")
    print("Using EPSG:4326 as fallback for legacy data.")

    srs = osr.SpatialReference()
    srs.ImportFromEPSG(4326)

    return srs.ExportToWkt()
  
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
def maskgeoreferencing(input_raster, output_raster, gcp_points, correction=None):

    try:
        os.makedirs(output_raster, exist_ok=True)

        print("\n--- maskgeoreferencing ---")
        print("Input raster:", input_raster)
        print("GCP file:", gcp_points)

        # ---------- Read GCP file ----------
        try:
            f = pd.read_csv(
                gcp_points,
                encoding="utf-8",
                comment="#"
            )
            print("GCP encoding: UTF-8")
        
        except UnicodeDecodeError:
            f = pd.read_csv(
                gcp_points,
                encoding="cp1252",
                comment="#"
            )
            print("GCP encoding: CP1252")

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

        dest_wkt = read_crs_from_points(gcp_points)
        dx, dy = validate_correction(correction, dest_wkt, gcp_points)
        # Translate world coordinates, never source pixels. This precedes Warp
        # and polygonization so every downstream representation inherits it.
        if dx != 0 or dy != 0:
            df['mapX'] = df['mapX'] + dx
            df['mapY'] = df['mapY'] + dy

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
        # Read CRS from .points file
        # --------------------------------------------------------
        dest_wkt = read_crs_from_points(gcp_points)

        dst_ds.SetProjection(dest_wkt)
        dst_ds.SetGCPs(gcp_list, dest_wkt)
        if correction is not None:
            dst_ds.SetMetadataItem("DD_CALIBRATION", json.dumps({
                "x": dx, "y": dy, "crs": dest_wkt,
                "gcpHash": points_hash(gcp_points)}))

        print("✅ Georeferencing successful:", out_file)

    except Exception as e:
        print("❌ ERROR in maskgeoreferencing:", e)
        if correction is not None:
            raise

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
def mainmaskgeoreferencingMasks_PF(workingDir, outDir, nMapTypes=1, config=None):
    print("workingDir =", workingDir)
    print("Full GCP path =", os.path.join(workingDir, "data", "input", "templates", "1", "geopoints"))
    workingDir = workingDir.strip()  # ← entfernt unsichtbare Zeichen
    if config is None:
        config = read_calibration_config(workingDir)
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
        correction = configured_correction(config, i)
        if correction is not None:
            if len(gcp_files) != 1:
                raise ValueError("Calibration requires exactly one .points file per map type")
            validate_correction(correction, read_crs_from_points(gcp_points), gcp_points)

        for input_raster in tif_files:
            print("Processing:", input_raster)
            maskgeoreferencing(input_raster, output_raster, gcp_points, correction)
                

#mainmaskgeoreferencingMasks_PF(" D:/distribution_digitizer/", "D:/test/output_2026-02-20_08-40-28/", 2)


