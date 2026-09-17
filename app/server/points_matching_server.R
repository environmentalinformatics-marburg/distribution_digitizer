points_matching_server <- function(
    input,
    output,
    session,
    outDir,
    manageProcessFlow,
    prepareImageView
) {
  observeEvent(input$pointMatching, {
    manageProcessFlow(
      processing = "pointMatching",
      allertText1 = "points matching",
      allertText2 = "pointMatching",
      input = input,
      session = session,
      current_out_dir = outDir()
    )
  })

  observeEvent(input$listPointsM, {
    output$listPM <- renderUI({
      prepareImageView(
        dirName = "pointMatching_png",
        map_type = input$map_type_PointsMatching,
        range_str = input$range_list_PointsMatching
      )
    })
  })

  observeEvent(input$pointFiltering, {
    manageProcessFlow(
      processing = "pointFiltering",
      allertText1 = "points filtering",
      allertText2 = "pointFiltering",
      input = input,
      session = session,
      current_out_dir = outDir()
    )
  })

  observeEvent(input$listPointsF, {
    output$listPF <- renderUI({
      prepareImageView(
        dirName = "pointFiltering_png",
        map_type = input$map_type_PointsFiltering,
        range_str = input$range_list_PointsFiltering
      )
    })
  })

  observeEvent(input$listMapsMatching2, {
    output$listMapsMatching2 <- renderUI({
      if (input$siteNumberPointsMatching != '') {
        prepareImageView("/output/matching_png/", input$siteNumberPointsMatching)
      } else {
        prepareImageView("/output/matching_png/", '.png')
      }
    })
  })
}
