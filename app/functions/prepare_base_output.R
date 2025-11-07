# -------------------------------------------------------------------
# Function: prepare_base_output
# -------------------------------------------------------------------
# This function prepares the main "output" directory structure 
# for storing processing results. It ensures that all required 
# subdirectories exist before the workflow starts, so that 
# intermediate and final results can be organized consistently.
#
# Arguments:
#   base_path - the path to the base output directory
#
# Behavior:
#   1. Validates the provided base_path (must not be empty).
#   2. Creates the base output directory if it does not exist.
#   3. Creates a predefined set of subdirectories for various 
#      processing steps (e.g., final_output, georeferencing, maps).
#   4. Creates additional nested subdirectories for specific folders:
#        - "maps" → subfolders: align, csvFiles, matching, readSpecies, pointMatching
#        - "georeferencing" → subfolders: maps, masks
#        - "final_output", "maps", "masking_black", "polygonize", "rectifying" 
#            → subfolders: circleDetection, pointFiltering
#   5. If the provided base_path is empty, an error dialog is shown in the app.
#   6. Any errors are caught and printed to the console for debugging.
#
# Usage:
#   prepare_base_output(file.path(workingDir, "data/output"), nMapTypes)
# -------------------------------------------------------------------
# -------------------------------------------------------------------
# Function: prepare_base_output
# -------------------------------------------------------------------
# Creates a complete "output" directory tree for multiple map types.
# -------------------------------------------------------------------
prepare_base_output <- function(base_path, nMapTypes = 1) {
  tryCatch({
    if (nchar(base_path) == 0) {
      showModal(modalDialog(title = "Error", "Please provide a valid input directory path."))
      return()
    }
    
    # --- 1. Haupt-Output-Ordner vorbereiten ---
    if (dir.exists(base_path)) {
      unlink(base_path, recursive = TRUE)
      cat("🗑️ Removed existing output directory:", base_path, "\n")
    }
    dir.create(base_path, recursive = TRUE, showWarnings = FALSE)
    cat("📁 Created new output base directory:", base_path, "\n")
    
    # --- 2. Ordnerstruktur für jeden Kartentyp (1, 2, …) ---
    for (i in seq_len(nMapTypes)) {
      type_dir <- file.path(base_path, as.character(i))
      dir.create(type_dir, recursive = TRUE, showWarnings = FALSE)
      cat("📁 Created output type folder:", type_dir, "\n")
      
      # Define top-level directories
      directory_names <- c(
        "final_output", "georeferencing", "maps", "masking",
        "masking_black", "output_shape", "pagerecords",
        "polygonize", "rectifying"
      )
      
      for (dir_name in directory_names) {
        dir_path <- file.path(type_dir, dir_name)
        dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
        
        # --- Special subfolders ---
        if (dir_name == "maps") {
          sub_directory_names <- c("align", "csvFiles", "matching", "readSpecies", "pointMatching")
          for (sub_dir in sub_directory_names) {
            dir.create(file.path(dir_path, sub_dir), recursive = TRUE, showWarnings = FALSE)
          }
        }
        
        if (dir_name == "georeferencing") {
          sub_directory_names <- c("maps", "masks")
          for (sub_dir in sub_directory_names) {
            dir.create(file.path(dir_path, sub_dir), recursive = TRUE, showWarnings = FALSE)
          }
        }
        
        if (dir_name %in% c("final_output", "maps", "masking_black", "polygonize", "rectifying")) {
          sub_directory_names <- c("circleDetection", "pointFiltering")
          for (sub_dir in sub_directory_names) {
            dir.create(file.path(dir_path, sub_dir), recursive = TRUE, showWarnings = FALSE)
          }
        }
      }
    }
    
    cat("✅ All output structures created successfully.\n")
    
  }, error = function(e) {
    cat("🚨 An error occurred during prepare_base_output processing:\n")
    print(e)
  })
}

  # -------------------------------------------------------------------
  # Function: prepare_base_output
  # -------------------------------------------------------------------
  # This function prepares the main "output" directory structure 
  # for storing processing results. It ensures that all required 
  # subdirectories exist before the workflow starts, so that 
  # intermediate and final results can be organized consistently.
  #
  # Arguments:
  #   base_path - the path to the base output directory
  #
  # Behavior:
  #   1. Validates the provided base_path (must not be empty).
  #   2. Creates the base output directory if it does not exist.
  #   3. Creates a predefined set of subdirectories for various 
  #      processing steps (e.g., final_output, georeferencing, maps).
  #   4. Creates additional nested subdirectories for specific folders:
  #        - "maps" → subfolders: align, csvFiles, matching, readSpecies, pointMatching
  #        - "georeferencing" → subfolders: maps, masks
  #        - "final_output", "maps", "masking_black", "polygonize", "rectifying" 
  #            → subfolders: circleDetection, pointFiltering
  #   5. If the provided base_path is empty, an error dialog is shown in the app.
  #   6. Any errors are caught and printed to the console for debugging.
  #
  # Usage:
  #   prepare_base_output(file.path(workingDir, "data/output"))
  # -------------------------------------------------------------------
# -------------------------------------------------------------------
# Function: prepare_base_output
# -------------------------------------------------------------------
# Creates a complete "output" directory tree for multiple map types.
# -------------------------------------------------------------------
prepare_base_output <- function(base_path, nMapTypes = 1) {
  tryCatch({
    if (nchar(base_path) == 0) {
      showModal(modalDialog(title = "Error", "Please provide a valid input directory path."))
      return()
    }
    
    # --- 1. Haupt-Output-Ordner vorbereiten ---
    if (dir.exists(base_path)) {
      unlink(base_path, recursive = TRUE)
      cat("🗑️ Removed existing output directory:", base_path, "\n")
    }
    dir.create(base_path, recursive = TRUE, showWarnings = FALSE)
    cat("📁 Created new output base directory:", base_path, "\n")
    
    # --- 2. Ordnerstruktur für jeden Kartentyp (1, 2, …) ---
    for (i in seq_len(nMapTypes)) {
      type_dir <- file.path(base_path, as.character(i))
      dir.create(type_dir, recursive = TRUE, showWarnings = FALSE)
      cat("📁 Created output type folder:", type_dir, "\n")
      
      # Define top-level directories
      directory_names <- c(
        "final_output", "georeferencing", "maps", "masking",
        "masking_black", "output_shape", "pagerecords",
        "polygonize", "rectifying"
      )
      
      for (dir_name in directory_names) {
        dir_path <- file.path(type_dir, dir_name)
        dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
        
        # --- Special subfolders ---
        if (dir_name == "maps") {
          sub_directory_names <- c("align", "csvFiles", "matching", "readSpecies", "pointMatching")
          for (sub_dir in sub_directory_names) {
            dir.create(file.path(dir_path, sub_dir), recursive = TRUE, showWarnings = FALSE)
          }
        }
        
        if (dir_name == "georeferencing") {
          sub_directory_names <- c("maps", "masks")
          for (sub_dir in sub_directory_names) {
            dir.create(file.path(dir_path, sub_dir), recursive = TRUE, showWarnings = FALSE)
          }
        }
        
        if (dir_name %in% c("final_output", "maps", "masking_black", "polygonize", "rectifying")) {
          sub_directory_names <- c("circleDetection", "pointFiltering")
          for (sub_dir in sub_directory_names) {
            dir.create(file.path(dir_path, sub_dir), recursive = TRUE, showWarnings = FALSE)
          }
        }
      }
    }
    
    cat("✅ All output structures created successfully.\n")
    
  }, error = function(e) {
    cat("🚨 An error occurred during prepare_base_output processing:\n")
    print(e)
  })
}
