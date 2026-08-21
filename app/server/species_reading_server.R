# ============================================================
# File: species_reading_server.R
#
# Description:
# Server logic for the Read Species tab.
#
# Handles:
# - selection of example pages
# - interactive species title selection
# - preparation of training data
# ============================================================


species_reading_server <- function(
    input,
    output,
    session,
    workingDir,
    current_out_dir 
) {
  
  # ============================================================
  # Reactive values
  # ============================================================
  
  source(
    file.path(
      workingDir,
      "src",
      "species",
      "species_training.R"
    ),
    local = TRUE
  )
  species_training_pages <- reactiveVal(NULL)
  
  # Current rectangle drawn by the user,
  # but not yet confirmed
  current_species_selection <- reactiveVal(NULL)
  # Current temporarily selected map region
  current_species_map_selection <- reactiveVal(NULL)
  
  # Unique ID for confirmed regions
  next_species_region_id <- reactiveVal(1)
  
  
  species_training_regions <- reactiveVal(
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
      
      # Original OCR result - never modified
      ocr_text = character(),
      
      # Only populated if the user corrects OCR
      confirmed_text = character(),
      map_x = numeric(),
      map_y = numeric(),
      map_width = numeric(),
      map_height = numeric(),
      
      map_x_relative = numeric(),
      map_y_relative = numeric(),
      map_width_relative = numeric(),
      map_height_relative = numeric(),
      stringsAsFactors = FALSE
    )
  )

  # ============================================================
  # Python module for species title training
  # ============================================================
  
  species_title_training <- reticulate::import_from_path(
    "species_training_ocr",
    path = file.path(
      workingDir,
      "src",
      "species"
    )
  )
  
  read_species_server <- function(
    input,
    output,
    session,
    workingDir,
    current_out_dir
  ) {
    
    current_species_selection <- reactiveVal(NULL)
    
    # NEW
    current_species_map_selection <- reactiveVal(NULL)
    
    
  }
  # ============================================================
  # Training pages for interactive species title selection
  # ============================================================
  
  observe({
    
    pages_dir <- file.path(
      workingDir,
      "app",
      "www",
      "pages"
    )
    
    cat("\n=== SPECIES TRAINING PAGES ===\n")
    cat("Prepared PNG directory:", pages_dir, "\n")
    
    if (!dir.exists(pages_dir)) {
      cat("Directory does not exist!\n")
      return()
    }
    
    # Get all PNG pages prepared for the current test workflow
    png_files <- list.files(
      pages_dir,
      pattern = "\\.png$",
      ignore.case = TRUE,
      full.names = FALSE
    )
    
    cat("Prepared pages found:", length(png_files), "\n")
    print(png_files)
    
    if (length(png_files) == 0) {
      cat("No PNG pages found!\n")
      return()
    }
    
    # Convert PNG filenames to corresponding original TIFF filenames
    page_files <- paste0(
      tools::file_path_sans_ext(png_files),
      ".tif"
    )
    
    species_training_pages(page_files)
    
    cat("Corresponding TIFF pages:\n")
    print(page_files)
    
    updateSelectInput(
      session,
      "species_training_page",
      choices = page_files,
      selected = page_files[1]
    )
  })
  
  output$species_map_selection_info <- renderUI({
    
    sel <- current_species_map_selection()
    
    if (is.null(sel)) {
      return(NULL)
    }
    
    tags$div(
      style = "
      margin-top:10px;
      padding:8px;
      border:1px solid #3498db;
      border-radius:4px;
    ",
      
      tags$strong("Associated map selected"),
      
      tags$br(),
      
      sprintf(
        "x: %.1f | y: %.1f | width: %.1f | height: %.1f",
        sel$x,
        sel$y,
        sel$width,
        sel$height
      )
    )
  })
  
  # ============================================================
  # Species name source
  # ============================================================
  # legend  = species names are read from / below map legend
  # regions = species titles are detected directly on book pages
  # ============================================================
  
  observeEvent(input$speciesNameSource, {
    
    req(input$speciesNameSource)
    
    cfg_path <- file.path(
      workingDir,
      "config",
      "config.csv"
    )
    
    cfg <- read.table(
      cfg_path,
      sep = ";",
      header = FALSE,
      stringsAsFactors = FALSE,
      fill = TRUE
    )
    
    colnames(cfg) <- c("key", "value")
    
    key   <- "speciesNameSource"
    value <- as.character(input$speciesNameSource)
    
    if (key %in% cfg$key) {
      cfg$value[cfg$key == key] <- value
    } else {
      cfg <- rbind(
        cfg,
        data.frame(
          key = key,
          value = value,
          stringsAsFactors = FALSE
        )
      )
    }
    
    write.table(
      cfg,
      cfg_path,
      sep = ";",
      row.names = FALSE,
      col.names = FALSE,
      quote = FALSE
    )
    
    cat("Species name source saved:", value, "\n")
  })
  
  
  # ============================================================
  # LEGEND WORKFLOW
  # ============================================================
  
  # ------------------------------------------------------------
  # Read species names from map legend
  # ------------------------------------------------------------
  observeEvent(input$mapReadRpecies, {
    
    manageProcessFlow(
      processing = "mapReadRpecies",
      allertText1 = "cropping map species",
      allertText2 = "pointFiltering",
      input = input,
      session = session,
      current_out_dir = current_out_dir
    )
  })
  
  
  # ------------------------------------------------------------
  # Read complete species titles from page content
  # ------------------------------------------------------------
  observeEvent(input$pageReadRpecies, {
    
    manageProcessFlow(
      processing = "pageReadRpecies",
      allertText1 = "read page species",
      allertText2 = "output",
      input = input,
      session = session,
      current_out_dir = current_out_dir
    )
  })
  # ============================================================
  # Display confirmed training regions
  # ============================================================
  
  output$species_training_regions <- renderUI({
    cat(
      "\nSELECTION TYPE:",
      input$species_selection_type,
      "\n"
    )
    req(input$species_training_page)
    map_selection_mode <- identical(
      input$species_selection_type,
      "map"
    )
    regions <- species_training_regions()
    current_page <- input$species_training_page
    
    page_regions <- regions[
      regions$page == current_page,
      ,
      drop = FALSE
    ]
    # All training regions collected so far
    all_regions <- regions
    # Total confirmed training data
    total_regions <- nrow(regions)
    total_pages <- length(unique(regions$page))

    
    region_list <- lapply(
      seq_len(nrow(all_regions)),
      function(i) {
        
        region <- all_regions[i, ]
        
        tags$div(
          style = "
    border:1px solid #ddd;
    padding:10px;
    margin-bottom:10px;
    background:#fafafa;
  ",
          
          fluidRow(
            
            column(
              2,
              strong(
                paste0(
                  "Region ",
                  region$region_id
                )
              ),
              tags$br(),
              region$page
            ),
            
            column(
              4,
              
              tags$strong("OCR result:"),
              
              tags$p(
                region$ocr_text,
                style = "
          margin-top:5px;
          padding:5px;
          background:white;
          border:1px solid #ddd;
        "
              )
            ),
            
            column(
              4,
              
              textInput(
                inputId = paste0(
                  "confirmedSpeciesTitle_",
                  region$region_id
                ),
                
                label = "Correct title if necessary:",
                
                value = if (
                  !is.na(region$confirmed_text) &&
                  nzchar(region$confirmed_text)
                ) {
                  region$confirmed_text
                } else {
                  region$ocr_text
                }
              )
            ),
            
            column(
              2,
              
              # ----------------------------------------------------------
              # Title actions - always available
              # ----------------------------------------------------------
              actionButton(
                inputId = paste0(
                  "updateSpeciesTitle_",
                  region$region_id
                ),
                label = "Update",
                class = "btn-sm btn-primary",
                onclick = paste0(
                  "Shiny.setInputValue(",
                  "'update_species_title_region', ",
                  "{region_id: ", region$region_id, ", nonce: Math.random()}, ",
                  "{priority: 'event'}",
                  ");"
                )
              ),
              
              tags$br(),
              tags$br(),
              
              actionButton(
                inputId = paste0(
                  "removeSpeciesRegion_",
                  region$region_id
                ),
                label = "Remove",
                class = "btn-sm btn-danger",
                onclick = paste0(
                  "Shiny.setInputValue(",
                  "'remove_species_training_region', ",
                  "{region_id: ", region$region_id, ", nonce: Math.random()}, ",
                  "{priority: 'event'}",
                  ");"
                )
              ),
              
              # ----------------------------------------------------------
              # Map assignment
              # Only shown while map-selection mode is active
              # ----------------------------------------------------------
              if (map_selection_mode) {
                
                tagList(
                  tags$br(),
                  tags$br(),
                  
                  if (!is.na(region$map_x)) {
                    
                    tagList(
                      tags$strong(
                        "✓ Map assigned",
                        style = "color:green;"
                      ),
                      
                      tags$br(),
                      
                      tags$small(
                        sprintf(
                          "x: %.0f | y: %.0f",
                          region$map_x,
                          region$map_y
                        )
                      ),
                      
                      tags$br(),
                      
                      tags$small(
                        sprintf(
                          "w: %.0f | h: %.0f",
                          region$map_width,
                          region$map_height
                        )
                      )
                    )
                    
                  } else {
                    
                    actionButton(
                      inputId = paste0(
                        "addSpeciesMap_",
                        region$region_id
                      ),
                      label = "Add map selection",
                      class = "btn-sm",
                      style = "
                        color:#FFFFFF;
                        background:#337ab7;
                        border-color:#2e6da4;
                      ",
                      onclick = paste0(
                        "Shiny.setInputValue(",
                        "'add_species_map_region', ",
                        "{region_id: ", region$region_id,
                        ", nonce: Math.random()}, ",
                        "{priority: 'event'}",
                        ");"
                      )
                    )
                  }
                )
              }
            )
          )
        )
      }
    )
    
    tagList(
      
      tags$h4("Confirmed training regions"),
      
      tags$p(
        paste0(
          "Current page: ",
          nrow(page_regions),
          " / 2 regions | ",
          "Training set: ",
          total_regions,
          " regions from ",
          total_pages,
          " page(s)"
        )
      
      ),
      
      region_list
    )
  })
  
  # ============================================================
  # Update corrected OCR title
  # ============================================================
  
  observeEvent(input$update_species_title_region, {
    
    req(input$update_species_title_region$region_id)
    
    region_id <- as.integer(
      input$update_species_title_region$region_id
    )
    
    regions <- species_training_regions()
    
    row_index <- which(
      regions$region_id == region_id
    )
    
    if (length(row_index) != 1) {
      return()
    }
    
    # Dynamic text input belonging to this region
    input_name <- paste0(
      "confirmedSpeciesTitle_",
      region_id
    )
    
    corrected_text <- input[[input_name]]
    
    if (is.null(corrected_text)) {
      return()
    }
    
    corrected_text <- trimws(corrected_text)
    original_text <- trimws(regions$ocr_text[row_index])
    
    
    # ----------------------------------------------------------
    # Only store confirmed_text when OCR was actually corrected
    # ----------------------------------------------------------
    
    if (
      nzchar(corrected_text) &&
      corrected_text != original_text
    ) {
      
      regions$confirmed_text[row_index] <-
        corrected_text
      
      cat(
        "\n=== OCR TITLE CORRECTED ===\n",
        "Region:", region_id, "\n",
        "OCR:      ", original_text, "\n",
        "Corrected:", corrected_text, "\n"
      )
      
      showNotification(
        "Correction stored.",
        type = "message",
        duration = 3
      )
      
    } else {
      
      # No correction -> OCR was accepted as correct
      regions$confirmed_text[row_index] <-
        NA_character_
      
      cat(
        "\n=== OCR TITLE ACCEPTED ===\n",
        "Region:", region_id, "\n",
        "OCR:", original_text, "\n"
      )
      
      showNotification(
        "OCR title accepted without correction.",
        type = "message",
        duration = 3
      )
    }
    
    species_training_regions(regions)
  })
  
  # ============================================================
  # Clear confirmed regions on current page
  # ============================================================
  
  observeEvent(input$clearSpeciesTrainingRegions, {
    
    req(input$species_training_page)
    
    current_page <- input$species_training_page
    
    regions <- species_training_regions()
    
    regions <- regions[
      regions$page != current_page,
      ,
      drop = FALSE
    ]
    
    species_training_regions(regions)
    
    current_species_selection(NULL)
    # Current map rectangle selected by the user.
    # Temporary only - not stored in the training data yet.
    current_species_map_selection <- reactiveVal(NULL)
  })
  
  # ============================================================
  # Remove one confirmed training region
  # ============================================================
  
  observeEvent(input$remove_species_training_region, {
    
    req(input$remove_species_training_region$region_id)
    
    remove_id <- as.integer(
      input$remove_species_training_region$region_id
    )
    
    regions <- species_training_regions()
    
    regions <- regions[
      regions$region_id != remove_id,
      ,
      drop = FALSE
    ]
    
    species_training_regions(regions)
    
    cat(
      "\nRemoved species training region:",
      remove_id,
      "\n"
    )
  })
  
  # ============================================================
  # Store current temporary map selection
  # ============================================================
  
  observeEvent(input$species_training_map_region, {
    
    req(input$species_training_page)
    
    current_species_map_selection(
      input$species_training_map_region
    )
    
    cat("\n=== CURRENT ASSOCIATED MAP SELECTION ===\n")
    cat("Page:", input$species_training_page, "\n")
    
    print(
      input$species_training_map_region
    )
    
    cat("========================================\n")
  })
  
  
  # ============================================================
  # Assign selected map to species title region
  # ============================================================
  
  observeEvent(input$add_species_map_region, {
    
    req(input$add_species_map_region$region_id)
    req(current_species_map_selection())
    
    region_id <- as.integer(
      input$add_species_map_region$region_id
    )
    
    map_region <- current_species_map_selection()
    regions <- species_training_regions()
    
    row_index <- which(
      regions$region_id == region_id
    )
    
    if (length(row_index) != 1) {
      return()
    }
    
    # Store absolute map coordinates
    regions$map_x[row_index] <- map_region$x
    regions$map_y[row_index] <- map_region$y
    regions$map_width[row_index] <- map_region$width
    regions$map_height[row_index] <- map_region$height
    
    # Store relative map coordinates
    regions$map_x_relative[row_index] <-
      map_region$x / map_region$image_width
    
    regions$map_y_relative[row_index] <-
      map_region$y / map_region$image_height
    
    regions$map_width_relative[row_index] <-
      map_region$width / map_region$image_width
    
    regions$map_height_relative[row_index] <-
      map_region$height / map_region$image_height
    
    species_training_regions(regions)
    
    # Selection is now confirmed
    current_species_map_selection(NULL)
    
    cat("\n=== MAP ASSIGNED TO SPECIES REGION ===\n")
    cat("Region:", region_id, "\n")
    print(regions[row_index, ])
    cat("======================================\n")
  })
  
  
  # ============================================================
  # Store current temporary selection
  # ============================================================
  
  observeEvent(input$species_training_region, {
    
    req(input$species_training_page)
    
    # Store rectangle temporarily.
    # It is NOT yet part of the training data.
    current_species_selection(
      input$species_training_region
    )
    
    cat("\n=== CURRENT SPECIES TITLE SELECTION ===\n")
    cat("Page:", input$species_training_page, "\n")
    print(input$species_training_region)
  })
  
  
  # ============================================================
  # Confirm selected species title region
  # ============================================================
  
  observeEvent(input$addSpeciesTrainingRegion, {
    
    req(input$species_training_page)
    req(current_species_selection())
    #req(current_species_map_selection())
    current_page <- input$species_training_page
    region <- current_species_selection()
    regions <- species_training_regions()
    current_page <- input$species_training_page
    region <- current_species_selection()
    #map_region <- current_species_map_selection()
    regions <- species_training_regions()
    # ----------------------------------------------------------
    # Maximum 2 confirmed regions per page
    # ----------------------------------------------------------
    regions_on_page <- regions[
      regions$page == current_page,
      ,
      drop = FALSE
    ]
    
    if (nrow(regions_on_page) >= 2) {
      
      showNotification(
        "Maximum of 2 species title regions per page.",
        type = "warning"
      )
      
      return()
    }
    
    # ----------------------------------------------------------
    # Convert browser coordinates to relative coordinates
    # ----------------------------------------------------------
    x_relative <-
      region$x / region$image_width
    
    y_relative <-
      region$y / region$image_height
    
    width_relative <-
      region$width / region$image_width
    
    height_relative <-
      region$height / region$image_height
    
    # map_x_relative <-
    #   map_region$x / map_region$image_width
    # 
    # map_y_relative <-
    #   map_region$y / map_region$image_height
    # 
    # map_width_relative <-
    #   map_region$width / map_region$image_width
    # 
    # map_height_relative <-
    #   map_region$height / map_region$image_height
    
    # ----------------------------------------------------------
    # Read OCR text immediately from selected region
    # ----------------------------------------------------------
    
    image_path <- file.path(
      workingDir,
      "data",
      "input",
      "pages",
      current_page
    )
    
    ocr_text <- ""
    
    if (file.exists(image_path)) {
      
      ocr_text <- species_title_training$read_training_region(
        image_path,
        x_relative,
        y_relative,
        width_relative,
        height_relative
      )
      
      ocr_text <- trimws(
        as.character(ocr_text)
      )
      
      cat("\nOCR result for selected region:\n")
      cat(ocr_text, "\n")
      
    } else {
      
      cat(
        "\nTIFF not found:",
        image_path,
        "\n"
      )
    }
    # ----------------------------------------------------------
    # Unique ID
    # ----------------------------------------------------------
    region_id <- next_species_region_id()
    
    
    # ----------------------------------------------------------
    # Store confirmed region
    # ----------------------------------------------------------
    new_region <- data.frame(
      region_id = region_id,
      page = current_page,
      
      x = region$x,
      y = region$y,
      width = region$width,
      height = region$height,
      
      x_relative = x_relative,
      y_relative = y_relative,
      width_relative = width_relative,
      height_relative = height_relative,
      
      # Original OCR result
      ocr_text = ocr_text,
      
      # Remains empty unless user corrects OCR
      confirmed_text = NA_character_,
      
      # Associated map will be added later
      map_x = NA_real_,
      map_y = NA_real_,
      map_width = NA_real_,
      map_height = NA_real_,
      
      map_x_relative = NA_real_,
      map_y_relative = NA_real_,
      map_width_relative = NA_real_,
      map_height_relative = NA_real_,
      
      stringsAsFactors = FALSE
    )
    
    species_training_regions(
      rbind(
        regions,
        new_region
      )
    )
    cat("\n=== ALL CONFIRMED TRAINING REGIONS ===\n")
    print(species_training_regions())
    cat("======================================\n")
    # Prepare next unique ID
    next_species_region_id(
      region_id + 1
    )
    
    # Temporary selection is now confirmed
    current_species_selection(NULL)
    current_species_map_selection(NULL)
    cat("\n=== CONFIRMED SPECIES TITLE REGION ===\n")
    print(new_region)
  })
    
  
  # ============================================================
  # Save species title training data
  # ============================================================
  observeEvent(input$saveSpeciesTraining, {
    
    regions <- species_training_regions()
    
    tryCatch({
      
      training_data <- save_species_training(
        regions = regions,
        workingDir = workingDir
      )
      
      showNotification(
        paste(
          nrow(training_data),
          "training examples saved successfully."
        ),
        type = "message",
        duration = 5
      )
      
    }, error = function(e) {
      
      showNotification(
        conditionMessage(e),
        type = "warning",
        duration = 5
      )
      
    })
    
  })
  

  
  observeEvent(input$showPageSpeciesData, {
    
    species_file <- file.path(
      current_out_dir,
      "1",
      "pageSpeciesData.csv"
    )
    
    if (!file.exists(species_file)) {
      showNotification(
        "No processed species data found.",
        type = "warning"
      )
      return()
    }
    
    species_data <- read.csv(
      species_file,
      sep = ";",
      stringsAsFactors = FALSE
    )
    
    output$pageSpeciesData_result <- renderUI({
      tagList(
        h4("Detected species"),
        tableOutput("pageSpeciesData_table")
      )
    })
    
    output$pageSpeciesData_table <- renderTable({
      species_data
    })
  })
  
  # List map legend species
  observeEvent(input$listCropped, {
    if(input$siteNumberMapsMatching != ''){
      #print(input$siteNumberMapsMatching)
      output$listCropped = renderUI({
        prepareImageView("/output/cropped_png/", input$siteNumberMapsMatching)
      })
    }
    else{
      output$listCropped = renderUI({
        prepareImageView("/output/cropped_png/", '.png')
      })
    }
  })
  
  # ============================================================
  # Start automatic species-title processing
  # ============================================================
  # The training examples have already been created and saved.
  # This event only starts the central processing workflow.
  #
  # All processing logic is handled outside the Shiny module
  # through manageProcessFlow().
  # ============================================================
  
  observeEvent(input$processSpeciesTitles, {
    
    
    # ----------------------------------------------------------
    # Start processing
    # ----------------------------------------------------------
    manageProcessFlow(
      processing = "pageReadSpeciesDirect",
      allertText1 = "species title detection",
      allertText2 = "species title detection",
      input = input,
      session = session,
      current_out_dir = current_out_dir
    )
    
  })
  # ============================================================
  # Display selected training page
  # ============================================================
  
  output$species_training_page_preview <- renderUI({
    
    req(input$species_training_page)
    
    # ----------------------------------------------------------
    # Selected TIFF, e.g. "0066.tif"
    # ----------------------------------------------------------
    selected_file <- input$species_training_page

    # Browser uses the PNG version from app/www/pages
    page_name <- tools::file_path_sans_ext(
      basename(selected_file)
    )
    
    png_file <- paste0(page_name, ".png")
    
    # ----------------------------------------------------------
    # Check physical file
    # ----------------------------------------------------------
    png_path <- file.path(
      workingDir,
      "app",
      "www",
      "pages",
      png_file
    )
    
    cat("\n=== SPECIES TRAINING PAGE PREVIEW ===\n")
    cat("Selected TIFF:", selected_file, "\n")
    cat("PNG path:", png_path, "\n")
    
    if (!file.exists(png_path)) {
      
      cat("PNG does not exist!\n")
      
      return(
        tags$p(
          paste("Preview image not found:", png_file),
          style = "color:red;"
        )
      )
    }
    
    # ----------------------------------------------------------
    # Browser-relative path
    # ----------------------------------------------------------
    image_src <- file.path(
      "pages",
      png_file
    )
    
    # Windows backslashes must not appear in browser URL
    image_src <- gsub(
      "\\\\",
      "/",
      image_src
    )
    # ----------------------------------------------------------
    # Confirmed regions for selected page
    # ----------------------------------------------------------
    regions <- species_training_regions()
    
    page_regions <- regions[
      regions$page == selected_file,
      ,
      drop = FALSE
    ]
    
    
    # ----------------------------------------------------------
    # Build permanent boxes for confirmed regions
    # ----------------------------------------------------------
    confirmed_boxes <- lapply(
      seq_len(nrow(page_regions)),
      function(i) {
        
        region <- page_regions[i, ]
        
        tags$div(
          style = paste0(
            "position:absolute;",
            "left:", region$x_relative * 100, "%;",
            "top:", region$y_relative * 100, "%;",
            "width:", region$width_relative * 100, "%;",
            "height:", region$height_relative * 100, "%;",
            "border:2px solid green;",
            "background:rgba(0,255,0,0.08);",
            "pointer-events:none;",
            "z-index:9;",
            "box-sizing:border-box;"
          ),
          
          tags$span(
            paste0("Region ", i),
            style = "
          position:absolute;
          top:-22px;
          left:0;
          background:white;
          color:green;
          font-weight:bold;
          padding:1px 4px;
          font-size:12px;
        "
          )
        )
      }
    )
    
    # ----------------------------------------------------------
    # Build permanent boxes for confirmed map selections
    # ----------------------------------------------------------
    
    confirmed_map_boxes <- lapply(
      seq_len(nrow(page_regions)),
      function(i) {
        
        region <- page_regions[i, ]
        
        # No map assigned to this region
        if (
          is.na(region$map_x_relative) ||
          is.na(region$map_y_relative) ||
          is.na(region$map_width_relative) ||
          is.na(region$map_height_relative)
        ) {
          return(NULL)
        }
        
        tags$div(
          style = paste0(
            "position:absolute;",
            "left:", region$map_x_relative * 100, "%;",
            "top:", region$map_y_relative * 100, "%;",
            "width:", region$map_width_relative * 100, "%;",
            "height:", region$map_height_relative * 100, "%;",
            "border:2px solid green;",
            "background:rgba(0,255,0,0.08);",
            "pointer-events:none;",
            "z-index:9;",
            "box-sizing:border-box;"
          ),
          
          tags$span(
            paste0("Map ", region$region_id),
            style = "
          position:absolute;
          top:-22px;
          left:0;
          background:white;
          color:green;
          font-weight:bold;
          padding:1px 4px;
          font-size:12px;
        "
          )
        )
      }
    )
    
    # ----------------------------------------------------------
    # Display page
    # ----------------------------------------------------------
    tags$div(
      id = "species_training_container",
      
      style = "
    width:650px;
    max-width:100%;
    margin-left:auto;
    margin-right:auto;
    position:relative;
  ",
      
      # Page image
      tags$img(
        id = "species_training_image",
        src = image_src,
        
        style = "
      width:100%;
      height:auto;
      display:block;
      cursor:crosshair;
      user-select:none;
    ",
        
        draggable = "false"
      ),
      
      # Confirmed regions
      confirmed_boxes,
      
      # Confirmed map regions
      confirmed_map_boxes,
      
      # Current unconfirmed selection
      tags$div(
        id = "species_selection_rectangle",
        
        style = "
      display:none;
      position:absolute;
      border:2px solid red;
      background:rgba(255,0,0,0.10);
      pointer-events:none;
      z-index:10;
      box-sizing:border-box;
    "
      )
    )

  })
}