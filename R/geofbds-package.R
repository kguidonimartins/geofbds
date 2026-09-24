#' @keywords internal
#' @importFrom rlang .data
"_PACKAGE"

## usethis namespace: start
## usethis namespace: end
NULL

utils::globalVariables("fbds_municipios")

#' Ler o catalogo de municipios a partir de `data/`
#'
#' `fbds_municipios` mora em `data/`, que so entra no caminho de busca quando
#' o pacote e anexado por `library()`. Chamadas como `geofbds::fbds_resolve()`
#' carregam apenas a namespace: `data()` e a unica forma de trazer o objeto de
#' la, e e o que `.onLoad()` usa para prende-lo a namespace sob demanda.
#'
#' @return O tibble `fbds_municipios`.
#' @noRd
municipios_data <- function() {
  env <- new.env(parent = emptyenv())
  utils::data("fbds_municipios", package = "geofbds", envir = env)
  get("fbds_municipios", envir = env)
}

# nocov start
# Roda antes de o covr instrumentar a namespace, entao nunca e contado.
.onLoad <- function(libname, pkgname) {
  # Prende o catalogo a namespace (e nao a search path) para que ele exista
  # em `geofbds::` sem `library()`. Sob demanda: o banco lazy so e lido no
  # primeiro uso do catalogo.
  ns <- asNamespace(pkgname)
  delayedAssign(
    "fbds_municipios",
    municipios_data(),
    eval.env = ns,
    assign.env = ns
  )

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
# nocov end
