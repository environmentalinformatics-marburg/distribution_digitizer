# ============================================================
# File: create_templates_ui.R
#
# Description:
# UI for creating map templates and map symbol templates.
# ============================================================

create_templates_ui <- function(shinyfields1, workingDir) {
  
  tabItem(
    tabName = "tab1",
    
    fluidRow(
      
      # ========================================================
      # LEFT PANEL - CONTROLS AND INFORMATION
      # ========================================================
      
      column(
        width = 5,
        
        wellPanel(
          
          h3(
            strong(
              shinyfields1$head,
              style = "color:black"
            )
          ),
          
          p(
            shinyfields1$inf4,
            style = "color:black"
          ),
          
          fileInput(
            "image",
            label = h5(shinyfields1$lab1),
            buttonLabel = "Browse...",
            placeholder = "No file selected"
          ),
          
          verbatimTextOutput("file_out")
        ),
        
        
        # ======================================================
        # MAP TEMPLATE INFORMATION
        # Visible after a crop region has been selected
        # ======================================================
        
        conditionalPanel(
          condition = "output.showCropHint",
          
          wellPanel(
            
            tags$p(
              strong("⚠️ Important:")
            ),
            
            tags$p(
              paste(
                "Please select only map pages that are already",
                "well-scanned and correctly aligned. This will",
                "significantly improve the accuracy of the",
                "template matching process."
              )
            ),
            
            tags$p(
              style = "font-weight:bold;",
              
              paste(
                "👉 When cropping the map area, make sure that",
                "the entire map border is included, but extend",
                "the selection only a few pixels beyond the frame.",
                "No page text or captions should appear inside",
                "the cropped template image."
              )
            ),
            
            tags$p(
              style = "font-weight:bold;",
              
              "👉 For best results, create at least two template maps."
            ),
            
            
            # --------------------------------------------------
            # Example template structure
            # --------------------------------------------------
            
            tags$div(
              style = "text-align:center; margin:10px 0;",
              
              tags$img(
                src = "assets/templates_struct_1.JPG",
                alt = "Template folder structure example",
                style = paste(
                  "max-width:100%;",
                  "border:1px solid #ccc;",
                  "border-radius:8px;"
                )
              )
            ),
            
            tags$p(
              paste(
                "👉 If your book contains different types or",
                "layouts of maps, create separate template groups",
                "under the templates directory."
              ),
              tags$br(),
              paste(
                "Each group (e.g. t_1, t_2, t_3) should have",
                "the same internal structure."
              )
            ),
            
            tags$div(
              style = "text-align:center; margin:10px 0;",
              
              tags$img(
                src = "assets/templates_struct_2.JPG",
                alt = "Multiple template groups example",
                style = paste(
                  "max-width:100%;",
                  "border:1px solid #ccc;",
                  "border-radius:8px;"
                )
              )
            ),
            
            
            # ==================================================
            # SAVE MAP TEMPLATE
            # ==================================================
            
            hr(),
            
            h4(
              strong(
                shinyfields1$save_template,
                style = "color:black"
              )
            ),
            
            numericInput(
              "imgIndexTemplate",
              label = "Map template number",
              value = 1,
              min = 1
            ),
            
            downloadButton(
              "saveTemplate",
              "Save map template",
              style = "color:#FFFFFF;background:#999999"
            )
          ),
          
          
          # ====================================================
          # SAVE SYMBOL TEMPLATE
          # Only for point/symbol representation
          # ====================================================
          
          conditionalPanel(
            condition = "output.showSymbolTemplate",
            
            wellPanel(
              
              h4(
                strong(
                  "Save distribution symbol template",
                  style = "color:black"
                )
              ),
              
              p(
                paste(
                  "For maps using points or symbols, select a",
                  "representative distribution symbol such as",
                  "a point, circle or square."
                )
              ),
              
              numericInput(
                "imgIndexSymbol",
                label = "Symbol template number",
                value = 1,
                min = 1
              ),
              
              downloadButton(
                "saveSymbol",
                "Save symbol template",
                style = "color:#FFFFFF;background:#999999"
              )
            )
          )
        )
      ),
      
      
      # ========================================================
      # RIGHT PANEL - BOOK PAGE AND CROP PREVIEW
      # ========================================================
      
      column(
        width = 7,
        
        wellPanel(
          
          h4(
            strong(
              "Select template region",
              style = "color:black"
            )
          ),
          
          p(
            paste(
              "Draw a rectangle around the map or distribution symbol",
              "that you want to use as a template."
            ),
            style = "color:black"
          ),
          
          p(
            paste(
              "The selected region will be shown below as a preview.",
              "You can adjust the selection before saving the template."
            ),
            style = "color:#555;"
          ),
          
          plotOutput(
            "plot",
            click = "plot_click",
            hover = hoverOpts(
              id = "plot_hover",
              delayType = "throttle"
            ),
            brush = brushOpts(
              id = "plot_brush"
            ),
            width = "100%"
          )
        ),
        
        
        # ------------------------------------------------------
        # CROPPED PREVIEW
        # ------------------------------------------------------
        
        conditionalPanel(
          condition = "output.showCropHint",
          
          wellPanel(
            
            h4(
              strong(
                "Selected region",
                style = "color:black"
              )
            ),
            
            div(
              style = "width:60%; margin-left:0;",
              
              plotOutput(
                "plot1",
                width = "100%",
                height = "350px"
              )
            )
          )
        )
      )
    )
  )
}