# ============================================================
# Python: Species Area Detection
# ============================================================
# Loads the Python function used to detect species contours
# from colors selected interactively by the user.
# ============================================================

reticulate::source_python(
  file.path(
    workingDir,
    "src",
    "matching",
    "species_area_detection.py"
  )
)


species_distribution_server <- function(
    input,
    output,
    session,
    current_out_dir
) {
  
  # ============================================================
  # Selected contour color samples
  # ============================================================
  # Stores RGB colors selected by clicking on the species contour.
  # Colors are stored separately for each map type.
  # ============================================================
  contour_colors <- reactiveValues()
  
  # Path of the current contour preview image
  contour_preview_path <- reactiveVal(NULL)
  
  contour_preview_version <- reactiveVal(0)
  # ============================================================
  # Preview Species Contour Detection
  # ============================================================
  # Starts the Python contour detection for the currently selected
  # map using the RGB colors selected by the user.
  # ============================================================
  
  observeEvent(input$previewContourDetection, {
    
    req(current_out_dir)
    req(input$map_type_Contour)
    req(input$contour_example_map)
    
    map_type <- as.character(input$map_type_Contour)
    
    # ----------------------------------------------------------
    # Get selected colors
    # ----------------------------------------------------------
    colors <- contour_colors[[map_type]]
    
    if (is.null(colors) || nrow(colors) == 0) {
      showNotification(
        "Please select at least one contour color.",
        type = "warning"
      )
      return()
    }
    
    # ----------------------------------------------------------
    # Original map
    # ----------------------------------------------------------
    tif_name <- paste0(
      tools::file_path_sans_ext(input$contour_example_map),
      ".tif"
    )
    
    image_path <- file.path(
      current_out_dir,
      map_type,
      "maps",
      "align",
      tif_name
    )
    
    cat("Contour detection input:", image_path, "\n")
    
    req(file.exists(image_path))
    
    # ----------------------------------------------------------
    # Output directory
    # ----------------------------------------------------------
    output_dir <- file.path(
      current_out_dir,
      map_type,
      "maps",
      "speciesAreaDetection"
    )
    
    dir.create(
      output_dir,
      recursive = TRUE,
      showWarnings = FALSE
    )
    
    # ----------------------------------------------------------
    # Convert R data.frame -> Python-friendly RGB list
    # ----------------------------------------------------------
    colors_python <- lapply(
      seq_len(nrow(colors)),
      function(i) {
        as.integer(c(
          colors$red[i],
          colors$green[i],
          colors$blue[i]
        ))
      }
    )
    
    cat("\n=== START SPECIES AREA DETECTION ===\n")
    cat("Image:", image_path, "\n")
    cat("Output:", output_dir, "\n")
    cat("Colors:\n")
    print(colors)
    cat(
      "Tolerance:",
      input$contourColorTolerance,
      "\n"
    )
    cat(
      "Border margin:",
      input$contourBorderMargin,
      "\n"
    )
    
    result_path <- detect_species_contour(
      image_path = image_path,
      output_dir = output_dir,
      colors = colors_python,
      tolerance = as.integer(input$contourColorTolerance),
      border_margin = as.integer(input$contourBorderMargin),
      debug = TRUE
    )
    
    cat("Python result:", result_path, "\n")
    
    
    # ----------------------------------------------------------
    # Store generated preview image
    # ----------------------------------------------------------
    if (!is.null(result_path) && file.exists(result_path)) {
      
      contour_preview_path(result_path)
      contour_preview_version(
        contour_preview_version() + 1
      )
      cat("Contour preview ready:", result_path, "\n")
      
    } else {
      
      contour_preview_path(NULL)
      
      showNotification(
        "Contour detection did not produce a preview image.",
        type = "error"
      )
    }
    
    cat("====================================\n")
  })
  
  # ============================================================
  # Display selected contour colors
  # ============================================================
  
  output$selected_contour_color <- renderUI({
    
    req(input$map_type_Contour)
    
    map_type <- as.character(input$map_type_Contour)
    
    colors <- contour_colors[[map_type]]
    
    if (is.null(colors) || nrow(colors) == 0) {
      
      return(
        tags$p(
          "No contour colors selected yet.",
          style = "color:#777;"
        )
      )
    }
    
    tagList(
      
      h4("Selected contour colors"),
      
      lapply(seq_len(nrow(colors)), function(i) {
        
        r <- colors$red[i]
        g <- colors$green[i]
        b <- colors$blue[i]
        
        tags$div(
          style = "
          display:flex;
          align-items:center;
          margin-bottom:6px;
        ",
          
          # Color preview
          tags$div(
            style = paste0(
              "width:28px;",
              "height:28px;",
              "margin-right:10px;",
              "border:1px solid #555;",
              "background-color:rgb(",
              r, ",", g, ",", b,
              ");"
            )
          ),
          
          tags$span(
            paste0(
              "RGB(",
              r, ", ",
              g, ", ",
              b,
              ")"
            )
          )
        )
      })
    )
  })
  
  
  # ============================================================
  # Clear selected contour colors
  # ============================================================
  
  observeEvent(input$clearContourColors, {
    
    req(input$map_type_Contour)
    
    map_type <- as.character(input$map_type_Contour)
    
    contour_colors[[map_type]] <- NULL
    
    cat(
      "Cleared contour colors for map type",
      map_type,
      "\n"
    )
  })
  
  # ============================================================
  # List processed contour / area maps
  # ============================================================
  
  # Species results browser, following the Map Matching / Align explorer.
  contour_results_revision <- reactiveVal(0L)
  contour_results_page <- reactiveVal(1L)
  contour_results_selected <- reactiveVal(NULL)
  contour_results_cache <- new.env(parent = emptyenv())
  contour_results_files <- reactive({
    contour_results_revision()
    root <- file.path(workingDir, "app", "www", "output")
    type <- input$map_type_Contours
    if (is.null(root) || !nzchar(root) || is.null(type) ||
        !grepl("^[0-9]+$", type)) return(character())
    sort(list.files(file.path(root, type, "contourMatching_png"),
      pattern = "\\.png$", full.names = TRUE, ignore.case = TRUE))
  })
  contour_results_filtered <- reactive({
    files <- contour_results_files()
    query <- trimws(if (is.null(input$contour_results_search)) "" else input$contour_results_search)
    if (nzchar(query)) files <- files[grepl(tolower(query), tolower(basename(files)), fixed = TRUE)]
    files
  })
  observeEvent(list(input$map_type_Contours, contour_results_revision()), {
    contour_results_selected(NULL)
    rm(list = ls(contour_results_cache), envir = contour_results_cache)
  }, ignoreNULL = FALSE)
  observeEvent(contour_results_filtered(), { contour_results_page(1L) }, ignoreNULL = FALSE)
  observeEvent(input$contour_results_refresh, { contour_results_revision(contour_results_revision() + 1L) })
  contour_results_page_count <- reactive(max(1L, ceiling(length(contour_results_filtered()) / 12L)))
  observeEvent(input$contour_results_previous, { contour_results_page(max(1L, contour_results_page() - 1L)) })
  observeEvent(input$contour_results_next, { contour_results_page(min(contour_results_page_count(), contour_results_page() + 1L)) })
  contour_results_thumbnail <- function(path) {
    info <- file.info(path)
    key <- paste(path, info$size, as.numeric(info$mtime), sep = "|")
    if (exists(key, envir = contour_results_cache, inherits = FALSE)) return(get(key, envir = contour_results_cache))
    uri <- tryCatch({
      img <- magick::image_resize(magick::image_read(path)[1], "320x220>")
      base64enc::dataURI(data = magick::image_write(img, format = "png"), mime = "image/png")
    }, error = function(e) NULL)
    assign(key, uri, envir = contour_results_cache)
    uri
  }
  output$contour_results_gallery <- renderUI({
    files <- contour_results_filtered()
    if (!length(files)) return(p(
      if (length(contour_results_files())) "No maps match your search." else
        "No detected areas available. Process the maps or choose another map type.",
      class = "dd-align-empty"))
    page <- min(contour_results_page(), contour_results_page_count())
    visible <- seq.int((page - 1L) * 12L + 1L, min(page * 12L, length(files)))
    all_files <- contour_results_files()
    div(class = "dd-align-grid", lapply(visible, function(i) {
      path <- files[i]
      uri <- contour_results_thumbnail(path)
      tags$button(type = "button",
        class = paste("dd-align-card", if (identical(path, contour_results_selected())) "is-selected" else ""),
        onclick = sprintf("Shiny.setInputValue('contour_results_pick', %d, {priority: 'event'});", match(path, all_files)),
        if (is.null(uri)) div(class = "dd-align-empty", "Preview unavailable") else
          tags$img(src = uri, alt = basename(path)),
        tags$span(basename(path))
      )
    }))
  })
  output$contour_results_page_info <- renderText({
    sprintf("Page %d of %d - %d maps", min(contour_results_page(), contour_results_page_count()),
      contour_results_page_count(), length(contour_results_filtered()))
  })
  observeEvent(input$contour_results_pick, {
    index <- suppressWarnings(as.integer(input$contour_results_pick))
    files <- contour_results_files()
    if (length(index) == 1L && !is.na(index) && index >= 1L && index <= length(files))
      contour_results_selected(files[index])
  })
  contour_results_selection <- reactive({
    path <- contour_results_selected()
    req(length(path) == 1L, path %in% contour_results_files(), file.exists(path))
    path
  })
  output$contour_results_has_selection <- renderText({
    path <- contour_results_selected()
    if (length(path) == 1L && path %in% contour_results_files() && file.exists(path)) "true" else "false"
  })
  outputOptions(output, "contour_results_has_selection", suspendWhenHidden = FALSE)
  output$contour_results_selected_name <- renderText(basename(contour_results_selection()))
  contour_results_preview <- function(path) {
    validate(need(file.exists(path), "The aligned map preview is unavailable."))
    img <- tryCatch(magick::image_read(path)[1], error = function(e) NULL)
    validate(need(!is.null(img), "Preview unavailable. You can still download the result PNG."))
    preview <- tempfile(fileext = ".png")
    magick::image_write(magick::image_resize(img, "1600x1600>"), preview, format = "png")
    list(src = preview, contentType = "image/png", alt = basename(path), width = "100%")
  }
  output$contour_results_selected_preview <- renderImage({ contour_results_preview(contour_results_selection()) }, deleteFile = TRUE)
  output$contour_results_original_preview <- renderImage({
    path <- contour_results_selection()
    contour_results_preview(file.path(dirname(dirname(path)), "align_png",
      sub("_species_contour(?=\\.png$)", "", basename(path), perl = TRUE)))
  }, deleteFile = TRUE)
  output$download_contour_result <- downloadHandler(
    filename = function() basename(contour_results_selection()), contentType = "image/png",
    content = function(file) {
      if (!file.copy(contour_results_selection(), file, overwrite = TRUE)) stop("Could not copy contour result.")
    }
  )

  observeEvent(input$speciesRepresentation, {
    
    cat("\n### speciesRepresentation CHANGED ###\n")
    cat("Value:", input$speciesRepresentation, "\n")
    
  })
  
  
  # ============================================================
  # Process all contour maps
  # ============================================================
  # Shiny only triggers the processing.
  # The actual contour-processing logic is implemented in
  # manageprocessingFlow.R.
  # ============================================================
  
  observeEvent(input$processAllContours, {
    
    req(current_out_dir)
    req(input$map_type_Contour)
    
    map_type <- as.character(input$map_type_Contour)
    
    # ----------------------------------------------------------
    # Get colors selected interactively in Shiny
    # ----------------------------------------------------------
    colors <- contour_colors[[map_type]]
    
    if (is.null(colors) || nrow(colors) == 0) {
      
      showNotification(
        "Please select at least one contour color.",
        type = "warning"
      )
      
      return()
    }
    # ----------------------------------------------------------
    # Save tested contour settings to config.csv
    # ----------------------------------------------------------
    
    colors_string <- paste(
      apply(
        colors,
        1,
        function(x) paste(x, collapse = ",")
      ),
      collapse = "|"
    )
    
    cfg_path <- file.path(
      workingDir,
      "config",
      "config.csv"
    )
    
    cfg <- read.table(
      cfg_path,
      sep = ";",
      header = FALSE,
      stringsAsFactors = FALSE,
      fill = TRUE
    )
    
    colnames(cfg) <- c("key", "value")
    
    settings <- c(
      contourColorTolerance = as.character(input$contourColorTolerance),
      contourBorderMargin   = as.character(input$contourBorderMargin),
      contourColors         = colors_string
    )
    
    for (key in names(settings)) {
      
      if (key %in% cfg$key) {
        cfg$value[cfg$key == key] <- settings[[key]]
      } else {
        cfg <- rbind(
          cfg,
          data.frame(
            key = key,
            value = settings[[key]],
            stringsAsFactors = FALSE
          )
        )
      }
    }
    
    write.table(
      cfg,
      cfg_path,
      sep = ";",
      row.names = FALSE,
      col.names = FALSE,
      quote = FALSE
    )
    # ----------------------------------------------------------
    # Start processing through central workflow
    # ----------------------------------------------------------
    manageProcessFlow(
      processing      = "contourMatching",
      allertText1     = "contour matching",
      allertText2     = "",
      input           = input,
      session         = session,
      current_out_dir = current_out_dir,
      contour_colors  = colors
    )
    updateSelectInput(session, "map_type_Contours", selected = map_type)
    contour_results_revision(contour_results_revision() + 1L)
  })
  
  # ============================================================
  # Display Species Area Detection Preview
  # ============================================================
  
  output$contourPreview <- renderUI({
    
    req(contour_preview_path())
    
    image_path <- contour_preview_path()
    
    req(file.exists(image_path))
    
    version <- contour_preview_version()
    
    tags$div(
      style = "text-align:center;",
      
      tags$h4(
        "Area detection preview",
        style = "color:black;"
      ),
      
      tags$img(
        src = session$fileUrl(
          name = paste0(
            "contour_preview_",
            as.integer(Sys.time())
          ),
          file = image_path,
          contentType = "image/png"
        ),
        style = paste0(
          "max-width:100%;",
          "height:auto;",
          "border:1px solid #aaa;"
        )
      )
    )
  })
  
  # ============================================================
  # Load maps for contour / area detection
  # ============================================================
  # ============================================================
  # Load example maps for contour / area detection
  # ============================================================
  
  observeEvent(
    list(input$map_type_Contour, input$speciesRepresentation),
    {
      
      req(input$map_type_Contour)
      
      # Only needed for contour representation
      if (!identical(input$speciesRepresentation, "contour")) {
        return()
      }
      
      map_type <- as.character(input$map_type_Contour)
      
      map_dir <- file.path(
        workingDir,
        "app",
        "www",
        "output",
        map_type,
        "matching_png"
      )
      
      cat("\n=== LOAD CONTOUR EXAMPLE MAPS ===\n")
      cat("Map type:", map_type, "\n")
      cat("Directory:", map_dir, "\n")
      cat("Directory exists:", dir.exists(map_dir), "\n")
      
      if (!dir.exists(map_dir)) {
        
        updateSelectInput(
          session,
          "contour_example_map",
          choices = character(0)
        )
        
        return()
      }
      
      map_files <- list.files(
        map_dir,
        pattern = "\\.png$",
        ignore.case = TRUE,
        full.names = FALSE
      )
      
      cat("Example maps found:", length(map_files), "\n")
      cat("================================\n")
      
      updateSelectInput(
        session,
        "contour_example_map",
        choices = map_files,
        selected = if (length(map_files) > 0) map_files[1] else NULL
      )
    },
    ignoreInit = FALSE
  )
  
  # ============================================================
  # Display selected example map
  # ============================================================
  # Shows the PNG version of the map selected by the user.
  # The PNG files were previously created in:
  # app/www/output/<map_type>/align_png/
  # ============================================================
  
  output$contour_map_preview <- renderUI({
    
    req(input$map_type_Contour)
    req(input$contour_example_map)
    
    map_type <- as.character(input$map_type_Contour)
    
    # ----------------------------------------------------------
    # Convert selected TIF filename to corresponding PNG filename
    # ----------------------------------------------------------
    png_name <- sub(
      "\\.(tif|tiff)$",
      ".png",
      input$contour_example_map,
      ignore.case = TRUE
    )
    
    # ----------------------------------------------------------
    # Path relative to app/www/
    # IMPORTANT:
    # Browser paths must be relative to www, not absolute paths.
    # ----------------------------------------------------------
    png_src <- file.path(
      "output",
      map_type,
      "align_png",
      png_name
    )
    cat("\n=== CONTOUR PREVIEW DEBUG ===\n")
    cat("Selected map type:", input$map_type_Contour, "\n")
    cat("Selected TIF:", input$contour_example_map, "\n")
    cat("Expected PNG:", png_name, "\n")
    
    png_absolute <- file.path(
      getwd(),
      "www",
      "output",
      map_type,
      "align_png",
      png_name
    )
    
    cat("Working directory:", getwd(), "\n")
    cat("Expected absolute path:", png_absolute, "\n")
    cat("PNG exists:", file.exists(png_absolute), "\n")
    cat("=============================\n")
    # Windows paths may contain backslashes.
    # Browser URLs require forward slashes.
    png_src <- gsub("\\\\", "/", png_src)
    
    cat("Contour preview:", png_src, "\n")
    
    # ----------------------------------------------------------
    # Display map
    # ----------------------------------------------------------
    tags$div(
      style = "text-align:center;",
      
      tags$img(
        id = "contour_map_image",
        src = png_src,
        style = paste0(
          "max-width:100%;",
          "height:auto;",
          "cursor:crosshair;",
          "border:1px solid #aaa;"
        )
      )
    )
  })
  
  
  # ============================================================
  # Helper: Prepare image view
  # ============================================================
  prepareImageView <- function(dirName = "matching_png",
                               map_type = "1",
                               range_str = "") {
    
    tryCatch({
      
      cat("\n====== prepareImageView ======\n")
      cat("INPUT  dirName   =", dirName, "\n")
      cat("INPUT  map_type  =", map_type, "\n")
      cat("INPUT  range_str =", range_str, "\n")
      
      dirName_clean  <- sanitize_dirname(dirName)
      map_type_clean <- sanitize_dirname(map_type)
      
      fs_dir <- file.path(
        workingDir,
        "app",
        "www",
        "output",
        map_type_clean,
        dirName_clean
      )
      
      cat("FS DIR =", fs_dir, "\n")
      
      if (!dir.exists(fs_dir)) {
        return(
          HTML(
            paste0(
              "<p><i>Directory not found: ",
              fs_dir,
              "</i></p>"
            )
          )
        )
      }
      
      files <- sort(
        list.files(
          fs_dir,
          pattern = "\\.png$",
          full.names = FALSE
        )
      )
      
      if (length(files) == 0) {
        return(
          HTML("<p><i>No images found.</i></p>")
        )
      }
      
      sel <- parse_range_indices(
        range_str,
        length(files)
      )
      
      lapply(sel, function(i) {
        
        rel_img <- file.path(
          "output",
          map_type_clean,
          dirName_clean,
          files[i]
        )
        
        page_number <- regmatches(
          files[i],
          regexpr("[0-9]{4}", files[i])
        )
        
        page_png <- file.path(
          "pages",
          paste0(page_number, ".png")
        )
        
        HTML(
          paste0(
            '<div class="shiny-map-image">',
            '  <a href="', rel_img, '" target="_blank">',
            '    <img src="', rel_img,
            '" style="width:100%;">',
            '  </a>',
            '  <p><a href="', page_png,
            '" target="_blank">see original page</a></p>',
            '</div>'
          )
        )
      })
      
    }, error = function(e) {
      
      print(e)
      
      HTML(
        "<p><i>Error while preparing image view.</i></p>"
      )
    })
  }
  # --- Helper ---------------------------------------------------------------
  
  sanitize_dirname <- function(dirName, default = "data/matching_png") {
    dn <- if (is.null(dirName)) "" else trimws(dirName)
    dn <- gsub("^/+","", dn)
    dn <- gsub("/+$","", dn)
    if (dn == "") default else dn
  }
  
  # "1", "1-5", "3-", "-4" -> Indizes (1-basiert, automatisch begrenzt)
  parse_range_indices <- function(range_str, n_max) {
    s <- if (is.null(range_str)) "" else trimws(range_str)
    if (!nzchar(s)) return(seq_len(n_max))                 # leer -> alle
    is_int <- function(x) grepl("^-?\\d+$", x)
    
    if (is_int(s)) {
      a <- max(1, min(as.integer(s), n_max)); return(a)
    }
    if (grepl("^\\d+\\s*-\\s*\\d+$", s)) {
      ab <- as.integer(unlist(strsplit(gsub("\\s*", "", s), "-")))
      a <- max(1, min(ab[1], n_max)); b <- max(1, min(ab[2], n_max))
      return(if (a <= b) seq(a,b) else seq(b,a))
    }
    if (grepl("^\\d+\\s*-$", s)) {
      a <- as.integer(gsub("\\D", "", s)); a <- max(1, min(a, n_max))
      return(seq(a, n_max))
    }
    if (grepl("^-\\s*\\d+$", s)) {
      b <- as.integer(gsub("\\D", "", s)); b <- max(1, min(b, n_max))
      return(seq(1, b))
    }
    seq_len(n_max)  # Fallback
  }
  
  
  # ============================================================
  # Read contour color from original TIF
  # ============================================================
  # Converts the click coordinates from the displayed PNG to the
  # coordinate system of the original TIF and reads the RGB color
  # at the selected position.
  # ============================================================
  
  observeEvent(input$contour_map_click, {
    
    req(current_out_dir)
    req(input$map_type_Contour)
    req(input$contour_example_map)
    
    click <- input$contour_map_click
    
    # ----------------------------------------------------------
    # Original TIF
    # ----------------------------------------------------------
    tif_name <- paste0(
      tools::file_path_sans_ext(input$contour_example_map),
      ".tif"
    )
    
    tif_path <- file.path(
      current_out_dir,
      as.character(input$map_type_Contour),
      "maps",
      "align",
      tif_name
    )
    
    if (!file.exists(tif_path)) {
      cat("TIF not found:", tif_path, "\n")
      return()
    }
    
    # ----------------------------------------------------------
    # Read original image
    # ----------------------------------------------------------
    img <- magick::image_read(tif_path)
    
    info <- magick::image_info(img)
    
    original_width  <- info$width
    original_height <- info$height
    
    # ----------------------------------------------------------
    # Convert displayed coordinates -> original coordinates
    # ----------------------------------------------------------
    scale_x <- original_width / click$width
    scale_y <- original_height / click$height
    
    original_x <- round(click$x * scale_x)
    original_y <- round(click$y * scale_y)
    
    # Keep coordinates inside image
    original_x <- max(0, min(original_x, original_width - 1))
    original_y <- max(0, min(original_y, original_height - 1))
    
    # ----------------------------------------------------------
    # Read pixel color
    # ----------------------------------------------------------
    pixel <- magick::image_crop(
      img,
      geometry = paste0(
        "1x1+",
        original_x,
        "+",
        original_y
      )
    )
    
    pixel_data <- magick::image_data(
      pixel,
      channels = "rgb"
    )
    
    red   <- as.integer(pixel_data[1, 1, 1])
    green <- as.integer(pixel_data[2, 1, 1])
    blue  <- as.integer(pixel_data[3, 1, 1])
    
    # ----------------------------------------------------------
    # Store selected RGB color for current map type
    # ----------------------------------------------------------
    
    map_type <- as.character(input$map_type_Contour)
    
    new_color <- data.frame(
      red   = red,
      green = green,
      blue  = blue
    )
    
    # Get already selected colors for this map type
    existing_colors <- contour_colors[[map_type]]
    
    if (is.null(existing_colors)) {
      
      contour_colors[[map_type]] <- new_color
      
    } else {
      
      # Avoid exact duplicates
      duplicate <- any(
        existing_colors$red   == red &
          existing_colors$green == green &
          existing_colors$blue  == blue
      )
      
      if (!duplicate) {
        contour_colors[[map_type]] <- rbind(
          existing_colors,
          new_color
        )
      }
    }
    
    cat(
      "Stored contour colors for map type",
      map_type, ":",
      nrow(contour_colors[[map_type]]),
      "\n"
    )
    # ----------------------------------------------------------
    # Debug
    # ----------------------------------------------------------
    cat("\n=== CONTOUR COLOR SELECTION ===\n")
    
    cat(
      "Display position:",
      round(click$x, 1),
      round(click$y, 1),
      "\n"
    )
    
    cat(
      "Original image size:",
      original_width,
      "x",
      original_height,
      "\n"
    )
    
    cat(
      "Original position:",
      original_x,
      original_y,
      "\n"
    )
    
    cat(
      "RGB:",
      red,
      green,
      blue,
      "\n"
    )
    
    cat("=================================\n")
  })
}
