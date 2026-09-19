# ============================================================
# File: georeferencing_ui.R
#
# Description:
# UI for the Georeferencing tab.
# ============================================================

georeferencing_ui <- function(
    shinyfields6,
    shinyfields8,
    shinyfields2,
    mapTypes
) {
  
  tabItem(
    tabName = "tab6",
    
    fluidRow(
      column(
        12,
        
        wellPanel(
          
          # ==================================================
          # HEADER
          # ==================================================
          
          h3("Georeferencing"),

          p(
            shinyfields6$inf1,
            style = "color:black"
          ),
          
          p(
            shinyfields6$inf2,
            style = "color:black"
          ),
          
          
          # ==================================================
          # OPTIONAL CALIBRATION
          # ==================================================
          
          selectInput("map_type_Georeferencing", "Map type", choices = mapTypes, selected = mapTypes[1]),
          h4("Georeferencing calibration (optional)"),
          p("Use three representative maps to check the spatial alignment of the rectified results. If the overlay does not match the reference map, move the complete overlay until the best possible alignment is reached. Save the correction, then choose whether to run georeferencing with calibration."),
          checkboxInput("geocal_open", "Open calibration", FALSE),
          conditionalPanel("input.geocal_open",
            div(class = "alert alert-info", role = "note",
              strong("Important: "),
              "Select three representative maps with typical alignment errors. Avoid unusually distorted maps caused by poor scans, page curvature, printing defects or other map-specific deformation. The median X/Y correction addresses a systematic displacement shared by the map type. Strongly distorted maps may need separate correction and should not be used as calibration examples."),
            fluidRow(lapply(1:3, function(i) column(4,
              selectInput(paste0("geocal_file", i), paste("Training map", i), choices = c("Choose a map" = ""))))),
            radioButtons("geocal_active", "Adjust training map", choices = 1:3, selected = 1, inline = TRUE),
            textOutput("geocal_status"),
            leaflet::leafletOutput("geocal_map", height = 480),
            fluidRow(
              column(3, numericInput("geocal_step", "Movement step (metres)", 1000, min = 1)),
              column(3, numericInput("geocal_x", "Correction X (GCP CRS units)", 0)),
              column(3, numericInput("geocal_y", "Correction Y (GCP CRS units)", 0)),
              column(3, sliderInput("geocal_opacity", "Overlay opacity", 0, 1, 0.55, step = 0.05))
            ),
            actionButton("geocal_west", "\u2190 West"),
            actionButton("geocal_east", "\u2192 East"),
            actionButton("geocal_north", "\u2191 North"),
            actionButton("geocal_south", "\u2193 South"),
            actionButton("geocal_apply", "Apply X / Y"),
            actionButton("geocal_reset", "Reset position"),
            actionButton("geocal_position", "Save position for this training map"),
            p("Movement shifts the complete overlay. X/Y are absolute corrections in the GCP CRS; Reset restores this TIFF's original position. Use Apply X / Y after editing the numbers."),
            tableOutput("geocal_states"),
            textOutput("geocal_recommendation"),
            actionButton("geocal_save", "Save calibration", class = "btn-primary")
          ),
          textOutput("geocal_saved_status"),
          div(id = "geocal_comparison",
            h4("Calibration comparison"),
            p("Compare the original position with the saved final calibration. Both views share the same zoom and centre."),
            fluidRow(
              column(8, selectInput("geocal_compare_file", "Map to compare", choices = c("Choose a map" = ""))),
              column(4, sliderInput("geocal_compare_opacity", "Comparison overlay opacity", 0, 1, 0.55, step = 0.05))
            ),
            textOutput("geocal_compare_status"),
            fluidRow(
              column(6, h5("Without calibration"), leaflet::leafletOutput("geocal_compare_left", height = 380)),
              column(6, h5("With calibration"), leaflet::leafletOutput("geocal_compare_right", height = 380))
            )
          ),
          hr(),
          h4("Run georeferencing"),
          actionButton("georeferencing", "Run georeferencing",
            style = "color:#FFFFFF;background:#999999"),
          actionButton("georeferencing_calibrated", "Run georeferencing with calibration",
            disabled = "disabled", class = "btn-primary"),
          hr(),
          h4("Browse georeferencing maps"),
          p("Choose a map to view the georeferenced result or download its original TIFF."),
          fluidRow(
            column(9, textInput("georef_search", "Search file name or page number", placeholder = "e.g. 0036 or map_5")),
            column(3, actionButton("georef_refresh", "Refresh", icon = icon("refresh")))
          ),
          uiOutput("georef_gallery"),
          div(class = "dd-align-pagination",
            actionButton("georef_previous", "Previous"),
            textOutput("georef_page_info", inline = TRUE),
            actionButton("georef_next", "Next")
          ),
          conditionalPanel(
            condition = "output.georef_has_selection === 'true'",
            hr(),
            h4(textOutput("georef_selected_name", inline = TRUE)),
            imageOutput("georef_selected_preview", height = "auto"),
            downloadButton("download_georef_map", "Download georeferenced TIFF", class = "btn-primary")
          )
        ),
        
        
        # ====================================================
        # LEAFLET OUTPUT
        # ====================================================
        
        #uiOutput("leaflet_outputs_GEO")
      )
    ),
    
    
    # ========================================================
    # CSV GEOREFERENCING
    # ========================================================
    
    # wellPanel(
    #   
    #   h4(
    #     shinyfields8$head_sub,
    #     style = "color:red"
    #   ),
    #   
    #   p(
    #     shinyfields8$info1,
    #     style = "color:black"
    #   ),
    #   
    #   p(
    #     shinyfields8$info2,
    #     style = "color:black"
    #   ),
    #   
    #   actionButton(
    #     "georef_coords_from_csv",
    #     label = shinyfields8$lab1,
    #     style = "color:#FFFFFF;background:#999999"
    #   )
    # )
    
  )
}
