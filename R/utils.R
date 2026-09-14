#' Normalize free text for matching against the catalog
#'
#' Strips diacritics, upper-cases and collapses internal whitespace so that
#' e.g. "  Sao  Paulo" and "São Paulo" compare equal. Diacritics are
#' translated with an explicit table rather than `iconv(..., "ASCII//
#' TRANSLIT")`: that transliteration is libiconv-dependent and on macOS
#' turns e.g. "ÃO" into "~AO" instead of "AO".
#'
#' @noRd
normalize_text <- function(x) {
  x <- toupper(trimws(x))
  x <- chartr(
    "\u00C1\u00C0\u00C2\u00C3\u00C4\u00C9\u00C8\u00CA\u00CB\u00CD\u00CC\u00CE\u00CF\u00D3\u00D2\u00D4\u00D5\u00D6\u00DA\u00D9\u00DB\u00DC\u00C7\u00D1",
    "AAAAAEEEEIIIIOOOOOUUUUCN",
    x
  )
  gsub("\\s+", " ", x)
}

#' Basename used to group shapefile components into a set
#'
#' Strips one extension, so "x.shp", "x.shx" and "x.dbf" all group under
#' "x". Reused by `fbds_coverage()` (Fase 3, approximate) and
#' `shapefile_sets()` (Fase 4, authoritative on a downloaded manifest).
#'
#' @noRd
shapefile_basename <- function(file) {
  tools::file_path_sans_ext(file)
}

#' Formatar bytes de forma legivel (ex. "1.2 GB")
#'
#' @noRd
format_bytes <- function(bytes) {
  if (is.na(bytes) || bytes <= 0) {
    return("0 B")
  }

  units <- c("B", "KB", "MB", "GB", "TB")
  exponent <- min(floor(log(bytes, 1024)), length(units) - 1L)
  value <- bytes / 1024^exponent
  sprintf("%.1f %s", value, units[exponent + 1L])
}

#' Interpolate `{name}` placeholders in a path pattern
#'
#' A minimal stand-in for `glue::glue()` restricted to named substitution
#' from `values`; no expression evaluation.
#'
#' @noRd
interp_path <- function(pattern, values) {
  for (name in names(values)) {
    pattern <- gsub(
      paste0("{", name, "}"),
      values[[name]],
      pattern,
      fixed = TRUE
    )
  }
  pattern
}
