map_matching_ui <- function(shinyfields2, mapTypes) {
  
  tabItem(
    tabName = "tab2",
    
    # ============================================================
    # MATCHING CONFIGURATION
    # ============================================================
    
    fluidRow(
      column(
        8,
        wellPanel(
          
          textInput(
            "range_matching",
            label = HTML(shinyfields2$inf6),
            value = "1-1"
          ),
          
          textOutput("range_warning"),
          
          selectInput(
            "matchingType",
            label = HTML(shinyfields2$matchingType),
            choices = c(
              "Template matching" = 1,
              "Contour matching" = 2
            ),
            selected = 1
          ),
          
          selectInput(
            "sNumberPosition",
            "Page Number Position",
            choices = c(
              "top" = 1,
              "bottom" = 2
            ),
            selected = 1
          )
        )
      )
    ),
    
    # ============================================================
    # MATCHING + ALIGNMENT
    # ============================================================
    
    fluidRow(
      
      # ==========================================================
      # LEFT: MAP MATCHING
      # ==========================================================
      
      column(
        6,
        
        wellPanel(
          
          h3(
            strong(
              shinyfields2$head,
              style = "color:black"
            )
          ),
          
          p(
            shinyfields2$inf1,
            style = "color:black"
          ),
          
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
          
          p(
            shinyfields2$inf2,
            style = "color:black"
          )
          
        ),
        # --------------------------------------------------------
        # MATCHING RESULTS
        # --------------------------------------------------------
        
        shinyjs::hidden(
          div(
            id = "matching_results_block",
            
            wellPanel(
              
              h4("Matching results"),
              
              selectInput(
                "map_type_matching",
                label = "Select map type:",
                choices = mapTypes,
                selected = mapTypes[1]
              ),
          ),
          actionButton(
            "showMatchingRecords",
            "Show Result List",
            icon = icon("table"),
            style = "margin-left:10px;"
          ),
        ),
        br(),
        br(),
        
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
            
            DT::DTOutput("matchingRecords"),
            
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
      # RIGHT: ALIGN MAPS
      # ==========================================================
      
      column(
        6,
        
        wellPanel(
          
          h3(
            strong(
              shinyfields2$head_sub,
              style = "color:black"
            )
          ),
          
          p(
            shinyfields2$inf3,
            style = "color:black"
          ),
          
          actionButton(
            "alignMaps",
            label = shinyfields2$start2,
            style = "color:#FFFFFF;background:#007bff"
          )
        ),
        
        # --------------------------------------------------------
        # ALIGNMENT RESULTS
        # --------------------------------------------------------
        
        shinyjs::hidden(
          div(
            id = "align_results_block",
            
            wellPanel(
              
              h4("Aligned results"),
              
              selectInput(
                "map_type_align",
                label = "Select map type:",
                choices = mapTypes,
                selected = mapTypes[1]
              ),
              
              textInput(
                "range_list_align",
                label = HTML(shinyfields2$inf7),
                value = "1-2"
              ),
              
              actionButton(
                "listAlignButton",
                "List aligned maps"
              ),
              
              uiOutput("listAlign")
            )
          )
        )
      )
    )
  ))
}