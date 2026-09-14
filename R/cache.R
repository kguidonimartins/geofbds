listing_cache_env <- new.env(parent = emptyenv())

#' Diretorio de cache do pacote
#'
#' Padrao [tools::R_user_dir()], sobreponivel via
#' `options(geofbds.cache_dir = ...)` ou [fbds_cache_set()]. Se o diretorio
#' ainda nao existe e a sessao e interativa, pede confirmacao antes de
#' criar (politica do CRAN); fora de sessao interativa, cria direto.
#'
#' @return O caminho do diretorio de cache (character).
#' @export
fbds_cache_dir <- function() {
  dir <- getOption("geofbds.cache_dir")
  if (is.null(dir)) {
    dir <- tools::R_user_dir("geofbds", "cache")
  }

  if (!dir.exists(dir)) {
    if (interactive()) {
      cli::cli_inform("geofbds ainda nao tem um diretorio de cache.")
      proceed <- isTRUE(utils::askYesNo(sprintf(
        "Criar %s para guardar listagens e downloads?",
        dir
      )))
      if (!proceed) {
        abort_fbds(
          "Diretorio de cache nao confirmado: {.path {dir}}",
          "fbds_cache_declined"
        )
      }
    }
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }

  dir
}

#' Definir o diretorio de cache do pacote
#'
#' @param path Caminho do diretorio a usar. Criado se nao existir.
#'
#' @return `path`, invisivelmente.
#' @export
fbds_cache_set <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  options(geofbds.cache_dir = path)
  invisible(path)
}

#' Inventario do cache do pacote
#'
#' @return Um tibble com `path`, `bytes` e `modified`, um por arquivo sob
#'   [fbds_cache_dir()].
#' @export
fbds_cache_status <- function() {
  dir <- fbds_cache_dir()
  files <- list.files(dir, recursive = TRUE, full.names = TRUE)

  if (length(files) == 0L) {
    return(tibble::tibble(
      path = character(0),
      bytes = double(0),
      modified = as.POSIXct(character(0))
    ))
  }

  info <- file.info(files)
  tibble::tibble(
    path = files,
    bytes = info$size,
    modified = info$mtime
  )
}

#' Limpar o cache do pacote
#'
#' @param what `"listings"` (padrao) remove so as listagens cacheadas;
#'   `"all"` remove todo o [fbds_cache_dir()], inclusive downloads.
#'
#' @return `NULL`, invisivelmente.
#' @export
fbds_cache_clean <- function(what = c("listings", "all")) {
  what <- match.arg(what)
  dir <- fbds_cache_dir()

  target <- if (identical(what, "listings")) {
    file.path(dir, "listings")
  } else {
    dir
  }

  rm(list = ls(listing_cache_env), envir = listing_cache_env)

  if (dir.exists(target)) {
    unlink(target, recursive = TRUE)
  }
  if (identical(what, "listings")) {
    dir.create(target, recursive = TRUE, showWarnings = FALSE)
  }

  cli::cli_inform("Cache limpo: {.path {target}}")
  invisible(NULL)
}

#' Obter a listagem de um municipio x camada, usando cache quando possivel
#'
#' Cache em duas camadas: ambiente de sessao (sempre consultado primeiro) e
#' disco, em `{cache}/listings/{uf}/{slug}/{layer}.rds` (sufixo
#' `_recursive` quando `recursive = TRUE`), valido por
#' `getOption("geofbds.listing_ttl")` dias.
#'
#' @noRd
get_listing_cached <- function(geocode, uf, slug, layer, recursive, cache) {
  key <- paste(geocode, layer, recursive, sep = "|")

  if (
    isTRUE(cache) && exists(key, envir = listing_cache_env, inherits = FALSE)
  ) {
    return(get(key, envir = listing_cache_env, inherits = FALSE))
  }

  disk_path <- NULL
  if (isTRUE(cache)) {
    filename <- paste0(
      layer,
      if (isTRUE(recursive)) "_recursive" else "",
      ".rds"
    )
    disk_path <- file.path(fbds_cache_dir(), "listings", uf, slug, filename)

    if (file.exists(disk_path)) {
      ttl_days <- getOption("geofbds.listing_ttl", 7)
      age_days <- as.numeric(
        difftime(Sys.time(), file.info(disk_path)$mtime, units = "days")
      )
      if (age_days <= ttl_days) {
        listing <- readRDS(disk_path)
        assign(key, listing, envir = listing_cache_env)
        return(listing)
      }
    }
  }

  url <- fbds_url(geocode, layer = layer)
  listing <- list_remote_dir(url, recursive = recursive)

  if (isTRUE(cache)) {
    assign(key, listing, envir = listing_cache_env)
    dir.create(dirname(disk_path), recursive = TRUE, showWarnings = FALSE)
    saveRDS(listing, disk_path)
  }

  listing
}
