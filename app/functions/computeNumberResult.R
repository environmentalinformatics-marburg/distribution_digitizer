# -------------------------------------------------------------------
# Function: computeNumberResult
# -------------------------------------------------------------------
# Counts all TIF images across multiple map-type subdirectories,
# converts them to PNG (for display in Shiny), and returns a summary message.
#
# Arguments:
#   base_output_dir - base output path (e.g., current_out_dir)
#   working_dir     - path to the main working directory (for PNG destination)
#   nMapTypes       - number of map types (integer)
#   subfolder       - relative subfolder where TIFs are stored (e.g., "maps/align")
#   png_subdir      - relative www subfolder for PNG output (e.g., "data/align_png")
#
# Returns:
#   A formatted message string summarizing number of files and output location.
# -------------------------------------------------------------------

# -------------------------------------------------------------------
# Function: computeNumberResult
# -------------------------------------------------------------------
# Counts all TIF/TIFF images across map-type subdirectories,
# converts them to PNG for display in Shiny, and returns a summary.
#
# Example:
#
# Matching:
#   subfolder  = "maps/matching"
#   png_subdir = "output/matching_png"
#
# Alignment:
#   subfolder  = "maps/align"
#   png_subdir = "output/align_png"
#
# TIF source:
#   <base_output_dir>/<map_type>/<subfolder>/
#
# PNG destination:
#   <working_dir>/app/www/output/<map_type>/<png-folder>/
# -------------------------------------------------------------------

computeNumberResult <- function(
    base_output_dir,
    working_dir,
    nMapTypes = 1,
    subfolder = "maps/align",
    png_subdir = "output/align_png",
    tesseract_available = TRUE
) {
  
  cat("\nDEBUG computeNumberResult:\n")
  cat("  base_output_dir =", base_output_dir, "\n")
  cat("  working_dir     =", working_dir, "\n")
  cat("  nMapTypes       =", nMapTypes, "\n")
  cat("  subfolder       =", subfolder, "\n")
  cat("  png_subdir      =", png_subdir, "\n\n")
  
  tryCatch({
    
    nMapTypes <- as.integer(nMapTypes)
    
    if (is.na(nMapTypes) || nMapTypes < 1) {
      stop("nMapTypes must be an integer >= 1.")
    }
    
    # ------------------------------------------------------------
    # Result containers
    # ------------------------------------------------------------
    
    all_files <- character(0)
    summary_lines <- character(0)
    source_directories <- character(0)
    
    # We only need the final folder name:
    #
    # "output/align_png"    -> "align_png"
    # "output/matching_png" -> "matching_png"
    #
    png_folder_name <- basename(png_subdir)
    
    # ------------------------------------------------------------
    # Process every map type
    # ------------------------------------------------------------
    
    for (i in seq_len(nMapTypes)) {
      
      type_id <- as.character(i)
      
      # Example:
      # D:/test/output_xxx/1/maps/matching
      type_dir <- file.path(
        base_output_dir,
        type_id,
        subfolder
      )
      
      source_directories <- c(
        source_directories,
        type_dir
      )
      
      # ----------------------------------------------------------
      # Source directory does not exist
      # ----------------------------------------------------------
      
      if (!dir.exists(type_dir)) {
        
        cat(
          "⚠️ Directory not found for map type",
          type_id, ":",
          type_dir, "\n"
        )
        
        summary_lines <- c(
          summary_lines,
          paste0(
            "🗺️ Map type ",
            type_id,
            ": directory not found"
          )
        )
        
        next
      }
      
      # ----------------------------------------------------------
      # Find TIF images
      # ----------------------------------------------------------
      
      files_i <- list.files(
        type_dir,
        pattern = "\\.(tif|tiff)$",
        full.names = TRUE,
        ignore.case = TRUE
      )
      
      n_files <- length(files_i)
      
      all_files <- c(
        all_files,
        files_i
      )
      
      cat(
        "🗺️ Map type",
        type_id, ":",
        n_files,
        "TIF file(s) found\n"
      )
      
      # ----------------------------------------------------------
      # PNG destination for Shiny
      # ----------------------------------------------------------
      #
      # Example:
      #
      # D:/distribution_digitizer/
      #     app/www/output/1/matching_png/
      #
      # or
      #
      # D:/distribution_digitizer/
      #     app/www/output/1/align_png/
      #
      # ----------------------------------------------------------
      
      png_target <- file.path(
        working_dir,
        "app",
        "www",
        "output",
        type_id,
        png_folder_name
      )
      
      if (!dir.exists(png_target)) {
        dir.create(
          png_target,
          recursive = TRUE,
          showWarnings = FALSE
        )
      }
      
      # ----------------------------------------------------------
      # Convert TIF -> PNG
      # ----------------------------------------------------------
      
      converted <- convertTifToPngSave(
        tif_dir = type_dir,
        png_target = png_target
      )
      
      # ----------------------------------------------------------
      # Summary
      # ----------------------------------------------------------
      
      summary_lines <- c(
        summary_lines,
        paste0(
          "🗺️ Map type ",
          type_id,
          ": ",
          n_files,
          " maps found, ",
          converted,
          " PNGs created"
        )
      )
    }
    
    # ------------------------------------------------------------
    # Total number of maps
    # ------------------------------------------------------------
    
    total <- length(all_files)
    
    # ------------------------------------------------------------
    # Build result message
    # ------------------------------------------------------------
    
    message <- paste0(
      paste(summary_lines, collapse = "\n"),
      "\n\n",
      "✅ Total generated maps: ",
      total,
      "\n",
      "Ended on: ",
      format(Sys.time(), "%H:%M:%S"),
      "\n",
      "Directories:\n",
      paste(source_directories, collapse = "\n")
    )
    
    # ------------------------------------------------------------
    # Optional OCR warning
    # ------------------------------------------------------------
    
    if (!tesseract_available) {
      
      message <- paste0(
        message,
        "\n\n",
        "⚠️ OCR notice:\n",
        "Tesseract OCR was not available on this system.\n",
        "Species detection was skipped or incomplete.\n",
        "To enable OCR, install Tesseract or set 'tesserAct' ",
        "in config/config.csv."
      )
    }
    
    cat("\n✅ computeNumberResult summary:\n")
    cat(message, "\n")
    
    return(message)
    
  }, error = function(e) {
    
    cat("\n🚨 Error in computeNumberResult:\n")
    cat(conditionMessage(e), "\n")
    
    return(
      paste0(
        "Error while computing number of results: ",
        conditionMessage(e)
      )
    )
  })
}

computeNumberResult_orign <- function(
    base_output_dir,
    working_dir,
    nMapTypes = 1,
    subfolder = "maps/align",
    png_subdir = "output/align_png",
    tesseract_available = TRUE   # 👈 NEU
) {
  
  #print("DEBUG computeNumberResult:")
  #print(paste("  base_output_dir =", base_output_dir))
  #print(paste("  working_dir     =", working_dir))
  #print(paste("  nMapTypes       =", nMapTypes))
  #print(paste("  subfolder       =", subfolder))
  #print(paste("  png_subdir      =", png_subdir))
  
  tryCatch({
    
    all_files <- c()
    summary_lines <- c()
    
    for (i in seq_len(nMapTypes)) {
      type_dir <- file.path(base_output_dir, as.character(i), subfolder)
      
      if (dir.exists(type_dir)) {
        files_i <- list.files(type_dir, pattern = "\\.(tif|tiff)$", full.names = TRUE)
        n_files <- length(files_i)
        all_files <- c(all_files, files_i)
        
        summary_lines <- c(
          summary_lines,
          paste0("🗺️ Map type ", i, ": ", n_files, " maps found")
        )
        
        png_target <- file.path(
          working_dir,
          "app",
          "www",
          "output",
          as.character(i),
          basename(png_subdir)
        )
        
        if (!dir.exists(png_target)) {
          dir.create(png_target, recursive = TRUE, showWarnings = FALSE)
        }
        
        convertTifToPngSave(type_dir, png_target)
        
      } else {
        cat("⚠️ Directory not found for type", i, ":", type_dir, "\n")
      }
    }
    
    total <- length(all_files)
    
    message <- paste0(
      paste(summary_lines, collapse = "\n"), "\n",
      "✅ Total generated maps: ", total, "\n",
      "Ended on: ", format(Sys.time(), "%H:%M:%S"), "\n",
      "Directories:\n",
      paste(file.path(base_output_dir, 1:nMapTypes, subfolder), collapse = "\n")
    )
    
    # 🔔 OCR-Hinweis anhängen (falls nötig)
    if (!tesseract_available) {
      message <- paste0(
        message, "\n\n",
        "⚠️ OCR notice:\n",
        "Tesseract OCR was not available on this system.\n",
        "Species detection was skipped or incomplete.\n",
        "To enable OCR, install Tesseract or set 'tesserAct' in config/config.csv.\n"
      )
    }
    
    cat("✅ computeNumberResult summary:\n", message, "\n")
    return(message)
    
  }, error = function(e) {
    cat("🚨 Error in computeNumberResult:\n")
    print(e)
    return("Error while computing number of results.")
  })
}

# -------------------------------------------------------------------
# Function: convertTifToPngSave
# -------------------------------------------------------------------
# Converts all TIF/TIFF images from a source directory to PNG
# and saves them into a target directory (e.g. app/www/output/...).
# The target directory is cleaned BEFORE conversion.
# -------------------------------------------------------------------

convertTifToPngSave <- function(tif_dir, png_target) {
  
  cat("🔄 convertTifToPngSave\n")
  cat("  Source:", tif_dir, "\n")
  cat("  Target:", png_target, "\n")
  
  # ------------------------------------------------------------
  # Dependency check
  # ------------------------------------------------------------
  if (!requireNamespace("magick", quietly = TRUE)) {
    stop("Package 'magick' is required. Please run install.packages('magick').")
  }
  
  if (!dir.exists(tif_dir)) {
    warning("TIF directory does not exist: ", tif_dir)
    return(0)
  }
  
  if (!dir.exists(png_target)) {
    dir.create(png_target, recursive = TRUE, showWarnings = FALSE)
  }
  
  # ------------------------------------------------------------
  # Clean target directory
  # ------------------------------------------------------------
  old_pngs <- list.files(
    png_target,
    pattern = "\\.png$",
    full.names = TRUE,
    ignore.case = TRUE
  )
  
  if (length(old_pngs) > 0) {
    file.remove(old_pngs)
    cat("🧹 Removed", length(old_pngs), "old PNG files\n")
  }
  
  # ------------------------------------------------------------
  # Find TIF files
  # ------------------------------------------------------------
  tif_files <- list.files(
    tif_dir,
    pattern = "\\.(tif|tiff)$",
    full.names = TRUE,
    ignore.case = TRUE
  )
  
  if (length(tif_files) == 0) {
    cat("⚠️ No TIF files found in", tif_dir, "\n")
    return(0)
  }
  
  # ------------------------------------------------------------
  # Convert using magick
  # ------------------------------------------------------------
  converted <- 0
  
  for (tif_path in tif_files) {
    tryCatch({
      
      img <- magick::image_read(tif_path)
      
      png_name <- paste0(
        tools::file_path_sans_ext(basename(tif_path)),
        ".png"
      )
      
      png_path <- file.path(png_target, png_name)
      
      magick::image_write(img, png_path, format = "png")
      
      converted <- converted + 1
      
    }, error = function(e) {
      cat("🚨 Failed to convert:", tif_path, "\n")
      print(e)
    })
  }
  
  cat("✅ Converted", converted, "files to PNG\n")
  return(converted)
}
