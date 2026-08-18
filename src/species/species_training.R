# ============================================================
# File: species_training.R
#
# Description:
# R-side processing and storage of training data used for
# species title detection.
#
# The Shiny server collects user selections and passes the
# confirmed regions to the functions in this file.
# ============================================================


save_species_training <- function(
    regions,
    workingDir
) {
  
  # ----------------------------------------------------------
  # Nothing to save
  # ----------------------------------------------------------
  if (nrow(regions) == 0) {
    stop("No confirmed training regions available.")
  }
  
  # ----------------------------------------------------------
  # Require examples from at least two different pages
  # ----------------------------------------------------------
  training_pages <- unique(regions$page)
  
  if (length(training_pages) < 2) {
    stop(
      "Please select species titles from at least two different pages."
    )
  }
  
  # ----------------------------------------------------------
  # Read book configuration
  # ----------------------------------------------------------
  config_path <- file.path(
    workingDir,
    "config",
    "config.csv"
  )
  
  if (!file.exists(config_path)) {
    stop("config.csv was not found.")
  }
  
  config <- read.csv(
    config_path,
    sep = ";",
    header = FALSE,
    stringsAsFactors = FALSE,
    fill = TRUE
  )
  
  # ----------------------------------------------------------
  # Helper for reading config values
  # ----------------------------------------------------------
  get_config_value <- function(key) {
    
    row <- config[
      config[[1]] == key,
      ,
      drop = FALSE
    ]
    
    if (nrow(row) == 0) {
      return(NA_character_)
    }
    
    value <- as.character(row[1, 2])
    
    if (is.na(value) || trimws(value) == "") {
      return(NA_character_)
    }
    
    value
  }
  
  # ----------------------------------------------------------
  # Book information
  # ----------------------------------------------------------
  book_title <- get_config_value("title")
  book_author <- get_config_value("author")
  publication_year <- get_config_value("pYear")
  page_format <- get_config_value("pFormat")
  page_color <- get_config_value("pColor")
  
  config_title_keyword <-
    get_config_value("specieTitleKeyword")
  
  config_title_keyword_before <-
    get_config_value("specieTitleKeywordBefore")
  
  config_title_keyword_then <-
    get_config_value("specieTitleKeywordThen")
  
  config_legend_keywords <-
    get_config_value("legendKeywords")
  
  # ----------------------------------------------------------
  # Build training table
  # ----------------------------------------------------------
  training_data <- regions
  
  training_data$book_title <- book_title
  training_data$book_author <- book_author
  training_data$publication_year <- publication_year
  
  training_data$page_format <- page_format
  training_data$page_color <- page_color
  
  training_data$scan_number <- suppressWarnings(
    as.integer(
      tools::file_path_sans_ext(
        basename(training_data$page)
      )
    )
  )
  
  training_data$printed_page_number <- NA_integer_
  
  # ----------------------------------------------------------
  # Text used for feature extraction
  # ----------------------------------------------------------
  training_text <- ifelse(
    !is.na(training_data$confirmed_text) &
      nzchar(trimws(training_data$confirmed_text)),
    trimws(training_data$confirmed_text),
    trimws(training_data$ocr_text)
  )
  
  training_data$ocr_was_corrected <-
    !is.na(training_data$confirmed_text) &
    nzchar(trimws(training_data$confirmed_text))
  
  training_dir <- file.path(
    workingDir,
    "training"
  )
  
  dir.create(
    training_dir,
    recursive = TRUE,
    showWarnings = FALSE
  )
  
  training_file <- file.path(
    training_dir,
    "species_title_training.csv"
  )
  
  write.csv(
    training_data,
    training_file,
    row.names = FALSE,
    na = ""
  )
  
  cat("\n=======================================\n")
  cat("SPECIES TITLE TRAINING DATA SAVED\n")
  cat("File:", training_file, "\n")
  cat("Regions:", nrow(training_data), "\n")
  cat("Pages:", length(unique(training_data$page)), "\n")
  cat("Book:", book_title, "\n")
  cat("=======================================\n")
  
  invisible(training_data)
}