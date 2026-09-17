masking_ui <- function(shinyfields2, shinyfields5.1, mapTypes) {
  tabItem(
    tabName = "tab4",
    shinyjs::hidden(
      div(
        id = "masking_unavailable_message",
        role = "alert",
        style = "color:#a12622;background:#fce8e6;border:1px solid #c62828;border-radius:6px;padding:16px;margin-bottom:18px;font-weight:600;",
        "Masking is only available for point/symbol distributions.",
        tags$br(),
        "The current species representation is set to Contours / areas."
      )
    ),
    tags$fieldset(
      id = "masking_controls", disabled = "disabled", inert = "inert",
    fluidRow(
      column(
        6,
        wellPanel(
          h3("Centroid masking", style = "color:black"),
          h4("You can mask the centroids of the points detected by Point Filtering and Circle Detection.", style = "color:black"),
          p(shinyfields5.1$inf1, style = "color:black"),
          actionButton("maskingCentroids", label = shinyfields5.1$lab1, style = "color:#FFFFFF;background:#999999"),
          conditionalPanel(
            condition = "input.maskingCentroids > 0",
            fluidRow(
              column(
                6,
                h4("Review centroid masks"),
                textInput("range_list_MasksCentroids", HTML(shinyfields2$inf7), "1-2"),
                selectInput("map_type_MasksCentroids", "Select map type:", mapTypes),
                actionButton("listMasksCD", "Show centroid masks")
              )
            ),
            tags$hr(),
            uiOutput("listMCD")
          )
        )
      )
    )
    )
  )
}
