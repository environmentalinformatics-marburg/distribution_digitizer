# ============================================================
# Central Tesseract configuration
# ============================================================

resolve_tesseract_installation <- function(tesseract_path) {
  if (length(tesseract_path) != 1L || is.na(tesseract_path) ||
      !nzchar(trimws(as.character(tesseract_path)))) {
    stop("Invalid Tesseract configuration: config$tesserAct is empty.", call. = FALSE)
  }

  configured_path <- normalizePath(
    trimws(as.character(tesseract_path)),
    winslash = "/",
    mustWork = FALSE
  )

  if (tolower(basename(configured_path)) == "tesseract.exe") {
    installation_dir <- dirname(configured_path)
  } else {
    installation_dir <- configured_path
  }

  executable <- file.path(installation_dir, "tesseract.exe")
  tessdata_dir <- file.path(installation_dir, "tessdata")

  if (!file.exists(executable)) {
    stop(
      "Invalid Tesseract configuration: executable not found at ",
      executable,
      ". Check config$tesserAct in config/config.csv.",
      call. = FALSE
    )
  }

  if (!dir.exists(tessdata_dir)) {
    stop(
      "Invalid Tesseract configuration: tessdata directory not found at ",
      tessdata_dir,
      ". Check config$tesserAct in config/config.csv.",
      call. = FALSE
    )
  }

  list(
    installation_dir = installation_dir,
    executable = normalizePath(executable, winslash = "/", mustWork = TRUE),
    tessdata_dir = normalizePath(tessdata_dir, winslash = "/", mustWork = TRUE)
  )
}

configure_tesseract <- function(tesseract_path) {
  installation <- resolve_tesseract_installation(tesseract_path)

  Sys.setenv(TESSDATA_PREFIX = installation$tessdata_dir)

  pytesseract_module <- reticulate::import("pytesseract", delay_load = FALSE)
  pytesseract_module$pytesseract$tesseract_cmd <- installation$executable

  message("Tesseract executable configured: ", installation$executable)
  message("TESSDATA_PREFIX configured: ", installation$tessdata_dir)

  invisible(installation)
}
