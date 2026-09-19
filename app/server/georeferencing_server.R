# ============================================================
# File: georeferencing_server.R
#
# Description:
# Server logic for the Georeferencing tab.
# ============================================================

georeferencing_server <- function(
    input,
    output,
    session,
    workingDir,
    current_out_dir,
    speciesRepresentation
) {
  
  # ==========================================================
  # RUN GEOREFERENCING
  # ==========================================================
  
  run_georeferencing <- function(apply_calibration = FALSE) {
    
    req(current_out_dir())
    representation <- speciesRepresentation()
    req(representation %in% c("point", "contour"))
    
    calibration_config <- NULL
    if (isTRUE(apply_calibration)) {
      # Revalidate at execution time too; a disabled button is not a server guard.
      saved <- read_saved_calibration()
      if (!isTRUE(saved$valid)) {
        showNotification(saved$message, type = "error")
        return()
      }
      calibration_config <- saved$config
    }
    manageProcessFlow(
      processing = if (representation == "point") "georeferencing" else "georeferencing_contour",
      allertText1 = "georeferencing", allertText2 = "georeferencing",
      input = input, session = session, current_out_dir = current_out_dir(),
      apply_calibration = apply_calibration, calibration_config = calibration_config
    )
    georef_revision(georef_revision() + 1L)
  }
  observeEvent(input$georeferencing, { run_georeferencing(FALSE) })
  observeEvent(input$georeferencing_calibrated, { run_georeferencing(TRUE) })
  
  
 
  
  # Read the active run rather than the shared PNG preview folder.
  georef_revision <- reactiveVal(0L)
  georef_page <- reactiveVal(1L)
  georef_selected <- reactiveVal(NULL)
  georef_cache <- new.env(parent = emptyenv())
  georef_files <- reactive({
    georef_revision()
    root <- current_out_dir()
    type <- input$map_type_Georeferencing
    if (is.null(root) || !nzchar(root) || is.null(type) ||
        !grepl("^[0-9]+$", type)) return(character())
    sort(list.files(file.path(root, type, "rectifying", "pointFiltering"),
      pattern = "\\.(tif|tiff)$", full.names = TRUE, ignore.case = TRUE))
  })
  georef_filtered <- reactive({
    files <- georef_files()
    query <- trimws(if (is.null(input$georef_search)) "" else input$georef_search)
    if (nzchar(query)) files <- files[grepl(tolower(query), tolower(basename(files)), fixed = TRUE)]
    files
  })
  observeEvent(list(current_out_dir(), input$map_type_Georeferencing, georef_revision()), {
    georef_selected(NULL)
    rm(list = ls(georef_cache), envir = georef_cache)
  }, ignoreNULL = FALSE)
  observeEvent(georef_filtered(), { georef_page(1L) }, ignoreNULL = FALSE)
  observeEvent(input$georef_refresh, { georef_revision(georef_revision() + 1L) })
  georef_page_count <- reactive(max(1L, ceiling(length(georef_filtered()) / 12L)))
  observeEvent(input$georef_previous, { georef_page(max(1L, georef_page() - 1L)) })
  observeEvent(input$georef_next, { georef_page(min(georef_page_count(), georef_page() + 1L)) })
  georef_thumbnail <- function(path) {
    info <- file.info(path)
    key <- paste(path, info$size, as.numeric(info$mtime), sep = "|")
    if (exists(key, envir = georef_cache, inherits = FALSE)) return(get(key, envir = georef_cache))
    uri <- tryCatch({
      img <- magick::image_resize(magick::image_read(path)[1], "320x220>")
      base64enc::dataURI(data = magick::image_write(img, format = "png"), mime = "image/png")
    }, error = function(e) NULL)
    assign(key, uri, envir = georef_cache)
    uri
  }
  output$georef_gallery <- renderUI({
    files <- georef_filtered()
    if (!length(files)) return(p(
      if (length(georef_files())) "No maps match your search." else
        "No georeferenced maps in the current output folder. Run georeferencing or choose another map type.",
      class = "dd-align-empty"))
    page <- min(georef_page(), georef_page_count())
    visible <- seq.int((page - 1L) * 12L + 1L, min(page * 12L, length(files)))
    all_files <- georef_files()
    div(class = "dd-align-grid", lapply(visible, function(i) {
      path <- files[i]
      uri <- georef_thumbnail(path)
      tags$button(type = "button",
        class = paste("dd-align-card", if (identical(path, georef_selected())) "is-selected" else ""),
        onclick = sprintf("Shiny.setInputValue('georef_pick', %d, {priority: 'event'});", match(path, all_files)),
        if (is.null(uri)) div(class = "dd-align-empty", "Preview unavailable") else
          tags$img(src = uri, alt = basename(path)),
        tags$span(basename(path))
      )
    }))
  })
  output$georef_page_info <- renderText({
    sprintf("Page %d of %d - %d maps", min(georef_page(), georef_page_count()),
      georef_page_count(), length(georef_filtered()))
  })
  observeEvent(input$georef_pick, {
    index <- suppressWarnings(as.integer(input$georef_pick))
    files <- georef_files()
    if (length(index) == 1L && !is.na(index) && index >= 1L && index <= length(files))
      georef_selected(files[index])
  })
  georef_selection <- reactive({
    path <- georef_selected()
    req(length(path) == 1L, path %in% georef_files(), file.exists(path))
    path
  })
  output$georef_has_selection <- renderText({
    path <- georef_selected()
    if (length(path) == 1L && path %in% georef_files() && file.exists(path)) "true" else "false"
  })
  outputOptions(output, "georef_has_selection", suspendWhenHidden = FALSE)
  output$georef_selected_name <- renderText(basename(georef_selection()))
  georef_preview <- function(path) {
    validate(need(file.exists(path), "The extracted map is unavailable in this output folder."))
    img <- tryCatch(magick::image_read(path)[1], error = function(e) NULL)
    validate(need(!is.null(img), "Preview unavailable. You can still download the georeferenced TIFF."))
    preview <- tempfile(fileext = ".png")
    magick::image_write(magick::image_resize(img, "1600x1600>"), preview, format = "png")
    list(src = preview, contentType = "image/png", alt = basename(path), width = "100%")
  }
  output$georef_selected_preview <- renderImage({ georef_preview(georef_selection()) }, deleteFile = TRUE)
  output$download_georef_map <- downloadHandler(
    filename = function() basename(georef_selection()), contentType = "image/tiff",
    content = function(file) {
      if (!file.copy(georef_selection(), file, overwrite = TRUE)) stop("Could not copy georeferenced map.")
    }
  )

  # Calibration shares discovery with the gallery and loads Python only on use.
  # Session drafts are invalidated on run/type/refresh changes, never shared
  # between map types. The saved config is read by the common Python entrypoint.
  calibration_python <- NULL
  cal_python <- function() {
    if (is.null(calibration_python)) {
      python_environment <- new.env(parent = globalenv())
      reticulate::source_python(file.path(workingDir, "src", "georeferencing", "mask_georeferencing.py"),
        envir = python_environment)
      calibration_python <<- python_environment
    }
    calibration_python
  }
  cal_states <- reactiveVal(vector("list", 3))
  cal_error <- reactiveVal("")
  cal_saved_revision <- reactiveVal(0L)
  read_saved_calibration <- function() {
    type <- input$map_type_Georeferencing
    unavailable <- list(valid = FALSE, message = "No valid saved calibration for the selected map type.")
    if (is.null(type) || !grepl("^[0-9]+$", type)) return(unavailable)
    path <- file.path(workingDir, "config", "config.csv")
    if (!file.exists(path)) return(unavailable)
    tryCatch({
      rows <- read.csv2(path, header = FALSE, col.names = c("key", "value"),
        colClasses = "character", quote = "", stringsAsFactors = FALSE)
      prefix <- paste0("georefCalibration_", type, "_")
      cfg <- as.list(stats::setNames(rows$value, rows$key))
      if (!identical(tolower(cfg[[paste0(prefix, "enabled")]]), "true")) return(unavailable)
      python <- cal_python()
      context <- python$calibration_context(workingDir, type)
      correction <- python$configured_correction(cfg, type)
      python$validate_correction(correction, context$crs, context$points)
      list(valid = TRUE, config = cfg[startsWith(names(cfg), prefix)],
        message = sprintf("Calibration saved for Map type %s. X = %.9g, Y = %.9g (%s).",
          type, as.numeric(correction$x), as.numeric(correction$y), context$units))
    }, error = function(e) list(valid = FALSE,
      message = paste("Saved calibration is unavailable:", conditionMessage(e))))
  }
  cal_saved_status <- reactive({
    cal_saved_revision()
    georef_revision()
    read_saved_calibration()
  })
  observe({
    shinyjs::toggleState("georeferencing_calibrated", condition = isTRUE(cal_saved_status()$valid))
  })
  output$geocal_saved_status <- renderText(cal_saved_status()$message)

  # Read-only comparison: cache just the current preview pair in this reactive.
  # The existing helper subtracts any TIFF baseline before applying an absolute
  # correction. It uses GDAL memory datasets and /vsimem, never processing paths.
  observeEvent(georef_files(), {
    files <- georef_files()
    selected <- isolate(input$geocal_compare_file)
    updateSelectInput(session, "geocal_compare_file",
      choices = c("Choose a map" = "", stats::setNames(files, basename(files))),
      selected = if (length(selected) == 1L && selected %in% files) selected else "")
  }, ignoreNULL = FALSE)
  cal_comparison <- reactive({
    georef_revision()
    saved <- cal_saved_status()
    path <- input$geocal_compare_file
    if (!isTRUE(saved$valid)) return(list(error = "Save a valid calibration for this map type to compare results."))
    if (length(path) != 1L || !path %in% georef_files() || !file.exists(path))
      return(list(error = "Choose an available rectified map to compare."))
    tryCatch({
      python <- cal_python()
      context <- python$calibration_context(workingDir, input$map_type_Georeferencing)
      correction <- python$configured_correction(saved$config, input$map_type_Georeferencing)
      python$validate_correction(correction, context$crs, context$points)
      before <- python$calibration_preview(path, context, 0, 0)
      after <- python$calibration_preview(path, context, as.numeric(correction$x), as.numeric(correction$y))
      sw <- pmin(unlist(before$bounds[[1]]), unlist(after$bounds[[1]]))
      ne <- pmax(unlist(before$bounds[[2]]), unlist(after$bounds[[2]]))
      list(before = before, after = after, bounds = list(unname(sw), unname(ne)),
        key = paste(path, file.info(path)$mtime, georef_revision(), correction$x, correction$y, sep = "|"),
        message = sprintf("Saved final correction: X = %.9g, Y = %.9g (%s). Read-only preview.",
          as.numeric(correction$x), as.numeric(correction$y), context$units))
    }, error = function(e) list(error = paste("Comparison unavailable:", conditionMessage(e))))
  })
  output$geocal_compare_status <- renderText({
    pair <- cal_comparison()
    if (!is.null(pair$error)) pair$error else pair$message
  })
  for (side in c("left", "right")) local({
    map_id <- paste0("geocal_compare_", side)
    output[[map_id]] <- leaflet::renderLeaflet({
      map <- leaflet::addProviderTiles(leaflet::leaflet(), leaflet::providers$OpenStreetMap)
      map <- leaflet::setView(map, lng = 0, lat = 20, zoom = 2)
      htmlwidgets::onRender(map, "function(el, x, data) {
        var map = this, overlay = null, lastKey = null;
        var host = document.getElementById('geocal_comparison');
        var shared = host._comparison || (host._comparison = {maps:{}, busy:false});
        shared.maps[data.id] = map;
        map.on('moveend', function() {
          if (shared.busy) return;
          shared.busy = true;
          try {
            Object.keys(shared.maps).forEach(function(id) {
              var other = shared.maps[id];
              if (other !== map && (!other.getCenter().equals(map.getCenter()) || other.getZoom() !== map.getZoom()))
                other.setView(map.getCenter(), map.getZoom(), {animate:false});
            });
          } finally { shared.busy = false; }
        });
        Shiny.addCustomMessageHandler(data.id, function(d) {
          if (overlay) { map.removeLayer(overlay); overlay = null; }
          if (!d.uri) { lastKey = null; return; }
          overlay = L.imageOverlay(d.uri, d.bounds, {opacity:d.opacity}).addTo(map);
          if (lastKey !== d.key) { map.fitBounds(d.fitBounds, {animate:false}); lastKey = d.key; }
        });
        Shiny.setInputValue(data.id + '_ready', Date.now(), {priority:'event'});
      }", data = list(id = map_id))
    })
  })
  observe({
    req(input$geocal_compare_left_ready, input$geocal_compare_right_ready)
    pair <- cal_comparison()
    for (side in c("left", "right")) {
      preview <- if (!is.null(pair$error)) list(uri = NULL) else {
        result <- if (side == "left") pair$before else pair$after
        result$fitBounds <- pair$bounds
        result$key <- pair$key
        result$opacity <- input$geocal_compare_opacity
        result
      }
      session$sendCustomMessage(paste0("geocal_compare_", side), preview)
    }
  })
  cal_context <- reactive({
    req(isTRUE(input$geocal_open), input$map_type_Georeferencing)
    georef_revision()
    tryCatch(cal_python()$calibration_context(workingDir, input$map_type_Georeferencing),
      error = function(e) list(error = conditionMessage(e)))
  })
  cal_require_context <- function() {
    context <- cal_context()
    if (!is.null(context$error)) stop(context$error)
    context
  }
  cal_guard <- function(code) {
    tryCatch({ force(code); cal_error("") }, error = function(e) {
      cal_error(conditionMessage(e))
      showNotification(conditionMessage(e), type = "error", duration = 8)
    })
  }
  cal_stamp <- function(path) paste(file.info(path)$size, as.numeric(file.info(path)$mtime))
  observeEvent(list(current_out_dir(), input$map_type_Georeferencing, georef_revision()), {
    cal_states(vector("list", 3))
    cal_error("")
    files <- georef_files()
    choices <- c("Choose a map" = "", stats::setNames(files, basename(files)))
    for (i in 1:3) updateSelectInput(session, paste0("geocal_file", i), choices = choices,
      selected = if (length(files) >= i) files[i] else "")
  }, ignoreNULL = FALSE)
  for (slot in 1:3) local({
    i <- slot
    observeEvent(input[[paste0("geocal_file", i)]], {
      states <- cal_states()
      states[i] <- list(NULL)
      cal_states(states)
    }, ignoreNULL = FALSE)
  })
  cal_active <- reactive({
    req(isTRUE(input$geocal_open))
    i <- as.integer(input$geocal_active)
    req(length(i) == 1L, i %in% 1:3)
    path <- input[[paste0("geocal_file", i)]]
    req(length(path) == 1L, nzchar(path), path %in% georef_files(), file.exists(path))
    context <- cal_require_context()
    state <- cal_states()[[i]]
    if (is.null(state) || !identical(state$path, path) || !identical(state$stamp, cal_stamp(path))) {
      xy <- cal_python()$calibration_initial(path, context)
      state <- list(path = path, x = xy$x, y = xy$y, saved = FALSE,
        stamp = cal_stamp(path), gcpHash = context$gcpHash)
    }
    state
  })
  cal_set <- function(state) {
    states <- cal_states()
    states[[as.integer(input$geocal_active)]] <- state
    cal_states(states)
  }
  observe({
    state <- tryCatch(cal_active(), error = function(e) NULL)
    if (!is.null(state)) {
      updateNumericInput(session, "geocal_x", value = state$x)
      updateNumericInput(session, "geocal_y", value = state$y)
    }
  })
  output$geocal_status <- renderText({
    context <- cal_context()
    if (!is.null(context$error)) return(context$error)
    state <- tryCatch(cal_active(), error = function(e) NULL)
    paste(context$name, "- X/Y units:", context$units,
      if (!is.null(state)) sprintf("| Current X = %.9g, Y = %.9g", state$x, state$y),
      "|", cal_error())
  })
  output$geocal_map <- leaflet::renderLeaflet({
    map <- leaflet::addProviderTiles(leaflet::leaflet(), leaflet::providers$OpenStreetMap)
    htmlwidgets::onRender(map, "function(el, x) {
      var map = this, overlay = null, lastFile = null;
      Shiny.addCustomMessageHandler('geocal_overlay', function(d) {
        if (overlay) { map.removeLayer(overlay); overlay = null; }
        if (!d.uri) { lastFile = null; return; }
        overlay = L.imageOverlay(d.uri, d.bounds, {opacity:d.opacity}).addTo(map);
        if (lastFile !== d.file) { map.fitBounds(d.bounds); lastFile = d.file; }
      });
      Shiny.setInputValue('geocal_ready', Date.now(), {priority:'event'});
    }")
  })
  cal_preview <- reactive({
    state <- cal_active()
    cal_python()$calibration_preview(state$path, cal_require_context(), state$x, state$y)
  })
  observe({
    req(isTRUE(input$geocal_open), input$geocal_ready)
    tryCatch({
      preview <- cal_preview()
      preview$file <- cal_active()$path
      preview$opacity <- input$geocal_opacity
      session$sendCustomMessage("geocal_overlay", preview)
    }, error = function(e) {
      session$sendCustomMessage("geocal_overlay", list(uri = NULL))
      if (!inherits(e, "shiny.silent.error")) cal_error(conditionMessage(e))
    })
  })
  for (direction in c("west", "east", "north", "south")) local({
    direction_name <- direction
    observeEvent(input[[paste0("geocal_", direction_name)]], cal_guard({
      state <- cal_active()
      step <- input$geocal_step
      if (length(step) != 1L || !is.finite(step) || step <= 0) stop("Choose a positive movement step")
      east <- switch(direction_name, west = -step, east = step, 0)
      north <- switch(direction_name, south = -step, north = step, 0)
      xy <- cal_python()$calibration_move(state$path, cal_require_context(), state$x, state$y, east, north)
      state$x <- xy$x; state$y <- xy$y; state$saved <- FALSE
      cal_set(state)
    }))
  })
  observeEvent(input$geocal_apply, cal_guard({
    state <- cal_active()
    xy <- c(input$geocal_x, input$geocal_y)
    if (length(xy) != 2L || any(!is.finite(xy))) stop("X and Y must be finite numbers")
    state$x <- xy[1]; state$y <- xy[2]; state$saved <- FALSE
    cal_set(state)
  }))
  observeEvent(input$geocal_reset, cal_guard({
    state <- cal_active()
    xy <- cal_python()$calibration_initial(state$path, cal_require_context())
    state$x <- xy$x; state$y <- xy$y; state$saved <- FALSE
    cal_set(state)
  }))
  observeEvent(input$geocal_position, cal_guard({
    state <- cal_active()
    # Only a successfully rendered spatial position can be accepted.
    cal_preview()
    state$saved <- TRUE
    cal_set(state)
  }))
  output$geocal_states <- renderTable({
    states <- cal_states()
    do.call(rbind, lapply(1:3, function(i) {
      s <- states[[i]]
      data.frame(Training = i, File = if (is.null(s)) "" else basename(s$path),
        X = if (is.null(s)) NA_real_ else s$x, Y = if (is.null(s)) NA_real_ else s$y,
        Position = if (isTRUE(s$saved)) "Saved" else "Not saved")
    }))
  }, digits = 8)
  cal_summary <- reactive({
    states <- cal_states()
    if (!all(vapply(states, function(s) isTRUE(s$saved), logical(1))))
      stop("Save positions for three different training maps.")
    context <- cal_require_context()
    paths <- vapply(states, `[[`, "", "path")
    if (!all(file.exists(paths)) || !all(paths %in% georef_files())) stop("A training TIFF is missing")
    if (!all(vapply(states, function(s) identical(s$stamp, cal_stamp(s$path)) &&
        identical(s$gcpHash, context$gcpHash), logical(1)))) stop("Training data changed; save the positions again")
    cal_python()$calibration_summary(paths, vapply(states, `[[`, 0, "x"),
      vapply(states, `[[`, 0, "y"), context)
  })
  output$geocal_recommendation <- renderText({
    tryCatch({
      summary <- cal_summary()
      sprintf("Recommended correction (median): X = %.9g, Y = %.9g. Maximum deviation: %.1f km. %s",
        summary$x, summary$y, summary$spreadMetres / 1000,
        if (isTRUE(summary$warning)) "Warning: the training maps disagree strongly. Check alignment before saving." else "")
    }, error = function(e) conditionMessage(e))
  })
  observeEvent(input$geocal_save, cal_guard({
    context <- cal_require_context()
    # Recheck the actual GCP file and TIFFs at save time, not just cached reactives.
    fresh <- cal_python()$calibration_context(workingDir, input$map_type_Georeferencing)
    if (!identical(fresh$gcpHash, context$gcpHash)) stop("The GCP file changed. Refresh and recalibrate.")
    states <- cal_states()
    summary <- cal_summary()
    if (!all(vapply(states, function(s) file.exists(s$path) && identical(s$stamp, cal_stamp(s$path)), logical(1))))
      stop("A training TIFF changed or disappeared. Refresh and recalibrate.")
    path <- file.path(workingDir, "config", "config.csv")
    cfg <- read.csv2(path, header = FALSE, col.names = c("key", "value"),
      colClasses = "character", quote = "", stringsAsFactors = FALSE)
    prefix <- paste0("georefCalibration_", input$map_type_Georeferencing, "_")
    # Base64 WKT keeps embedded quotes/semicolons safe in the existing unquoted CSV.
    values <- c(enabled = "TRUE", x = sprintf("%.17g", summary$x), y = sprintf("%.17g", summary$y),
      crs = paste0("base64:", base64enc::base64encode(charToRaw(enc2utf8(context$crs)))), gcpHash = context$gcpHash)
    cfg <- cfg[!startsWith(cfg$key, prefix), , drop = FALSE]
    cfg <- rbind(cfg, data.frame(key = paste0(prefix, names(values)), value = unname(values)))
    write.table(cfg, path, sep = ";", row.names = FALSE, col.names = FALSE, quote = FALSE)
    cal_saved_revision(cal_saved_revision() + 1L)
    showNotification(paste("Calibration saved for map type", input$map_type_Georeferencing,
      "- choose Run georeferencing with calibration to apply it.",
      if (isTRUE(summary$warning)) "Warning: training corrections differ strongly." else ""),
      type = if (isTRUE(summary$warning)) "warning" else "message", duration = 10)
  }))
}
