# ============================================================
# File: create_templates_server.R
#
# Description:
# Server logic for creating map templates and symbol templates.
#
# Map templates are used to detect map regions on book pages.
# Symbol templates are used to detect distribution symbols
# such as points, circles, squares, etc. inside the maps.
# ============================================================


create_templates_server <- function(
    input,
    output,
    session,
    workingDir,
    tempImage,
    scale,
    rescale,
    plot_png
) {
  
  # ==========================================================
  # DISPLAY SELECTED IMAGE
  # ==========================================================
  
  output$plot <- renderImage({
    
    req(input$image)
    
    temp <- image_read(input$image$datapath)
    file <- image_convert(temp, "png")
    
    temp_scale <- image_scale(
      file,
      paste0(scale, "%")
    )
    
    fname <- paste0(
      workingDir,
      "/",
      tempImage
    )
    
    image_write(
      temp_scale,
      path = fname,
      format = "png"
    )
    
    list(
      src = fname,
      alt = "Selected book page"
    )
    
  }, deleteFile = FALSE)
  
  
  # ==========================================================
  # DISPLAY CROPPED REGION
  # ==========================================================
  
  output$plot1 <- renderPlot({
    
    req(input$image)
    req(input$plot_brush)
    
    plot_png(input$plot_brush)
    
  })
  
  
  # ==========================================================
  # SHOW CROP HINT
  # ==========================================================
  
  output$showCropHint <- reactive({
    
    !is.null(input$plot_brush) &&
      !is.null(input$image)
    
  })
  
  outputOptions(
    output,
    "showCropHint",
    suspendWhenHidden = FALSE
  )
  
  
  # ==========================================================
  # SAVE MAP TEMPLATE
  # ==========================================================
  
  output$saveTemplate <- downloadHandler(
    
    filename = function() {
      
      paste0(
        "map_",
        input$imgIndexTemplate,
        ".tif"
      )
      
    },
    
    content = function(file) {
      
      # Crop coordinates
      x1 <- input$plot_brush$xmin
      x2 <- input$plot_brush$xmax
      y2 <- input$plot_brush$ymin
      y1 <- input$plot_brush$ymax
      
      tempI <- image_read(
        input$image$datapath
      )
      
      width <- (
        x2 * rescale -
          x1 * rescale
      )
      
      height <- (
        y1 * rescale -
          y2 * rescale
      )
      
      geometrie <- paste0(
        width,
        "x",
        height,
        "+",
        x1 * rescale,
        "+",
        y2 * rescale
      )
      
      tempI <- image_crop(
        tempI,
        geometrie
      )
      
      
      # Save directory
      save_dir <- file.path(
        workingDir,
        "output",
        "templates",
        "maps"
      )
      
      if (!dir.exists(save_dir)) {
        
        dir.create(
          save_dir,
          recursive = TRUE
        )
        
      }
      
      
      # Final template path
      save_path <- file.path(
        save_dir,
        paste0(
          "map_",
          input$imgIndexTemplate,
          ".tif"
        )
      )
      
      
      # Save map template
      image_write(
        tempI,
        save_path,
        format = "tif"
      )
      
      
      # Return file to downloadHandler
      file.copy(
        save_path,
        file
      )
      
      
      # Increase map template index
      updateNumericInput(
        session,
        "imgIndexTemplate",
        value = input$imgIndexTemplate + 1
      )
      
    }
  )
  
  
  # ==========================================================
  # SAVE SYMBOL TEMPLATE
  # ==========================================================
  
  output$saveSymbol <- downloadHandler(
    
    filename = function() {
      
      paste(
        workingDir,
        "/data/templates/maps/symbols",
        "_",
        input$imgIndexSymbol,
        ".tif",
        sep = ""
      )
      
    },
    
    content = function(file) {
      
      # Crop coordinates
      x1 <- input$plot_brush$xmin
      x2 <- input$plot_brush$xmax
      y2 <- input$plot_brush$ymin
      y1 <- input$plot_brush$ymax
      
      tempI <- image_read(
        input$image$datapath
      )
      
      width <- (
        x2 * rescale -
          x1 * rescale
      )
      
      height <- (
        y1 * rescale -
          y2 * rescale
      )
      
      geometrie <- paste0(
        width,
        "x",
        height,
        "+",
        x1 * rescale,
        "+",
        y2 * rescale
      )
      
      tempI <- image_crop(
        tempI,
        geometrie
      )
      
      
      # Save symbol template
      image_write(
        tempI,
        file,
        format = "tif"
      )
      
      
      # Increase symbol template index
      i <- input$imgIndexSymbol + 1
      
      updateNumericInput(
        session,
        "imgIndexSymbol",
        value = i
      )
      
    }
  )
  
}