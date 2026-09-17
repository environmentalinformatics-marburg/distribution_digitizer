# ============================================================
# File: map_matching_server.R
#
# Description:
# Server logic for:
#   1. Map matching
#   2. Displaying matching records
#   3. Displaying selected matching results
#   4. Map alignment
# ============================================================


map_matching_server <- function(
    input,
    output,
    session,
    workingDir,
    outDir
) {
  cat("### map_matching_server STARTED ###\n")
  # ==========================================================
  # MAP MATCHING
  # ==========================================================
  
  observeEvent(input$templateMatching, {
    
    current_out_dir <- outDir()
    
    # --------------------------------------------------------
    # Validate page range
    # --------------------------------------------------------
    
    if (
      is.null(input$range_matching) ||
      trimws(input$range_matching) == ""
    ) {
      
      shinyjs::runjs(
        "$('#range_matching').css('border-color', 'red')"
      )
      
      output$range_warning <- renderText(
        "⚠️ Please fill in 'range matching' before starting."
      )
      
      return()
    }
    
    
    # --------------------------------------------------------
    # Save tested map matching settings to config.csv
    # --------------------------------------------------------
    
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
      threshold_for_TM = as.character(input$threshold_for_TM),
      sNumberPosition  = as.character(input$sNumberPosition),
      matchingType     = as.character(input$matchingType)
    )
    
    for (key in names(settings)) {
      
      if (key %in% cfg$key) {
        
        cfg$value[cfg$key == key] <- settings[[key]]
        
      } else {
        
        cfg <- rbind(
          cfg,
          data.frame(
            key   = key,
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
    
    
    # --------------------------------------------------------
    # Clear validation warning
    # --------------------------------------------------------
    
    shinyjs::runjs(
      "$('#range_matching').css('border-color', '')"
    )
    
    output$range_warning <- renderText("")
    
    
    # --------------------------------------------------------
    # Start map matching
    # --------------------------------------------------------
    
    manageProcessFlow(
      processing      = "mapMatching",
      allertText1     = "map matching",
      allertText2     = "matching",
      input           = input,
      session         = session,
      current_out_dir = current_out_dir
    )
    
    shinyjs::show("matching_results_block")
  })
  
  
  # ==========================================================
  # SHOW MATCHING RECORDS
  # ==========================================================
  
  observeEvent(input$showMatchingRecords, {
    
    req(input$map_type_matching)
    
    records_file <- file.path(
      outDir(),
      as.character(input$map_type_matching),
      "records.csv"
    )
    
    print(paste("Records file:", records_file))
    
    if (!file.exists(records_file)) {
      
      showNotification(
        paste(
          "No records.csv found for map type",
          input$map_type_matching
        ),
        type = "warning"
      )
      
      return()
    }
    
    # Read records.csv NEW on every button click
    records <- read.csv(
      records_file,
      stringsAsFactors = FALSE
    )
    
    cat("Records loaded:", nrow(records), "\n")
    
    # Re-create table with the newly loaded data
    output$matchingRecords <- DT::renderDT({
      
      DT::datatable(
        records,
        selection = "single",
        rownames = FALSE,
        options = list(
          pageLength = 10
        )
      )
    })
    
    shinyjs::show("matching_records_block")
  })
  
  
  
  # ==========================================================
  # SELECTED MATCHING RECORD
  # ==========================================================
  
  selected_matching_record <- reactiveVal(NULL)
  
  observeEvent(input$matchingRecords_rows_selected, {
    
    row <- input$matchingRecords_rows_selected
    
    req(length(row) == 1)
    
    records_file <- file.path(
      outDir(),
      input$map_type_matching,
      "records.csv"
    )
    
    records <- read.csv(
      records_file,
      stringsAsFactors = FALSE
    )
    
    selected <- records[row, ]
    
    
    # --------------------------------------------------------
    # Original page
    # --------------------------------------------------------
    
    page_file <- gsub(
      "\\\\",
      "/",
      selected$file_name
    )
    
    page_file <- basename(page_file)
    
    page_png <- paste0(
      tools::file_path_sans_ext(page_file),
      ".png"
    )
    
    page_url <- paste0(
      "pages/",
      page_png
    )
    
    
    # --------------------------------------------------------
    # Matched map
    # --------------------------------------------------------
    
    map_file <- gsub(
      "\\\\",
      "/",
      selected$map_name
    )
    
    map_file <- basename(map_file)
    
    map_png <- paste0(
      tools::file_path_sans_ext(map_file),
      ".png"
    )
    
    map_url <- paste0(
      "output/",
      input$map_type_matching,
      "/matching_png/",
      map_png
    )
    
    
    # --------------------------------------------------------
    # Show original page + detected map
    # --------------------------------------------------------
    
    output$selected_matching_result_ui <- renderUI({
      
      fluidRow(
        
        column(
          6,
          
          h4("Original page"),
          
          tags$img(
            src = page_url,
            style = "
              width:100%;
              height:auto;
              border:1px solid #ccc;
            "
          )
        ),
        
        column(
          6,
          
          h4("Detected map"),
          
          tags$img(
            src = map_url,
            style = "
              width:100%;
              height:auto;
              border:1px solid #ccc;
            "
          )
        )
      )
    })
    
    shinyjs::show(
      "selected_matching_result"
    )
  })
  
  
  # ==========================================================
  # ALIGN MAPS
  # ==========================================================
  
  observeEvent(input$alignMaps, {
    
    current_out_dir <- outDir()
    
    # --------------------------------------------------------
    # Validate page range
    # --------------------------------------------------------
    
    if (
      is.null(input$range_matching) ||
      trimws(input$range_matching) == ""
    ) {
      
      shinyjs::runjs(
        "$('#range_matching').css('border-color', 'red')"
      )
      
      output$range_warning <- renderText(
        "⚠️ Please fill in 'range matching' before starting."
      )
      
      return()
    }
    
    
    # --------------------------------------------------------
    # Clear validation warning
    # --------------------------------------------------------
    
    shinyjs::runjs(
      "$('#range_matching').css('border-color', '')"
    )
    
    output$range_warning <- renderText("")
    
    
    # --------------------------------------------------------
    # Start alignment
    # --------------------------------------------------------
    
    manageProcessFlow(
      processing      = "alignMaps",
      allertText1     = "align maps",
      allertText2     = "allign",
      input           = input,
      session         = session,
      current_out_dir = current_out_dir
    )
    
    align_revision(align_revision() + 1L)
  })
  
  
  # Read the active run rather than the shared PNG preview folder.
  align_revision <- reactiveVal(0L)
  align_page <- reactiveVal(1L)
  align_selected <- reactiveVal(NULL)
  align_cache <- new.env(parent = emptyenv())
  align_files <- reactive({
    align_revision()
    root <- outDir()
    type <- input$map_type_align
    if (is.null(root) || !nzchar(root) || is.null(type) ||
        !grepl("^[0-9]+$", type)) return(character())
    sort(list.files(file.path(root, type, "maps", "align"),
      pattern = "\\.(tif|tiff)$", full.names = TRUE, ignore.case = TRUE))
  })
  align_filtered <- reactive({
    files <- align_files()
    query <- trimws(if (is.null(input$align_search)) "" else input$align_search)
    if (nzchar(query)) files <- files[grepl(tolower(query), tolower(basename(files)), fixed = TRUE)]
    files
  })
  observeEvent(list(outDir(), input$map_type_align, align_revision()), {
    align_selected(NULL)
    rm(list = ls(align_cache), envir = align_cache)
  }, ignoreNULL = FALSE)
  observeEvent(align_filtered(), { align_page(1L) }, ignoreNULL = FALSE)
  observeEvent(input$align_refresh, { align_revision(align_revision() + 1L) })
  align_page_count <- reactive(max(1L, ceiling(length(align_filtered()) / 12L)))
  observeEvent(input$align_previous, { align_page(max(1L, align_page() - 1L)) })
  observeEvent(input$align_next, { align_page(min(align_page_count(), align_page() + 1L)) })
  align_thumbnail <- function(path) {
    info <- file.info(path)
    key <- paste(path, info$size, as.numeric(info$mtime), sep = "|")
    if (exists(key, envir = align_cache, inherits = FALSE)) return(get(key, envir = align_cache))
    uri <- tryCatch({
      img <- magick::image_resize(magick::image_read(path)[1], "320x220>")
      base64enc::dataURI(data = magick::image_write(img, format = "png"), mime = "image/png")
    }, error = function(e) NULL)
    assign(key, uri, envir = align_cache)
    uri
  }
  output$align_gallery <- renderUI({
    files <- align_filtered()
    if (!length(files)) return(p(
      if (length(align_files())) "No maps match your search." else
        "No aligned maps in the current output folder. Run alignment or choose another map type.",
      class = "dd-align-empty"))
    page <- min(align_page(), align_page_count())
    visible <- seq.int((page - 1L) * 12L + 1L, min(page * 12L, length(files)))
    all_files <- align_files()
    div(class = "dd-align-grid", lapply(visible, function(i) {
      path <- files[i]
      uri <- align_thumbnail(path)
      tags$button(type = "button",
        class = paste("dd-align-card", if (identical(path, align_selected())) "is-selected" else ""),
        onclick = sprintf("Shiny.setInputValue('align_pick', %d, {priority: 'event'});", match(path, all_files)),
        if (is.null(uri)) div(class = "dd-align-empty", "Preview unavailable") else
          tags$img(src = uri, alt = basename(path)),
        tags$span(basename(path))
      )
    }))
  })
  output$align_page_info <- renderText({
    sprintf("Page %d of %d - %d maps", min(align_page(), align_page_count()),
      align_page_count(), length(align_filtered()))
  })
  observeEvent(input$align_pick, {
    index <- suppressWarnings(as.integer(input$align_pick))
    files <- align_files()
    if (length(index) == 1L && !is.na(index) && index >= 1L && index <= length(files))
      align_selected(files[index])
  })
  align_selection <- reactive({
    path <- align_selected()
    req(length(path) == 1L, path %in% align_files(), file.exists(path))
    path
  })
  output$align_has_selection <- renderText({
    path <- align_selected()
    if (length(path) == 1L && path %in% align_files() && file.exists(path)) "true" else "false"
  })
  outputOptions(output, "align_has_selection", suspendWhenHidden = FALSE)
  output$align_selected_name <- renderText(basename(align_selection()))
  align_preview <- function(path) {
    validate(need(file.exists(path), "The extracted map is unavailable in this output folder."))
    img <- tryCatch(magick::image_read(path)[1], error = function(e) NULL)
    validate(need(!is.null(img), "Preview unavailable. You can still download the aligned TIFF."))
    preview <- tempfile(fileext = ".png")
    magick::image_write(magick::image_resize(img, "1600x1600>"), preview, format = "png")
    list(src = preview, contentType = "image/png", alt = basename(path), width = "100%")
  }
  output$align_selected_preview <- renderImage({ align_preview(align_selection()) }, deleteFile = TRUE)
  output$align_original_preview <- renderImage({
    path <- align_selection()
    align_preview(file.path(dirname(dirname(path)), "matching", basename(path)))
  }, deleteFile = TRUE)
  output$download_aligned_map <- downloadHandler(
    filename = function() basename(align_selection()), contentType = "image/tiff",
    content = function(file) {
      if (!file.copy(align_selection(), file, overwrite = TRUE)) stop("Could not copy aligned map.")
    }
  )
}
