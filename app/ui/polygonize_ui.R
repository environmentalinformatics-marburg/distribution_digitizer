polygonize_ui <- function(shinyfields2, shinyfields7, mapTypes) {
  tabItem(
    tabName = "tab7",
    fluidRow(
      column(
        12,
        wellPanel(
          h3("Polygonize"),
          p(shinyfields7$inf1, style = "color:black"),
          p(shinyfields7$inf2, style = "color:black"),
          actionButton("polygonize", label = "Run polygonization", style = "color:#FFFFFF;background:#999999"),
          tags$hr(),
          h4("Browse polygonized maps"),
          p("Choose a result to view it on an interactive map or download the shapefile and its companion files."),
          fluidRow(
            column(4, selectInput("map_type_Polygonize", "Map type", choices = mapTypes, selected = mapTypes[1])),
            column(5, textInput("polygon_search", "Search file name or page number", placeholder = "e.g. 0036 or map_5")),
            column(3, actionButton("polygon_refresh", "Refresh", icon = icon("refresh")))
          ),
          uiOutput("polygon_gallery"),
          div(class = "dd-align-pagination",
            actionButton("polygon_previous", "Previous"),
            textOutput("polygon_page_info", inline = TRUE),
            actionButton("polygon_next", "Next")
          ),
          conditionalPanel(
            condition = "output.polygon_has_selection === 'true'",
            hr(),
            h4(textOutput("polygon_selected_name", inline = TRUE)),
            uiOutput("leaflet_outputs_PL"),
            downloadButton("download_polygon_map", "Download shapefile ZIP", class = "btn-primary")
          )
        )
      )
    )
  )
}
