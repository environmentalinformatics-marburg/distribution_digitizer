general_config_ui <- function(config, info) {
  required_label <- function(text) {
    tagList(text, " ", tags$span("*", class = "dd-required-star", title = "Required field", `aria-label` = "Required field"))
  }
  tabItem(
    tabName = "tab0",
    wellPanel(
      includeHTML(file.path("www", "start_instructions.html")),
      fluidRow(
        column(
          12,
          h4("✅ General Configuration Settings"),
          p("Define the book, input data and settings used for processing.", style = "color:#555;"),
          tags$hr()
        ),
        column(
          6,
          h4(strong("Book & Processing"), style = "color:black;"),
          fluidRow(column(10,
            tags$div(style = "position:relative;", textInput("title", required_label("Book Title"), config$title)),
            div(id = "title_infoBox", class = "infobox_tab_0", info$title_infoBox)
          )),
          fluidRow(column(10,
            tags$div(style = "position:relative;", textInput("author", required_label("Author"), config$author)),
            div(id = "author_infoBox", class = "infobox_tab_0", info$author_infoBox)
          )),
          fluidRow(column(10,
            tags$div(style = "position:relative;", textInput("pYear", required_label("Publication Year"), config$pYear)),
            div(id = "pYear_infoBox", class = "infobox_tab_0", info$pYear_infoBox)
          )),
          fluidRow(column(10,
            tags$div(style = "position:relative;", textInput("tesserAct", required_label("Tesseract Path"), config$tesserAct)),
            div(id = "tesserAct_infoBox", class = "infobox_tab_0", info$tesserAct_infoBox)
          )),
          fluidRow(column(10,
            tags$div(style = "position:relative;", numericInput("nMapTypes", "Number of map types", as.integer(config$nMapTypes), min = 1, max = 3, step = 1)),
            div(id = "nMapTypes_infoBox", class = "infobox_tab_0", info$nMapTypes_infoBox)
          )),
          fluidRow(column(10,
            tags$div(
              class = "dd-representation-block",
              tags$label(class = "dd-section-label", required_label("How is the species distribution represented on the maps?")),
              p("Choose one representation before saving the configuration.", class = "dd-section-help"),
              tags$div(
                class = "dd-representation-selector",
                radioButtons(
                  inputId = "speciesRepresentation", label = NULL,
                  choiceNames = list(
                    tags$div(
                      class = "dd-representation-option",
                      tags$div(class = "dd-representation-title", "Points / symbols"),
                      tags$img(class = "dd-representation-image", src = "images/species_points_example.png", alt = "Example of point and symbol distribution"),
                      tags$div(class = "dd-representation-caption", "Individual locations shown as points or symbols.")
                    ),
                    tags$div(
                      class = "dd-representation-option",
                      tags$div(class = "dd-representation-title", "Contours / areas"),
                      tags$img(class = "dd-representation-image", src = "images/species_contours_example.png", alt = "Example of contour and area distribution"),
                      tags$div(class = "dd-representation-caption", "Distribution shown as connected areas or contours.")
                    )
                  ),
                  choiceValues = c("point", "contour"),
                  selected = if (isTRUE(config$speciesRepresentation %in% c("point", "contour")))
                    config$speciesRepresentation else character(0),
                  inline = TRUE
                )
              )
            ),
            div(id = "speciesRepresentation_infoBox", class = "infobox_tab_0", info$speciesRepresentation_infoBox)
          ))
        ),
        column(
          6,
          h4(strong("Input & Image Settings"), style = "color:black;"),
          configFolderInput(id = "dataInputDir", label = required_label("Input Directory"), value = config$dataInputDir, infoText = info$dataInputDir_infoBox),
          configFolderInput(id = "dataOutputDir", label = required_label("Output Directory"), value = config$dataOutputDir, infoText = info$dataOutputDir_infoBox, color = "#007bff"),
          fluidRow(column(10,
            tags$div(id = "d_pFormat", style = "position:relative;",
              selectInput("pFormat", "Image Format", choices = c("tif" = 1, "png" = 2, "jpg" = 3), selected = config$pFormat)
            ),
            div(id = "pFormat_infoBox", class = "infobox_tab_0", info$pFormat_infoBox)
          )),
          fluidRow(column(10,
            tags$div(id = "d_pColor", style = "position:relative;",
              selectInput("pColor", "Page Color", choices = c("black white" = 1, "color" = 2), selected = config$pColor)
            ),
            div(id = "pColor_infoBox", class = "infobox_tab_0", info$pColor_infoBox)
          )),
          tags$hr(),
          h5(strong("Map Legend Identification"), style = "color:black;"),
          p(paste("Use characteristic words or phrases from the", "map legends to help identify species information."), style = "color:#555; margin-bottom:10px;"),
          fluidRow(column(10,
            tags$div(style = "position:relative;", textInput("legendKeywords", "Keywords used in map legends", value = config$legendKeywords, placeholder = "e.g. distribution of, type locality of")),
            div(id = "legendKeywords_infoBox", class = "infobox_tab_0", info$legendKeywords_infoBox)
          )),
          tags$hr(),
          h4(strong("Species Identification Settings"), style = "color:black;"),
          p("These settings help locate species titles within the book's content.", style = "color:#555; margin-bottom:15px;"),
          fluidRow(column(10,
            tags$div(class = "dd-species-title-primary",
              tags$div(style = "position:relative;", checkboxInput("middle", "Species titles are usually centered on the page", value = isTRUE(as.logical(config$middle)))),
              div(id = "middle_infoBox", class = "infobox_tab_0", info$middle_infoBox)
            )
          )),
          tags$div(class = "dd-species-title-optional",
          h5(strong("Additional search hints"), tags$span(class = "dd-optional-label", "Optional")),
          p("If a recurring keyword appears near species titles, these hints can help locate them. Fill them in when applicable; they are not required to save the configuration.", class = "dd-section-help"),
          fluidRow(column(10,
            tags$div(style = "position:relative;", textInput("specieTitleKeyword", "Keyword used near species titles", value = config$specieTitleKeyword)),
            div(id = "specieTitleKeyword_infoBox", class = "infobox_tab_0", info$specieTitleKeyword_infoBox)
          )),
          fluidRow(column(10,
            tags$div(style = "position:relative;", textInput("specieTitleKeywordBefore", "Number of lines before the keyword", value = config$specieTitleKeywordBefore)),
            div(id = "keywordBefore_infoBox", class = "infobox_tab_0", info$keywordBefore_infoBox)
          )),
          fluidRow(column(10,
            tags$div(style = "position:relative;", textInput("specieTitleKeywordThen", "Number of lines after the keyword", value = config$specieTitleKeywordThen)),
            div(id = "keywordThen_infoBox", class = "infobox_tab_0", info$keywordThen_infoBox)
          ))
          )
        )
      ),
      tags$hr(),
      uiOutput("configRequiredWarning"),
      tags$div(style = "text-align:center;", shinyjs::disabled(actionButton("saveConfig", "Save configuration", style = paste("color:#FFFFFF;", "background:#007bff;")))),
      shinyjs::hidden(tags$div(style = "text-align:center; margin-top:20px;", h3("Output folder"), actionButton("open_output", "Open output folder", style = "color:#FFFFFF;background:#28a745;")))
    )
  )
}
