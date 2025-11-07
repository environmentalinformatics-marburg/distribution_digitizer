# -------------------------------------------------------------------
# Function: prepare_www_output
# -------------------------------------------------------------------
# This function prepares the "www" output directory that is used to 
# store intermediate and final results of the processing steps. 
# The created subdirectories organize images and data so that the user 
# can easily navigate and view them inside the Shiny app.
#
# Arguments:
#   www_output - the path to the "www/data" output directory
#
# Behavior:
#   1. Removes any existing content of the www_output directory 
#      (using unlink with recursive = TRUE).
#   2. Creates the main www_output directory if it does not exist.
#   3. Creates a predefined set of subdirectories for different 
#      processing outputs (e.g., align_png, matching_png, polygonize).
#   4. If the provided path is empty, shows an error dialog in the app.
#   5. Any errors encountered are caught and printed to the console.
#
# Usage:
#   prepare_www_output(file.path(workingDir, "www/data"), nMapTypes)
# -------------------------------------------------------------------
prepare_www_output <- function(workingDir, www_output, nMapTypes = 1) {
  tryCatch({
    
    # --- 1. Bereinige den gesamten www_output-Ordner ---
    if (dir.exists(www_output)) {
      unlink(www_output, recursive = TRUE)
      cat("🗑️ Removed existing www_output directory:", www_output, "\n")
    }
    
    # --- 2. Erstelle den neuen www_output-Ordner ---
    if (nchar(www_output) > 0) {
      dir.create(www_output, recursive = TRUE)
      cat("📁 Created new www_output directory:", www_output, "\n")
    } else {
      showModal(modalDialog(title = "Error", "Please provide a valid input directory path."))
      return()
    }
    
    # --- 3. Definiere die Unterordnerstruktur ---
    directory_names <- c(
      "align_png", "CircleDetection_png", "readSpecies_png", "georeferencing_png",
      "masking_black_png", "masking_circleDetection", "masking_png", "maskingCentroids",
      "matching_png", "pages", "pointFiltering_png", "pointMatching_png", "polygonize",
      "symbol_templates_png", "map_templates_png"
    )
    
    # --- 4. Strukturen für jede Kartentyp-Gruppe (1, 2, …) anlegen ---
    for (i in seq_len(nMapTypes)) {
      type_dir <- file.path(www_output, as.character(i))
      dir.create(type_dir, recursive = TRUE, showWarnings = FALSE)
      cat("📁 Created map type folder:", type_dir, "\n")
      
      for (sub_dir_name in directory_names) {
        sub_dir_path <- file.path(type_dir, sub_dir_name)
        dir.create(sub_dir_path, recursive = TRUE, showWarnings = FALSE)
        cat("   📂 Subdirectory created:", sub_dir_path, "\n")
      }
    }
    
    
    # --- 5. Verkleinere und konvertiere TIFs nach www/pages/ (wie bisher) ---
    input_pages <- file.path(workingDir, "data", "input", "pages")
    output_pages <- file.path(workingDir, "www", "pages")
    
    if (!dir.exists(output_pages)) {
      dir.create(output_pages, recursive = TRUE, showWarnings = FALSE)
    }
    
    if (!dir.exists(input_pages)) {
      cat("⚠️ Warning: Input pages directory not found:", input_pages, "\n")
      return()
    }
    
    tif_files <- list.files(input_pages, pattern = "\\.tif{1,2}$", ignore.case = TRUE, full.names = TRUE)
    
    if (length(tif_files) == 0) {
      cat("ℹ️ No TIF files found in:", input_pages, "\n")
      return()
    }
    
    target_width <- 800
    
    showModal(modalDialog(
      title = "Please wait...",
      tags$div(style="text-align:center;",
               tags$div(style="border:8px solid #f3f3f3;border-top:8px solid #4CAF50;border-radius:50%;
                             width:60px;height:60px;animation:spin 1s linear infinite;margin:20px auto;"),
               tags$style("@keyframes spin{ from { transform: rotate(0deg);} to{ transform:rotate(360deg);} }"),
               tags$p(paste("Preparing monitoring feedback... Resizing and copying", length(tif_files),
                            "page files as PNGs into the www/pages directory..."))
      ),
      footer = NULL, easyClose = FALSE, size ="l"
    ))
    
    Sys.sleep(3)
    log_text <- ""
    
    for (tif_path in tif_files) {
      base_name <- tools::file_path_sans_ext(basename(tif_path))
      png_path <- file.path(output_pages, paste0(base_name, ".png"))
      
      if (!file.exists(png_path)) {
        img <- magick::image_read(tif_path)
        img_resized <- magick::image_resize(img, paste0(target_width, "x"))
        magick::image_write(img_resized, path = png_path, format = "png")
        
        cat("✅ Converted & resized:", basename(tif_path), "→", png_path, "\n")
        log_text <- paste(log_text, "✅ Converted & resized:", tif_path, "→", png_path, "\n")
      } else {
        cat("🚨 PNG already exists:", png_path, "\n")
      }
    }
    
    if (log_text == "") log_text <- "The pages already exist – no pages copied."
    removeModal()
    
  }, error = function(e) {
    cat("🚨 An error occurred during prepare_www_output processing:\n")
    print(e)
  })
}
