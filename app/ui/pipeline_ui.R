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
          
          h3("Complete Pipeline"),
          
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
            "Save changes",
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
            "Start pipeline",
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

          fluidRow(
            column(
              6,
              textInput(
                "savedPipelineOutputDir",
                "Previously completed pipeline output folder:",
                placeholder = "Paste the full output folder path"
              )
            ),
            column(
              3,
              br(),
              shinyFiles::shinyDirButton(
                "savedPipelineOutputDirPicker",
                "Choose folder",
                "Choose a completed pipeline output folder or a map type folder"
              )
            ),
            column(
              3,
              br(),
              actionButton(
                "viewSavedPipelineResults",
                "View saved results",
                icon = icon("folder-open"),
                class = "btn-primary"
              )
            )
          ),

          conditionalPanel(
            condition = "input.showPipelineResults > 0",
            tags$hr(),
            h4("Pipeline results", style = "color:black"),
            p("Select a result row to view its polygon on the map.", style = "color:black"),
            DT::DTOutput("pipelineResultTable"),
            br(),
            leaflet::leafletOutput("pipelineResultMap", height = 600)
          ),
          
          br(),
          
          # ============================================================
          # USER QUALITY FOR THE RESULTS
          # ============================================================

          tags$hr(),

          h4(
            "User Quality for the Results",
            style = "color:black"
          ),

          p(
            "Choose which optional components should be kept in the shapefile names prepared for download. Page number, y coordinate, and x coordinate are always included.",
            style = "color:black"
          ),

          tags$div(
            tags$strong("Mandatory components (always included):"),
            tags$div(
              class = "checkbox",
              tags$label(
                tags$input(type = "checkbox", checked = "checked", disabled = "disabled"),
                " Page number"
              )
            ),
            tags$div(
              class = "checkbox",
              tags$label(
                tags$input(type = "checkbox", checked = "checked", disabled = "disabled"),
                " Y coordinate"
              )
            ),
            tags$div(
              class = "checkbox",
              tags$label(
                tags$input(type = "checkbox", checked = "checked", disabled = "disabled"),
                " X coordinate"
              )
            )
          ),

          checkboxGroupInput(
            "downloadFilenameTokens",
            "Optional filename components:",
            choices = c(
              "Threshold" = "threshold",
              "Scanned page ID" = "page_id",
              "Map/template identifier" = "map_id",
              "Existing identifier (n)" = "sequence"
            ),
            selected = c("threshold", "page_id", "map_id", "sequence")
          ),

          # ============================================================
          # EXPORT SHAPEFILES
          # ============================================================
          
          tags$hr(),
          
          h4(
            "Export Shapefiles",
            style = "color:black"
          ),
          
          p(
            paste(
              "Download all generated shapefiles from the current",
              "pipeline result as a ZIP archive."
            ),
            style = "color:black"
          ),
          
          downloadButton(
            "downloadShapefiles",
            "Download shapefiles",
            style = "
    color:#FFFFFF;
    background:#337ab7;
    font-weight:bold;
  "
          ),
          
          tags$hr(),
        )
      )
    ),helpText(
      "Edit the configuration if necessary, then save it before starting the complete pipeline."
    )
  )
}
