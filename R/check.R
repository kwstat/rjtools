#' A single article check
#'
#' @details
#'
#' @param path The directory that contains the .tex file (Ideally, this directory should contain .bib, .rmd, and .tex with author names and two RJwrapper files:  RJwrapper.pdf and RJwrapper.tex)
#' @param dic The dictionary used for spelling check. See \code{dict} argument in [hunspell::hunspell()]
#' @param pkg The name of the proposed package (if relevant), to be checked for activity on CRAN
#' @details
#' Folder structure checks:
#'
#' * \code{check_wrappers()}: the two expected RJwrapper files (RJwrapper.tex and RJwrapper.pdf) exist
#' * \code{check_filenames()}: the three files (.bib, .Rmd, and .tex) all present and have consistent names
#' * \code{check_unnecessary_files()}: template files (i.e. RJtemplate.tex and RJournal.sty) are not included in the directory
#' * \code{check_cover_letter()}: a motivational letter
#'
#' Content checks:
#'
#' * \code{check_title()}: article title is in title case
#' * \code{check_section()}: section sections are in sentence case
#' * \code{check_abstract_before_intro()}: abstract comes before the introduction section
#' * \code{check_spelling()}: potential spelling mistakes
#' * \code{check_proposed_pkg()}: package proposed in the paper is on CRAN
#' * \code{check_packages_available()}: packages mentioned in the article are available on CRAN
#'
#' See \code{vignette("create_article", package = "rjtools")} for how to use the check functions
#' @rdname checks
#' @export
initial_check_article <- function(path = here::here(), dic = "en_US", pkg=NULL) {

  # Documents:
  # Necessary files must be included in submission folder
  # Do not proceed without them, flag for manual check
  # Unnecessary files must not be included in submission folder
  # Do not proceed with them, flag for manual check

  if (!"tex" %in% tools::file_ext(list.files(path = path))){
    stop("Please supply the directory that contains the .tex file")
  }

  # Create a log file for errors
  sink(file.path(path, "initial_checks.log"))

  # Display the name of the current article
  cat(paste0("Initial check results: ", "\n"))

  cli::cli_h1(paste0("Initial check results: "))

  # BEGIN CHECKS
  # Folder structure checks:
  check_wrappers(path)
  check_filenames(path)
  check_unnecessary_files(path)
  check_cover_letter(path)

  # Tex file checks:
  check_title(path)
  check_section(path)
  check_abstract_before_intro(path)
  check_spelling(path, dic)
  check_proposed_pkg(pkg)
  check_packages_available(path)

  # Show a numeric summary of successes, errors and notes
  output_summary(path)

  # Return to console output
  sink()
  closeAllConnections()

}


##############################################
##############################################
# Folder structure checks:

#' @rdname checks
#' @export
check_wrappers <- function(path) {

  submission_files <-  list.files(path)

  # Check for RJwrapper files
  wrapper_files <- c("RJwrapper.tex", "RJwrapper.pdf")

  # Immediate failure?
  # Return a warning if either "RJwrapper.tex" and/or "RJwrapper.pdf" not found
  if (!all(wrapper_files %in% submission_files)) {

    log_error("Submission is missing an RJwrapper file")

  } else {

    log_success("Submission contains both RJwrapper.tex and RJwrapper.pdf")

  }

}

#' @importFrom tools file_ext file_path_sans_ext
#' @rdname checks
#' @export
check_filenames <- function(path) {

  remaining_files <- remove_wrapper(path)
  exts <- tools::file_ext(remaining_files)

  files_exist <- c("tex", "bib", "R") %in% exts

  matching_filename <- remaining_files[exts %in% c("tex", "bib", "R")]

  single_filename <- tools::file_path_sans_ext(matching_filename)

  # Check for all three files with matching names
  # Find the file name that should match

  if (!length(unique(single_filename)) == 1) {

    log_error("Submission does not have consistently named tex, bib, and R files")

  } else if (!all(files_exist)){

    log_error("Submission is missing a tex, bib or R file")

  } else{

    log_success("Submission has consistently named tex, bib, and R files")

  }

}

#' @rdname checks
#' @export
check_unnecessary_files <- function(path) {

  submission_files <- list.files(path)
  unnecessary_files <- "RJtemplate.tex"

  if (any(unnecessary_files %in% submission_files)) {

    unnecessary <- unnecessary_files[unnecessary_files %in% submission_files]
    log_error("Submission contains unnecessary files: ", unnecessary)

  } else {

    log_success("No problematic file found")

  }

}

#' @rdname checks
#' @export
check_cover_letter <- function(path){


  remaining_files <- remove_wrapper(path)
  if (!any(grepl("motivation", remaining_files))) {

    log_note("Motivation letter is not detected, if applicable")

  } else {

    log_success("Possible motivation letter found")

  }

}


##############################################
##############################################
# Tex file checks:

#' @importFrom stringr str_extract
#' @importFrom tools toTitleCase
#' @rdname checks
#' @export
check_title <- function(path){

  tex <- extract_tex(path)
  str <- stringr::str_extract(tex,  "(?<=\\\\title\\{).*?(?=\\})")

  if (tools::toTitleCase(str) != str){
    correct <- tools::toTitleCase(str)
    quote_fixed <- gsub('\"', "", correct, fixed = TRUE)
    log_error("The title is not in title case! Suggest title to be changed to:
              {quote_fixed}")
  } else{
    log_success("The article title is properly formatted in title case.")
  }

}


#' @importFrom stringr str_extract
#' @importFrom utils available.packages
#' @rdname checks
#' @export
check_section <- function(path){

  tex <- extract_tex(path)

  str <- unlist(stringr::str_extract_all(tex,  "(?<=\\\\section\\{).*?(?=\\}[\\s]?[\\\\label]?)"))

  if (any(str_detect(str, "texorpdfstring"))){
    str <- unlist(stringr::str_extract_all(tex,  "(?<=\\\\section\\{).*?(?=\\}\\\\label)"))
  }

  clean_section_title <- function(str){
    if (str_detect(str, "texorpdfstring")){
      str <- str_extract(str, "(?<=\\}\\{).*?(?=\\})")
    }

    str
  }

  str <- lapply(str, clean_section_title)

  if (!all(stringr::str_to_sentence(str) == str)){
    problem_one <- str[!stringr::str_to_sentence(str) == str]
    log_error("Section {problem_one} is not in sentence case!")
  } else{
    log_success("All sections are properly formatted in sentence case")
  }

}


#' @importFrom stringr str_locate
#' @rdname checks
#' @export
check_abstract_before_intro <- function(path){

  tex <- extract_tex_vec(path)

  abstract <- stringr::str_locate(tex, "abstract")[,"start"]
  abstract <- abstract[!is.na(abstract)][1]
  intro <- stringr::str_locate(tex, "introduction")[,"start"]
  intro <- intro[!is.na(intro)][1]

  if(is.na(abstract)){
    log_error(paste0("Unable to find abstract! Please check for the \abstract ",
                     "tag in your Tex document"))
  } else if(is.na(intro)){
    log_error(paste0("Unable to find introduction! Please check for an intro ",
                     "in your Tex document"))
  } else if (abstract > intro){
    log_error("Abstract doesn't come before the introduction section")
  } else {
    log_success("Abstract comes before the introduction section")
  }
}

#' @importFrom stringr str_extract str_replace_all
#' @importFrom purrr map2 map
#' @importFrom hunspell hunspell dictionary
#' @importFrom tools toTitleCase
#' @rdname checks
#' @export
check_spelling <- function(path, dic = "en_US"){

  tex <- extract_tex_vec(path)

  detect_abstract <- purrr::map(tex, ~stringr::str_extract(.x,  "(?<=\\\\abstract\\{).*?"))
  abstract_loc <- match(detect_abstract[!is.na(detect_abstract)], detect_abstract)

  detect_bib <- purrr::map(tex, ~stringr::str_extract(.x,  "(?<=\\\\bibliography\\{).*?(?=\\})"))
  bib_loc <- match(detect_bib[!is.na(detect_bib)], detect_bib)

  # spell_to_remove is a pre-defined vector of latex commands
  # to be removed from spelling check
  to_replace <- paste(spell_to_remove, collapse = "|")
  tex2 <- stringr::str_replace_all(tex, to_replace, "")
  text_bw <- tex2[(abstract_loc + 1):(bib_loc - 1)]

  chunk_begin <- which(text_bw == "\\begin{Schunk}")
  chunk_end <- which(text_bw == "\\end{Schunk}")
  chunk_idx <- unlist(purrr::map2(chunk_begin, chunk_end, ~.x:.y))

  select_idx <- !c(1:length(text_bw)) %in% chunk_idx
  text_clean <- text_bw[select_idx]

  check_raw <- hunspell::hunspell(text_clean, format = "latex", dic = hunspell::dictionary(dic))
  check <- unique(unlist(check_raw))
  check_out <- check[tolower(check) == check]

  if (length(check_out) != 0){
    log_note("A potential list of spelling to check: ", paste(check_out, collapse = ", "))
  } else{
    log_success("No spelling mistake detected")
  }

}


#' @importFrom cranlogs cran_downloads
#' @rdname checks
#' @export
check_proposed_pkg <- function(pkg=NULL){
  if(is.null(pkg)){
    pkg <- readline(prompt = paste0("What's the name of package being ",
                                    "proposed in the article? If none, please ",
                                    "enter 0. "))
  }

  if (pkg != 0) {
    count <- sum(cranlogs::cran_downloads(pkg, from = "2020-01-01")$count)
    if (count == 0){
      log_note(text = "No CRAN activities detected for package {pkg}")
    } else{
      log_success(text = "CRAN activities have been detected for package {pkg}")
    }

  }
}


#' @importFrom stringr str_extract_all
#' @importFrom utils available.packages
#' @rdname checks
#' @export
check_packages_available <- function(path) {


  tex <- extract_tex(path)
  # List of CRAN and BIO pkgs used in the text
  pkgs_to_check <- lapply(X = c("\\\\CRANpkg\\{(.*?)\\}", "\\\\BIOpkg\\{(.*?)\\}"),
                          FUN = stringr::str_extract_all, string = tex)

  # Names of cran pkgs
  CRANpkgs <- unique(stringr::str_sub(unlist(pkgs_to_check[1]), start = 10, end = -2))

  # Run cran checks
  allCRANpkgs <- available.packages()[,1]

  allBIOpkgs <- available.packages(repos = "https://bioconductor.org/packages/3.11/bioc")[,1]

  BIOpkgs <- unique(stringr::str_sub(unlist(pkgs_to_check[2]), start = 9, end = -2))

  if (!all(CRANpkgs %in% allCRANpkgs)) {
    # When one is missing from CRAN
    missing <- CRANpkgs[!(CRANpkgs %in% allCRANpkgs)]
    amount_missing <- length(missing)
    amount_pkgs <- length(CRANpkgs)

    log_error(text = "{amount_missing} of {amount_pkgs} package(s) not available on CRAN: {paste(missing, collapse = ', ')}")

  } else if (!all(BIOpkgs %in% allBIOpkgs)) {
    # When one is missing from Bioconductor
    missing <- BIOpkgs[!(BIOpkgs %in% allBIOpkgs)]
    amount_missing <- length(missing)
    amount_pkgs <- length(BIOpkgs)

    log_error("{amount_missing} of {amount_pkgs} package(s) not available on Bioconductor: {paste(missing, collapse = ', ')}")

  } else {
    log_success("All CRAN & Bioconductor packages mentioned are available")

  }


  # Check that all packages with a \pkg reference also have a \CRANpkg or \BIOpkg mention

  # pkgs referred to in the text

  pkgs_used <- stringr::str_sub(
    unlist(
      stringr::str_extract_all(string = tex, "pkg\\{(.*?)\\}")),
    start = 5, end = -2)

  # Start with full list of pkgs
  declared_pkgs <- pkgs_used %in% c(CRANpkgs, BIOpkgs)

  if (any(!declared_pkgs)) {
    # Look for pkgs that were used in the text but did not have a CRANpkg{} commands
    pkgs_missing_ref <- unique(pkgs_used[!(declared_pkgs)])
    amount_missing <- length(pkgs_missing_ref)

    log_note("{amount_missing} package(s) used in the text without CRANpkg or BIOpkg commands: {paste(pkgs_missing_ref, collapse = ', ')}")
  }


}


#' @importFrom stringr str_match str_count
output_summary <- function(path, file = stdout()) {

  completed_checks <- readLines(file.path(path, "initial_checks.log"))

  results <- lapply(X = c("SUCCESS", "ERROR", "NOTE"),
                    FUN = stringr::str_count,
                    string = completed_checks)

  results_tally <- lapply(results, sum)

  results_text <- paste("\n",
                        "SUCCESSES:", results_tally[[1]],"|",
                        "ERRORS:", results_tally[[2]], "|",
                        "NOTES:", results_tally[[3]], sep = " ")

  cat(results_text, "\n",
      sep = " ", file = file, append = TRUE)

  cli::cli_h3(results_text)

}

##############################################
##############################################
# helper functions

remove_wrapper <- function(path){

  submission_files <- list.files(path)
  wrapper_files <- c("RJwrapper.tex", "RJwrapper.pdf")
  submission_files[!(submission_files %in% wrapper_files)]
}

extract_tex_vec <- function(path){
  remaining <- remove_wrapper(path)
  name <- remaining[tools::file_ext(remaining) == "tex"]

  if (length(name) == 0){
    stop("please specify the correct path that contains the .tex file")
  }

  readLines(file.path(path, name))
}

extract_tex <- function(path){

  vec <- extract_tex_vec(path)
  paste0(vec , collapse = " ")
}

spell_to_remove <- c("(\\\\url\\{(.*)\\})",
                     "(\\\\href\\{(.*)\\})",
                     "(\\\\label\\{(.*)\\})",
                     "(\\\\nameref\\{(.*)\\})",
                     "(\\\\code\\{(.*)\\})",
                     "(\\\\CRANpkg\\{(.*)\\})",
                     "(\\\\pkg\\{(.*)\\})",
                     '("(.*)")',
                     "(\\\\textt\\{(.*)\\})",
                     "(\\\\emph\\{(.*)\\})",
                     "(\\\\file\\{(.*)\\})",
                     "(\\\\includegraphics\\[(.*)\\})",
                     "(emph)"
)

##############################################
log_factory <- function(prefix, .f) {

  # Guarantee definitions exist in the factory environment
  force(.f)
  force(prefix)

  function(text, ..., file = stdout(), .envir = parent.frame()) {

    text <- glue::glue(prefix, text, ..., .envir = .envir)

    .f(text)

    # Send output to the log file
    cat(text, "\n", sep = "", file = file, append = TRUE)

  }
}

#' Produce a log file entry for an error
#'
#' Append a line in the log file that details an error
#'
#' @param text Description of the error that occurred
#' @param ... Additional inputs for text passed to the glue function
#' @param .envir The environment used to find the text string replacements
#' @param file The console output directed to the log, using `stdout`
#'
#'
log_error <- log_factory(prefix = "ERROR: ", .f = cli::cli_alert_warning)

#' Produce a log file entry for a success
#'
#' Append a line in the log file that details a success
#'
#' @param text Description of the error that occurred
#' @param ... Additional inputs for text passed to the glue function
#' @param .envir The environment used to find the text string replacements
#' @param file The console output directed to the log, using `stdout`
#'
#'
log_success <- log_factory(prefix = "SUCCESS: ", .f = cli::cli_alert_success)


#' Produce a log file entry for a note
#'
#' Append a line in the log file that details a note
#'
#' @param text Description of the error that occurred
#' @param ... Additional inputs for text passed to the glue function
#' @param .envir The environment used to find the text string replacements
#' @param file The console output directed to the log, using `stdout`
#'
#'
log_note <- log_factory(prefix = "NOTE: ", .f = cli::cli_alert_info)


################################################################################

#' Various handy symbols to use in a command line UI
#'
#' Show symbols in console output
#'
#'
#' @name symbol
#' @aliases symbol
#'
symbol_utf8 <- list(
  "tick" = '\u2714',
  "cross" = '\u2716',
  "pointer" = '\u276F',
  "line" = '\u2500'
)

symbol_rstudio <- symbol_utf8
symbol_rstudio$tick <- "\u2713"
symbol_rstudio$cross <- "x"
symbol_rstudio$pointer <- ">"

symbol_win <- list(
  "tick" = '\u221A',
  "cross" = 'x',
  "line" = '-'
)

symbol_ascii <- list(
  "tick" = 'v',
  "cross" = 'x',
  "star" = '*',
  "line" = '-'
)
