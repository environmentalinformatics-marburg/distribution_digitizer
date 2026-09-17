# UI for map templates, distribution symbols and page-number training.
book_structure_training_ui <- function(shinyfields1, workingDir) {
  template_save_help <- tags$div(
    class = "dd-template-note",
    p("Saving creates a TIFF file in the application folder shown below and downloads a copy through your browser."),
    tags$code(file.path(workingDir, "data", "input", "templates")),
    p("Use a new template number for each example. Reusing a number replaces the existing file; the number increases automatically after saving.")
  )

  tabItem(
    tabName = "tab1",
    wellPanel(
      h3("Create Templates"),
      p("Create reference examples for finding maps, distribution symbols and printed page numbers in this book."),
      tags$div(class = "dd-template-note",
        strong("Read before creating templates"),
        tags$ul(
          tags$li(strong("Choose a clear, well-aligned scan. "), "Poor alignment can cause matching errors."),
          tags$li(strong("Crop maps precisely. "), "Include the complete map border with a margin of no more than 5 pixels. Exclude surrounding page text and captions."),
          tags$li(strong("Use the required folders. "), "Follow the map-type folder structure under 'Where to save your templates' below so the processing steps can find your files."),
          tags$li(strong("Correct skewed templates before use. "),
            "Use ", tags$a("ScanTailor", href = "https://scantailor.org/downloads/", target = "_blank"),
            " or ", tags$a("GIMP", href = "https://www.gimp.org/downloads", target = "_blank"),
            " and save the corrected files in the same folder structure. For alignment of extracted maps, use the alignment step in Map Matching."
          )
        )
      ),
      radioButtons(
        "bookTrainingType", label = "1. Choose what to prepare",
        choices = c("Map template" = "map", "Distribution symbol" = "symbol", "Page number" = "page_number"),
        selected = "map", inline = TRUE
      ),
      p("Distribution symbol templates apply to Points / symbols, as selected in General Config.", class = "dd-template-help")
    ),
    conditionalPanel(
      condition = "input.bookTrainingType != 'page_number'",
      fluidRow(
        column(5,
          wellPanel(
            h4("2. Choose a source page"),
            p("Upload a clear, correctly aligned scan. Then drag on the page preview to select the region you need."),
            fileInput("image", label = "Scanned book page", buttonLabel = "Browse...", placeholder = "No file selected"),
            conditionalPanel(
              condition = "input.bookTrainingType == 'map'",
              p("For best results, create at least two map templates where possible, with separate examples for each map layout.", class = "dd-template-help")
            ),
            conditionalPanel(
              condition = "input.bookTrainingType == 'symbol'",
              tags$div(class = "dd-template-note",
                strong("Symbol cropping checklist"),
                tags$ul(
                  tags$li("Select one complete point, circle, square or other distribution symbol."),
                  tags$li("Crop closely around it and exclude surrounding map features."),
                  tags$li("Create at least one example of each symbol type used in the book.")
                )
              )
            )
          ),
          wellPanel(
            conditionalPanel(
              condition = "input.bookTrainingType == 'map'",
              h4("4. Save the map template")
            ),
            conditionalPanel(
              condition = "input.bookTrainingType == 'symbol'",
              h4("4. Save the symbol template")
            ),
            p(strong("Read before saving"), class = "dd-template-note"),
            h4("Where to save your templates"),
            template_save_help,
            conditionalPanel(
              condition = "input.bookTrainingType == 'map'",
              tags$div(class = "dd-template-note",
                strong("Required folder structure for Map Matching"),
                p("After saving, copy or move each map template into the maps subfolder of its map-type group. The Save button does not place files into these groups automatically."),
                tags$code(file.path(workingDir, "data", "input", "templates", "1", "maps")),
                p("For the first map type, place map_1.tif, map_2.tif and any additional examples in templates/1/maps/."),
                p("If the book contains different map layouts, use a separate numbered group for each type: 1, 2, 3. Keep the same subfolder structure in each group and set Number of map types in General Config accordingly."),
                tags$pre(paste(
                  "templates/",
                  "  1/",
                  "    maps/",
                  "      map_1.tif",
                  "      map_2.tif",
                  "    symbols/",
                  "    geopoints/",
                  "  2/",
                  "    maps/",
                  "      map_1.tif",
                  "      map_2.tif",
                  "    symbols/",
                  "    geopoints/",
                  sep = "\n"
                )),
                p(strong("Map Matching looks for map templates in these numbered maps folders. Files left directly in templates/ will not be used for matching."))
              )
            ),
            conditionalPanel(
              condition = "input.bookTrainingType == 'symbol'",
              tags$div(class = "dd-template-note",
                strong("Where to save symbol templates"),
                p("After saving, copy or move each symbol template into the symbols subfolder of its map-type group. The Save button does not place files into these groups automatically."),
                tags$code(file.path(workingDir, "data", "input", "templates", "1", "symbols")),
                p("For the first map type, place symbol_1.tif, symbol_2.tif and any additional examples in templates/1/symbols/. For additional map types, use templates/2/symbols/, templates/3/symbols/ and so on, according to Number of map types in General Config."),
                p("Save at least one example of each symbol type used by the corresponding map type."),
                tags$pre(paste(
                  "templates/",
                  "  1/",
                  "    maps/",
                  "    symbols/",
                  "      symbol_1.tif",
                  "      symbol_2.tif",
                  "    geopoints/",
                  "  2/",
                  "    maps/",
                  "      map_1.tif",
                  "      map_2.tif",
                  "    symbols/",
                  "      symbol_1.tif",
                  "      symbol_2.tif",
                  "    geopoints/",
                  sep = "\n"
                ))
              )
            ),
            p("Check the selected-region preview before saving."),
            conditionalPanel(
              condition = "input.bookTrainingType == 'map'",
              numericInput("imgIndexTemplate", "Map template number", value = 1, min = 1, step = 1),
              p("File name: map_<number>.tif", class = "dd-template-help"),
              downloadButton("saveTemplate", "Save map template", class = "btn-primary")
            ),
            conditionalPanel(
              condition = "input.bookTrainingType == 'symbol'",
              numericInput("imgIndexSymbol", "Symbol template number", value = 1, min = 1, step = 1),
              p("File name: symbol_<number>.tif", class = "dd-template-help"),
              downloadButton("saveSymbol", "Save symbol template", class = "btn-primary")
            )
          )
        ),
        column(7,
          wellPanel(
            h4("3. Select and review the region"),
            p("Drag to draw a rectangle around the map or symbol. Adjust the rectangle until the preview contains exactly the area you want."),
            tags$div(class = "dd-template-page-viewport",
              imageOutput("plot", click = "plot_click",
                hover = hoverOpts(id = "plot_hover", delayType = "throttle"),
                brush = brushOpts(id = "plot_brush"), width = "100%", height = "auto")
            )
          ),
          conditionalPanel(
            condition = "output.showCropHint",
            wellPanel(
              h4("Selected-region preview"),
              tags$div(class = "dd-template-crop-viewport",
                plotOutput("plot1", width = "100%", height = "350px")
              )
            )
          )
        )
      )
    ),
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
            "Select page-number examples from at least five different pages.",
            "Check and correct every detected number before saving. These examples record where page numbers are",
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
              label = "1. Choose a prepared page",
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
              strong("2. Review and add the selected region")
            ),
            
            p(
              paste(
                "Drag on the page to draw a rectangle around the complete printed page number.",
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
              "3. Save page-number training data",
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