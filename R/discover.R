#' Parsear uma pagina de listagem h5ai
#'
#' O h5ai do portal renderiza, no `<noscript>`/`<div id="fallback">`, uma
#' tabela com nome, data de modificacao e tamanho ja no HTML (sem precisar
#' de JavaScript nem do endpoint `?action=get`). Cada linha traz um icone
#' cujo `alt` classifica a entrada: `"file"`, `"folder"` ou
#' `"folder-parent"` (a linha "Parent Directory", sempre descartada).
#'
#' @param html Texto HTML da pagina de listagem.
#' @param base_url URL da propria pagina, para resolver hrefs absolutos
#'   (`/UF/MUNICIPIO/CAMADA/arquivo`) em URLs completas.
#'
#' @return Um tibble com `file`, `url`, `bytes`, `modified`, `is_dir`.
#' @noRd
parse_h5ai_listing <- function(html, base_url) {
  page <- xml2::read_html(html)
  rows <- rvest::html_elements(page, "#fallback table tr")
  rows <- rows[
    vapply(
      rows,
      function(r) length(rvest::html_elements(r, "td.fb-n a")) > 0L,
      logical(1)
    )
  ]

  empty <- tibble::tibble(
    file = character(0),
    url = character(0),
    bytes = double(0),
    modified = as.POSIXct(character(0)),
    is_dir = logical(0)
  )
  if (length(rows) == 0L) {
    return(empty)
  }

  link <- lapply(rows, rvest::html_element, css = "td.fb-n a")
  href <- vapply(link, rvest::html_attr, character(1), name = "href")
  name <- vapply(link, rvest::html_text2, character(1))

  icon <- lapply(rows, rvest::html_element, css = "td.fb-i img")
  icon_alt <- vapply(icon, rvest::html_attr, character(1), name = "alt")

  size_txt <- vapply(
    rows,
    function(r) rvest::html_text2(rvest::html_element(r, "td.fb-s")),
    character(1)
  )
  modified_txt <- vapply(
    rows,
    function(r) rvest::html_text2(rvest::html_element(r, "td.fb-d")),
    character(1)
  )

  keep <- href != ".." &
    !is.na(icon_alt) &
    icon_alt != "folder-parent" &
    !(name %in% c("Thumbs.db"))

  if (!any(keep)) {
    return(empty)
  }

  tibble::tibble(
    file = name[keep],
    url = xml2::url_absolute(href[keep], base_url),
    bytes = parse_h5ai_size(size_txt[keep]),
    modified = parse_h5ai_modified(modified_txt[keep]),
    is_dir = icon_alt[keep] == "folder"
  )
}

parse_h5ai_size <- function(x) {
  vapply(x, parse_h5ai_size_one, numeric(1), USE.NAMES = FALSE)
}

parse_h5ai_size_one <- function(x) {
  x <- trimws(x)
  if (identical(x, "") || is.na(x)) {
    return(NA_real_)
  }

  number_txt <- regmatches(x, regexpr("^[0-9]+([.,][0-9]+)?", x))
  if (length(number_txt) == 0L || identical(number_txt, "")) {
    return(NA_real_)
  }

  number <- as.numeric(sub(",", ".", number_txt, fixed = TRUE))
  unit <- toupper(trimws(sub("^[0-9.,]+", "", x)))

  multiplier <- switch(
    unit,
    B = 1,
    KB = 1024,
    MB = 1024^2,
    GB = 1024^3,
    TB = 1024^4,
    NA_real_
  )

  number * multiplier
}

parse_h5ai_modified <- function(x) {
  x <- trimws(x)
  x[x == ""] <- NA_character_
  as.POSIXct(x, format = "%Y-%m-%d %H:%M", tz = "UTC")
}

#' Listar recursivamente um diretorio remoto do portal
#'
#' Com `recursive = FALSE`, subdiretorios encontrados geram um aviso `cli`
#' informando o que foi ignorado, em vez de desaparecer em silencio
#' (SPECS.md §2.2-7). Com `recursive = TRUE`, sao percorridos.
#'
#' @param url URL do diretorio a listar.
#' @param recursive Se `TRUE`, desce em subdiretorios.
#' @param rel_path Caminho relativo ao diretorio original (uso interno,
#'   preenchido nas chamadas recursivas).
#'
#' @return Um tibble com `path` (subdiretorio relativo, `""` no nivel
#'   raiz), `file`, `url`, `bytes`, `modified`.
#' @noRd
list_remote_dir <- function(url, recursive = FALSE, rel_path = "") {
  resp <- fbds_request(url)
  html <- rawToChar(resp$content)
  listing <- parse_h5ai_listing(html, resp$url)
  listing$path <- rel_path

  dirs <- listing[listing$is_dir, , drop = FALSE]
  files <- listing[!listing$is_dir, , drop = FALSE]
  files$is_dir <- NULL

  if (nrow(dirs) > 0L) {
    if (isTRUE(recursive)) {
      nested <- lapply(seq_len(nrow(dirs)), function(i) {
        child_rel <- if (nzchar(rel_path)) {
          paste(rel_path, dirs$file[[i]], sep = "/")
        } else {
          dirs$file[[i]]
        }
        list_remote_dir(dirs$url[[i]], recursive = TRUE, rel_path = child_rel)
      })
      files <- dplyr::bind_rows(files, dplyr::bind_rows(nested))
    } else {
      cli::cli_warn(c(
        "{nrow(dirs)} subdiretorio(s) ignorado(s) em {.url {url}}: {.val {dirs$file}}",
        "i" = "Use {.code recursive = TRUE} para incluir o conteudo."
      ))
    }
  }

  files
}

#' Listar arquivos disponiveis para municipios x camadas
#'
#' @param x Identificadores aceitos por [fbds_resolve()].
#' @param layers Camadas de [fbds_layers()]. `NULL` (padrao) usa todas.
#' @param recursive Se `TRUE`, desce em subdiretorios (ex. `USO/MAPAS`).
#' @param cache Se `TRUE` (padrao), usa e alimenta o cache de listagens
#'   (sessao + disco, ver [fbds_cache_dir()]).
#'
#' @return Um tibble com `geocode`, `uf`, `municipality`, `layer`, `path`,
#'   `file`, `ext`, `bytes`, `modified`, `url` — uma linha por arquivo.
#' @export
#'
#' @examples
#' \dontrun{
#' fbds_files("1100031", layers = "app")
#' }
fbds_files <- function(x, layers = NULL, recursive = FALSE, cache = TRUE) {
  geocode <- fbds_resolve(x)
  layers_tbl <- fbds_layers()

  if (is.null(layers)) {
    layers <- layers_tbl$layer
  }
  unknown_layer <- setdiff(layers, layers_tbl$layer)
  if (length(unknown_layer) > 0L) {
    abort_fbds(
      c(
        "Camada desconhecida: {.val {unknown_layer}}",
        "i" = "Camadas validas: {.val {layers_tbl$layer}}."
      ),
      "fbds_bad_layer"
    )
  }

  info <- fbds_municipios[
    match(geocode, fbds_municipios$geocode),
    c("geocode", "municipality", "uf", "slug")
  ]
  grid <- tidyr::expand_grid(info, layer = layers)

  empty <- tibble::tibble(
    geocode = character(0),
    uf = character(0),
    municipality = character(0),
    layer = character(0),
    path = character(0),
    file = character(0),
    ext = character(0),
    bytes = double(0),
    modified = as.POSIXct(character(0)),
    url = character(0)
  )

  results <- lapply(seq_len(nrow(grid)), function(i) {
    row <- grid[i, ]
    listing <- tryCatch(
      get_listing_cached(
        geocode = row$geocode,
        uf = row$uf,
        slug = row$slug,
        layer = row$layer,
        recursive = recursive,
        cache = cache
      ),
      fbds_http_error = function(e) {
        cli::cli_warn(c(
          "Nao foi possivel consultar {row$municipality}/{row$uf} ({row$layer}): {conditionMessage(e)}",
          "i" = "Continuando com os demais municipios/camadas."
        ))
        NULL
      }
    )
    if (is.null(listing) || nrow(listing) == 0L) {
      return(NULL)
    }
    dplyr::mutate(
      listing,
      geocode = row$geocode,
      uf = row$uf,
      municipality = row$municipality,
      layer = row$layer,
      .before = 1
    )
  })

  out <- dplyr::bind_rows(results)
  if (nrow(out) == 0L) {
    return(empty)
  }

  out |>
    dplyr::mutate(ext = tolower(tools::file_ext(.data$file))) |>
    dplyr::select(
      "geocode",
      "uf",
      "municipality",
      "layer",
      "path",
      "file",
      "ext",
      "bytes",
      "modified",
      "url"
    )
}

#' Estimar cobertura de dados por municipio x camada
#'
#' Verificacao aproximada, a partir da listagem remota: `has_shapefile` e
#' `complete` agrupam arquivos pelo nome-base (um municipio pode ter mais
#' de um conjunto de shapefile por camada, ex. `HIDROGRAFIA` tem quatro).
#' A verificacao autoritativa, sobre arquivos ja baixados, e
#' `fbds_validate()` (Fase 4).
#'
#' @param uf UF(s) a cobrir. `NULL` (padrao) usa todo o catalogo — caro,
#'   uma requisicao por municipio x camada.
#' @param layers Camadas de [fbds_layers()]. `NULL` (padrao) usa todas.
#'
#' @return Um tibble com uma linha por municipio x camada: `geocode`,
#'   `uf`, `municipality`, `layer`, `n_files`, `bytes`, `has_shapefile`,
#'   `complete`.
#' @export
#'
#' @examples
#' \dontrun{
#' fbds_coverage("RO")
#' }
fbds_coverage <- function(uf = NULL, layers = NULL) {
  catalog <- if (is.null(uf)) fbds_municipios else fbds_catalog(uf = uf)
  layers_tbl <- fbds_layers()
  layer_set <- if (is.null(layers)) layers_tbl$layer else layers

  files <- fbds_files(catalog$geocode, layers = layer_set, recursive = FALSE)

  required_ext <- c("shp", "shx", "dbf", "prj")
  set_summary <- files |>
    dplyr::mutate(set_id = shapefile_basename(.data$file)) |>
    dplyr::group_by(.data$geocode, .data$layer, .data$set_id) |>
    dplyr::summarise(
      set_complete = all(required_ext %in% .data$ext),
      .groups = "drop"
    )

  by_geocode_layer <- files |>
    dplyr::group_by(.data$geocode, .data$layer) |>
    dplyr::summarise(
      n_files = dplyr::n(),
      bytes = sum(.data$bytes, na.rm = TRUE),
      has_shapefile = any(.data$ext == "shp"),
      .groups = "drop"
    ) |>
    dplyr::left_join(
      dplyr::summarise(
        dplyr::group_by(set_summary, .data$geocode, .data$layer),
        complete = any(.data$set_complete),
        .groups = "drop"
      ),
      by = c("geocode", "layer")
    )

  base <- tidyr::expand_grid(
    catalog[c("geocode", "uf", "municipality")],
    layer = layer_set
  )

  base |>
    dplyr::left_join(by_geocode_layer, by = c("geocode", "layer")) |>
    dplyr::mutate(
      n_files = dplyr::coalesce(.data$n_files, 0L),
      bytes = dplyr::coalesce(.data$bytes, 0),
      has_shapefile = dplyr::coalesce(.data$has_shapefile, FALSE),
      complete = dplyr::coalesce(.data$complete, FALSE)
    )
}
