configFolderInput <- function(id, label, value = "", infoText = NULL, color = "#28a745") {
  fluidRow(
    column(10,
           tags$div(style = "display:flex; align-items:center; gap:10px;",
                    
                    textInput(paste0(id, "_path"), label, value, width = "100%"),
                    
                    actionButton(paste0(id, "_open"), "Open",
                                 title = "This button opens the path in File Explorer. Please type or paste your folder path manually above.",
                                 style = paste0(
                                   "background-color:", color,
                                   "; color:white; border:none; border-radius:4px; padding:6px 10px; cursor:pointer;"
                                 ))
           ),
           tags$small(style = "color:gray; font-style:italic;",
                      "💡 Please type or paste the full folder path manually. 
                      The 'Open' button only opens the entered path in Explorer."),
           if (!is.null(infoText)) {
             div(id = paste0(id, "_infoBox"), class = "infobox_tab_0", infoText)
           }
    )
  )
}
