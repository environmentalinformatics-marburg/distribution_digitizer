# ============================================================
# File: create_templates_server.R
#
# Description:
# Server logic for creating:
#   1. map templates for map detection
#   2. symbol templates for distribution detection
# ============================================================


book_structure_training_server <- function(
    input,
    output,
    session,
    workingDir,
    tempImage,
    speciesRepresentation 
) {
  
  # ==========================================================
  # PAGE NUMBER OCR - LOAD PYTHON MODULE
  # ==========================================================
  
  page_number_ocr <- reticulate::import_from_path(
    "page_number_training_ocr",
    path = file.path(
      workingDir,
      "src",
      "page_structure"
    )
  )
 
  # ==========================================================
  # PAGE NUMBER TRAINING - TEMPORARY DATA
  # ==========================================================
  
  pageNumberTrainingRegions <- reactiveVal(
    data.frame(
      region_id = integer(),
      page = character(),
      
      x = numeric(),
      y = numeric(),
      width = numeric(),
      height = numeric(),
      
      x_relative = numeric(),
      y_relative = numeric(),
      width_relative = numeric(),
      height_relative = numeric(),
      
      ocr_text = character(),
      confirmed_text = character(),
      
      stringsAsFactors = FALSE
    )
    
  ) 
  
  # ==========================================================
  # ADD PAGE NUMBER TRAINING REGION
  # ==========================================================
  
  observeEvent(
    input$addPageNumberTrainingRegion,
    {
      
      req(input$page_number_training_page)
      req(input$page_number_training_region)
      
      sel <- input$page_number_training_region
      
      # ------------------------------------------------------
      # Absolute coordinates in displayed image
      # ------------------------------------------------------
      
      x <- sel$x
      y <- sel$y
      width <- sel$width
      height <- sel$height
      
      
      # ------------------------------------------------------
      # Relative coordinates
      # ------------------------------------------------------
      
      x_relative <-
        x / sel$image_width
      
      y_relative <-
        y / sel$image_height
      
      width_relative <-
        width / sel$image_width
      
      height_relative <-
        height / sel$image_height
      
      # ------------------------------------------------------
      # Run OCR on selected page-number region
      # ------------------------------------------------------
      
      original_page <- file.path(
        workingDir,
        "data",
        "input",
        "pages",
        sub(
          "\\.png$",
          ".tif",
          input$page_number_training_page,
          ignore.case = TRUE
        )
      )
      
      if (!file.exists(original_page)) {
        stop(
          paste(
            "Original page not found:",
            original_page
          )
        )
      }
      
      ocr_result <- page_number_ocr$read_page_number_region(
        image_path = original_page,
        x_relative = x_relative,
        y_relative = y_relative,
        width_relative = width_relative,
        height_relative = height_relative
      )
      
      ocr_result <- as.character(ocr_result)
      # ------------------------------------------------------
      # Existing training data
      # ------------------------------------------------------
      
      regions <- pageNumberTrainingRegions()
      
      new_id <- if (nrow(regions) == 0) {
        1
      } else {
        max(regions$region_id) + 1
      }
      
      
      # ------------------------------------------------------
      # New training region
      # OCR will be added in the next step
      # ------------------------------------------------------
      
      new_region <- data.frame(
        region_id = new_id,
        page = input$page_number_training_page,
        
        x = x,
        y = y,
        width = width,
        height = height,
        
        x_relative = x_relative,
        y_relative = y_relative,
        width_relative = width_relative,
        height_relative = height_relative,
        
        ocr_text = ocr_result,
        confirmed_text = ocr_result,
        
        stringsAsFactors = FALSE
      )
      
      
      # ------------------------------------------------------
      # Add to temporary training data
      # ------------------------------------------------------
      
      regions <- rbind(
        regions,
        new_region
      )
      
      pageNumberTrainingRegions(
        regions
      )
    }
  )
  
  # ==========================================================
  # SHOW PAGE NUMBER TRAINING REGIONS
  # ==========================================================
  
  output$page_number_training_regions <- renderUI({
    
    regions <- pageNumberTrainingRegions()
    
    if (nrow(regions) == 0) {
      
      return(
        tags$p(
          "No page-number regions added yet.",
          style = "color:#777;"
        )
      )
    }
    
    
    tagList(
      lapply(
        seq_len(nrow(regions)),
        function(i) {
          
          r <- regions[i, ]
          
          wellPanel(
            
            strong(
              paste0(
                "Training example ",
                r$region_id
              )
            ),
            
            tags$br(),
            
            paste(
              "Page:",
              r$page
            ),
            
            tags$br(),
            tags$br(),
            
            tags$strong("OCR detected: "),
            
            tags$span(
              ifelse(
                nchar(trimws(r$ocr_text)) > 0,
                r$ocr_text,
                "No text detected"
              ),
              style = "color:#337ab7; font-weight:bold;"
            ),
            
            tags$br(),
            tags$br(),
            textInput(
              inputId = paste0(
                "page_number_confirmed_",
                r$region_id
              ),
              label = "Correct page number:",
              value = r$confirmed_text,
              width = "150px"
            ),
            paste0(
              "x = ", round(r$x_relative, 4),
              ", y = ", round(r$y_relative, 4)
            ),
            
            tags$br(),
            
            paste0(
              "width = ", round(r$width_relative, 4),
              ", height = ", round(r$height_relative, 4)
            )
          )
        }
      )
    )
  })
  
  # ==========================================================
  # UPDATE CONFIRMED PAGE NUMBERS
  # ==========================================================
  
  observe({
    
    regions <- pageNumberTrainingRegions()
    
    if (nrow(regions) == 0) {
      return()
    }
    
    changed <- FALSE
    
    for (i in seq_len(nrow(regions))) {
      
      input_id <- paste0(
        "page_number_confirmed_",
        regions$region_id[i]
      )
      
      corrected_value <- input[[input_id]]
      
      if (
        !is.null(corrected_value) &&
        !identical(
          corrected_value,
          regions$confirmed_text[i]
        )
      ) {
        
        regions$confirmed_text[i] <- corrected_value
        changed <- TRUE
      }
    }
    
    if (changed) {
      pageNumberTrainingRegions(regions)
    }
  })
  # ==========================================================
  # PAGE NUMBER TRAINING - AVAILABLE PAGES
  # ==========================================================
  
  observe({
    
    pages_dir <- file.path(
      workingDir,
      "app",
      "www",
      "pages"
    )
    
    if (!dir.exists(pages_dir)) {
      return()
    }
    
    page_files <- list.files(
      pages_dir,
      pattern = "\\.(png|jpg|jpeg|tif|tiff)$",
      ignore.case = TRUE
    )
    
    if (length(page_files) == 0) {
      return()
    }
    
    page_files <- sort(page_files)
    
    updateSelectInput(
      session,
      "page_number_training_page",
      choices = page_files,
      selected = page_files[1]
    )
  })
  # ==========================================================
  # PAGE NUMBER TRAINING - SHOW SELECTED PAGE
  # ==========================================================
  
  output$page_number_training_page_preview <- renderUI({
    
    req(input$page_number_training_page)
    
    page_file <- input$page_number_training_page
    
    # File is located in app/www/pages
    page_path <- file.path(
      workingDir,
      "app",
      "www",
      "pages",
      page_file
    )
    
    if (!file.exists(page_path)) {
      return(
        tags$p(
          paste(
            "Page image not found:",
            page_file
          ),
          style = "color:red;"
        )
      )
    }
    
    # ==========================================================
    # PAGE NUMBER TRAINING - STATUS
    # ==========================================================
    
    output$page_number_training_status <- renderUI({
      
      regions <- pageNumberTrainingRegions()
      
      n_pages <- length(
        unique(regions$page)
      )
      
      if (n_pages < 5) {
        
        tags$p(
          paste0(
            "Training pages: ",
            n_pages,
            " / 5"
          ),
          style = "color:#777; font-weight:bold;"
        )
        
      } else {
        
        tags$p(
          paste0(
            "Training pages: ",
            n_pages,
            " / 5 — ready to save."
          ),
          style = "color:#3c763d; font-weight:bold;"
        )
      }
    })
    
    # ==========================================================
    # SAVE PAGE NUMBER TRAINING DATA
    # ==========================================================
    
    observeEvent(
      input$savePageNumberTraining,
      {
        
        regions <- pageNumberTrainingRegions()
        
        # ------------------------------------------------------
        # Check minimum number of training pages
        # ------------------------------------------------------
        
        training_pages <- unique(
          regions$page
        )
        
        if (length(training_pages) < 5) {
          
          shinyalert::shinyalert(
            title = "More training pages required",
            text = paste0(
              "Please select page numbers from at least 5 different pages. ",
              "Currently selected: ",
              length(training_pages),
              "."
            ),
            type = "warning"
          )
          
          return()
        }
        
        
        # ------------------------------------------------------
        # Check confirmed page numbers
        # ------------------------------------------------------
        
        if (
          any(
            is.na(regions$confirmed_text) |
            trimws(regions$confirmed_text) == ""
          )
        ) {
          
          shinyalert::shinyalert(
            title = "Missing page number",
            text = paste(
              "Please check and correct all detected page numbers",
              "before saving the training data."
            ),
            type = "warning"
          )
          
          return()
        }
        
        
        # ------------------------------------------------------
        # Training directory
        # ------------------------------------------------------
        
        training_dir <- file.path(
          workingDir,
          "training"
        )
        
        training_file <- file.path(
          training_dir,
          "page_number_training.csv"
        )
        
        if (!dir.exists(training_dir)) {
          dir.create(
            training_dir,
            recursive = TRUE
          )
        }
        
        
        # ------------------------------------------------------
        # Save CSV
        # ------------------------------------------------------
        
        training_file <- file.path(
          training_dir,
          "training_data.csv"
        )
        
        write.csv(
          regions,
          training_file,
          row.names = FALSE
        )
        
        
        shinyalert::shinyalert(
          title = "Page number training saved",
          text = paste0(
            length(training_pages),
            " training pages were saved successfully."
          ),
          type = "success"
        )
      }
    )
    
    # --------------------------------------------------------
    # Image container
    # The relative position is important because later the
    # blue selection rectangle will be positioned inside it.
    # --------------------------------------------------------
    
    tags$div(
      style = "
      position:relative;
      display:inline-block;
      width:100%;
    ",
      
      tags$img(
        id = "page_number_training_image",
        src = paste0(
          "pages/",
          page_file
        ),
        style = "
        width:100%;
        height:auto;
        display:block;
        border:1px solid #ccc;
      "
      ),
      
      
      # ------------------------------------------------------
      # Blue page-number selection rectangle
      # Initially hidden
      # ------------------------------------------------------
      
      tags$div(
        id = "page_number_selection_rectangle",
        style = "
        position:absolute;
        display:none;
        border:3px solid #337ab7;
        background:rgba(51,122,183,0.08);
        pointer-events:none;
        box-sizing:border-box;
      "
      )
    )
  })
  observe({
    
    req(speciesRepresentation())
    
    if (speciesRepresentation() == "point") {
      
      choices <- c(
        "Map template" = "map",
        "Distribution symbol" = "symbol",
        "Page number" = "page_number"
      )
      
    } else {
      
      choices <- c(
        "Map template" = "map",
        "Page number" = "page_number"
      )
    }
    
    # Keep current selection if it is still valid
    selected <- isolate(input$bookTrainingType)
    
    if (is.null(selected) || !selected %in% unname(choices)) {
      selected <- "map"
    }
    
    updateRadioButtons(
      session,
      "bookTrainingType",
      choices = choices,
      selected = selected
    )
  })

  # ==========================================================
  # CURRENT TRAINING TYPE
  # ==========================================================
  
  currentTrainingType <- reactive({
    
    req(input$bookTrainingType)
    
    input$bookTrainingType
  })
  
  
  # ==========================================================
  # DISPLAY SETTINGS
  # ==========================================================

  # Display book pages at 35% of their original size
  template_display_scale <- 35
  
  # Factor for converting display coordinates back
  # to coordinates of the original image
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
  # DISPLAY CROPPED PREVIEW
  # ==========================================================
  
  output$plot1 <- renderPlot({
    
    req(input$image)
    req(input$plot_brush)
    
    plot_png(
      input$plot_brush
    )
    
  })
  
  
  # ==========================================================
  # DISPLAY UPLOADED IMAGE
  # ==========================================================
  
  output$plot <- renderImage({
    
    req(input$image)
    
    img <- image_read(
      input$image$datapath
    )
    
    img <- image_convert(
      img,
      "png"
    )
    
    img <- image_scale(
      img,
      paste0(template_display_scale, "%")
    )
    
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
        "data",
        "input",
        "templates"
      )
      
      if (!dir.exists(save_dir)) {
        stop(
          paste(
            "Template directory does not exist:",
            save_dir
          )
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
  
  output$saveSymbol <- downloadHandler(
    
    filename = function() {
      paste0(
        "symbol_",
        input$imgIndexSymbol,
        ".tif"
      )
    },
    
    content = function(file) {
      
      req(input$image)
      req(input$plot_brush)
      req(input$imgIndexSymbol)
      
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
        "data",
        "input",
        "templates"
      )
      
      if (!dir.exists(save_dir)) {
        stop(
          paste(
            "Template directory does not exist:",
            save_dir
          )
        )
      }
      
      # --------------------------------------------------------
      # Save symbol
      # --------------------------------------------------------
      
      save_path <- file.path(
        save_dir,
        paste0(
          "symbol_",
          input$imgIndexSymbol,
          ".tif"
        )
      )
      
      image_write(
        tempI,
        save_path,
        format = "tif"
      )
      
      file.copy(
        save_path,
        file,
        overwrite = TRUE
      )
      
      # --------------------------------------------------------
      # Increase index
      # --------------------------------------------------------
      
      updateNumericInput(
        session,
        "imgIndexSymbol",
        value = input$imgIndexSymbol + 1
      )
    }
  )
  
}