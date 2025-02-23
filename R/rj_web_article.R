#' R Markdown output formats for R Journal articles
#'
#' The R Journal is built upon the distill framework with some modifications.
#' This output format behaves almost identically to the
#' `distill::distill_article()` format, with some formatting and structural
#' changes.
#'
#' @param ... Arguments passed to `distill::distill_article()` for web articles,
#'   and `rticles::rjournal_article()` for pdf articles.
#' @inheritParams distill::distill_article
#' @export
rjournal_web_article <- function(toc = FALSE, self_contained = FALSE, ...) {
  args <- c()
  base_format <- distill::distill_article(
    self_contained = self_contained, toc = toc, ...
  )
  distill_post_knit <- base_format$post_knit

  rmd_path <- NULL
  render_pdf <- NULL

  base_format$post_knit <- function(metadata, input_file, runtime, ...) {
    # Modify YAML metadata for pre-processor
    render_env <- rlang::caller_env(n = 2)
    metadata <- replace_names(metadata, c("abstract" = "description"))
    metadata$title <- strip_macros(metadata$title)
    metadata$description <- strip_macros(metadata$description)
    for(i in seq_along(metadata$author)) {
      metadata$author[[i]] <- replace_names(metadata$author[[i]], c("orcid" = "orcid_id"))
    }

    metadata$journal <- list(
      title = metadata$journal$title %||% "The R Journal",
      issn = metadata$journal$issn %||% "2073-4859",
      firstpage = metadata$journal$firstpage %||% metadata$pages[1],
      lastpage = metadata$journal$lastpage %||% metadata$pages[2]
    )
    metadata$slug <- metadata$slug %||% xfun::sans_ext(basename(input_file))
    metadata$pdf_url <- xfun::with_ext(metadata$slug, "pdf")
    metadata$citation_url <- paste0("https://doi.org/10.32614/", metadata$slug)
    metadata$doi <- paste0("10.32614/", metadata$slug)
    metadata$creative_commons <- metadata$creative_commons %||% "CC BY"
    if(is.null(metadata$packages)) {
      input <- xfun::read_utf8(input_file)
      pkgs <- gregexpr("\\\\(CRAN|BIO)pkg\\{.+?\\}", input)
      pkgs <- mapply(
        function(pos, line) {
          if(pos[1] == -1) return(NULL)
          substr(rep_len(line, length(pos)), pos, pos + pos%@%"match.length" - 1)
        },
        pkgs, input,
        SIMPLIFY = FALSE
      )
      pkgs <- unique(do.call(c, pkgs))
      pkg_is_cran <- grepl("^\\\\CRAN", pkgs)
      pkgs <- sub("\\\\(CRAN|BIO)pkg\\{(.+?)\\}$", "\\2", pkgs)
      message(paste0(
        "Detected the following packages from article:\n  ",
        "CRAN: ", paste0(pkgs[pkg_is_cran], collapse = ", "), "\n  ",
        "Bioconductor: ", paste0(pkgs[!pkg_is_cran], collapse = ", ")
      ))
      metadata$packages <- list(
        cran = pkgs[pkg_is_cran],
        bioc = pkgs[!pkg_is_cran]
      )
    }
    if(is.null(metadata$CTV)) {
      ctvs <- readRDS(
        gzcon(url("https://cran.r-project.org/src/contrib/Views.rds", open = "rb"))
      )
      ctvs <- Filter(
        function(taskview) {
          any(metadata$packages$cran %in% taskview$packagelist$name)
        },
        ctvs
      )
      metadata$CTV <- vapply(ctvs, function(x) x[["name"]], character(1L))
    }

    metadata$csl <- metadata$csl %||% system.file("rjournal.csl", package = "rjtools", mustWork = TRUE)

    metadata$output <- replace_names(metadata$output, c("rjtools::rjournal_web_article" = "distill::distill_article"))

    rlang::env_poke(
      render_env, nm = "front_matter", value = metadata,
      inherit = TRUE, create = TRUE
    )

    # save Rmd path for later use
    rmd_path <<- normalizePath(input_file)
    render_pdf <<- !is.null(metadata$author)

    # Pass updated metadata to distill's post_knit()
    distill_post_knit(metadata, input_file, runtime, ...)
  }

  pre_processor <- function(metadata, input_file, runtime, knit_meta, files_dir,
                            output_dir) {

    # Add custom appendix
    data <- list()
    if (!is.null(metadata$supplementary_materials)) {
      data <- c(data, list(supp = metadata$supplementary_materials))
    }
    if (!is.null(metadata$CTV)) {
      CTV <- sprintf("[%s](https://cran.r-project.org/view=%s)", metadata$CTV, metadata$CTV)
      CTV <- paste(CTV, collapse = ", ")
      data <- c(data, list(CTV = CTV))
    }
    if (!is.null(metadata$packages)) {
      if (length(metadata$packages$cran) != 0) {
        CRAN <- sprintf("[%s](https://cran.r-project.org/package=%s)", metadata$packages$cran, metadata$packages$cran)
        CRAN <- paste(CRAN, collapse = ", ")
        data <- c(data, list(CRAN = CRAN))
      }
      if (length(metadata$packages$bioc) != 0) {
        BIOC <- sprintf("[%s](https://www.bioconductor.org/packages/%s)", metadata$packages$bioc, metadata$packages$bioc)
        BIOC <- paste(BIOC, collapse = ", ")
        data <- c(data, list(BIOC = BIOC))
      }
    }

    template <- xfun::read_utf8(system.file("appendix.md", package = "rjtools"))
    appendix <- whisker::whisker.render(template, data)

    input <- xfun::read_utf8(input_file)
    front_matter_delimiters <- grep("^(---|\\.\\.\\.)\\s*$", input)

    xfun::write_utf8(
      c("---", yaml::as.yaml(metadata), "---",
        input[(front_matter_delimiters[2]+1):length(input)], "", appendix),
      input_file
    )
    # Custom args
    args <- rmarkdown::pandoc_include_args(in_header = system.file("rjdistill.html", package = "rjtools"))

    args
  }

  on_exit <- function() {
    # TODO: This should be done in a temp directory
    # and files produced moved back into the main dir.

    # Deactivate for now as I am not sure to understand what should be built
    if (!is.null(render_pdf)) {
      callr::r(function(input){
        rmarkdown::render(
          input,
          # output_format = "rticles::rjournal_article",
          output_format = "rjtools::rjournal_pdf_article"
        )
      }, args = list(input = rmd_path))
    }
  }

  rmarkdown::output_format(
    knitr = NULL, # use base one
    pandoc = list(
      args = args,
      lua_filters = system.file("latex-pkg.lua", package = "rjtools")
    ),
    keep_md = NULL, # use base one
    clean_supporting = NULL, # use base one
    pre_knit = NULL,
    # post_knit = post_knit, # passed directly to base_format
    pre_processor = pre_processor,
    on_exit = on_exit,
    base_format = base_format
  )
}
