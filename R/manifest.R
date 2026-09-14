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
    timestamp = Sys.time()
  )
}

#' Gravar um manifesto versionado em disco
#'
#' `{dest}/_manifests/{run_id}.csv`, sem sobrescrever execucoes
#' anteriores (SPECS.md §2.2-13), mais um indice cumulativo em
#' `{dest}/_manifests/_index.csv`.
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

  invisible(run_path)
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
