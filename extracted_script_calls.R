
library(reticulate)
library(tesseract)
workingDir = "D:/distribution_digitizer/"
outDir = "D:/test/output_2024-08-09_14-39-27/"
config <- read.csv(paste0(workingDir,"/config/config.csv"),header = TRUE, sep = ';')
outDir = config$dataOutputDir


fname=paste0(workingDir, "/", "src/matching/map_matching.py")

print("The processing template matching python script:")
print(fname)
source_python(fname)
print("Threshold:")
print(2)
print(outDir)
main_template_matching(workingDir, outDir, 0.2, config$sNumberPosition)


# align
fname=paste0(workingDir, "/", "src/matching/map_align.py")
print("Processing align python script:")
print(fname)
source_python(fname)
align_images_directory(workingDir, outDir)

cat("\nSuccessfully executed")
findTemplateResult = paste0(outDir, "/maps/align/")
files<- list.files(findTemplateResult, full.names = TRUE, recursive = FALSE)
countFiles = paste0(length(files),"")

# point_matching
fname=paste0(workingDir, "/", "src/matching/point_matching.py")
print(" Processing point python script:")
print(fname)
source_python(fname)
map_points_matching(workingDir, outDir, 0.7)
findTemplateResult = paste0(outDir, "/maps/pointMatching/")
print(findTemplateResult)
cat("\nSuccessfully executed")


#point_filtering
fname=paste0(workingDir, "/", "src/matching/point_filtering.py")
fname2 = paste0(workingDir, "/", "src/matching/coords_to_csv.py")
print(" Process pixel filtering  python script:")
print(fname)
source_python(fname)
source_python(fname2)
main_point_filtering(workingDir, outDir, 5, 9)

cat("\nSuccessfully executed")
# convert the tif images to png and save in www
findTemplateResult = paste0(outDir, "/maps/pointFiltering/")
files <- list.files(findTemplateResult, full.names = TRUE, recursive = FALSE)
countFiles <- paste0(length(files), "")


# circle_detection
fname=paste0(workingDir, "/", "src/matching/circle_detection.py")
#fname2 = paste0(workingDir, "/", "src/matching/coords_to_csv.py")
print("Processing circle detection python script:")
print(fname)
source_python(fname)
#source_python(fname2)
print(outDir)
gaussian <- 9L
minDist <- 5L
thresholdEdge <- 50L
thresholdCircles <- 30L
minRadius <- 10L
maxRadius <- 40L
# Aufruf der Funktion
mainCircleDetection(workingDir, outDir, gaussian, minDist, thresholdEdge, thresholdCircles, minRadius, maxRadius)


# masking
fname=paste0(workingDir, "/", "src/masking/masking.py")
print(" Process masking normale python script:")
print(fname)
source_python(fname)
mainGeomask(workingDir, outDir, 5L)

fname=paste0(workingDir, "/", "src/masking/creating_masks.py")
print(" Process masking black python script:")
print(fname)
source_python(fname)
mainGeomaskB(workingDir, outDir, 5L)



# mask_centroids
fname=paste0(workingDir, "/", "src/masking/mask_centroids.py")
print(" Process masking Centroids python script:")
print(fname)
source_python(fname)
MainMaskCentroids(workingDir, outDir)


# Croping
fname <- paste0(workingDir, "/", "src/read_species/map_read_species.R")
print("Croping the species names from the map botton R script:")
print(fname)
source(fname)
species <- read_legends(workingDir, outDir)
cat("\nSuccessfully executed")



# Read page species
fname <- paste0(workingDir, "/", "src/read_species/page_read_species.R")
print(paste0("Reading page species data and saving the results to a 'pageSpeciesData.csv' file in the ", outDir, " directory"))
source(fname)

if (length(config$keywordReadSpecies) > 0) {
  species <- readPageSpecies(workingDir, outDir, config$keywordReadSpecies, config$keywordBefore, config$keywordThen, config$middle)
} else {
  species <- readPageSpecies(workingDir, outDir, 'None', config$keywordBefore, config$keywordThen, config$middle)
}




# processing georeferencing
fname=paste0(workingDir, "/", "src/georeferencing/mask_georeferencing.py")
print(" Process georeferencing python script:")
print(fname)
source_python(fname)
# mainmaskgeoreferencingMaps(workingDir, outDir)
mainmaskgeoreferencingMaps_CD(workingDir, outDir)
#mainmaskgeoreferencingMasks(workingDir, outDir)
mainmaskgeoreferencingMasks_CD(workingDir, outDir)
mainmaskgeoreferencingMasks_PF(workingDir, outDir)
# processing rectifying

fname=paste0(workingDir, "/", "src/polygonize/rectifying.py")
print(" Process rectifying python script:")
print(fname)
source_python(fname)
mainRectifying_Map_PF(workingDir, outDir)
mainRectifying(workingDir, outDir)
mainRectifying_CD(workingDir, outDir)
mainRectifying_PF(workingDir, outDir)
#outDir = "D:/test/output_2024-08-05_15-38-45/"
findTemplateResult = paste0(outDir, "/georeferencing/maps/circleDetection/")
files <- list.files(findTemplateResult, full.names = TRUE, recursive = FALSE)
countFiles <- paste0(length(files), "")



# processing polygonize
fname=paste0(workingDir, "/", "src/polygonize/polygonize.py")
print(" Process polygonizing python script:")
print(fname)
source_python(fname)
#mainPolygonize(workingDir, outDir)
#mainPolygonize_Map_PF(workingDir, outDir)
mainPolygonize_CD(workingDir, outDir)
mainPolygonize_PF(workingDir, outDir)
findTemplateResult = paste0(outDir, "/polygonize/pointFiltering")
files <- list.files(findTemplateResult, full.names = TRUE, recursive = FALSE)
countFiles <- paste0(length(files), "")

# merge_spatial
convertTifToPngSave(paste0(workingDir, "/data/input/pages/"),paste0(workingDir, "/www/data/pages/"))
source(paste0(workingDir, "/src/spatial_view/merge_spatial_final_data.R"))
mergeFinalData(workingDir, outDir)


