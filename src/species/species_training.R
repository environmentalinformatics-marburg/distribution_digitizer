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


species_training_file <- function(workingDir) {
  file.path(workingDir, "training", "species_title_training.csv")
}

valid_species_training <- function(data) {
  required <- c("page", "ocr_text", "confirmed_text", "x", "y", "width", "height",
    "x_relative", "y_relative", "width_relative", "height_relative")
  if (!is.data.frame(data) || !nrow(data) || !all(required %in% names(data))) return(FALSE)
  pages <- trimws(as.character(data$page))
  if (anyNA(pages) || any(!nzchar(pages)) || length(unique(pages)) < 2L) return(FALSE)
  text <- ifelse(!is.na(data$confirmed_text) & nzchar(trimws(data$confirmed_text)),
    data$confirmed_text, data$ocr_text)
  if (anyNA(text) || any(!nzchar(trimws(text)))) return(FALSE)
  for (name in c("x", "y", "width", "height", "x_relative", "y_relative", "width_relative", "height_relative")) {
    values <- suppressWarnings(as.numeric(data[[name]]))
    if (any(!is.finite(values)) || any(values < 0)) return(FALSE)
    if (grepl("width|height", name) && any(values <= 0)) return(FALSE)
  }
  TRUE
}

has_saved_species_training <- function(workingDir) {
  tryCatch(valid_species_training(read.csv(species_training_file(workingDir),
    stringsAsFactors = FALSE, check.names = FALSE)), error = function(e) FALSE)
}

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
  
  if (!valid_species_training(regions)) {
    stop("Training examples need readable or corrected species titles and valid regions on at least two pages.")
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
  
  # Preserve the existing CSV template's column structure and order.
  training_file <- species_training_file(workingDir)
  if (!file.exists(training_file)) stop("The species title training CSV template was not found.")
  template <- read.csv(training_file, nrows = 0L, check.names = FALSE)
  if (!setequal(names(template), names(training_data))) {
    stop("Training columns do not match the species title training CSV template.")
  }
  training_data <- training_data[, names(template), drop = FALSE]

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