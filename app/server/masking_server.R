masking_server <- function(
    input,
    output,
    session,
    outDir,
    manageProcessFlow,
    prepareImageView,
    speciesRepresentation
) {
  observe({
    unavailable <- identical(speciesRepresentation(), "contour")
    shinyjs::toggle("masking_unavailable_message", condition = unavailable)
    shinyjs::runjs(if (unavailable) {
      "$('#masking_controls').prop('disabled', true).attr('inert', '').attr('aria-disabled', 'true');"
    } else {
      "$('#masking_controls').prop('disabled', false).removeAttr('inert').attr('aria-disabled', 'false');"
    })
  })

  observeEvent(input$masking, {
    req(!identical(speciesRepresentation(), "contour"))
    manageProcessFlow(
      processing = "masking",
      allertText1 = "masking white background",
      allertText2 = "masking",
      input = input,
      session = session,
      current_out_dir = outDir()
    )
  })

  observeEvent(input$maskingCentroids, {
    req(!identical(speciesRepresentation(), "contour"))
    manageProcessFlow(
      processing = "maskingCentroids",
      allertText1 = "masking centroids",
      allertText2 = "maskingCentroids",
      input = input,
      session = session,
      current_out_dir = outDir()
    )
  })

  observeEvent(input$listMasks, {
    req(!identical(speciesRepresentation(), "contour"))
    output$listMS <- renderUI({
      prepareImageView(
        dirName = "masking_png",
        map_type = input$map_type_Masks,
        range_str = input$range_list_Masks
      )
    })
  })

  observeEvent(input$listMasksCD, {
    req(!identical(speciesRepresentation(), "contour"))
    output$listMCD <- renderUI({
      prepareImageView(
        dirName = "maskingCentroids_png",
        map_type = input$map_type_MasksCentroids,
        range_str = input$range_list_MasksCentroids
      )
    })
  })
}
