# app/app.R
library(shiny)

# --- Optional: global.R laden, falls vorhanden ---
if (file.exists("global.R")) source("global.R")

# --- UI & Server laden ---
ui <- source("ui/ui.R")$value
server <- source("server/server.R")$value

# --- App starten ---
shinyApp(ui = ui, server = server)
