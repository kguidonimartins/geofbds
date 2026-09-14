#' Ler o progresso de uma execucao estadual anterior
#'
#' @param progress_path Caminho de `_progress.csv`.
#'
#' @return Um tibble com `geocode`, `uf`, `municipality`, `status`
#'   (`"complete"`/`"incomplete"`), `n_files`, `n_failed`,
#'   `last_run_id`, `timestamp`. Vazio se o arquivo nao existir.
#' @noRd
resume_state <- function(progress_path) {
  if (!file.exists(progress_path)) {
    return(tibble::tibble(
      geocode = character(0),
      uf = character(0),
      municipality = character(0),
      status = character(0),
      n_files = integer(0),
      n_failed = integer(0),
      last_run_id = character(0),
      timestamp = as.POSIXct(character(0))
    ))
  }

  vroom::vroom(
    progress_path,
    col_types = vroom::cols(
      geocode = "c",
      uf = "c",
      municipality = "c",
      status = "c",
      n_files = "i",
      n_failed = "i",
      last_run_id = "c",
      timestamp = "T"
    )
  )
}

#' Atualizar `_progress.csv` com o resultado de um bloco
#'
#' Um municipio e `"complete"` quando nenhum dos seus arquivos, no
#' manifesto do bloco, terminou com `status == "failed"`. Linhas de
#' municipios ja presentes no arquivo sao substituidas pelo resultado
#' mais recente.
#'
#' @noRd
update_progress_state <- function(progress_path, manifest, catalog) {
  summary <- manifest |>
    dplyr::group_by(.data$geocode) |>
    dplyr::summarise(
      n_files = dplyr::n(),
      n_failed = sum(.data$status == "failed"),
      last_run_id = dplyr::last(.data$run_id),
      timestamp = max(.data$timestamp),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      status = dplyr::if_else(.data$n_failed == 0L, "complete", "incomplete")
    )

  info <- catalog[
    match(summary$geocode, catalog$geocode),
    c("uf", "municipality")
  ]
  summary <- dplyr::bind_cols(summary, info) |>
    dplyr::select(
      "geocode",
      "uf",
      "municipality",
      "status",
      "n_files",
      "n_failed",
      "last_run_id",
      "timestamp"
    )

  existing <- resume_state(progress_path)
  updated <- dplyr::bind_rows(
    dplyr::filter(existing, !.data$geocode %in% summary$geocode),
    summary
  )

  dir.create(dirname(progress_path), recursive = TRUE, showWarnings = FALSE)
  vroom::vroom_write(updated, progress_path, delim = ",")

  invisible(updated)
}
