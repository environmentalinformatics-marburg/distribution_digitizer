tab_species_distribution_ui <- function(
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
    fluidRow(
      column(
        12,
        wellPanel(
          h3(
            strong(
              "Species Distribution Detection",
              style = "color:black"
            )
          ),
          
          p(
            "Select how species distributions are represented on the maps.",
            style = "color:black"
          ),
          
          # ------------------------------------------------------
          # NEW: Representation type
          # ------------------------------------------------------
          radioButtons(
            "speciesRepresentation",
            label = "Species distribution representation:",
            choices = c(
              "Points / symbols" = "point",
              "Contours / areas" = "contour"
            ),
            selected = "point",
            inline = TRUE
          )
        )
      )
    ),
    
    br(),
    
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
            
            h4(
              "Species Area Detection",
              style = "color:black"
            ),
            
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
              "Click on a species contour in the map to select its color.",
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
            # ----------------------------------------------------
            # Later: selected color + tolerance
            # ----------------------------------------------------
            fluidRow(
              
              column(
                6,
                uiOutput("selectedContourColor")
              ),
              
              column(
                6,
                sliderInput(
                  "contourColorTolerance",
                  label = "Color tolerance:",
                  min = 0,
                  max = 100,
                  value = 30,
                  step = 1
                )
              )
            ),
            
            tags$hr(),
            
            actionButton(
              "previewContourDetection",
              label = "Preview area detection",
              style = "color:#FFFFFF;background:#999999"
            ),
            
            actionButton(
              "saveContourSettings",
              label = "Save contour settings"
            ),
            
            tags$hr(),
            
            uiOutput("contourPreview")
          )
        )
      )
    )
  )
}