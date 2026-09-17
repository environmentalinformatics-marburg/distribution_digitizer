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
  
  observeEvent(input$georeferencing, {
    
    req(current_out_dir())
    representation <- speciesRepresentation()
    req(representation %in% c("point", "contour"))
    
    if (representation == "point") {
      
      manageProcessFlow(
        processing = "georeferencing",
        allertText1 = "georeferencing",
        allertText2 = "georeferencing",
        input = input,
        session = session,
        current_out_dir = current_out_dir()
      )
      
    } else if (representation == "contour") {
      
      manageProcessFlow(
        processing = "georeferencing_contour",
        allertText1 = "georeferencing",
        allertText2 = "georeferencing",
        input = input,
        session = session,
        current_out_dir = current_out_dir()
      )
    }
    georef_revision(georef_revision() + 1L)
  })
  
  
 
  
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
}