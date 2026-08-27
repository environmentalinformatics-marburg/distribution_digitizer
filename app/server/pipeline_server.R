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
    workingDir
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
    
    backup_file <- file.path(
      workingDir,
      "config",
      "config_backup.csv"
    )
    
    pipeline_file <- file.path(
      workingDir,
      "config",
      "config_pipeline.csv"
    )
    
    if (!file.exists(backup_file)) {
      
      showNotification(
        paste(
          "Configuration backup file not found:",
          backup_file
        ),
        type = "error"
      )
      
      return(NULL)
    }
    
    # --------------------------------------------------------
    # Create fresh pipeline configuration from backup
    # --------------------------------------------------------
    
    file.copy(
      from = backup_file,
      to = pipeline_file,
      overwrite = TRUE
    )
    
    # --------------------------------------------------------
    # Read the fresh pipeline configuration for the UI
    # --------------------------------------------------------
    
    config_data <- read.csv(
      pipeline_file,
      sep = ";",
      header = FALSE,
      stringsAsFactors = FALSE,
      col.names = c(
        "Parameter",
        "Value"
      ),
      check.names = FALSE
    )
    
    config_data
  }
  
 
  
  
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
  
  output$pipelineConfigTable <- DT::renderDT({
    
    req(pipeline_config())
    
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
      
      options = list(
        pageLength = 25,
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