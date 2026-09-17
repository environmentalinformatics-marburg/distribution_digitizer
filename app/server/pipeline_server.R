# ============================================================
# File: pipeline_server.R
#
# Description:
# Server logic for the Complete Pipeline tab.
#
# The current config.csv is loaded into a temporary reactive
# object. Values can be edited for the current pipeline run
# without modifying the original config.csv.
# ============================================================


pipeline_server <- function(
    input,
    output,
    session,
    workingDir,
    info,
    shinyfields2
) {
  
  # ==========================================================
  # Load complete pipeline function
  # ==========================================================
  
  source(
    file.path(
      workingDir,
      "src",
      "run_pipeline.R"
    ),
    local = TRUE
  )
  
  
  # ==========================================================
  # Temporary pipeline configuration
  # ==========================================================
  
  pipeline_config <- reactiveVal(NULL)
  
  selected_pipeline_map <- reactive({
    
    config_data <- pipeline_config()
    
    n_maps <- as.integer(
      config_data$Value[
        config_data$Parameter == "nMapTypes"
      ]
    )
    
    if (n_maps <= 1) {
      return(1L)
    }
    
    req(input$pipelineMapType)
    
    as.integer(input$pipelineMapType)
  })
  # ==========================================================
  # Read original config.csv
  # ==========================================================
  
  read_pipeline_config <- function() {
    config_file <- file.path(workingDir, "config", "config.csv")

    if (!file.exists(config_file)) {
      showNotification(
        paste("Configuration file not found:", config_file),
        type = "error"
      )
      return(NULL)
    }

    # Load the starting values without overwriting the saved pipeline configuration.
    # Save changes writes config_pipeline.csv; Start pipeline reads that file.
    config_data <- read.csv(
      config_file,
      sep = ";",
      header = FALSE,
      stringsAsFactors = FALSE,
      col.names = c("Parameter", "Value"),
      check.names = FALSE
    )
    # Keep the detection settings together immediately after page color.
    detection_keys <- c("threshold_for_TM", "sNumberPosition", "matchingType")
    detection_rows <- match(detection_keys, config_data$Parameter)
    detection_rows <- detection_rows[!is.na(detection_rows)]
    if ("pColor" %in% config_data$Parameter) {
      remaining <- setdiff(seq_len(nrow(config_data)), detection_rows)
      position <- match("pColor", config_data$Parameter[remaining])
      config_data <- config_data[append(remaining, detection_rows, after = position), , drop = FALSE]
      rownames(config_data) <- NULL
    }
    config_data
  }
  
 
  # ==========================================================
  # Download shapefiles
  # ==========================================================
  
  output$downloadShapefiles <- downloadHandler(
    
    # --------------------------------------------------------
    # Name of downloaded ZIP file
    # --------------------------------------------------------
    
    filename = function() {
      "shapefiles.zip"
    },
    
    
    # --------------------------------------------------------
    # Create ZIP archive
    # --------------------------------------------------------
    
    content = function(file) {
      
      # ------------------------------------------------------
      # Determine pipeline result directory
      # ------------------------------------------------------
      
      result_dir <- pipeline_result()
      
      
      # After an app reload pipeline_result() may be NULL.
      # In this case use the newest existing pipeline output.
      if (is.null(result_dir) || !nzchar(result_dir)) {
        
        config_data <- pipeline_config()
        req(config_data)
        
        output_base <- config_data$Value[
          config_data$Parameter == "dataOutputDir"
        ]
        
        parent_dir <- dirname(output_base)
        output_prefix <- basename(output_base)
        
        existing_outputs <- list.dirs(
          parent_dir,
          recursive = FALSE,
          full.names = TRUE
        )
        
        existing_outputs <- existing_outputs[
          startsWith(
            basename(existing_outputs),
            output_prefix
          )
        ]
        
        if (length(existing_outputs) == 0) {
          stop("No previous pipeline output directory found.")
        }
        
        dir_info <- file.info(existing_outputs)
        
        result_dir <- existing_outputs[
          which.max(dir_info$mtime)
        ]
      }
      
      
      cat("\n========== SHAPEFILE DOWNLOAD ==========\n")
      cat("Pipeline result directory:", result_dir, "\n")
      
      
      # ------------------------------------------------------
      # Find map directories: 1, 2, 3, ...
      # ------------------------------------------------------
      
      map_dirs <- list.dirs(
        result_dir,
        recursive = FALSE,
        full.names = TRUE
      )
      
      map_dirs <- map_dirs[
        grepl("[/\\\\][0-9]+$", map_dirs)
      ]
      
      if (length(map_dirs) == 0) {
        stop("No map directories found.")
      }
      
      
      # ------------------------------------------------------
      # Collect files from polygonize/pointFiltering
      # ------------------------------------------------------
      
      files_to_export <- character(0)
      
      for (map_dir in map_dirs) {
        
        polygonize_dir <- file.path(
          map_dir,
          "polygonize",
          "pointFiltering"
        )
        
        if (!dir.exists(polygonize_dir)) {
          next
        }
        
        current_files <- list.files(
          polygonize_dir,
          full.names = TRUE
        )
        
        files_to_export <- c(
          files_to_export,
          current_files
        )
      }
      
      
      if (length(files_to_export) == 0) {
        stop("No shapefile files found.")
      }
      
      
      cat("Files found:", length(files_to_export), "\n")
      
      
      # ------------------------------------------------------
      # Create temporary directory
      # ------------------------------------------------------
      
      temp_export_dir <- tempfile(
        pattern = "shapefile_export_"
      )
      
      dir.create(
        temp_export_dir,
        recursive = TRUE
      )
      
      
      # ------------------------------------------------------
      # Copy files into temporary directory
      # ------------------------------------------------------
      
      copied <- file.copy(
        from = files_to_export,
        to = temp_export_dir,
        overwrite = TRUE
      )
      
      if (!all(copied)) {
        stop("Some shapefile files could not be copied.")
      }
      
      
      # ------------------------------------------------------
      # Create ZIP
      # ------------------------------------------------------
      
      old_wd <- getwd()
      
      on.exit(
        setwd(old_wd),
        add = TRUE
      )
      
      setwd(temp_export_dir)
      
      utils::zip(
        zipfile = file,
        files = list.files(temp_export_dir)
      )
      
      
      cat("Files exported:", length(files_to_export), "\n")
      cat("ZIP created:", file, "\n")
      cat("========================================\n\n")
    },
    
    contentType = "application/zip"
  )
  output$shapeExportDirInput <- renderUI({
    
    req(pipeline_config())
    
    config_data <- pipeline_config()
    
    output_base <- config_data$Value[
      config_data$Parameter == "dataOutputDir"
    ]
    
    textInput(
      "shapeExportDir",
      "Export directory:",
      value = dirname(output_base),
      width = "100%"
    )
  })
  # ==========================================================
  # Load configuration when server module starts
  # ==========================================================
  
  observe({
    
    if (is.null(pipeline_config())) {
      
      config_data <- read_pipeline_config()
      
      if (!is.null(config_data)) {
        pipeline_config(config_data)
      }
    }
  })
  
  
  # ==========================================================
  # Display editable configuration table
  # ==========================================================
  
  pipeline_choices <- list(
    speciesRepresentation = c("Points / symbols" = "point", "Contours / areas" = "contour"),
    speciesNameSource = c("Species referenced in a map legend" = "legend", "Species identified directly from the title" = "regions"),
    pFormat = c("TIFF" = "1", "PNG" = "2", "JPEG" = "3"),
    pColor = c("Black and white" = "1", "Color" = "2"),
    middle = c("Yes" = "TRUE", "No" = "FALSE"),
    sNumberPosition = c("Top" = "1", "Bottom" = "2"),
    matchingType = c("Template matching" = "1", "Contour matching" = "2"),
    nMapTypes = c("1" = "1", "2" = "2", "3" = "3")
  )
  pipeline_edit_parameter <- reactiveVal(NULL)
  observeEvent(input$pipeline_choice_request, {
    key <- as.character(input$pipeline_choice_request)
    req(length(key) == 1L, key %in% names(pipeline_choices))
    data <- pipeline_config()
    row <- match(key, data$Parameter)
    req(!is.na(row))
    pipeline_edit_parameter(key)
    showModal(modalDialog(
      title = paste("Edit", key),
      selectInput("pipeline_choice_value", "Value", choices = c("Please select" = "", pipeline_choices[[key]]),
        selected = as.character(data$Value[row])),
      footer = tagList(modalButton("Cancel"), actionButton("applyPipelineChoice", "Apply", class = "btn-primary")),
      easyClose = TRUE
    ))
  })
  observeEvent(input$applyPipelineChoice, {
    key <- pipeline_edit_parameter()
    req(key %in% names(pipeline_choices), input$pipeline_choice_value %in% unname(pipeline_choices[[key]]))
    data <- pipeline_config()
    row <- match(key, data$Parameter)
    req(!is.na(row))
    data$Value[row] <- input$pipeline_choice_value
    pipeline_config(data)
    removeModal()
  })

  output$pipelineConfigTable <- DT::renderDT({
    
    req(pipeline_config())
    # Reuse the descriptions already loaded for General Config.
    help_keys <- paste0(pipeline_config()$Parameter, "_infoBox")
    aliases <- c(workingDir = "workingDir_info",
      specieTitleKeywordBefore = "keywordBefore_infoBox",
      specieTitleKeywordThen = "keywordThen_infoBox")
    for (key in names(aliases)) help_keys[pipeline_config()$Parameter == key] <- aliases[[key]]
    field_help <- setNames(lapply(help_keys, function(key) {
      text <- info[[key]]
      if (is.null(text) || !length(text) || is.na(text[1])) "" else as.character(text[1])
    }), pipeline_config()$Parameter)

    # Help only: reuse the Map Detection text and existing option labels.
    field_help$threshold_for_TM <- as.character(shinyfields2$inf1[1])
    field_help$sNumberPosition <- paste0(
      "Position of the printed page number on the scanned page. ",
      paste(paste(unname(pipeline_choices$sNumberPosition), names(pipeline_choices$sNumberPosition), sep = " = "), collapse = "; "), "."
    )
    field_help$matchingType <- paste0(
      as.character(shinyfields2$matchingType[1]), ": ",
      paste(paste(unname(pipeline_choices$matchingType), names(pipeline_choices$matchingType), sep = " = "), collapse = "; "), "."
    )

    DT::datatable(
      pipeline_config(),
      
      editable = list(
        target = "cell",
        
        # Parameter names must NOT be editable.
        # Only column 1 = Value can be changed.
        disable = list(
          columns = c(0)
        )
      ),
      
      rownames = FALSE,
      callback = DT::JS(paste0(
        "var choices = ", jsonlite::toJSON(names(pipeline_choices)), ";",
        "var fieldHelp = ", jsonlite::toJSON(field_help, auto_unbox = TRUE), ";",
        "function addEditHints() { table.rows({page:'current'}).every(function() {",
        "var cells = $(this.node()).children('td'); var key = this.data()[0];",
        "var description = fieldHelp[key] || '';",
        "cells.eq(0).attr('title', description || 'Parameter name - cannot be edited.');",
        "var hint = choices.indexOf(key) >= 0 ? 'Double-click this value to choose an option. Then click Save changes.' : 'Double-click this value to edit the text. Then click Save changes.';",
        "cells.eq(1).attr('title', description ? description + String.fromCharCode(10,10) + hint : hint).css('cursor', choices.indexOf(key) >= 0 ? 'pointer' : 'text');",
        "}); }",
        "table.on('draw.dt', addEditHints); addEditHints();",
        "table.table().node().addEventListener('dblclick', function(e) {",
        "var cell = $(e.target).closest('td'); if (!cell.length) return;",
        "var idx = table.cell(cell).index(); if (!idx || idx.column !== 1) return;",
        "var key = table.row(idx.row).data()[0]; if (choices.indexOf(key) < 0) return;",
        "e.preventDefault(); e.stopImmediatePropagation();",
        "Shiny.setInputValue('pipeline_choice_request', key, {priority:'event'});",
        "}, true);"
      )),
      options = list(
        pageLength = 25,
        order = list(),
        scrollX = TRUE,
        dom = "tip"
      )
    )
  })
  
  
  # ==========================================================
  # Store edited values temporarily
  # ==========================================================
  
  observeEvent(
    input$pipelineConfigTable_cell_edit,
    {
      
      info <- input$pipelineConfigTable_cell_edit
      
      cat("\n===== CELL EDIT =====\n")
      print(info)
      
      config_data <- pipeline_config()
      
      row <- info$row
      col <- info$col
      value <- info$value
      
      cat("row:", row, "\n")
      cat("col:", col, "\n")
      cat("value:", value, "\n")
      
      if (col != 1) {
        cat("EDIT IGNORED because col != 1\n")
        return()
      }
      
      req(length(row) == 1L, !is.na(row), row >= 1L, row <= nrow(config_data))
      key <- config_data$Parameter[row]
      if (key %in% names(pipeline_choices) && !value %in% unname(pipeline_choices[[key]])) {
        showNotification("Please choose one of the available options.", type = "warning")
        return()
      }
      config_data$Value[row] <- value
      pipeline_config(config_data)
      
      cat(
        "UPDATED:",
        config_data$Parameter[row],
        "=",
        config_data$Value[row],
        "\n"
      )
      
      cat("=====================\n")
    }
  
  )
  # ==========================================================
  # Save pipeline configuration
  # ==========================================================
  
  observeEvent(
    input$savePipelineConfig,
    {
      
      # --------------------------------------------------------
      # Use exactly the configuration currently shown in the UI
      # --------------------------------------------------------
      
      config_data <- pipeline_config()
      req(config_data)
      
      pipeline_config_file <- file.path(
        workingDir,
        "config",
        "config_pipeline.csv"
      )
      
      # Save exactly the configuration used for this run
      write.table(
        config_data,
        pipeline_config_file,
        sep = ";",
        row.names = FALSE,
        col.names = FALSE,
        quote = FALSE
      )
      
      # Create config object directly from current UI values
      config <- as.list(
        setNames(
          config_data$Value,
          config_data$Parameter
        )
      )
      
      cat(
        "Configuration used for pipeline:",
        pipeline_config_file,
        "\n"
      )
      
      cat("Title:", config$title, "\n")
      cat("Output:", config$dataOutputDir, "\n")
    }
  )
  
  # ==========================================================
  # Reset temporary configuration
  # ==========================================================
  
  observeEvent(
    input$resetPipelineConfig,
    {
      
      config_data <- read_pipeline_config()
      req(config_data)
      
      pipeline_config(config_data)
      
      DT::replaceData(
        DT::dataTableProxy("pipelineConfigTable"),
        config_data,
        resetPaging = FALSE,
        rownames = FALSE
      )
      
      showNotification(
        "Pipeline configuration reset.",
        type = "message"
      )
    }
  )
  
  # ==========================================================
  # Pipeline status
  # ==========================================================
  
  output$pipelineStatus <- renderUI({
    
    req(pipeline_config())
    
    tags$div(
      style = "
        padding:10px;
        background:#f5f5f5;
        border-left:4px solid #337ab7;
      ",
      
      tags$strong(
        "Configuration ready."
      ),
      
      tags$br(),
      
      tags$span(
        "Temporary changes will only be used for the current pipeline run."
      )
    )
  })
  
  
  # ==========================================================
  # Pipeline execution
  # ==========================================================
  
  pipeline_result <- reactiveVal(NULL)
  pipeline_error  <- reactiveVal(NULL)
  pipeline_running <- reactiveVal(FALSE)
  show_pipeline_results <- reactiveVal(FALSE)
  
  observeEvent(
    input$startCompletePipeline,
    {
      
      req(pipeline_config())

      # --------------------------------------------------------
      # Always use pipeline configuration for processing
      # --------------------------------------------------------
      
      pipeline_config_file <- file.path(
        workingDir,
        "config",
        "config_pipeline.csv"
      )
      
      cat(
        "Configuration used for pipeline:",
        pipeline_config_file,
        "\n"
      )
      
      config_data <- read.csv(
        pipeline_config_file,
        sep = ";",
        header = FALSE,
        stringsAsFactors = FALSE,
        col.names = c(
          "Parameter",
          "Value"
        ),
        check.names = FALSE
      )
      
      config <- as.list(
        setNames(
          config_data$Value,
          config_data$Parameter
        )
      )
      cat("\n========== PIPELINE CONFIG DEBUG ==========\n")
      
      cat("threshold_for_TM:\n")
      print(config$threshold_for_TM)
      str(config$threshold_for_TM)
      
      cat("\nsNumberPosition:\n")
      print(config$sNumberPosition)
      str(config$sNumberPosition)
      
      cat("\nmatchingType:\n")
      print(config$matchingType)
      str(config$matchingType)
      
      cat("\nnMapTypes:\n")
      print(config$nMapTypes)
      str(config$nMapTypes)
      
      cat("===========================================\n\n")
      # Always use the current application directory
      config$workingDir <- workingDir
      
      
      cat("\n=======================================\n")
      cat("PIPELINE CONFIGURATION LOADED\n")
      cat("=======================================\n")
      cat("File:", pipeline_config_file, "\n")
      cat("Species representation:", config$speciesRepresentation, "\n")
      cat("Species name source:", config$speciesNameSource, "\n")
      cat("=======================================\n\n")
      
      
      # --------------------------------------------------------
      # Input directory
      # --------------------------------------------------------
      
      inputDir <- config$dataInputDir
      
      if (is.null(inputDir) || !nzchar(inputDir)) {
        
        showNotification(
          "No input directory configured.",
          type = "error"
        )
        
        return()
      }
      
      
      # --------------------------------------------------------
      # Reset previous result
      # --------------------------------------------------------
      
      pipeline_result(NULL)
      pipeline_error(NULL)
      pipeline_running(TRUE)
      
      
      # --------------------------------------------------------
      # Run complete pipeline
      # --------------------------------------------------------
      
      tryCatch(
        {
          tif_files <- list.files(
            file.path(inputDir,"pages"),
            pattern = "\\.(tif|tiff)$",
            ignore.case = TRUE
          )
          
          n_pages <- length(tif_files)
          
          estimated_seconds <- n_pages * 10
          estimated_minutes <- ceiling(estimated_seconds / 60)

          showModal(modalDialog(
            title = "Complete pipeline is running...",

            tags$div(
              style = "text-align:center;",

              tags$div(
                style = "border:8px solid #f3f3f3;
               border-top:8px solid #4CAF50;
               border-radius:50%;
               width:60px;
               height:60px;
               animation:spin 1s linear infinite;
               margin:20px auto;"
              ),

              tags$style(
                "@keyframes spin{
         from { transform: rotate(0deg); }
         to   { transform: rotate(360deg); }
       }"
              ),

              tags$p(
                paste(
                  "Processing",
                  n_pages,
                  "pages."
                )
              ),

              tags$p(
                paste(
                  "Estimated processing time:",
                  estimated_minutes,
                  "minutes."
                )
              ),

              tags$p(
                "Please wait. The pipeline is processing the complete book."
              )
            ),

            footer = NULL,
            easyClose = FALSE,
            size = "l"
          ))
          output_dir <- run_complete_pipeline(
            inputDir = inputDir,
            config   = config
          )
          
          removeModal()
          
          pipeline_result(output_dir)
          
          showNotification(
            "Complete pipeline finished successfully.",
            type = "message",
            duration = 8
          )
        },
        
        error = function(e) {
          
          pipeline_error(conditionMessage(e))
          
          showNotification(
            paste(
              "Pipeline failed:",
              conditionMessage(e)
            ),
            type = "error",
            duration = NULL
          )
        },
        
        finally = {
          pipeline_running(FALSE)
        }
      )
    }
  )
  
  output$pipelineResultActions <- renderUI({
    
    req(pipeline_result())
    
    actionButton(
      "showPipelineResults",
      "View Results",
      icon = icon("table"),
      style = "
      color:#FFFFFF;
      background:#337ab7;
      font-weight:bold;
    "
    )
  })
  observeEvent(
    input$showPipelineResults,
    {
      show_pipeline_results(TRUE)
    }
  )
  
  output$pipelineMapSelector <- renderUI({
    
    req(pipeline_result())
    req(pipeline_config())
    
    config_data <- pipeline_config()
    
    n_maps <- as.integer(
      config_data$Value[
        config_data$Parameter == "nMapTypes"
      ]
    )

    selectInput(
      "pipelineMapType",
      "Select map type:",
      choices = seq_len(n_maps),
      selected = 1
    )
  })
  
  pipeline_result_data <- reactive({
    
    req(pipeline_result())
    
    map_index <- selected_pipeline_map()
    
    csv_file <- file.path(
      pipeline_result(),
      as.character(map_index),
      "spatial_data_final.csv"
    )
    
    validate(
      need(
        file.exists(csv_file),
        "Final spatial data file not found."
      )
    )
    
    read.csv(
      csv_file,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  })
  
  
  output$pipelineResultTable <- DT::renderDT({
    
    req(show_pipeline_results())
    
    DT::datatable(
      pipeline_result_data(),
      rownames = FALSE,
      filter = "top",
      selection = "single",
      options = list(
        pageLength = 20,
        scrollX = TRUE
      )
    )
  })
  output$pipelineResultMap <- leaflet::renderLeaflet({
    
    req(show_pipeline_results())
    
    selected_row <- input$pipelineResultTable_rows_selected
    
    req(length(selected_row) == 1)
    
    df <- pipeline_result_data()
    
    selected <- df[
      selected_row,
      ,
      drop = FALSE
    ]
    
    shp_file <- selected$shape_file
    
    validate(
      need(
        !is.na(shp_file) &&
          nzchar(shp_file) &&
          file.exists(shp_file),
        "Shapefile not found for the selected result."
      )
    )
    
    shape_data <- sf::st_read(
      shp_file,
      quiet = TRUE
    )
    
    # Leaflet requires geographic coordinates
    if (!is.na(sf::st_crs(shape_data))) {
      shape_data <- sf::st_transform(
        shape_data,
        4326
      )
    }
    
    bbox <- sf::st_bbox(shape_data)
    
    leaflet::leaflet() %>%
      leaflet::addProviderTiles(
        leaflet::providers$OpenStreetMap
      ) %>%
      leaflet::addPolygons(
        data = shape_data,
        color = "red",
        weight = 2,
        opacity = 1,
        fillOpacity = 0.3
      ) %>%
      leaflet::fitBounds(
        lng1 = as.numeric(bbox["xmin"]),
        lat1 = as.numeric(bbox["ymin"]),
        lng2 = as.numeric(bbox["xmax"]),
        lat2 = as.numeric(bbox["ymax"])
      )
  })
  
  # ==========================================================
  # Export shapefiles
  # ==========================================================
  
  observeEvent(
    input$exportShapefiles,
    {
      
      cat("\n### EXPORT BUTTON CLICKED ###\n")
      
      export_dir <- trimws(input$shapeExportDir)
      
      cat("Export directory:", export_dir, "\n")
      cat("pipeline_result():", pipeline_result(), "\n")
      # --------------------------------------------------------
      # Export directory entered by the user
      # --------------------------------------------------------
      
      export_dir <- trimws(input$shapeExportDir)
      
      if (!nzchar(export_dir)) {
        
        showNotification(
          "Please enter an export directory.",
          type = "error"
        )
        
        return()
      }
      
      
      # --------------------------------------------------------
      # Create export directory if necessary
      # --------------------------------------------------------
      
      if (!dir.exists(export_dir)) {
        
        dir.create(
          export_dir,
          recursive = TRUE
        )
      }
      
      
      # --------------------------------------------------------
      # Find all map directories: 1, 2, 3, ...
      # --------------------------------------------------------
      
      # --------------------------------------------------------
      # Determine pipeline result directory
      # --------------------------------------------------------
      
      result_dir <- pipeline_result()
      
      # After an app reload pipeline_result() is NULL.
      # In this case use the newest existing pipeline output.
      if (is.null(result_dir) || !nzchar(result_dir)) {
        
        config_data <- pipeline_config()
        req(config_data)
        
        output_base <- config_data$Value[
          config_data$Parameter == "dataOutputDir"
        ]
        
        # Example:
        # D:/test_eu/test/output_
        
        parent_dir <- dirname(output_base)
        output_prefix <- basename(output_base)
        
        existing_outputs <- list.dirs(
          parent_dir,
          recursive = FALSE,
          full.names = TRUE
        )
        
        existing_outputs <- existing_outputs[
          startsWith(
            basename(existing_outputs),
            output_prefix
          )
        ]
        
        if (length(existing_outputs) == 0) {
          
          showNotification(
            "No previous pipeline output directory found.",
            type = "error"
          )
          
          return()
        }
        
        # Newest output directory
        dir_info <- file.info(existing_outputs)
        
        result_dir <- existing_outputs[
          which.max(dir_info$mtime)
        ]
      }
      
      cat("Pipeline result directory:", result_dir, "\n")
      
      map_dirs <- list.dirs(
        result_dir,
        recursive = FALSE,
        full.names = TRUE
      )
      
      map_dirs <- map_dirs[
        grepl("[/\\\\][0-9]+$", map_dirs)
      ]
      
      
      # --------------------------------------------------------
      # Collect files from polygonize/pointFiltering
      # --------------------------------------------------------
      
      files_to_copy <- character(0)
      
      for (map_dir in map_dirs) {
        
        polygonize_dir <- file.path(
          map_dir,
          "polygonize",
          "pointFiltering"
        )
        
        if (!dir.exists(polygonize_dir)) {
          next
        }
        
        current_files <- list.files(
          polygonize_dir,
          full.names = TRUE
        )
        
        files_to_copy <- c(
          files_to_copy,
          current_files
        )
      }
      
      
      # --------------------------------------------------------
      # Nothing found
      # --------------------------------------------------------
      
      if (length(files_to_copy) == 0) {
        
        showNotification(
          "No shapefile files found.",
          type = "warning"
        )
        
        return()
      }
      
      
      # --------------------------------------------------------
      # Copy files
      # --------------------------------------------------------
      
      copied <- file.copy(
        from = files_to_copy,
        to = export_dir,
        overwrite = TRUE
      )
      
      
      # --------------------------------------------------------
      # Status
      # --------------------------------------------------------
      
      n_copied <- sum(copied)
      
      cat("\n========== SHAPEFILE EXPORT ==========\n")
      cat("Pipeline output:", result_dir, "\n")
      cat("Export directory:", export_dir, "\n")
      cat("Files found:", length(files_to_copy), "\n")
      cat("Files copied:", n_copied, "\n")
      cat("======================================\n\n")
      
      showNotification(
        paste(
          n_copied,
          "files copied successfully."
        ),
        type = "message",
        duration = 8
      )
    }
  )
  
  
  # ==========================================================
  # Pipeline result / status
  # ==========================================================
  
  output$pipelineResult <- renderUI({
    
    if (pipeline_running()) {
      
      return(
        tags$div(
          tags$strong("Pipeline is running..."),
          tags$br(),
          "The complete book is currently being processed."
        )
      )
    }
    
    
    if (!is.null(pipeline_error())) {
      
      return(
        tags$div(
          style = "color:#a94442;",
          tags$strong("Pipeline failed."),
          tags$br(),
          pipeline_error()
        )
      )
    }
    
    
    if (!is.null(pipeline_result())) {
      
      return(
        tags$div(
          tags$strong("Pipeline finished successfully."),
          tags$br(),
          tags$span("Output directory:"),
          tags$br(),
          tags$code(pipeline_result())
        )
      )
    }
    
    
    tags$span(
      "No pipeline has been started yet."
    )
  })
}