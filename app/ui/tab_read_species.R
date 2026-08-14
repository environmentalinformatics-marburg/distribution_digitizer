# ============================================================
# File: tab_read_species.R
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


tab_read_species_ui <- function(
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
            strong("Read Species"),
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
              "mapReadRpecies",
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
              "pageReadRpecies",
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
            
            h3(
              "Species Name Regions",
              style = "color:black"
            ),
            
            p(
              paste(
                "Select representative pages and mark regions",
                "containing species names."
              ),
              style = "color:black"
            ),
            
            p(
              paste(
                "Multiple regions can be selected if species names",
                "occur at different positions on the page."
              ),
              style = "color:black"
            )
            
            # ----------------------------------------------------
            # NEXT:
            #
            # Select example page
            # Display page
            # Draw/select regions
            # Clear selected regions
            # Preview OCR
            # Process species names
            # ----------------------------------------------------
          )
        )
      )
    )
  )
}