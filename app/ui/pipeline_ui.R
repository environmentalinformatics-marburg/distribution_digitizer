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
              "Review the configuration below before starting the complete processing pipeline.",
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
          
          p("Review and edit the configuration values if necessary.",
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
          
          h4(
            "Save Changes",
            style = "color:black"
          ),
          p(
            "If you edited any values above, save the changes before starting the pipeline.",
            style = "color:black"
          ),
          
          actionButton(
            "savePipelineConfig",
            "SAVE ",
            icon = icon("save"),
            style = "
              color:#FFFFFF;
              background:#337ab7;
              font-weight:bold;
            "
          ),
          tags$hr(),
          
          # ====================================================
          # PIPELINE START
          # ====================================================
          h4(
            "Run Complete Pipeline",
            style = "color:black"
          ),
          actionButton(
            "startCompletePipeline",
            "START ",
            icon = icon("play"),
            style = "
              color:#FFFFFF;
              background:#5cb85c;
              font-weight:bold;
            "
          ),

          p(
            paste(
              "Start all processing steps using the configuration",
              "shown above."
            ),
            style = "color:black"
          ),
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
          ),
          br(),
          uiOutput("pipelineMapSelector"),
          uiOutput(
            "pipelineResultActions"
          ),
          
          br(),
          
          DT::DTOutput(
            "pipelineResultTable"
          ),
          br(),
          
          leaflet::leafletOutput(
            "pipelineResultMap",
            height = 500
          )
        )
      )
    ),helpText(
      "Edit the configuration if necessary, then save it before starting the complete pipeline."
    )
  )
}