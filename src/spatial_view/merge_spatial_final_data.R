# ============================================================
# Script Author: [Spaska Forteva]
# Created On: 2024-01-10
# ============================================================

mergeFinalData <- function(workingDir) {
  # Load data from CSV files
  data2 <- read.csv(paste0(workingDir, "/data/output/output_final.csv"), sep = ",")
  data1 <- read.csv(paste0(workingDir, "/data/output/pageSpeciesData.csv"), sep = ";")
  
  # Steps:
  
  # Extract the base name from the "map_name" in the first file
  # Extract the base name from the "map_name" in the first file and remove ".tif" at the end
  data1$map_name <- sub("\\.tif$", "", basename(data1$map_name))
  
  # Extract the part of the filename before the double underscore in the "File" column in the second file
  data2$File <- sub("__.*", "", data2$File)
  
  # Steps:
  
  # 1. Merge data from both files based on the "map_name"
  merged_data <- merge(data2, data1, by.x = "File", by.y = "map_name", all.x = TRUE)
  
  # 2. Add the "species" from the first file as a new column in the second file
  final_data <- within(merged_data, {
    species <- ifelse(!is.na(species), species, NA)
  })
  
  # Display the result
  # Save final_data as a new CSV file
  write.csv(final_data, file = paste0(workingDir, "/data/output/spatial_final_data.csv"), row.names = FALSE)
}
