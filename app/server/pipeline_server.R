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
      "config.csv"
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
      
      
      config_data[row, col + 1] <- value
      
      pipeline_config(config_data)
      
      cat(
        "Temporary pipeline config changed:",
        config_data$Parameter[row],
        "=",
        value,
        "\n"
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
  
  output$pipelineResult <- renderUI({
    
    tags$span(
      "No pipeline has been started yet."
    )
  })
}