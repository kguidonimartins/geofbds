#' @keywords internal
#' @importFrom rlang .data
"_PACKAGE"

## usethis namespace: start
## usethis namespace: end
NULL

utils::globalVariables("fbds_municipios")

.onLoad <- function(libname, pkgname) {
  op <- options()
  op.geofbds <- list(
    geofbds.base_url = "https://geo.fbds.org.br",
    geofbds.workers = 4L,
    geofbds.timeout = 300,
    geofbds.retries = 3L,
    geofbds.user_agent = sprintf(
      "geofbds/%s (+https://github.com/kguidonimartins/geofbds)",
      utils::packageVersion("geofbds")
    ),
    geofbds.progress = TRUE,
    geofbds.quiet = FALSE,
    geofbds.listing_ttl = 7,
    geofbds.confirm_bytes = 1e9
  )
  toset <- !(names(op.geofbds) %in% names(op))
  if (any(toset)) {
    options(op.geofbds[toset])
  }

  invisible()
}
