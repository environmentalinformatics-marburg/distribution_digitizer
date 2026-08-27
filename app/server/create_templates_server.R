# ============================================================
# File: create_templates_server.R
#
# Description:
# Server logic for creating:
#   1. map templates for map detection
#   2. symbol templates for distribution detection
# ============================================================


create_templates_server <- function(
    input,
    output,
    session,
    workingDir,
    tempImage,
    speciesRepresentation 
) {
  
  # ==========================================================
  # DISPLAY SETTINGS
  # ==========================================================
  
  template_display_scale <- 25
  template_rescale <- 100 / template_display_scale
  
  
  # ==========================================================
  # HELPER FUNCTION: SHOW CROPPED IMAGE
  # ==========================================================
  
  plot_png <- function(plot_brush) {
    
    require("png")
    
    fname <- tempImage
    
    if (!file.exists(fname)) {
      return()
    }
    
    img <- as.raster(
      png::readPNG(fname)
    )
    
    res <- dim(img)[2:1]
    
    
    # --------------------------------------------------------
    # No crop selected
    # --------------------------------------------------------
    
    if (
      is.null(plot_brush) ||
      any(
        is.na(
          c(
            plot_brush$xmin,
            plot_brush$xmax,
            plot_brush$ymin,
            plot_brush$ymax
          )
        )
      )
    ) {
      
      plot(
        1, 1,
        type = "n",
        xlim = c(1, res[1]),
        ylim = c(1, res[2]),
        xlab = "",
        ylab = "",
        asp = 1,
        axes = FALSE
      )
      
      text(
        mean(res[1]),
        mean(res[2]),
        "Draw a crop area in the left image",
        col = "gray40"
      )
      
      return()
    }
    
    
    # --------------------------------------------------------
    # Crop coordinates
    # --------------------------------------------------------
    
    x1 <- round(plot_brush$xmin)
    x2 <- round(plot_brush$xmax)
    
    y1 <- round(plot_brush$ymax)
    y2 <- round(plot_brush$ymin)
    
    
    # Keep coordinates inside image
    x1 <- max(1, min(x1, res[1]))
    x2 <- max(1, min(x2, res[1]))
    
    y1 <- max(1, min(y1, res[2]))
    y2 <- max(1, min(y2, res[2]))
    
    
    # --------------------------------------------------------
    # Check selection size
    # --------------------------------------------------------
    
    if (
      x2 - x1 < 2 ||
      y1 - y2 < 2
    ) {
      
      plot(
        1, 1,
        type = "n",
        xlim = c(1, res[1]),
        ylim = c(1, res[2]),
        xlab = "",
        ylab = "",
        asp = 1,
        axes = FALSE
      )
      
      text(
        mean(res[1]),
        mean(res[2]),
        "Selection too small",
        col = "gray40"
      )
      
      return()
    }
    
    
    # --------------------------------------------------------
    # Show cropped region
    # --------------------------------------------------------
    
    plot(
      1, 1,
      xlim = c(1, x2 - x1),
      ylim = c(1, y1 - y2),
      asp = 1,
      type = "n",
      xaxs = "i",
      yaxs = "i",
      xaxt = "n",
      yaxt = "n",
      xlab = "",
      ylab = "",
      bty = "n"
    )
    
    grid::grid.raster(
      img[y2:y1, x1:x2, ]
    )
  }
  
  
  # ==========================================================
  # DISPLAY UPLOADED IMAGE
  # ==========================================================
  
  output$plot <- renderImage({
    
    req(input$image)
    
    # Load image
    img <- image_read(
      input$image$datapath
    )
    
    # Convert to PNG
    img <- image_convert(
      img,
      "png"
    )
    
    # Scale image for display
    img <- image_scale(
      img,
      paste0(template_display_scale, "%")
    )
    
    # Temporary image used by plot_png()
    temp_path <- file.path(
      getwd(),
      tempImage
    )
    
    image_write(
      img,
      path = temp_path,
      format = "png"
    )
    
    list(
      src = temp_path,
      alt = "uploaded image"
    )
    
  }, deleteFile = FALSE)
  
  
  # ==========================================================
  # DISPLAY CROPPED PREVIEW
  # ==========================================================
  
  output$plot1 <- renderPlot({
    
    req(input$image)
    req(input$plot_brush)
    
    plot_png(
      input$plot_brush
    )
    
  })
  
  output$showSymbolTemplate <- reactive({
    
    req(speciesRepresentation())
    
    speciesRepresentation() == "point"
  })
  
  outputOptions(
    output,
    "showSymbolTemplate",
    suspendWhenHidden = FALSE
  )
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
      
      req(input$image)
      req(input$plot_brush)
      req(input$imgIndexTemplate)
      
      # --------------------------------------------------------
      # Crop coordinates
      # --------------------------------------------------------
      
      x1 <- input$plot_brush$xmin
      x2 <- input$plot_brush$xmax
      y2 <- input$plot_brush$ymin
      y1 <- input$plot_brush$ymax
      
      tempI <- image_read(
        input$image$datapath
      )
      
      width <- x2 * template_rescale - x1 * template_rescale
      height <- y1 * template_rescale - y2 * template_rescale
      
      geometrie <- paste0(
        width,
        "x",
        height,
        "+",
        x1 * template_rescale,
        "+",
        y2 * template_rescale
      )
      
      tempI <- image_crop(
        tempI,
        geometrie
      )
      
      
      # --------------------------------------------------------
      # Save directory
      # --------------------------------------------------------
      
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
      
      
      # --------------------------------------------------------
      # Save template
      # --------------------------------------------------------
      
      save_path <- file.path(
        save_dir,
        paste0(
          "map_",
          input$imgIndexTemplate,
          ".tif"
        )
      )
      
      image_write(
        tempI,
        save_path,
        format = "tif"
      )
      
      # File for browser download
      file.copy(
        save_path,
        file,
        overwrite = TRUE
      )
      
      
      # --------------------------------------------------------
      # Increase template number
      # --------------------------------------------------------
      
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
  
  # ... dein bestehender output$saveSymbol kommt hier ...
  
}