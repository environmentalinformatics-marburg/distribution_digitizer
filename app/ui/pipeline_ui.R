# ============================================================
# File: pipeline_ui.R
#
# Description:
# UI for running the complete Distribution Digitizer pipeline.
#
# The current configuration is displayed before processing.
# Configuration values can be temporarily modified for the
# current pipeline run without changing the original config.csv.
#
# The configuration used for the pipeline run will later be
# stored together with the pipeline results for reproducibility.
# ============================================================


pipeline_ui <- function() {
  
  tabItem(
    tabName = "tab9",
    
    fluidRow(
      column(
        12,
        
        wellPanel(
          
          # ====================================================
          # HEADER
          # ====================================================
          
          h3(
            strong("Complete Pipeline"),
            style = "color:black"
          ),
          
          p(
            paste(
              "Review the current configuration and start the complete",
              "Distribution Digitizer processing pipeline."
            ),
            style = "color:black"
          ),
          
          p(
            paste(
              "Configuration values can be temporarily modified for this",
              "pipeline run. The original configuration file will not be changed."
            ),
            style = "color:black"
          ),
          
          tags$hr(),
          
          
          # ====================================================
          # CONFIGURATION
          # ====================================================
          
          h4(
            "Pipeline Configuration",
            style = "color:black"
          ),
          
          p(
            paste(
              "The table shows the configuration that will be used",
              "for the complete pipeline."
            ),
            style = "color:black"
          ),
          
          br(),
          
          DT::DTOutput(
            "pipelineConfigTable"
          ),
          
          br(),
          
          
          # ====================================================
          # CONFIG ACTIONS
          # ====================================================
          
          fluidRow(
            column(
              4,
              actionButton(
                "savePipelineConfig",
                "Save Pipeline Configuration",
                icon = icon("save"),
                class = "btn-primary"
              )
            ),
            column(
              3,
              
              actionButton(
                "resetPipelineConfig",
                "Reset configuration",
                style = "
                  color:#FFFFFF;
                  background:#999999;
                "
              )
            )
          ),
          
          tags$hr(),
          
          
          # ====================================================
          # PIPELINE START
          # ====================================================
          
          h4(
            "Run Complete Pipeline",
            style = "color:black"
          ),
          
          p(
            paste(
              "Start all processing steps using the configuration",
              "shown above."
            ),
            style = "color:black"
          ),
          
          actionButton(
            "startCompletePipeline",
            "Start complete pipeline",
            style = "
              color:#FFFFFF;
              background:#5cb85c;
              font-weight:bold;
            "
          ),
          
          br(),
          br(),
          
          
          # ====================================================
          # PIPELINE STATUS
          # ====================================================
          
          uiOutput(
            "pipelineStatus"
          )
          
        )
      )
    ),
    
    
    # ==========================================================
    # PIPELINE RESULT
    # ==========================================================
    
    fluidRow(
      column(
        12,
        
        wellPanel(
          
          h4(
            "Pipeline Result",
            style = "color:black"
          ),
          
          p(
            "Information about the completed pipeline run.",
            style = "color:black"
          ),
          
          uiOutput(
            "pipelineResult"
          )
        )
      )
    ),helpText(
      "Edit the configuration if necessary, then save it before starting the complete pipeline."
    )
  )
}