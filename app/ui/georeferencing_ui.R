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
          # RUN GEOREFERENCING
          # ==================================================
          
          actionButton(
            "georeferencing",
            label = shinyfields6$lab1,
            style = "color:#FFFFFF;background:#999999"
          ),
          
          tags$hr(),
          
          
          # ==================================================
          # LIST GEOREFERENCED MAPS
          # ==================================================
          
          h4("Browse georeferencing maps"),
          p("Choose a map to view the georeferenced result or download its original TIFF."),
          fluidRow(
            column(4, selectInput("map_type_Georeferencing", "Map type", choices = mapTypes, selected = mapTypes[1])),
            column(5, textInput("georef_search", "Search file name or page number", placeholder = "e.g. 0036 or map_5")),
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