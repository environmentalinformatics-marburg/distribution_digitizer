map_matching_ui <- function(shinyfields2, mapTypes) {
  
  tabItem(
    tabName = "tab2",
    
    # ============================================================
    # MATCHING CONFIGURATION
    # ============================================================
    
    wellPanel(
      h3("Map Detection"),
      p("Extract maps from scanned book pages, review the matching results, and align the extracted maps with a reference template for further processing."),
      p("For each detected map, the results record the detected page number, source page and map file names, and the map's x and y pixel coordinates and dimensions within the source page."),
      p("Run matching first and use Show Result List to review the extracted maps and page numbers before starting alignment.")
    ),
    wellPanel(
      h3("1. Matching"),
      textInput(
        "range_matching",
        label = HTML(shinyfields2$inf6),
        value = "1-1"
      ),
      textOutput("range_warning"),
      selectInput(
        "matchingType",
        label = HTML(shinyfields2$matchingType),
        choices = c("Template matching" = 1, "Contour matching" = 2),
        selected = 1
      ),
      selectInput(
        "sNumberPosition",
        "Page Number Position",
        choices = c("top" = 1, "bottom" = 2),
        selected = 1
      ),
      p(shinyfields2$inf1),
      numericInput(
        "threshold_for_TM",
        label = shinyfields2$threshold,
        value = 0.18,
        min = 0,
        max = 1,
        step = 0.05
      ),
      actionButton(
        "templateMatching",
        label = shinyfields2$start1,
        style = "color:#FFFFFF;background:#28a745"
      ),
      p(shinyfields2$inf2)
    ),

    # Matching results and alignment
    fluidRow(
      column(
        12,
        # --------------------------------------------------------
        # MATCHING RESULTS
        # --------------------------------------------------------
        
        shinyjs::hidden(
          div(
            id = "matching_results_block",
            
            wellPanel(
              
              h4("Matching results", class = "dd-matching-results-heading"),
              
              selectInput(
                "map_type_matching",
                label = "Select map type:",
                choices = mapTypes,
                selected = mapTypes[1]
              ),
              actionButton(
                "showMatchingRecords",
                "Show Result List",
                icon = icon("table"),
                class = "btn-primary"
              )
            )
          ),
        
        shinyjs::hidden(
          div(
            id = "matching_records_block",
            
            h4("Page-number detection results"),
            
            p(
              paste(
                "Page numbers are detected automatically.",
                "In some cases, a printed page number cannot be read reliably."
              ),
              style = "color:black;"
            ),
            
            tags$ul(
              tags$li(
                "Page numbers ending in 99 were inferred from the preceding page number."
              ),
              tags$li(
                "An empty page number means that no page number could be detected."
              )
            ),
            
            DT::DTOutput("matchingRecords", width = "100%"),
            
            shinyjs::hidden(
              div(
                id = "selected_matching_result",
                hr(),
                uiOutput("selected_matching_result_ui")
              )
            )
          )
        )

      ),
      
      # ==========================================================
      # ALIGN MAPS
      # ==========================================================
      
      column(
        12,
        
        wellPanel(
          
          h3("2. Align"),
          
          p(
            shinyfields2$inf3,
            style = "color:black"
          ),
          
          actionButton(
            "alignMaps",
            label = shinyfields2$start2,
            style = "color:#FFFFFF;background:#007bff"
          ),
          hr(),
          h4("Browse aligned maps"),
          p("Choose a map to compare the extracted and aligned images or download the aligned TIFF."),
          fluidRow(
            column(4, selectInput("map_type_align", "Map type", choices = mapTypes, selected = mapTypes[1])),
            column(5, textInput("align_search", "Search file name or page number", placeholder = "e.g. 0036 or map_5")),
            column(3, actionButton("align_refresh", "Refresh", icon = icon("refresh")))
          ),
          uiOutput("align_gallery"),
          div(class = "dd-align-pagination",
            actionButton("align_previous", "Previous"),
            textOutput("align_page_info", inline = TRUE),
            actionButton("align_next", "Next")
          ),
          conditionalPanel(
            condition = "output.align_has_selection === 'true'",
            hr(),
            h4(textOutput("align_selected_name", inline = TRUE)),
            fluidRow(
              column(6, h4("Extracted map"), imageOutput("align_original_preview", height = "auto")),
              column(6, h4("Aligned map"), imageOutput("align_selected_preview", height = "auto"))
            ),
            downloadButton("download_aligned_map", "Download aligned TIFF", class = "btn-primary")
          )
        )
      )
    )
  ))
}