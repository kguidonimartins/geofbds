#' Consultar o catalogo de municipios
#'
#' Filtra [fbds_municipios] por UF, nome (busca parcial, sem acento e sem
#' distincao de caixa) e/ou geocodigo exato. Todos os filtros informados sao
#' combinados com E. Para resolver identificadores do usuario em geocodigos
#' canonicos, use [fbds_resolve()].
#'
#' @param uf Sigla(s) de UF, ex. `"RO"`.
#' @param name Trecho do nome do municipio a buscar.
#' @param geocode Geocodigo(s) exatos, numericos ou texto.
#'
#' @return Um tibble com as linhas de [fbds_municipios] que casam os filtros.
#' @export
#'
#' @examples
#' fbds_catalog(uf = "RO")
#' fbds_catalog(name = "cabixi")
fbds_catalog <- function(uf = NULL, name = NULL, geocode = NULL) {
  out <- fbds_municipios

  if (!is.null(uf)) {
    uf_norm <- toupper(trimws(uf))
    out <- out[out$uf %in% uf_norm, , drop = FALSE]
  }

  if (!is.null(name)) {
    name_norm <- normalize_text(name)
    out <- out[
      grepl(name_norm, normalize_text(out$municipality), fixed = TRUE),
      ,
      drop = FALSE
    ]
  }

  if (!is.null(geocode)) {
    geocode_chr <- as.character(geocode)
    out <- out[out$geocode %in% geocode_chr, , drop = FALSE]
  }

  tibble::as_tibble(out)
}

#' Resolver identificadores de municipio em geocodigos canonicos
#'
#' Ponto de entrada universal do pacote: aceita geocodigo (numerico ou
#' texto), sigla de UF (expande para todos os municipios), nome de municipio
#' (sem acento, caixa indiferente) e a forma `"Municipio/UF"`. Ambiguidade
#' (o mesmo nome em mais de uma UF) nunca e resolvida em silencio: gera um
#' erro classificado (`fbds_ambiguous_municipality`) listando os candidatos.
#'
#' @param x Vetor de geocodigos, nomes, UFs ou `"Municipio/UF"`.
#' @param uf UF usada para desambiguar um nome de municipio informado sem
#'   UF. Ignorada para entradas que ja trazem geocodigo, UF ou
#'   `"Municipio/UF"`.
#' @param strict Se `TRUE` (padrao), um identificador que nao resolve a
#'   nenhum municipio interrompe a execucao com
#'   `fbds_unknown_municipality`. Se `FALSE`, o identificador e ignorado com
#'   um aviso.
#'
#' @return Vetor de geocodigos (texto, 7 digitos), sem duplicatas, na ordem
#'   de primeira ocorrencia.
#' @export
#'
#' @examples
#' fbds_resolve("1100031")
#' fbds_resolve("cabixi")
#' fbds_resolve("Cabixi/RO")
#' fbds_resolve("RO")
fbds_resolve <- function(x, uf = NULL, strict = TRUE) {
  x_chr <- as.character(x)

  if (length(x_chr) == 0L) {
    abort_fbds(
      "Informe ao menos um geocodigo, nome de municipio ou UF.",
      "fbds_bad_geocode"
    )
  }

  resolved <- lapply(
    x_chr,
    resolve_token,
    uf = uf,
    catalog = fbds_municipios,
    strict = strict
  )

  unique(unlist(resolved, use.names = FALSE))
}

resolve_token <- function(token, uf, catalog, strict) {
  token_trim <- trimws(token)

  if (grepl("^[0-9]+$", token_trim)) {
    return(resolve_geocode(token_trim, catalog))
  }

  if (grepl("/", token_trim, fixed = TRUE)) {
    parts <- strsplit(token_trim, "/", fixed = TRUE)[[1]]
    if (length(parts) != 2L || any(trimws(parts) == "")) {
      abort_fbds(
        c(
          "Formato invalido para municipio/UF: {.val {token}}",
          "i" = "Use o formato {.val Municipio/UF}."
        ),
        "fbds_bad_geocode",
        input = token
      )
    }
    return(resolve_name(
      parts[[1]],
      uf = parts[[2]],
      catalog = catalog,
      strict = strict,
      original = token
    ))
  }

  token_upper <- toupper(token_trim)
  if (nchar(token_upper) == 2L && token_upper %in% catalog$uf) {
    return(catalog$geocode[catalog$uf == token_upper])
  }

  resolve_name(
    token_trim,
    uf = uf,
    catalog = catalog,
    strict = strict,
    original = token
  )
}

resolve_geocode <- function(code, catalog) {
  if (nchar(code) != 7L) {
    abort_fbds(
      c(
        "Geocodigo invalido: {.val {code}}",
        "i" = "Um geocodigo do IBGE tem exatamente 7 digitos."
      ),
      "fbds_bad_geocode",
      input = code
    )
  }

  if (!(code %in% catalog$geocode)) {
    abort_fbds(
      "Geocodigo nao encontrado no catalogo da FBDS: {.val {code}}",
      "fbds_unknown_municipality",
      input = code
    )
  }

  code
}

resolve_name <- function(name, uf, catalog, strict, original) {
  name_norm <- normalize_text(name)

  candidates <- catalog
  if (!is.null(uf)) {
    uf_norm <- toupper(trimws(uf))
    candidates <- candidates[candidates$uf == uf_norm, , drop = FALSE]
  }

  matches <- candidates[
    normalize_text(candidates$municipality) == name_norm,
    ,
    drop = FALSE
  ]

  if (nrow(matches) == 1L) {
    return(matches$geocode)
  }

  if (nrow(matches) > 1L) {
    abort_fbds(
      c(
        "Nome de municipio ambiguo: {.val {name}}",
        "i" = "Encontrado em mais de uma UF: {.val {matches$uf}}.",
        "i" = paste(
          "Use o formato {.val Municipio/UF} ou informe o argumento",
          "{.arg uf}."
        )
      ),
      "fbds_ambiguous_municipality",
      input = name,
      candidates = matches
    )
  }

  if (isTRUE(strict)) {
    abort_fbds(
      "Municipio nao encontrado no catalogo da FBDS: {.val {original}}",
      "fbds_unknown_municipality",
      input = original
    )
  }

  cli::cli_warn(c(
    "Municipio nao encontrado no catalogo da FBDS: {.val {original}}",
    "i" = "Ignorado porque {.arg strict} = FALSE."
  ))
  character(0)
}

#' Camadas de dados disponiveis no portal
#'
#' @return Um tibble com uma linha por camada: `layer` (identificador curto
#'   usado nas funcoes do pacote), `dir` (nome do diretorio no portal) e
#'   `description`.
#' @export
#'
#' @examples
#' fbds_layers()
fbds_layers <- function() {
  tibble::tribble(
    ~layer        , ~dir          , ~description                      ,
    "app"         , "APP"         , "Areas de Preservacao Permanente" ,
    "hidrografia" , "HIDROGRAFIA" , "Massas d'agua, nascentes e rios" ,
    "uso"         , "USO"         , "Uso e cobertura do solo"
  )
}

#' Montar URLs do portal para um municipio
#'
#' @param geocode Um ou mais identificadores aceitos por [fbds_resolve()].
#' @param layer Uma ou mais camadas de [fbds_layers()]. `NULL` (padrao) usa
#'   todas.
#'
#' @return Vetor de URLs, uma por combinacao de municipio x camada.
#' @export
#'
#' @examples
#' fbds_url("1100031", layer = "app")
fbds_url <- function(geocode, layer = NULL) {
  geocode <- fbds_resolve(geocode)
  layers_tbl <- fbds_layers()

  if (is.null(layer)) {
    layer <- layers_tbl$layer
  }

  unknown_layer <- setdiff(layer, layers_tbl$layer)
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
    c("uf", "slug")
  ]

  grid <- tidyr::expand_grid(info, layer = layer)
  dirs <- layers_tbl$dir[match(grid$layer, layers_tbl$layer)]

  mapply(
    function(uf, slug, dir) {
      paste(
        getOption("geofbds.base_url"),
        utils::URLencode(uf),
        utils::URLencode(slug),
        utils::URLencode(dir),
        sep = "/"
      )
    },
    grid$uf,
    grid$slug,
    dirs,
    USE.NAMES = FALSE
  )
}

#' Listar as 27 UFs com contagem de municipios
#'
#' @return Um tibble com `uf` e `n_municipios`.
#' @export
#'
#' @examples
#' fbds_ufs()
fbds_ufs <- function() {
  dplyr::arrange(
    dplyr::count(fbds_municipios, .data$uf, name = "n_municipios"),
    .data$uf
  )
}
