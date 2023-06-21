import os
os.system('gdal_edit.py {} two.tiff'.format(gcp_string))

workingDir="D:/distribution_digitizer/"
output_raster= workingDir + "data/output/maps/align//"
input_raster = workingDir +"data/output/maps/align/2_0064map_1_0__danna.tif"
gcp_points = workingDir + "data/input/templates/geopoints/10_ESRI_102025.points"
os.environ['PROJ_LIB'] = "C:/ProgramData/miniconda3/Library/share/proj"
  
from osgeo import gdal

  
  f=pd.read_csv(gcp_points)
  keep_col = ['mapX','mapY','sourceX', 'sourceY', 'enable', 'dX','dY', 'residual']
  #['mapX','mapY','sourceX', 'sourceY', 'enable', 'dX','dY', 'residual']
  new_f = f[keep_col]
  df = new_f.drop(columns=['enable','dX', 'dY', 'residual'])
  col=['mapX','mapY', 'sourceX','sourceY']
  modified_df = df[col]
  modified_df['sourceY'] = modified_df['sourceY']*(-1)
  gcp_list=[]
  for index, rows in modified_df.iterrows():
   gcps = gdal.GCP(rows.mapX, rows.mapY, 1, rows.sourceX, rows.sourceY )
   gcp_list.append(gcps)

  srs = osr.SpatialReference()
  srs.ImportFromEPSG(4326) # WGS84 (EPSG:4326)
  dest_wkt = srs.ExportToWkt()
  
ds = gdal.Open(input_raster, gdal.GA_Update)
wkt = ds.GetProjection()
ds.SetGCPs(gcp_list, dest_wkt)
ds = None


 gcpList = [
        gdal.GCP(440720.000, 3751320.000, 0, 0, 0),
        gdal.GCP(441920.000, 3751320.000, 0, 20, 0),
        gdal.GCP(441920.000, 3750120.000, 0, 20, 20),
        gdal.GCP(440720.000, 3750120.000, 0, 0, 20),
    ]
    ds = gdal.Open("D:/distribution_digitizer/data/output/maps/align/2_0064map_1_0__danna.tif")
    ds = gdal.Translate("D:/distribution_digitizer/test8.tif", ds, outputSRS="EPSG:4326", GCPs=gcpList)
    assert ds is not None

    assert ds.GetRasterBand(1).Checksum() == 4672, "Bad checksum"

    gcps = ds.GetGCPs()
    assert len(gcps) == 4, "GCP count wrong."

    assert ds.GetGCPProjection().find("4326") != -1, "Bad GCP projection."

    ds = None
    
    
import subprocess
result = subprocess.run(["echo", "Hello, World!"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
print(result.stdout)
