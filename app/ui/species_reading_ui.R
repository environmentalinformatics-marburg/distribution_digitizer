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
    shinyfields6
) {
  
  tabItem(
    tabName = "tab5",
    
    # ============================================================
    # TOP: Species name source
    # ============================================================
    fluidRow(
      column(
        12,
        
        wellPanel(
          
          h3(
            strong("Species Reading"),
            style = "color:black"
          ),
          
          p(
            "Select how species names are represented in the book.",
            style = "color:black"
          ),
          
          radioButtons(
            "speciesNameSource",
            label = "Species name source:",
            choices = c(
              "Species names in / below map legend" = "legend",
              "Species names elsewhere on the page" = "regions"
            ),
            selected = "legend",
            inline = TRUE
          )
        )
      )
    ),
    
    br(),
    
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
      
      actionButton(
        "listCropped",
        label = "List cropped maps"
      ),
      
      br(),
      br(),
      
      fluidRow(
        column(
          4,
          
          # ------------------------------------------------------
          # Species from map
          # ------------------------------------------------------
          wellPanel(
            
            h3(
              shinyfields2$head_species,
              style = "color:black"
            ),
            
            p(
              shinyfields2$inf4,
              style = "color:black"
            ),
            
            actionButton(
              "mapReadSpecies",
              label = shinyfields2$start3,
              style = "color:#FFFFFF;background:#999999"
            )
          ),
          
          # ------------------------------------------------------
          # Species from page
          # ------------------------------------------------------
          wellPanel(
            
            h3(
              shinyfields2$head_page_species,
              style = "color:black"
            ),
            
            p(
              shinyfields2$inf5,
              style = "color:black"
            ),
            
            actionButton(
              "pageReadSpecies",
              label = shinyfields2$start4,
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
            h4(
              "Create training examples for species title detection",
              style = "color:black"
            ),
            
            p(
              paste(
                "Select pages from the current book and mark examples of species titles.",
                "These examples are used to learn how species titles are structured and positioned in this book."
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
                7,
                
                selectInput(
                  "species_training_page",
                  label = "Select a page for training:",
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
                5,
                
                radioButtons(
                  "species_selection_type",
                  label = "Select region for:",
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
                  "Clear all regions"
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
            
            fluidRow(
              
              column(
                3,
                
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
                3,
                
                actionButton(
                  "processSpeciesTitles",
                  "Process species titles",
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
            
            h4(
              "Species titles automatically detected and assigned to maps",
              style = "color:black"
            ),
            
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