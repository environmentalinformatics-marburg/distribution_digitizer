#  import the geopandas library, which is used for working with geographic data and shapefiles.
#  make sure you have the geopandas library installed by running pip install geopandas 
#  in your Python environment. 
import geopandas as gpd
import os,glob

'''' 
The main convert_shapefile_to_json function is defined with 3  parameters
It takes the path to the shapefile (shapefile_path) 
and the path to the output JSON file (output_json_path) as parameters.
Inside the function, the shapefile is read using gpd.read_file(shapefile_path) 
and loaded into a GeoDataFrame (gdf). 
A GeoDataFrame is a data structure that contains geographic data and allows 
us to perform various geographic operations.

'''

#  The convert_shapefile_to_json function
def convert_shapefile_to_json(root, fileName, outputDir):
    # Read the shapefile
    gdf = gpd.read_file(root + "/" + fileName)
    
    # Convert GeoDataFrame to JSON
    json_data = gdf.to_json()

    # Split the file name. Take the source name befor "."
    fileName = fileName.split(".")
    
    # Define the output json path
    output_json_path = outputDir + "/" + fileName[0]
    
    # Write he converted JSON string to the output JSON file
    with open(output_json_path, 'w') as json_file:
        json_file.write(json_data)


#  Find all shape files in /data/output/polygonize recursiv 
def converToJson(workingDir):
    inputDir = workingDir +"/data/output/polygonize"
    outputDir =  workingDir +"/data/output/convertShpJson"
    os.makedirs(outputDir, exist_ok=True) 
    for root, dirs, files in os.walk(inputDir):
        for file in files:
            if file.endswith(".shp"):
                print(os.path.join(root, file))
                # Call the function to perform the conversion
                convert_shapefile_to_json(root, file, outputDir)
                
