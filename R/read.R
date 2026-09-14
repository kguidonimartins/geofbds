#' Deriva o "tipo" de um shapefile a partir do nome do arquivo
#'
#' Os arquivos seguem o padrao `{UF}_{GEOCODE}_{TIPO}.shp` (ex.
#' `RO_1100031_APP.shp`, `RO_1100031_MASSAS_DAGUA.shp`). O tipo e o que
#' resta apos remover esse prefixo — o que [fbds_read()] usa para
#' distinguir os varios conjuntos de uma camada (ex. `HIDROGRAFIA` tem
#' quatro).
#'
#' @noRd
shapefile_type <- function(file, uf, geocode) {
  base <- shapefile_basename(file)
  prefix <- paste0(uf, "_", geocode, "_")
  type <- base
  has_prefix <- startsWith(base, prefix)
  type[has_prefix] <- substring(
    base[has_prefix],
    nchar(prefix[has_prefix]) + 1L
  )
  type
}

#' Indice vazio, com os tipos de coluna corretos
#'
#' @noRd
empty_read_index <- function() {
  tibble::tibble(
    geocode = character(0),
    uf = character(0),
    layer = character(0),
    shp_file = character(0),
    shp_path = character(0),
    type = character(0),
    complete = logical(0)
  )
}

#' Resolver conjuntos de shapefile a partir de um manifesto
#'
#' @noRd
resolve_from_manifest <- function(manifest, layer) {
  ok <- manifest[
    manifest$layer == layer & manifest$status %in% c("downloaded", "cached"),
    ,
    drop = FALSE
  ]
  shp_rows <- ok[tolower(tools::file_ext(ok$file)) == "shp", , drop = FALSE]

  if (nrow(shp_rows) == 0L) {
    return(empty_read_index())
  }

  sets <- shapefile_sets(ok)
  shp_rows$set_id <- shapefile_basename(shp_rows$file)
  merged <- dplyr::left_join(
    shp_rows,
    dplyr::select(sets, "geocode", "layer", "set_id", "complete"),
    by = c("geocode", "layer", "set_id")
  )
  merged$complete[is.na(merged$complete)] <- FALSE

  tibble::tibble(
    geocode = merged$geocode,
    uf = merged$uf,
    layer = merged$layer,
    shp_file = merged$file,
    shp_path = merged$path,
    type = shapefile_type(merged$file, merged$uf, merged$geocode),
    complete = merged$complete
  )
}

#' Resolver conjuntos de shapefile a partir do layout padrao em disco
#'
#' Assume `{root}/{uf}/{geocode}/{layer}/*.shp`, o layout que
#' [fbds_plan()] usa por padrao. Um `path_pattern` customizado nao e
#' reconhecido aqui — nesse caso, leia a partir do manifesto.
#'
#' @noRd
resolve_from_disk <- function(root, layer, geocode_filter = NULL) {
  all_dirs <- list.dirs(root, recursive = TRUE, full.names = TRUE)
  layer_dirs <- all_dirs[basename(all_dirs) == layer]

  if (length(layer_dirs) == 0L) {
    return(empty_read_index())
  }

  rows <- lapply(layer_dirs, function(d) {
    geocode <- basename(dirname(d))
    uf <- basename(dirname(dirname(d)))

    if (!is.null(geocode_filter) && !(geocode %in% geocode_filter)) {
      return(NULL)
    }

    shp_files <- list.files(d, pattern = "\\.shp$")
    if (length(shp_files) == 0L) {
      return(NULL)
    }

    all_files <- list.files(d)
    required <- c(".shp", ".shx", ".dbf", ".prj")
    bases <- shapefile_basename(shp_files)

    tibble::tibble(
      geocode = geocode,
      uf = uf,
      layer = layer,
      shp_file = shp_files,
      shp_path = file.path(d, shp_files),
      type = shapefile_type(shp_files, uf, geocode),
      complete = vapply(
        bases,
        function(base) all(paste0(base, required) %in% all_files),
        logical(1)
      )
    )
  })

  dplyr::bind_rows(rows)
}

#' Resolver `x` em conjuntos de shapefile a ler
#'
#' @noRd
resolve_read_inputs <- function(x, layer) {
  if (is.data.frame(x)) {
    return(resolve_from_manifest(x, layer))
  }
  if (length(x) == 1L && dir.exists(x)) {
    return(resolve_from_disk(x, layer))
  }

  geocode <- fbds_resolve(x)
  resolve_from_disk(fbds_cache_dir(), layer, geocode_filter = geocode)
}

#' Ler dados espaciais de uma camada
#'
#' Aceita um manifesto (de [fbds_fetch()] e afins), geocodigos/nomes
#' resolviveis por [fbds_resolve()], ou um diretorio. Para geocodigos ou
#' diretorio, assume o layout padrao de [fbds_plan()]
#' (`{uf}/{geocode}/{layer}/arquivo`); um download com `path_pattern`
#' customizado so e localizavel passando o manifesto.
#'
#' Uma camada pode ter mais de um conjunto de shapefile (ex.
#' `HIDROGRAFIA` tem `MASSAS_DAGUA`, `NASCENTES`, `RIOS_DUPLOS` e
#' `RIOS_SIMPLES`) com geometrias distintas, que nao fazem sentido
#' empilhadas juntas — por isso `type` e obrigatorio sempre que houver
#' mais de um. Um conjunto de shapefile incompleto (falta `.shp`, `.shx`,
#' `.dbf` ou `.prj`) e ignorado com aviso, nunca lido.
#'
#' @param x Um manifesto, identificadores aceitos por [fbds_resolve()],
#'   ou um diretorio.
#' @param layer Uma camada de [fbds_layers()].
#' @param type Tipo do conjunto de shapefile (ex. `"APP"`,
#'   `"MASSAS_DAGUA"`). Obrigatorio quando a camada tem mais de um tipo
#'   disponivel entre os arquivos encontrados.
#' @param crs Sistema de referencia para o qual harmonizar (via
#'   [sf::st_transform()]) antes de empilhar os municipios. `NULL`
#'   (padrao) nao transforma — se os municipios tiverem CRS diferentes,
#'   o empilhamento falha com o erro do proprio sf.
#'
#' @return Um objeto `sf`, com uma linha por feicao e os municipios
#'   empilhados; inclui as colunas `geocode` e `uf`.
#' @export
#'
#' @examples
#' \dontrun{
#' m <- fbds_download_municipality("1100031", layers = "app")
#' fbds_read(m, layer = "app", type = "APP")
#' }
fbds_read <- function(x, layer, type = NULL, crs = NULL) {
  rlang::check_installed("sf")

  if (length(layer) != 1L) {
    abort_fbds("{.arg layer} deve ter um unico valor.", "fbds_bad_layer")
  }
  layers_tbl <- fbds_layers()
  if (!(layer %in% layers_tbl$layer)) {
    abort_fbds(
      c(
        "Camada desconhecida: {.val {layer}}",
        "i" = "Camadas validas: {.val {layers_tbl$layer}}."
      ),
      "fbds_bad_layer"
    )
  }

  index <- resolve_read_inputs(x, layer)
  if (nrow(index) == 0L) {
    abort_fbds(
      "Nenhum shapefile encontrado para a camada {.val {layer}}.",
      "fbds_empty_plan"
    )
  }

  available_types <- unique(index$type)
  if (is.null(type)) {
    if (length(available_types) > 1L) {
      abort_fbds(
        c(
          "Mais de um tipo de shapefile disponivel na camada {.val {layer}}: {.val {available_types}}.",
          "i" = "Informe o argumento {.arg type}."
        ),
        "fbds_ambiguous_type"
      )
    }
  } else {
    unknown_type <- setdiff(type, available_types)
    if (length(unknown_type) > 0L) {
      abort_fbds(
        c(
          "Tipo(s) nao encontrado(s) na camada {.val {layer}}: {.val {unknown_type}}",
          "i" = "Tipos disponiveis: {.val {available_types}}."
        ),
        "fbds_ambiguous_type"
      )
    }
    index <- index[index$type %in% type, , drop = FALSE]
  }

  incomplete <- index[!index$complete, , drop = FALSE]
  for (i in seq_len(nrow(incomplete))) {
    cli::cli_warn(
      "Conjunto de shapefile incompleto, ignorado: {.val {incomplete$shp_file[[i]]}} ({incomplete$geocode[[i]]}/{incomplete$layer[[i]]})",
      class = "fbds_incomplete_shapefile"
    )
  }
  index <- index[index$complete, , drop = FALSE]

  if (nrow(index) == 0L) {
    abort_fbds(
      "Nenhum conjunto de shapefile completo para ler.",
      "fbds_incomplete_shapefile"
    )
  }

  shapes <- lapply(seq_len(nrow(index)), function(i) {
    sf_obj <- sf::st_read(
      index$shp_path[[i]],
      options = "ENCODING=LATIN1",
      quiet = TRUE
    )
    sf_obj$geocode <- index$geocode[[i]]
    sf_obj$uf <- index$uf[[i]]
    if (!is.null(crs)) {
      sf_obj <- sf::st_transform(sf_obj, crs)
    }
    sf_obj
  })

  do.call(rbind, shapes)
}

#' Baixar e ler dados espaciais em um passo
#'
#' Invólucro de `fbds_download_municipality() |> fbds_read()`.
#'
#' @inheritParams fbds_read
#' @param ... Repassado a [fbds_download_municipality()] (ex.
#'   `dest_dir`, `recursive`, `workers`).
#'
#' @return Um objeto `sf`, como em [fbds_read()].
#' @export
#'
#' @examples
#' \dontrun{
#' fbds_get("1100031", layer = "app", type = "APP")
#' }
fbds_get <- function(x, layer, type = NULL, crs = NULL, ...) {
  rlang::check_installed("sf")

  manifest <- fbds_download_municipality(x, layers = layer, ...)
  fbds_read(manifest, layer = layer, type = type, crs = crs)
}
