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

  # getVolumes() returns a function in shinyFiles; call that function once
  # more to obtain the actual named roots expected by shinyDirChoose.
  saved_result_roots <- shinyFiles::getVolumes()()
  shinyFiles::shinyDirChoose(
    input,
    "savedPipelineOutputDirPicker",
    roots = saved_result_roots,
    session = session,
    allowDirCreate = FALSE
  )

  observeEvent(input$savedPipelineOutputDirPicker, {
    selected_dir <- shinyFiles::parseDirPath(
      saved_result_roots,
      input$savedPipelineOutputDirPicker
    )

    if (length(selected_dir) == 1L && nzchar(selected_dir)) {
      updateTextInput(session, "savedPipelineOutputDir", value = selected_dir)
    }
  })

  available_pipeline_map_types <- reactive({
    result_dir <- pipeline_result()
    req(result_dir, dir.exists(result_dir))

    map_dirs <- list.dirs(result_dir, recursive = FALSE, full.names = TRUE)
    map_dirs <- map_dirs[grepl("[/\\\\][0-9]+$", map_dirs)]
    map_types <- basename(map_dirs)

    map_types[file.exists(file.path(map_dirs, "spatial_data_final.csv"))]
  })

  selected_pipeline_map <- reactive({
    map_types <- available_pipeline_map_types()
    req(length(map_types) > 0)

    selected <- if (is.null(input$pipelineMapType)) "" else as.character(input$pipelineMapType)
    if (selected %in% map_types) return(as.integer(selected))

    as.integer(map_types[1])
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

  # Preserve every current config.csv entry when saving pipeline-specific
  # changes. This also keeps fields added after a pipeline session began.
  merge_pipeline_config <- function(pipeline_data) {
    base_data <- read_pipeline_config()
    req(base_data, pipeline_data)

    # Calibration is trained in Georeferencing. A stale pipeline table must not
    # restore an older correction when saving or starting a subsequent run.
    common_keys <- setdiff(intersect(base_data$Parameter, pipeline_data$Parameter),
      grep("^georefCalibration_[0-9]+_", base_data$Parameter, value = TRUE))
    for (key in common_keys) {
      base_data$Value[base_data$Parameter == key] <-
        pipeline_data$Value[pipeline_data$Parameter == key][1]
    }

    additional_rows <- pipeline_data[
      !pipeline_data$Parameter %in% base_data$Parameter,
      ,
      drop = FALSE
    ]

    rbind(base_data, additional_rows)
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

      is_valid_pipeline_result <- function(candidate) {
        if (is.null(candidate) || length(candidate) != 1L ||
            !nzchar(trimws(as.character(candidate))) ||
            !dir.exists(candidate)) {
          return(FALSE)
        }

        numeric_map_dirs <- list.dirs(
          candidate,
          recursive = FALSE,
          full.names = TRUE
        )
        numeric_map_dirs <- numeric_map_dirs[
          grepl("[/\\\\][0-9]+$", numeric_map_dirs)
        ]

        length(numeric_map_dirs) > 0L && any(
          file.exists(file.path(numeric_map_dirs, "spatial_data_final.csv"))
        )
      }

      if (!is_valid_pipeline_result(result_dir)) {
        saved_result_dir <- trimws(input$savedPipelineOutputDir %||% "")
        if (is_valid_pipeline_result(saved_result_dir)) {
          result_dir <- normalizePath(
            saved_result_dir,
            winslash = "/",
            mustWork = TRUE
          )
        } else {
          showNotification(
            "Please select a valid saved pipeline result directory before downloading shapefiles.",
            type = "error",
            duration = NULL
          )
          stop(
            "No valid pipeline result is available. Select a saved pipeline result directory first.",
            call. = FALSE
          )
        }
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
      # Prepare renamed download files without changing originals
      # ------------------------------------------------------

      selected_tokens <- input$downloadFilenameTokens
      if (is.null(selected_tokens)) selected_tokens <- character(0)
      selected_tokens <- unique(c("page", "y", "x", selected_tokens))

      parse_filename_tokens <- function(shape_path) {
        stem <- tools::file_path_sans_ext(basename(shape_path))
        stem <- sub("_filtered$", "", stem)
        parts <- strsplit(stem, "_", fixed = TRUE)[[1]]
        first_part <- if (length(parts)) parts[1] else ""
        y_index <- which(grepl("^y[^_]*$", parts))[1]
        x_index <- which(grepl("^x[^_]*$", parts))[1]
        n_index <- which(grepl("^n[^_]*$", parts))[1]

        list(
          page = sub("-thr.*$", "", first_part),
          threshold = sub("^[^-]*-", "", first_part),
          page_id = if (length(parts) >= 2) parts[2] else "",
          map_id = if (!is.na(y_index) && y_index > 3) paste(parts[3:(y_index - 1)], collapse = "_") else "",
          y = if (!is.na(y_index)) parts[y_index] else "",
          x = if (!is.na(x_index)) parts[x_index] else "",
          sequence = if (!is.na(n_index)) parts[n_index] else ""
        )
      }

      resolve_shape_file <- function(row, map_dir) {
        candidates <- character(0)
        for (column in c("shape_file", "map_name", "File", "file_name")) {
          if (column %in% names(row)) {
            value <- as.character(row[[column]][1])
            if (!is.na(value) && nzchar(value)) candidates <- c(candidates, value)
          }
        }

        shape_dir <- file.path(map_dir, "polygonize", "pointFiltering")
        for (candidate in candidates) {
          if (file.exists(candidate) && grepl("\\.shp$", candidate, ignore.case = TRUE)) {
            return(normalizePath(candidate, winslash = "/", mustWork = TRUE))
          }
          candidate_base <- tools::file_path_sans_ext(basename(candidate))
          candidate_base <- sub("_filtered$", "", candidate_base)
          for (shape_name in c(paste0(candidate_base, "_filtered.shp"), paste0(candidate_base, ".shp"))) {
            shape_path <- file.path(shape_dir, shape_name)
            if (file.exists(shape_path)) return(normalizePath(shape_path, winslash = "/", mustWork = TRUE))
          }
        }
        NA_character_
      }

      build_download_basename <- function(tokens) {
        token_values <- unlist(tokens[selected_tokens], use.names = FALSE)
        token_values <- token_values[nzchar(token_values)]
        paste(token_values, collapse = "_")
      }

      temp_download <- file.path(result_dir, "temp_download")
      if (dir.exists(temp_download)) unlink(temp_download, recursive = TRUE, force = TRUE)
      dir.create(temp_download, recursive = TRUE, showWarnings = FALSE)

      download_rows <- list()
      copied_count <- 0L

      for (map_dir in map_dirs) {
        spatial_data_file <- file.path(map_dir, "spatial_data_final.csv")
        if (!file.exists(spatial_data_file)) next
        records <- read.csv(spatial_data_file, stringsAsFactors = FALSE, check.names = FALSE)
        map_download_dir <- file.path(temp_download, basename(map_dir), "polygonize", "pointFiltering")
        dir.create(map_download_dir, recursive = TRUE, showWarnings = FALSE)
        used_names <- character(0)

        for (row_index in seq_len(nrow(records))) {
          row <- records[row_index, , drop = FALSE]
          source_shape <- resolve_shape_file(row, map_dir)
          row$download_shape_file <- NA_character_

          if (!is.na(source_shape) && file.exists(source_shape)) {
            tokens <- parse_filename_tokens(source_shape)
            new_base <- build_download_basename(tokens)
            if (!nzchar(new_base)) new_base <- tools::file_path_sans_ext(basename(source_shape))
            if (new_base %in% used_names) {
              duplicate_index <- sum(used_names == new_base) + 1L
              new_base <- paste0(new_base, "_dup", duplicate_index)
            }
            used_names <- c(used_names, new_base)

            source_stem <- tools::file_path_sans_ext(basename(source_shape))
            companion_files <- list.files(
              dirname(source_shape),
              full.names = TRUE
            )
            companion_files <- companion_files[
              tools::file_path_sans_ext(basename(companion_files)) == source_stem
            ]

            for (companion in companion_files) {
              extension <- tools::file_ext(companion)
              destination <- file.path(map_download_dir, paste0(new_base, ".", extension))
              if (file.copy(companion, destination, overwrite = TRUE)) copied_count <- copied_count + 1L
            }

            row$download_shape_file <- file.path(
              basename(map_dir),
              "polygonize",
              "pointFiltering",
              paste0(new_base, ".shp")
            )
          }
          download_rows[[length(download_rows) + 1L]] <- row
        }
      }

      if (!length(download_rows) || copied_count == 0L) {
        stop("No shapefile records could be prepared for download.")
      }

      download_data <- do.call(rbind, download_rows)
      write.csv(
        download_data,
        file.path(temp_download, "spatial_data_final_download.csv"),
        row.names = FALSE,
        na = ""
      )

      old_wd <- getwd()
      on.exit(setwd(old_wd), add = TRUE)
      setwd(temp_download)
      zip::zipr(
        file,
        files = list.files(".", recursive = TRUE),
        include_directories = FALSE
      )
      
      
      cat("Files exported:", copied_count, "\n")
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
      
      config_data <- merge_pipeline_config(pipeline_config())
      req(config_data)
      pipeline_config(config_data)
      
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
      calibration_data <- read_pipeline_config()
      calibration_rows <- grepl("^georefCalibration_[0-9]+_", calibration_data$Parameter)
      config_data <- rbind(
        config_data[!grepl("^georefCalibration_[0-9]+_", config_data$Parameter), , drop = FALSE],
        calibration_data[calibration_rows, , drop = FALSE]
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

          # Store the actual output directory created for this run in the
          # pipeline-specific configuration file.
          saved_pipeline_config <- merge_pipeline_config(pipeline_config())
          output_row <- match("dataOutputDir", saved_pipeline_config$Parameter)
          if (!is.na(output_row)) {
            saved_pipeline_config$Value[output_row] <- output_dir
            pipeline_config(saved_pipeline_config)
            write.table(
              saved_pipeline_config,
              pipeline_config_file,
              sep = ";",
              row.names = FALSE,
              col.names = FALSE,
              quote = FALSE
            )
          }
          
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

  observeEvent(input$viewSavedPipelineResults, {
    result_dir <- trimws(input$savedPipelineOutputDir %||% "")

    if (!nzchar(result_dir) || !dir.exists(result_dir)) {
      showNotification(
        "Enter a valid previously completed pipeline output folder.",
        type = "warning"
      )
      return()
    }

    # Users may choose either the full pipeline output folder or one map
    # type subfolder, such as .../full_output_<book>/<map type>/.
    if (
      grepl("^[0-9]+$", basename(result_dir)) &&
        file.exists(file.path(result_dir, "spatial_data_final.csv"))
    ) {
      result_dir <- dirname(result_dir)
    }

    map_dirs <- list.dirs(result_dir, recursive = FALSE, full.names = TRUE)
    has_result_data <- any(
      grepl("[/\\\\][0-9]+$", map_dirs) &
        file.exists(file.path(map_dirs, "spatial_data_final.csv"))
    )

    if (!has_result_data) {
      showNotification(
        "No spatial_data_final.csv file was found in this output folder.",
        type = "warning"
      )
      return()
    }

    result_dir <- normalizePath(result_dir, winslash = "/", mustWork = TRUE)
    updateTextInput(session, "savedPipelineOutputDir", value = result_dir)
    pipeline_result(result_dir)
    show_pipeline_results(TRUE)
  })
  
  output$pipelineMapSelector <- renderUI({
    
    req(pipeline_result())
    map_types <- available_pipeline_map_types()
    req(length(map_types) > 0)

    selectInput(
      "pipelineMapType",
      "Select map type:",
      choices = map_types,
      selected = map_types[1]
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
