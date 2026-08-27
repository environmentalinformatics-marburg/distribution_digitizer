# ============================================================
# File: create_templates_ui.R
#
# Description:
# UI for creating map templates and map symbol templates.
# ============================================================

book_structure_training_ui <- function(shinyfields1, workingDir) {
  
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
          
          verbatimTextOutput("file_out"),
          hr(),
          
          h4(
            strong(
              "Book structure training",
              style = "color:black"
            )
          ),
          
          p(
            "Select which structural element of the book you want to train.",
            style = "color:black"
          ),
          
          radioButtons(
            "bookTrainingType",
            label = NULL,
            choices = c(
              "Map template" = "map",
              "Distribution symbol" = "symbol",
              "Page number" = "page_number"
            ),
            selected = "map",
            inline = FALSE
          ),
          conditionalPanel(
            condition = "input.bookTrainingType == 'page_number'",
            
            tags$div(
              style = "
      margin-top:15px;
      padding:10px;
      border-left:4px solid #337ab7;
      background:#f5f9fc;
    ",
              
              h4(
                strong("Page number training"),
                style = "color:black;"
              ),
              
              p(
                paste(
                  "Select the region containing the printed page number.",
                  "Include the complete page number and any surrounding",
                  "graphical elements that belong to it, such as a circle",
                  "or frame."
                ),
                style = "color:black;"
              ),
              
              p(
                strong(
                  "Select one page-number region per training page."
                ),
                style = "color:#337ab7;"
              )
            )
          )
        ),
        
        
        # ======================================================
        # MAP TEMPLATE INFORMATION
        # Visible after a crop region has been selected
        # ======================================================
        # ======================================================
        # MAP TEMPLATE INFORMATION
        # ======================================================
        
        conditionalPanel(
          condition = "input.bookTrainingType == 'map'",
          
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
          )
        ),
        # ======================================================
        # DISTRIBUTION SYMBOL INFORMATION
        # ======================================================
        
        conditionalPanel(
          condition = "input.bookTrainingType == 'symbol'",
          
          wellPanel(
            
            h4(
              strong(
                "Distribution symbol training",
                style = "color:black"
              )
            ),
            
            tags$p(
              paste(
                "Select one representative distribution symbol",
                "from the map, such as a point, circle, square",
                "or another symbol used to represent a species distribution."
              )
            ),
            
            tags$p(
              style = "font-weight:bold;",
              paste(
                "👉 Draw the selection as closely as possible around",
                "the symbol and avoid including surrounding map elements."
              )
            ),
            
            tags$p(
              paste(
                "If the book uses several different distribution symbols,",
                "save at least one representative example of each type."
              )
            ),
            
            hr(),
            
            h4(
              strong(
                "Save distribution symbol template",
                style = "color:black"
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
        ),
 
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
          
          div(
            style = paste0(
              "width:100%;",
              "max-height:750px;",
              "overflow:auto;",
              "border:1px solid #ddd;",
              "background:white;"
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
    ),
    # ========================================================
    # PAGE NUMBER TRAINING
    # ========================================================
    
    conditionalPanel(
      condition = "input.bookTrainingType == 'page_number'",
      
      br(),
      
      wellPanel(
        
        h4(
          strong(
            "Page number training",
            style = "color:black"
          )
        ),
        
        p(
          paste(
            "Select examples of printed page numbers from several pages.",
            "These examples are used to learn where page numbers are",
            "located and how they are represented in this book."
          ),
          style = "color:black"
        ),
        
        p(
          paste(
            "Select the complete page-number region, including surrounding",
            "elements such as a circle, frame or other characteristic",
            "structure if present."
          ),
          style = "color:#555"
        ),
        
        fluidRow(
          
          # ======================================================
          # LEFT - PAGE
          # ======================================================
          
          column(
            width = 7,
            
            selectInput(
              "page_number_training_page",
              label = "Select a page for training:",
              choices = NULL
            ),
            
            br(),
            
            uiOutput(
              "page_number_training_page_preview"
            ),# ======================================================
            # JAVASCRIPT - PAGE NUMBER REGION SELECTION
            # ======================================================
            
            tags$script(
              HTML("
    (function() {

      var drawingPageNumber = false;
      var startX = 0;
      var startY = 0;


      // ------------------------------------------------------
      // Start selection
      // ------------------------------------------------------
      $(document).on(
        'mousedown',
        '#page_number_training_image',
        function(e) {

          e.preventDefault();

          var rect =
            this.getBoundingClientRect();

          startX =
            e.clientX - rect.left;

          startY =
            e.clientY - rect.top;

          drawingPageNumber = true;

          $('#page_number_selection_rectangle').css({
            display: 'block',
            left: startX + 'px',
            top: startY + 'px',
            width: '0px',
            height: '0px',
            border: '3px solid #337ab7'
          });
        }
      );


      // ------------------------------------------------------
      // Draw selection
      // ------------------------------------------------------
      $(document).on(
        'mousemove',
        '#page_number_training_image',
        function(e) {

          if (!drawingPageNumber) return;

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

          $('#page_number_selection_rectangle').css({
            left: x + 'px',
            top: y + 'px',
            width: width + 'px',
            height: height + 'px'
          });
        }
      );


      // ------------------------------------------------------
      // Finish selection
      // ------------------------------------------------------
      $(document).on(
        'mouseup',
        '#page_number_training_image',
        function(e) {

          if (!drawingPageNumber) return;

          drawingPageNumber = false;

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


          // Ignore accidental tiny selections
          if (
            width < 5 ||
            height < 5
          ) {

            $('#page_number_selection_rectangle').hide();

            return;
          }


          // --------------------------------------------------
          // Send selection to Shiny
          // --------------------------------------------------

          Shiny.setInputValue(
            'page_number_training_region',
            {
              x: x,
              y: y,
              width: width,
              height: height,

              image_width:
                rect.width,

              image_height:
                rect.height,

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
            )
          ),
          
          
          # ======================================================
          # RIGHT - SELECTION
          # ======================================================
          
          column(
            width = 5,
            
            h4(
              strong("Selected page number region")
            ),
            
            p(
              paste(
                "Draw a blue rectangle around the printed page number.",
                "After selecting the region, add it to the training examples."
              )
            ),
            
            actionButton(
              "addPageNumberTrainingRegion",
              "Add selected region",
              style = "
            color:#FFFFFF;
            background:#337ab7;
            border-color:#2e6da4;
          "
            ),
            
            br(),
            br(),
            
            uiOutput(
              "page_number_training_regions"
            ),
            br(),
            
            uiOutput("page_number_training_status"),
            
            actionButton(
              "savePageNumberTraining",
              "Save page number training data",
              class = "btn-success"
            )
          )
        )
      )
    ),
    tags$script(
      HTML("
    (function() {

      var drawing = false;
      var startX = 0;
      var startY = 0;

      // --------------------------------------------------------
      // Start page-number selection
      // --------------------------------------------------------
      $(document).on(
        'mousedown',
        '#book_training_image',
        function(e) {

          var trainingType =
            Shiny.shinyapp.$inputValues.bookTrainingType;

          if (trainingType !== 'page_number') {
            return;
          }

          e.preventDefault();

          var rect = this.getBoundingClientRect();

          startX = e.clientX - rect.left;
          startY = e.clientY - rect.top;

          drawing = true;

          $('#page_number_selection_rectangle').css({
            display: 'block',
            left: startX + 'px',
            top: startY + 'px',
            width: '0px',
            height: '0px',
            border: '3px solid #337ab7',
            background: 'rgba(51,122,183,0.10)'
          });
        }
      );


      // --------------------------------------------------------
      // Draw rectangle
      // --------------------------------------------------------
      $(document).on(
        'mousemove',
        '#book_training_image',
        function(e) {

          if (!drawing) return;

          var rect = this.getBoundingClientRect();

          var currentX = e.clientX - rect.left;
          var currentY = e.clientY - rect.top;

          var x = Math.min(startX, currentX);
          var y = Math.min(startY, currentY);

          var width = Math.abs(currentX - startX);
          var height = Math.abs(currentY - startY);

          $('#page_number_selection_rectangle').css({
            left: x + 'px',
            top: y + 'px',
            width: width + 'px',
            height: height + 'px'
          });
        }
      );


      // --------------------------------------------------------
      // Finish selection
      // --------------------------------------------------------
      $(document).on(
        'mouseup',
        '#book_training_image',
        function(e) {

          if (!drawing) return;

          drawing = false;

          var rect = this.getBoundingClientRect();

          var endX = e.clientX - rect.left;
          var endY = e.clientY - rect.top;

          var x = Math.min(startX, endX);
          var y = Math.min(startY, endY);

          var width = Math.abs(endX - startX);
          var height = Math.abs(endY - startY);

          if (width < 5 || height < 5) {
            $('#page_number_selection_rectangle').hide();
            return;
          }

          Shiny.setInputValue(
            'page_number_training_region',
            {
              x: x,
              y: y,
              width: width,
              height: height,
              image_width: rect.width,
              image_height: rect.height,
              nonce: Math.random()
            },
            {
              priority: 'event'
            }
          );
        }
      );

    })();
  ")
    )
  )
}