# ============================================================
# File: species_reading.R
#
# Description:
# UI for species name detection.
#
# Two methods are supported:
#
# 1. Legend-based species detection
#    Existing workflow for maps where species names can be
#    identified from the map legend and surrounding page text.
#
# 2. User-defined page regions
#    For books where species names are located elsewhere on
#    the page. The user will interactively select regions
#    containing species names.
# ============================================================


species_reading_ui <- function(
    shinyfields2,
    shinyfields6,
    config = list()
) {
  
  tabItem(
    tabName = "tab5",
    
    # ============================================================
    # TOP: Species name source
    # ============================================================
    wellPanel(
      h3("Read Species"),
      p("This step defines how species names are identified in the book. Depending on the book structure, species information can either be obtained from a map legend and then linked to the full species title, or the full species title can be detected directly on the page.")
    ),
    wellPanel(
      h3("1. Select how species names are represented in the book"),
      p("Select how species information is provided in the book. This determines which workflow is used to identify the complete species title."),
      radioButtons(
        "speciesNameSource",
        label = "Species name source (required):",
        choices = c(
          "Please select" = "",
          "Species referenced in a map legend" = "legend",
          "Species identified directly from the title" = "regions"
        ),
        selected = if (isTRUE(config$speciesNameSource %in% c("legend", "regions"))) config$speciesNameSource else "",
        inline = TRUE
      ),
      p(strong("Species referenced in a map legend: "), "Use this option when a legend associates symbols, points, colors, or other map representations with species names. The species name identified from the legend is used as a reference to locate the corresponding full species title in the book. The full title may include additional information, such as the species author name."),
      p(strong("Species identified directly from the title: "), "Use this option when the complete species title can be identified directly on the page. In this workflow, no species reference from a map legend is required.")
    ),

    # ============================================================
    # METHOD 1:
    # Existing legend-based species detection
    # ============================================================
    conditionalPanel(
      condition = "input.speciesNameSource == 'legend'",
      
      fluidRow(
        column(
          3,
          
          textInput(
            "siteNumberMapsMatching",
            label = shinyfields6$input,
            value = ""
          )
        )
      ),
      
      fluidRow(
        column(
          12,
          
          # ------------------------------------------------------
          # Species from map
          # ------------------------------------------------------
          wellPanel(
            
            h3("2. Define the species reference area near the map"),
            
            p("Define the area relative to the detected map where the species name or reference from the legend should be read. The detected species name will later be used to find the corresponding full species title."),
            
            actionButton(
              "mapReadSpecies",
              label = "Read names from map legends",
              style = "color:#FFFFFF;background:#999999"
            )
          ),
          
          # ------------------------------------------------------
          # Species from page
          # ------------------------------------------------------
          wellPanel(
            
            h3("3. Define the species title area on the page"),
            
            p("Define the page region in which the complete species title should be detected. In this legend-based workflow, the species reference read from the map is used to locate the corresponding full title."),
            
            actionButton(
              "pageReadSpecies",
              label = "Read names from pages",
              style = "color:#FFFFFF;background:#999999"
            )
          )
        )
      )
    ),
    
    
    # ============================================================
    # METHOD 2:
    # User-defined species regions
    # ============================================================
    conditionalPanel(
      condition = "input.speciesNameSource == 'regions'",
      
      fluidRow(
        column(
          12,
          
          wellPanel(
            
            # ----------------------------------------------------
            # Introduction
            # ----------------------------------------------------
            h3("2. Define the species title area on the page"),
            
            p(
              paste(
                "Define the page region in which the complete species title should be detected directly.",
                "Choose an example page and draw a rectangle around the complete title, including the species author name where present, while avoiding unrelated text.",
                "These examples guide direct title detection; no species reference from a map legend is required."
              ),
              style = "color:black"
            ),
            
            
            # ====================================================
            # TRAINING AREA - TWO COLUMNS
            # ====================================================
            fluidRow(
              
              # ==================================================
              # LEFT:
              # Page selection and page preview
              # ==================================================
              column(
                6,
                
                selectInput(
                  "species_training_page",
                  label = "Choose an example page:",
                  choices = NULL
                ),
                
                br(),
                
                uiOutput(
                  "species_training_page_preview"
                )
              ),
              
              
              # ==================================================
              # RIGHT:
              # Selection controls and temporary training data
              # ==================================================
              column(
                6,
                
                h4("Select and review regions"),
                p("Choose 'Species title', drag around the name on the page, then click 'Add title selection'. You can add up to two title regions per page."),
                p("To link a map, choose 'Associated map' and draw around it. Use the assignment button on the appropriate title entry below to link that map to the title."),
                radioButtons(
                  "species_selection_type",
                  label = "Region to select:",
                  choices = c(
                    "Species title" = "title",
                    "Associated map" = "map"
                  ),
                  selected = "title",
                  inline = TRUE
                ),
                
                # ------------------------------------------------
                # Add selected title region
                # ------------------------------------------------
                conditionalPanel(
                  condition = "input.species_selection_type == 'title'",
                  
                  actionButton(
                    "addSpeciesTrainingRegion",
                    "Add title selection",
                    style = "
                        color:#FFFFFF;
                        background:#f39c12;
                        border-color:#e67e22;
                      "
                  )
                ),
                
                tags$span(" "),
                
                
                
                # ------------------------------------------------
                # Temporary selected map information
                # ------------------------------------------------
                uiOutput(
                  "species_map_selection_info"
                ),
                
                # ------------------------------------------------
                # All currently collected training regions
                # ------------------------------------------------
                uiOutput(
                  "species_training_regions"
                ),
                # ------------------------------------------------
                # Clear regions of current page
                # ------------------------------------------------
                actionButton(
                  "clearSpeciesTrainingRegions",
                  "Clear regions on this page"
                ),
                
                br(),
                br(),
              )
            ),
            
            
            # ====================================================
            # JAVASCRIPT:
            # Interactive rectangle selection
            # ====================================================
            tags$script(
              HTML("
                (function() {
                
                  var drawing = false;
                  var startX = 0;
                  var startY = 0;
                
                
                  // ----------------------------------------------------------
                  // Start rectangle
                  // ----------------------------------------------------------
                  $(document).on(
                    'mousedown',
                    '#species_training_image',
                    function(e) {
                
                      e.preventDefault();
                
                      var rect =
                        this.getBoundingClientRect();
                
                      startX =
                        e.clientX - rect.left;
                
                      startY =
                        e.clientY - rect.top;
                
                      drawing = true;
                
                      var selectionType =
                        Shiny.shinyapp.$inputValues.species_selection_type;
                
                      var borderColor =
                        selectionType === 'map'
                          ? 'blue'
                          : 'red';
                
                      $('#species_selection_rectangle').css({
                        display: 'block',
                        left: startX + 'px',
                        top: startY + 'px',
                        width: '0px',
                        height: '0px',
                        border: '3px solid ' + borderColor
                      });
                    }
                  );
                
                
                  // ----------------------------------------------------------
                  // Draw rectangle while mouse moves
                  // ----------------------------------------------------------
                  $(document).on(
                    'mousemove',
                    '#species_training_image',
                    function(e) {
                
                      if (!drawing) return;
                
                      var rect =
                        this.getBoundingClientRect();
                
                      var currentX =
                        e.clientX - rect.left;
                
                      var currentY =
                        e.clientY - rect.top;
                
                      var x =
                        Math.min(startX, currentX);
                
                      var y =
                        Math.min(startY, currentY);
                
                      var width =
                        Math.abs(currentX - startX);
                
                      var height =
                        Math.abs(currentY - startY);
                
                      $('#species_selection_rectangle').css({
                        left: x + 'px',
                        top: y + 'px',
                        width: width + 'px',
                        height: height + 'px'
                      });
                    }
                  );
                
                
                  // ----------------------------------------------------------
                  // Finish rectangle
                  // ----------------------------------------------------------
                  $(document).on(
                    'mouseup',
                    '#species_training_image',
                    function(e) {
                
                      if (!drawing) return;
                
                      drawing = false;
                
                      var rect =
                        this.getBoundingClientRect();
                
                      var endX =
                        e.clientX - rect.left;
                
                      var endY =
                        e.clientY - rect.top;
                
                      var x =
                        Math.min(startX, endX);
                
                      var y =
                        Math.min(startY, endY);
                
                      var width =
                        Math.abs(endX - startX);
                
                      var height =
                        Math.abs(endY - startY);
                
                      if (
                        width < 10 ||
                        height < 5
                      ) {
                        $('#species_selection_rectangle').hide();
                        return;
                      }
                
                      var selectionType =
                        Shiny.shinyapp.$inputValues.species_selection_type;
                
                      var selectionData = {
                        x: x,
                        y: y,
                        width: width,
                        height: height,
                        image_width: rect.width,
                        image_height: rect.height,
                        nonce: Math.random()
                      };
                
                
                      // ------------------------------------------------------
                      // Associated map selection
                      // ------------------------------------------------------
                      if (
                        selectionType === 'map'
                      ) {
                
                        Shiny.setInputValue(
                          'species_training_map_region',
                          selectionData,
                          {
                            priority: 'event'
                          }
                        );
                
                      } else {
                
                        // ----------------------------------------------------
                        // Species title selection
                        // ----------------------------------------------------
                        Shiny.setInputValue(
                          'species_training_region',
                          selectionData,
                          {
                            priority: 'event'
                          }
                        );
                      }
                    }
                  );
                
                
                  // ----------------------------------------------------------
                  // Remove confirmed training region
                  // ----------------------------------------------------------
                  $(document).on(
                    'click',
                    '[id^=\"removeSpeciesRegion_\"]',
                    function() {
                
                      var regionId =
                        this.id.replace(
                          'removeSpeciesRegion_',
                          ''
                        );
                
                      Shiny.setInputValue(
                        'remove_species_training_region',
                        {
                          region_id:
                            parseInt(regionId),
                          nonce:
                            Math.random()
                        },
                        {
                          priority: 'event'
                        }
                      );
                    }
                  );
                
                })();
              ")
            ),
            
            
            # ====================================================
            # SAVE / PROCESS
            # These actions operate on the collected training data
            # ====================================================
            br(),
            
            tags$hr(),
            
            h3("3. Save examples and read species names"),
            p("Review the title regions and map assignments from at least two different pages, then save your training examples. Use 'Read species names' to run detection with the saved examples."),
            fluidRow(
              
              column(
                6,
                
                actionButton(
                  "saveSpeciesTraining",
                  "Save training examples",
                  style = "
                    color:#FFFFFF;
                    background:#337ab7;
                  "
                )
              ),
              
              column(
                6,
                
                actionButton(
                  "processSpeciesTitles",
                  "Read species names",
                  disabled = TRUE,
                  style = "
                    color:#FFFFFF;
                    background:#5cb85c;
                  "
                )
              )
            ),
            
            
            # ====================================================
            # RESULT
            # ====================================================
            br(),
            
            h3("4. Review detected species names"),
            
            p(
              paste(
                "The table shows the species titles detected on the book pages",
                "and their assignment to the corresponding distribution maps."
              ),
              style = "color:black"
            ),
            
            actionButton(
              "showPageSpeciesData",
              "Show detected species"
            ),
            
            br(),
            br(),
            
            uiOutput(
              "pageSpeciesData_result"
            )
          )
        )
      )
    )
  )
}