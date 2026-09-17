spatial_view_ui <- function(shinyfields2, mapTypes) {
  tabItem(
    tabName = "tab8",
    fluidRow(
      column(
        12,
        wellPanel(
          h3("Spatial Data View"),
          p("Compute and explore the final species distribution data.", style = "color:black"),
          actionButton("startSpatialDataComputing", label = "Compute spatial data", style = "color:#FFFFFF;background:#999999"),
          tags$hr(),
          conditionalPanel(
            condition = "input.speciesRepresentation == 'point'",
            fluidRow(
              column(4, textInput("range_list_Spatial", label = HTML(shinyfields2$inf7), value = "1-2")),
              column(4, selectInput("map_type_Spatial", label = "Select map type:", choices = mapTypes, selected = mapTypes[1])),
              column(4, actionButton("spatialViewPF", "Show point results"))
            )
          )
        ),
        conditionalPanel(
          condition = "input.speciesRepresentation == 'point'",
          wellPanel(leafletOutput("mapSpatialViewPF", height = 600), verbatimTextOutput("hoverInfo3"))
        ),
        wellPanel(
          h4("Final Species Distribution Data", style = "color:black"),
          p("Load and display the final species distribution data.", style = "color:black"),
          actionButton("showFinalSpeciesData", "Show final data", style = "color:#FFFFFF; background:#337ab7; border-color:#2e6da4;"),
          br(),
          br(),
          DT::DTOutput("finalSpeciesTable"),
          tags$hr(),
          textInput("speciesSpatialSearch", label = "Search species:", placeholder = "e.g. Watsonalla binaria"),
          actionButton("showSpeciesDistribution", "Show species distribution"),
          downloadButton("downloadFinalSpeciesCSV", "Download final CSV")
        ),
        wellPanel(
          uiOutput("selectedSpeciesTitle"),
          leafletOutput("speciesDistributionMap", height = 600)
        )
      )
    )
  )
}
