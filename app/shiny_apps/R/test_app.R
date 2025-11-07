library(shiny)

ui <- fluidPage(
  tabsetPanel(id = "tabs",
              tabPanel("Tab 1", value = "tab1", actionButton("next", "Go to Tab 2")),
              tabPanel("Tab 2", value = "tab2", textOutput("text"))
  )
)

server <- function(input, output, session) {
  observeEvent(input$next, {
    updateTabsetPanel(session, "tabs", selected = "tab2")
  })
}

shinyApp(ui, server)
