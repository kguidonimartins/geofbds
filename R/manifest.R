#' Manifesto vazio, com os tipos de coluna corretos
#'
#' @noRd
empty_manifest <- function() {
  tibble::tibble(
    run_id = character(0),
    geocode = character(0),
    uf = character(0),
    municipality = character(0),
    layer = character(0),
    file = character(0),
    url = character(0),
    path = character(0),
    status = character(0),
    bytes = double(0),
    expected_bytes = double(0),
    sha256 = character(0),
    http_status = integer(0),
    attempts = integer(0),
    error = character(0),
    pkg_version = character(0),
    timestamp = as.POSIXct(character(0))
  )
}

#' Montar o manifesto de uma rodada de fetch
#'
#' @noRd
build_manifest <- function(
  run_id,
  plan,
  status,
  http_status,
  attempts,
  error,
  compute_hash
) {
  bytes <- rep(NA_real_, nrow(plan))
  sha256 <- rep(NA_character_, nrow(plan))

  has_file <- status %in%
    c("downloaded", "cached") &
    file.exists(plan$dest_path)
  bytes[has_file] <- file.size(plan$dest_path[has_file])

  if (isTRUE(compute_hash) && any(has_file)) {
    sha256[has_file] <- cli::hash_file_sha256(plan$dest_path[has_file])
  }

  mismatch <- has_file & !is.na(plan$bytes) & abs(bytes - plan$bytes) > 1024
  if (any(mismatch)) {
    cli::cli_warn(c(
      "{sum(mismatch)} arquivo(s) com tamanho diferente do esperado na listagem.",
      "i" = paste(
        "A listagem do portal so informa tamanho em KB; pequenas",
        "diferencas sao normais, mas confira os casos grandes."
      )
    ))
  }

  tibble::tibble(
    run_id = run_id,
    geocode = plan$geocode,
    uf = plan$uf,
    municipality = plan$municipality,
    layer = plan$layer,
    file = plan$file,
    url = plan$url,
    path = plan$dest_path,
    status = status,
    bytes = bytes,
    expected_bytes = plan$bytes,
    sha256 = sha256,
    http_status = http_status,
    attempts = attempts,
    error = error,
    pkg_version = rep(
      as.character(utils::packageVersion("geofbds")),
      nrow(plan)
    ),
    timestamp = Sys.time()
  )
}

#' Gravar um manifesto versionado em disco
#'
#' `{dest}/_manifests/{run_id}.csv`, sem sobrescrever execucoes
#' anteriores (SPECS.md §2.2-13), mais um indice cumulativo em
#' `{dest}/_manifests/_index.csv` e um resumo em `{dest}/manifest.json`.
#'
#' @noRd
write_manifest <- function(manifest, dest_dir) {
  manifests_dir <- file.path(dest_dir, "_manifests")
  dir.create(manifests_dir, recursive = TRUE, showWarnings = FALSE)

  run_id <- manifest$run_id[[1]]
  run_path <- file.path(manifests_dir, paste0(run_id, ".csv"))
  vroom::vroom_write(manifest, run_path, delim = ",")

  index_path <- file.path(manifests_dir, "_index.csv")
  index_row <- tibble::tibble(
    run_id = run_id,
    timestamp = manifest$timestamp[[1]],
    pkg_version = if ("pkg_version" %in% names(manifest)) {
      manifest$pkg_version[[1]]
    } else {
      NA_character_
    },
    n_files = nrow(manifest),
    n_downloaded = sum(manifest$status == "downloaded"),
    n_cached = sum(manifest$status == "cached"),
    n_failed = sum(manifest$status == "failed"),
    n_skipped = sum(manifest$status == "skipped"),
    bytes = sum(manifest$bytes, na.rm = TRUE),
    path = run_path
  )

  index <- if (file.exists(index_path)) {
    dplyr::bind_rows(
      vroom::vroom(index_path, show_col_types = FALSE),
      index_row
    )
  } else {
    index_row
  }
  vroom::vroom_write(index, index_path, delim = ",")

  write_manifest_summary(manifest_summary_from_index(index), dest_dir)

  invisible(run_path)
}

empty_manifest_status <- function() {
  tibble::tibble(
    last_updated = as.POSIXct(character(0)),
    pkg_version = character(0),
    n_files = integer(0),
    bytes_total = double(0),
    n_downloaded = integer(0),
    n_cached = integer(0),
    n_failed = integer(0),
    n_skipped = integer(0),
    run_ids = list()
  )
}

manifest_summary_from_index <- function(index) {
  if (nrow(index) == 0L) {
    return(empty_manifest_status())
  }

  timestamp <- index$timestamp
  if (!inherits(timestamp, "POSIXct")) {
    timestamp <- as.POSIXct(timestamp, tz = "UTC")
  }
  last_updated <- if (all(is.na(timestamp))) {
    as.POSIXct(NA, tz = "UTC")
  } else {
    max(timestamp, na.rm = TRUE)
  }

  pkg_version <- NA_character_
  if ("pkg_version" %in% names(index)) {
    versions <- as.character(index$pkg_version)
    versions <- versions[!is.na(versions) & nzchar(versions)]
    if (length(versions) > 0L) {
      pkg_version <- versions[[length(versions)]]
    }
  }

  tibble::tibble(
    last_updated = last_updated,
    pkg_version = pkg_version,
    n_files = as.integer(sum(index$n_files, na.rm = TRUE)),
    bytes_total = sum(index$bytes, na.rm = TRUE),
    n_downloaded = as.integer(sum(index$n_downloaded, na.rm = TRUE)),
    n_cached = as.integer(sum(index$n_cached, na.rm = TRUE)),
    n_failed = as.integer(sum(index$n_failed, na.rm = TRUE)),
    n_skipped = as.integer(sum(index$n_skipped, na.rm = TRUE)),
    run_ids = list(unique(as.character(index$run_id)))
  )
}

manifest_summary_json <- function(summary) {
  last_updated <- summary$last_updated[[1]]
  last_updated <- if (is.na(last_updated)) {
    NULL
  } else {
    format(last_updated, "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC")
  }

  pkg_version <- summary$pkg_version[[1]]
  pkg_version <- if (is.na(pkg_version)) NULL else pkg_version

  list(
    last_updated = last_updated,
    pkg_version = pkg_version,
    n_files = summary$n_files[[1]],
    bytes_total = summary$bytes_total[[1]],
    n_downloaded = summary$n_downloaded[[1]],
    n_cached = summary$n_cached[[1]],
    n_failed = summary$n_failed[[1]],
    n_skipped = summary$n_skipped[[1]],
    run_ids = I(summary$run_ids[[1]])
  )
}

write_manifest_summary <- function(summary, dest_dir) {
  if (nrow(summary) == 0L) {
    return(invisible(NULL))
  }

  jsonlite::write_json(
    manifest_summary_json(summary),
    file.path(dest_dir, "manifest.json"),
    auto_unbox = TRUE,
    pretty = TRUE,
    na = "null"
  )

  invisible(NULL)
}

read_manifest_summary_json <- function(path) {
  data <- jsonlite::read_json(path, simplifyVector = TRUE)

  last_updated <- data$last_updated
  if (is.null(last_updated) || length(last_updated) == 0L) {
    last_updated <- as.POSIXct(NA, tz = "UTC")
  } else {
    last_updated <- as.POSIXct(
      sub("Z$", "", last_updated),
      format = "%Y-%m-%dT%H:%M:%OS",
      tz = "UTC"
    )
  }

  pkg_version <- data$pkg_version
  if (is.null(pkg_version) || length(pkg_version) == 0L) {
    pkg_version <- NA_character_
  }

  run_ids <- data$run_ids
  if (is.null(run_ids)) {
    run_ids <- character(0)
  }

  tibble::tibble(
    last_updated = last_updated,
    pkg_version = as.character(pkg_version),
    n_files = as.integer(data$n_files),
    bytes_total = as.numeric(data$bytes_total),
    n_downloaded = as.integer(data$n_downloaded),
    n_cached = as.integer(data$n_cached),
    n_failed = as.integer(data$n_failed),
    n_skipped = as.integer(data$n_skipped),
    run_ids = list(as.character(run_ids))
  )
}

read_manifest_index <- function(path) {
  vroom::vroom(path, show_col_types = FALSE, altrep = FALSE)
}

#' Consultar o resumo do historico de downloads
#'
#' Le o resumo em `{dest_dir}/manifest.json`, gerado por [fbds_fetch()],
#' ou reconstroi o resultado a partir de `{dest_dir}/_manifests/_index.csv`
#' quando o destino foi criado por uma versao anterior do pacote.
#'
#' @param dest_dir Diretorio que contem os downloads. Padrao
#'   [fbds_cache_dir()].
#'
#' @return Um tibble de uma linha com `last_updated`, `pkg_version`,
#'   `n_files`, `bytes_total`, contagens por status (`n_downloaded`,
#'   `n_cached`, `n_failed`, `n_skipped`) e a lista de `run_ids`. Se ainda nao
#'   houver manifesto, devolve um tibble vazio com essas colunas.
#' @export
#'
#' @examples
#' \dontrun{
#' fbds_manifest_status()
#' fbds_manifest_status("/dados/fbds")
#' }
fbds_manifest_status <- function(dest_dir = fbds_cache_dir()) {
  json_path <- file.path(dest_dir, "manifest.json")
  index_path <- file.path(dest_dir, "_manifests", "_index.csv")

  if (file.exists(json_path)) {
    return(read_manifest_summary_json(json_path))
  }
  if (file.exists(index_path)) {
    return(manifest_summary_from_index(read_manifest_index(index_path)))
  }

  empty_manifest_status()
}

#' Agrupar os arquivos de um manifesto em conjuntos de shapefile
#'
#' @noRd
shapefile_sets <- function(manifest) {
  required_ext <- c("shp", "shx", "dbf", "prj")

  manifest |>
    dplyr::filter(.data$status %in% c("downloaded", "cached")) |>
    dplyr::mutate(
      ext = tolower(tools::file_ext(.data$file)),
      set_id = shapefile_basename(.data$file)
    ) |>
    dplyr::filter(.data$ext %in% required_ext) |>
    dplyr::group_by(.data$geocode, .data$layer, .data$set_id) |>
    dplyr::summarise(
      extensions = list(sort(unique(.data$ext))),
      complete = all(required_ext %in% .data$ext),
      .groups = "drop"
    )
}

#' Validar completude dos conjuntos de shapefile de um manifesto
#'
#' Agrupa os arquivos `.shp`/`.shx`/`.dbf`/`.prj` por nome-base e avisa
#' (classe `fbds_incomplete_shapefile`) para cada conjunto com algum
#' componente faltando.
#'
#' @param manifest Um manifesto de [fbds_fetch()] ou
#'   [fbds_download_municipality()].
#'
#' @return `manifest`, invisivelmente.
#' @export
#'
#' @examples
#' \dontrun{
#' m <- fbds_download_municipality("1100031", layers = "app")
#' fbds_validate(m)
#' }
fbds_validate <- function(manifest) {
  sets <- shapefile_sets(manifest)
  incomplete <- sets[!sets$complete, ]

  for (i in seq_len(nrow(incomplete))) {
    row <- incomplete[i, ]
    cli::cli_warn(
      c(
        "Conjunto de shapefile incompleto: {.val {row$set_id}} ({row$geocode}/{row$layer})",
        "i" = "Extensoes presentes: {.val {row$extensions[[1]]}}."
      ),
      class = "fbds_incomplete_shapefile"
    )
  }

  invisible(manifest)
}
