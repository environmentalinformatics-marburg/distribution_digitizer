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
  
  
  # ==========================================================
  # Read original config.csv
  # ==========================================================
  
  read_pipeline_config <- function() {
    
    config_file <- file.path(
      workingDir,
      "config",
      "config_backup.csv"
    )
    
    if (!file.exists(config_file)) {
      
      showNotification(
        paste(
          "Configuration file not found:",
          config_file
        ),
        type = "error"
      )
      
      return(NULL)
    }
    
    
    # config.csv has no header:
    # parameter;value
    
    config_data <- read.csv(
      config_file,
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
      
      config_data <- pipeline_config()
      
      row <- info$row
      col <- info$col
      value <- info$value
      
      
      # --------------------------------------------------------
      # Only the Value column may be edited
      #
      # DT uses zero-based column numbers here:
      # 0 = Parameter
      # 1 = Value
      # --------------------------------------------------------
      
      if (col != 1) {
        return()
      }
      
      
      config_data$Value[row] <- value
      
      pipeline_config(config_data)
      
      cat(
        "Temporary pipeline config changed:",
        config_data$Parameter[row],
        "=",
        config_data$Value[row],
        "\n"
      )
    }
  )
  # ==========================================================
  # Save pipeline configuration
  # ==========================================================
  
  observeEvent(
    input$savePipelineConfig,
    {
      
      config_data <- pipeline_config()
      req(config_data)
      
      pipeline_config_file <- file.path(
        workingDir,
        "config",
        "config_pipeline.csv"
      )
      
      # --------------------------------------------------------
      # Save current edited configuration
      # --------------------------------------------------------
      
      write.table(
        config_data,
        pipeline_config_file,
        sep = ";",
        row.names = FALSE,
        col.names = FALSE,
        quote = FALSE
      )
      
      cat(
        "\nPipeline configuration saved:\n",
        pipeline_config_file,
        "\n"
      )
      
      showNotification(
        "Pipeline configuration saved successfully.",
        type = "message",
        duration = 5
      )
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
  # Pipeline result
  #
  # Actual pipeline execution will be added next.
  # ==========================================================
  
  # ==========================================================
  # Pipeline execution
  # ==========================================================
  
  pipeline_result <- reactiveVal(NULL)
  pipeline_error  <- reactiveVal(NULL)
  pipeline_running <- reactiveVal(FALSE)
  
  
  observeEvent(
    input$startCompletePipeline,
    {
      
      req(pipeline_config())

      
      # --------------------------------------------------------
      # Select configuration for pipeline run
      # --------------------------------------------------------
      
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
      
      # Default: use tested backup configuration
      pipeline_config_file <- backup_file
      
      # If a pipeline configuration exists, compare both files
      if (file.exists(pipeline_file)) {
        
        backup_config <- readLines(
          backup_file,
          warn = FALSE
        )
        
        pipeline_config <- readLines(
          pipeline_file,
          warn = FALSE
        )
        
        if (!identical(backup_config, pipeline_config)) {
          pipeline_config_file <- pipeline_file
        }
      }
      
      cat(
        "Configuration used for pipeline:",
        pipeline_config_file,
        "\n"
      )
      
      if (!file.exists(pipeline_config_file)) {
        
        showNotification(
          "Please save the pipeline configuration before starting.",
          type = "error",
          duration = 8
        )
        
        return()
      }
      
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
            inputDir,
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