from osgeo import gdal, gdalconst
import string
from functools import reduce
import shutil
from osgeo import gdal, osr
import pandas as pd
import os,glob
os.environ['PROJ_LIB'] = "C:/ProgramData/miniconda3/Library/share/proj"
# Working with the Input GCP points from the csv file and then rearranging them according to the function
def maskgeoreferencing(input_raster,output_raster,gcp_points):
  workingDir="D:/distribution_digitizer/"
  output_raster= workingDir + "data/output/maps/align//"
  os.makedirs(output_raster, exist_ok=True) 
  input_raster = workingDir +"data/output/maps/align/2_0069map_2_0__ladakensis_centralis_sculda_chitralensis_asiatica.tif"
  gcp_points = workingDir + "data/input/templates/geopoints/10_ESRI_102025.points"
  
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
  #Load the original file
  out_file= output_raster + 'ggeo_translate' + os.path.basename(input_raster) 
  
  #Load the original file
  src_ds = gdal.Open(input_raster)
  
  format = "GTiff"
  #Create tmp dataset saved in memory
  driver = gdal.GetDriverByName(format)
  
  # Open destination dataset
  dst_ds = driver.CreateCopy(out_file, src_ds, 0)
  
  for index, rows in modified_df.iterrows():
   gcps = gdal.GCP(rows.mapX, rows.mapY, 1, rows.sourceX, rows.sourceY )
   gcp_list.append(gcps)
   
# Set raster projection
  srs = osr.SpatialReference()
  
  #srs.ImportFromESRI(osr.SpatialReference(),'ESRI:102025')
  srs.ImportFromEPSG(4326) # WGS84 (EPSG:4326)
  #srs.ImportFromProj4("+proj=aea +lat_1=15 +lat_2=65 +lat_0=30 +lon_0=95 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m no_defs") 
  dest_wkt = srs.ExportToWkt()
# Set projection
  #dst_ds.SetGeoTransform([x, 1, 0, y, 0, -1])
        
  dst_ds.SetProjection(dest_wkt)
  dst_ds.SetGCPs(gcp_list, dest_wkt)
  output_ds = gdal.Translate(out_file, src_ds, format='GTiff', outputSRS=dst_ds)
  output_ds = None
  src_ds = None

workingDir="D:/distribution_digitizer/"

def mainmaskgeoreferencingMaps(workingDir):
  output_raster= workingDir + "data/output/georeferencing/maps/"
  os.makedirs(output_raster, exist_ok=True) 
  inputdir = workingDir +"data/output/pixels/classification/filtering/"
  g_dir = workingDir + "data/input/templates/geopoints/"
  for gcp_points in glob.glob(g_dir + "*.points"):
    for input_raster in glob.glob(inputdir + "*.tif"):
       maskgeoreferencing(input_raster, output_raster,gcp_points)
       
def mainmaskgeoreferencingMasks(workingDir):
  output_raster= workingDir + "data/output/georeferencing/masks/"
  os.makedirs(output_raster, exist_ok=True) 
  inputdir = workingDir +"data/output/masking_black/"
  g_dir = workingDir + "data/input/templates/geopoints/"
  for gcp_points in glob.glob(g_dir + "*.points"):
    for input_raster in glob.glob(inputdir + "*.tif"):
       maskgeoreferencing(input_raster, output_raster,gcp_points)
 

from osgeo import gdal, osr

def gdal_translate(input_file, output_file, output_epsg, gcps_file=None):
    """
    Wrapper function to perform gdal_translate operation with EPSG code and a .points file.
    :param input_file: Path to the input file.
    :param output_file: Path to the output file.
    :param output_epsg: EPSG code of the desired output projection.
    :param gcps_file: Path to the .points file containing Ground Control Points (optional).
    """
    # Open the input dataset
    input_ds = gdal.Open(input_file)

    # Create an output spatial reference with the specified EPSG code
    output_srs = osr.SpatialReference()
    output_srs.ImportFromEPSG(output_epsg)

    # Set the GCPs if a .points file is provided
    
    if gcps_file:
          srs = osr.SpatialReference()
          srs.ImportFromEPSG(4326) # WGS84 (EPSG:4326)
          dest_wkt = srs.ExportToWkt()
          input_ds.SetProjection(dest_wkt)
          input_ds.SetGCPs(gcp_list, dest_wkt)

    # Create the output dataset with the desired output projection
    output_ds = gdal.Translate(output_file, input_ds, format='GTiff', outputSRS=output_srs)

    # Close the datasets
    input_ds = None
    output_ds = None

# Example usage
input_file = 'D:/distribution_digitizer/data/output/pixels/classification/filtering/2_0064map_2_1__augias.tif'
output_file = 'D:/distribution_digitizer/data/output/pixels/classification/filtering/geoTranslate2_0064map_2_1__augias.tif'
output_epsg = 3857  # Example: EPSG code for Web Mercator
gcps_file = 'D:/distribution_digitizer/data/input/templates/geopoints/10_ESRI_102025.points'  # Example: Path to the .points file

gdal_translate(input_file, output_file, output_epsg, gcps_file)

 
 
       
def myGOE():
  import shutil
  from osgeo import gdal, osr

  orig_fn = 'D:/distribution_digitizer/data/output/pixels/classification/filtering/2_0064map_2_1__augias.tif'
  output_fn = 'D:/distribution_digitizer/data/output/pixels/classification/filtering/2_0064map_2_1__augias_geo3.tif'

  # Create a copy of the original file and save it as the output filename:
  shutil.copy(orig_fn, output_fn)

  # Open the output file for writing for writing:
  ds = gdal.Open(output_fn, gdal.GA_Update)
  ds = gdal.Translate(output_fn, orig_fn)
  # Set spatial reference:
  sr = osr.SpatialReference()
  sr.ImportFromEPSG(4326) #My projection system

# Enter the GCPs
#   Format: [map x-coordinate(longitude)], [map y-coordinate (latitude)], [elevation],

#   [image column index(x)], [image row index (y)]

  gcps = [gdal.GCP(60.880310,  29.858205,    24.557252,   631.419847),
          gdal.GCP(66.336648,  30.002224,   415.702290,   648.183206),
          gdal.GCP(69.272546,  32.488266,   628.038168,   439.572519),
          gdal.GCP(70.325038,  33.417893,   698.816794,   361.343511),
          gdal.GCP(69.909581,  34.085722,   672.740458,   305.465649),
          gdal.GCP(71.100558,  34.429104,   758.419847,   281.251908),
          gdal.GCP(71.211347,  36.080057,   760.282443,   137.832061),
          gdal.GCP(74.091851,  36.903916,   944.679389,    61.465649),
          gdal.GCP(76.529200,  35.923208,  1117.900763,   135.969466),
          gdal.GCP(74.368822,  34.793829,   980.068702,   234.687023),
          gdal.GCP(73.787182,  34.383401,   937.229008,   271.938931),
          gdal.GCP(74.036456,  33.255915,   961.442748,   368.793893),
          gdal.GCP(75.338222,  32.324580,  1052.709924,   441.435115),
          gdal.GCP(74.645794,  31.099397,  1002.419847,   545.740458),
          gdal.GCP(73.427119,  29.930241,   922.328244,   642.595420),
          gdal.GCP(71.848381,  27.942775,   816.160305,   813.954198),
          gdal.GCP(70.574312,  28.016155,   721.167939,   812.091603),
          gdal.GCP(69.577215,  26.761981,   646.664122,   914.534351)]

outdataset.SetProjection(srs.ExportToWkt()) 
wkt = outdataset.GetProjection() 
outdataset.SetGCPs(gcp_list,wkt)
gdal.Warp("output_name.tif", outdataset, dstSRS='EPSG:2193', format='gtiff')

# Apply the GCPs to the open output file:
  ds.SetGCPs(gcps, sr.ExportToWkt())

# Close the output file in order to be able to work with it in other programs:
ds = None

