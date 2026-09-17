species_distribution_ui <- function(
    shinyfields2,
    shinyfields3,
    shinyfields4,
    mapTypes
) {
  
  tabItem(
    tabName = "tab3",
    
    # ============================================================
    # TOP: Info
    # ============================================================
    wellPanel(
      h3("Species Distribution"),
      p("Extract species distribution points or colored areas from aligned maps. Test the detection settings on an example and review the preview before processing all maps."),
      conditionalPanel(
        condition = "input.speciesRepresentation == 'point'",
        p(strong("Selected in General Config: "), "Points / symbols. To detect colored contours or areas instead, change this selection in General Config.")
      ),
      conditionalPanel(
        condition = "input.speciesRepresentation == 'contour'",
        p(strong("Selected in General Config: "), "Contours / areas. To detect points or symbols instead, change this selection in General Config.")
      ),
      conditionalPanel(
        condition = "!input.speciesRepresentation",
        p(class = "dd-config-required-warning", "No representation selected. Please choose Points / symbols or Contours / areas in General Config.")
      )
    ),

    # ============================================================
    # POINT-BASED DISTRIBUTION
    # ============================================================
    conditionalPanel(
      condition = "input.speciesRepresentation == 'point'",
      
      fluidRow(
        
        # --------------------------------------------------------
        # LEFT: Point Matching
        # --------------------------------------------------------
        column(
          6,
          
          wellPanel(
            
            h4(shinyfields3$head_sub, style = "color:black"),
            p(shinyfields3$inf3, style = "color:black"),
            
            numericInput(
              "threshold_for_PM",
              label = shinyfields3$threshold,
              value = 0.75,
              min = 0,
              max = 1,
              step = 0.05
            ),
            
            p(shinyfields3$inf4, style = "color:black"),
            
            actionButton(
              "pointMatching",
              label = shinyfields3$lab,
              style = "color:#FFFFFF;background:#999999"
            ),
            
            tags$hr(),
            
            conditionalPanel(
              condition = "input.pointMatching > 0",
              
              fluidRow(
                column(
                  4,
                  textInput(
                    "range_list_PointsMatching",
                    label = HTML(shinyfields2$inf7),
                    value = "1-2"
                  )
                ),
                
                column(
                  4,
                  selectInput(
                    "map_type_PointsMatching",
                    label = "Select map type:",
                    choices = mapTypes,
                    selected = mapTypes[1]
                  )
                ),
                
                column(
                  4,
                  actionButton(
                    "listPointsM",
                    "List points matching"
                  )
                )
              )
            )
          ),
          
          uiOutput("listPM")
        ),
        
        # --------------------------------------------------------
        # RIGHT: Point Filtering
        # --------------------------------------------------------
        column(
          6,
          
          wellPanel(
            
            h4(shinyfields4$head, style = "color:black"),
            
            numericInput(
              "filterK",
              shinyfields4$lab1,
              value = 5
            ),
            
            p(shinyfields4$inf1),
            
            numericInput(
              "filterG",
              shinyfields4$lab2,
              value = 9
            ),
            
            p(shinyfields4$inf2),
            
            actionButton(
              "pointFiltering",
              label = shinyfields4$lab3,
              style = "color:#FFFFFF;background:#999999"
            ),
            
            tags$hr(),
            
            conditionalPanel(
              condition = "input.pointFiltering > 0",
              
              fluidRow(
                column(
                  4,
                  textInput(
                    "range_list_PointsFiltering",
                    label = HTML(shinyfields2$inf7),
                    value = "1-2"
                  )
                ),
                
                column(
                  4,
                  selectInput(
                    "map_type_PointsFiltering",
                    label = "Select map type:",
                    choices = mapTypes,
                    selected = mapTypes[1]
                  )
                ),
                
                column(
                  4,
                  actionButton(
                    "listPointsF",
                    "List points filtering"
                  )
                )
              )
            )
          ),
          
          uiOutput("listPF")
        )
      )
    ),
    
    # ============================================================
    # AREA / CONTOUR-BASED DISTRIBUTION
    # ============================================================
    conditionalPanel(
      condition = "input.speciesRepresentation == 'contour'",
      
      fluidRow(
        column(
          12,
          
          wellPanel(
            
            h3("1. Detect species areas"),
            
            p(
              paste(
                "Select a representative map and define the color",
                "used for the species distribution contour."
              ),
              style = "color:black"
            ),
            
            fluidRow(
              
              column(
                4,
                selectInput(
                  "map_type_Contour",
                  label = "Select map type:",
                  choices = mapTypes,
                  selected = mapTypes[1]
                )
              ),
              
              column(
                4,
                selectInput(
                  "contour_example_map",
                  label = "Select example map:",
                  choices = NULL
                )
              )
            ),
            
            tags$hr(),
            
            # ----------------------------------------------------
            # Select contour color from example map
            # ----------------------------------------------------
            h4(
              "Select contour color",
              style = "color:black"
            ),
            
            p(
              "Printing and scanning can produce different shades along the same contour. Click three different places on the species contour, sampling lighter and darker shades of its color. Avoid the background, labels and map borders. These samples help extract the contour more completely.",
              style = "color:black"
            ),
            
            # ----------------------------------------------------
            # Display selected example map
            # ----------------------------------------------------
            uiOutput("contour_map_preview"),
            # ----------------------------------------------------
            # Capture mouse click on contour map
            # ----------------------------------------------------
            tags$script(HTML("
                $(document).on('click', '#contour_map_image', function(e) {
              
                  var rect = this.getBoundingClientRect();
              
                  var x = e.clientX - rect.left;
                  var y = e.clientY - rect.top;
              
                  var width  = rect.width;
                  var height = rect.height;
              
                  Shiny.setInputValue(
                    'contour_map_click',
                    {
                      x: x,
                      y: y,
                      width: width,
                      height: height,
                      nonce: Math.random()
                    },
                    {priority: 'event'}
                  );
                });
              ")),
            
            br(),
            
            # ----------------------------------------------------
            # Selected contour color
            # ----------------------------------------------------
            uiOutput("selected_contour_color"),
            actionButton(
              "clearContourColors",
              "Clear selected colors"
            ),
            br(),
            br(),
            fluidRow(
              column(6,
                sliderInput(
                  "contourColorTolerance",
                  label = "Color tolerance:",
                  min = 0, max = 100, value = 30, step = 1
                ),
                p("Color tolerance includes shades close to your selected samples, compensating for printing and scanning variations. Increase it if parts of the contour are missing; decrease it if background or unrelated features are included. Check the preview after each adjustment.")
              ),
              column(6,
                numericInput(
                  "contourBorderMargin",
                  label = "Ignore contours within border margin (pixels):",
                  value = 10, min = 0, step = 1
                ),
                p("Contour pixels within this distance from the image border are ignored. Try different values and check the preview to exclude unwanted border marks without losing species contours.")
              )
            ),

            tags$hr(),
            
            actionButton(
              "previewContourDetection",
              label = "Preview area detection",
              class = "btn-primary"
            ),
            
            actionButton(
              "processAllContours",
              label = "Process all maps",
              class = "btn-success"
            ),
            
            tags$hr(),
            uiOutput("contourPreview"),
            h4("Browse detected areas"),
            p("Choose a map to compare the aligned image with the detected areas or download the result."),
            fluidRow(
              column(4, selectInput("map_type_Contours", "Map type", choices = mapTypes, selected = mapTypes[1])),
              column(5, textInput("contour_results_search", "Search file name or page number", placeholder = "e.g. 0036 or map_5")),
              column(3, actionButton("contour_results_refresh", "Refresh", icon = icon("refresh")))
            ),
            uiOutput("contour_results_gallery"),
            div(class = "dd-align-pagination",
              actionButton("contour_results_previous", "Previous"),
              textOutput("contour_results_page_info", inline = TRUE),
              actionButton("contour_results_next", "Next")
            ),
            conditionalPanel(
              condition = "output.contour_results_has_selection === 'true'",
              hr(),
              h4(textOutput("contour_results_selected_name", inline = TRUE)),
              fluidRow(
                column(6, h4("Aligned map"), imageOutput("contour_results_original_preview", height = "auto")),
                column(6, h4("Detected areas"), imageOutput("contour_results_selected_preview", height = "auto"))
              ),
              downloadButton("download_contour_result", "Download result PNG", class = "btn-primary")
            )
          )
        )
      )
    )
  )
}
