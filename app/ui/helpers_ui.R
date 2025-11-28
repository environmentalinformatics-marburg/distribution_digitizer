configFolderInput <- function(id, label, value = "", infoText = "", color = "#28a745") {
  fluidRow(
    column(
      10,
      
      # --- Eingabefeld + Button ---
      tags$div(
        style = "position:relative; display:flex; gap:10px; align-items:center;",
        
        # TextInput
        textInput(id, label, value, width = "100%"),
        
        # Button "Open"
        actionButton(
          paste0(id, "_open"), "Open",
          title = "This button opens the path in File Explorer. 
                   Please type or paste your folder path manually above.",
          style = paste0(
            "background-color:", color,
            "; color:white; border:none; border-radius:4px;
             padding:6px 10px; cursor:pointer;"
          )
        )
      ),
      
      # --- Info-Box: startet immer mit display:none ---
      tags$div(
        id = paste0(id, "_infoBox"),
        class = "infobox_tab_0",
        infoText
      ),
      

    )
  )
}
