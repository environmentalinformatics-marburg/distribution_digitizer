import numpy as np
import rasterio
from rasterio import plot

workingDir="D:/distribution_digitizer/"
file= workingDir + "data/output/mask/georeferenced_masks/test.tif"

file1 = "D:/distribution_digitizer/data/output/georeferencing/masks/georeferenced2_0064map_1_1.tif"
file2 = "D:/distribution_digitizer/data/output/georeferencing/masks/QGIS_saved_georeferenced2_0069map_2_0.tif"

fileSave = "D:/distribution_digitizer/data/output/georeferencing/map_1_2.tif"

step1 = gdal.Open(file2, gdal.GA_ReadOnly)
GT_input = step1.GetGeoTransform()
step2 = step1.GetRasterBand(1)
img_as_array = step2.ReadAsArray()
size1,size2=img_as_array.shape
import numpy as np
output=np.zeros(shape=(size1,size2))
for i in range(0,size1):
    for j in range(0,size2):
        output[i,j]=img_as_array[i,j] ** 1.2

dst_crs='EPSG:32722'
output = np.float32(output)
with rasterio.open(
    fileSave,
    'w',
    driver='GTiff',
    height=output.shape[0],
    width=output.shape[1],
    count=1,
    dtype=np.float32,
    crs=dst_crs,
    transform=GT_input,
) as dest_file:
    dest_file.write(output, 1)
dest_file.close()

import rasterio
import os
import numpy as np




file1 = "D:/distribution_digitizer/data/output/georeferencing/masks/georeferenced2_0064map_1_1.tif"
file2 = "D:/distribution_digitizer/data/output/georeferencing/masks/QGIS_saved_georeferenced2_0069map_2_0.tif"

fileSave = "D:/distribution_digitizer/data/output/georeferencing/map_1_2.tif"

import numpy as np
import rasterio
a = 1
b = 1

    
fp = file2
data = rasterio.open(fp)
out_meta = data.meta
out_transform =  data.transform
out_height = data.height
out_width = data.width
crs = data.crs
data.dtypes
out_meta.update({"driver":"GTiff",
                    "height": out_height,
                     "weight": out_width,
                    "transform": out_transform,
                    "crs" : data.crs })
out_tif = fileSave
with rasterio.open(out_tif,"w",**out_meta) as dest:
        dest.write(out_tif)

    

"D:/distribution_digitizer/data/output/georeferencing/masks/georeferenced2_0064map_1_1.tif"
# adjusting the RGB image for creating a nice plot
rgb[rgb > 3000] = 3000
img = ((rgb / rgb.max()) * 255).astype(np.uint8)
plot.show(img)
