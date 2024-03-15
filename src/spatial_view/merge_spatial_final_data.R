# ============================================================
# Script Author: [Spaska Forteva]
# Created On: 2024-01-10
# ============================================================

#workingDir="D:/distribution_digitizer_11_01_2024/"
  
mergeFinalData <- function(workingDir, outDir) {
  tryCatch(
    # Processing spatial data computing
    expr = {
      # Load data from CSV files
      data2 <- read.csv(paste0(outDir, "/output_final.csv"), sep = ";")
      data1 <- read.csv(paste0(outDir, "/pageSpeciesData.csv"), sep = ";")
      
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
      write.csv2(final_data, file = paste0(outDir, "/spatial_final_data.csv"), row.names = FALSE)
    }, 
    error = function(e) {
      print(e)
    },
    finally = {
      cat("\nSuccessfully executed")
    }
  )
}
