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

computeNumberResult <- function(base_output_dir,
                                working_dir,
                                nMapTypes = 1,
                                subfolder = "maps/align",
                                png_subdir = "output/align_png") {
  print("DEBUG computeNumberResult:")
  print(paste("  base_output_dir =", base_output_dir))
  print(paste("  working_dir     =", working_dir))
  print(paste("  nMapTypes       =", nMapTypes))
  print(paste("  subfolder       =", subfolder))
  print(paste("  png_subdir      =", png_subdir))
  tryCatch({
    
    all_files <- c()
    summary_lines <- c()
    
    for (i in seq_len(nMapTypes)) {
      type_dir <- file.path(base_output_dir, as.character(i), subfolder)
      if (dir.exists(type_dir)) {
        files_i <- list.files(type_dir, pattern = "\\.(tif|tiff)$", full.names = TRUE)
        n_files <- length(files_i)
        all_files <- c(all_files, files_i)
        
        summary_lines <- c(summary_lines,
                           paste0("🗺️ Map type ", i, ": ", n_files, " maps found"))
        
        # --- Optional: Konvertiere TIF → PNG ---
        png_target <- file.path(
          working_dir, 
          "app",
          "www", 
          "output",
          as.character(i),
          basename(png_subdir)
        )
        
        # Ordner sicher erstellen
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
    
    cat("✅ computeNumberResult summary:\n", message, "\n")
    return(message)
    
  }, error = function(e) {
    cat("🚨 Error in computeNumberResult:\n")
    print(e)
    return("Error while computing number of results.")
  })
}
#computeNumberResult(
#  base_output_dir = "D:/test/output_2025-11-07_14-01-05/",
#  working_dir = "D:/distribution_digitizer/",
#  nMapTypes = 2,
#  subfolder = "maps/matching",
#  png_subdir = "data/matching_png"
#)

# Convert TIF(F) -> PNG in 'pathToPngImages'.
# Vorher: Alle bestehenden Dateien im Zielordner werden gelöscht.
# Wenn source == "matching": kopiere zusätzlich <outDir>/records.csv nach <workingDir>/www/
convertTifToPngSave <- function(pathToTiffImages,
                                pathToPngImages,
                                source = NULL,
                                records_csv_name = "records.csv",
                                out_dir = NULL,
                                working_dir = NULL) {
  tryCatch({
    # --- 1. Sichere Bereinigung des PNG-Zielordners ---
    if (dir.exists(pathToPngImages)) {
      # Liste alle Dateien (nur Dateien, keine Verzeichnisse)
      files <- list.files(pathToPngImages, full.names = TRUE, include.dirs = FALSE)
      
      if (length(files) > 0) {
        # Versuche, alle Dateien zu löschen
        failed <- file.remove(files)
        
        # Zeige an, welche gelöscht wurden, welche nicht
        deleted <- sum(failed)
        not_deleted <- sum(!failed)
        
        if (not_deleted > 0) {
          cat("⚠️ WARNING: Could not delete", not_deleted, "file(s) in", pathToPngImages, "\n")
          # Zeige die fehlgeschlagenen Dateien an
          failed_files <- files[!failed]
          cat("  Failed to delete:", paste(failed_files, collapse = ", "), "\n")
        } else {
          cat("✅ Cleaned", deleted, "existing PNG files from:", pathToPngImages, "\n")
        }
      } else {
        cat("ℹ️ PNG output directory is already empty:", pathToPngImages, "\n")
      }
    } else {
      # Ordner existiert nicht → erstellen
      dir.create(pathToPngImages, recursive = TRUE, showWarnings = FALSE)
      cat("📁 Created PNG output directory:", pathToPngImages, "\n")
    }
    
    # --- 2. TIF -> PNG Konvertierung ---
    if (!dir.exists(pathToTiffImages)) {
      cat("❌ No TIF directory found:", pathToTiffImages, "\n")
      return(invisible(NULL))
    }
    
    #tifs <- list.files(pathToTiffImages, pattern = "\\.tif{1,2}$", ignore.case = TRUE, full.names = TRUE)
    tifs <- list.files(pathToTiffImages, pattern = "\\.(tif|tiff)$", ignore.case = TRUE, full.names = TRUE)
    
    
    if (length(tifs) == 0) {
      cat("ℹ️ No TIF files found in:", pathToTiffImages, "\n")
      return(invisible(NULL))
    }
    
    for (tif in tifs) {
      img <- magick::image_read(tif)
      out <- file.path(pathToPngImages, paste0(tools::file_path_sans_ext(basename(tif)), ".png"))
      magick::image_write(magick::image_convert(img, "png"), path = out, format = "png")
    }
    
    # --- 3. CSV Kopieren (nur bei "matching") ---
    if (!is.null(source) && identical(tolower(source), "matching")) {
      od <- if (!is.null(out_dir)) out_dir else if (exists("outDir", inherits = TRUE) && is.function(outDir)) outDir() else outDir
      wd <- if (!is.null(working_dir)) working_dir else if (exists("workingDir", inherits = TRUE) && is.function(workingDir)) workingDir() else workingDir
      od <- normalizePath(od, winslash = "/", mustWork = FALSE)
      wd <- normalizePath(wd, winslash = "/", mustWork = FALSE)
      
      from_csv <- file.path(od, records_csv_name)
      to_dir   <- file.path(wd, "app", "www")
      to_csv   <- file.path(to_dir, records_csv_name)
      
      cat("📋 CSV COPY DEBUG: from =", from_csv, " | to =", to_csv, "\n")
      
      if (!dir.exists(to_dir)) dir.create(to_dir, recursive = TRUE, showWarnings = FALSE)
      
      if (file.exists(from_csv)) {
        ok <- file.copy(from_csv, to_csv, overwrite = TRUE)
        if (!ok) {
          cat("❌ ERROR: file.copy failed!\n")
        } else {
          cat("✅ CSV copied successfully to:", to_csv, "\n")
        }
      } else {
        cat("ℹ️ records.csv not found at:", from_csv, "\n")
      }
    }
    
  }, error = function(e) {
    cat("🚨 convertTifToPngSave ERROR:\n")
    print(e)
  })
}
