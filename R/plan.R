#' Planejar um download
#'
#' Separa planejar de executar: `fbds_plan()` so consulta a listagem
#' remota (via [fbds_files()], cacheada) e decide os destinos locais;
#' [fbds_fetch()] e quem baixa. Isso da `dry_run` de verdade e permite
#' inspecionar o volume antes de aceitar um download grande.
#'
#' @param x Identificadores aceitos por [fbds_resolve()].
#' @param layers Camadas de [fbds_layers()]. `NULL` (padrao) usa todas.
#' @param dest_dir Diretorio de destino. Padrao [fbds_cache_dir()].
#' @param recursive Se `TRUE`, inclui subdiretorios (ex. `USO/MAPAS`).
#' @param skip_existing Se `TRUE` (padrao), um arquivo ja presente em
#'   `dest_dir` com tamanho a ate 1 KB do esperado e marcado para pular
#'   (sem nova requisicao). A listagem do portal so informa tamanho em
#'   KB, daí a tolerancia; a palavra final sobre integridade e de
#'   [fbds_fetch()], que confere o arquivo de verdade apos a transferencia.
#' @param path_pattern Padrao do caminho local, com placeholders `{uf}`,
#'   `{geocode}`, `{layer}`, `{file}`. Quando um arquivo vem de um
#'   subdiretorio remoto (`recursive = TRUE`), `{file}` ja inclui esse
#'   subdiretorio como prefixo.
#'
#' @return Um objeto `<fbds_plan>` (tibble + metadados), com `print()`
#'   mostrando municipios, arquivos e volume estimado.
#' @export
#'
#' @examples
#' \dontrun{
#' fbds_plan("1100031", layers = "app")
#' }
fbds_plan <- function(
  x,
  layers = NULL,
  dest_dir = fbds_cache_dir(),
  recursive = FALSE,
  skip_existing = TRUE,
  path_pattern = "{uf}/{geocode}/{layer}/{file}"
) {
  files <- fbds_files(x, layers = layers, recursive = recursive, cache = TRUE)

  file_component <- files$file
  has_subdir <- nzchar(files$path)
  file_component[has_subdir] <- file.path(
    files$path[has_subdir],
    files$file[has_subdir]
  )

  dest_path <- vapply(
    seq_len(nrow(files)),
    function(i) {
      file.path(
        dest_dir,
        interp_path(
          path_pattern,
          list(
            uf = files$uf[[i]],
            geocode = files$geocode[[i]],
            layer = files$layer[[i]],
            file = file_component[[i]]
          )
        )
      )
    },
    character(1)
  )

  action <- rep("download", nrow(files))
  if (isTRUE(skip_existing) && nrow(files) > 0L) {
    exists <- file.exists(dest_path)
    actual_size <- rep(NA_real_, length(dest_path))
    actual_size[exists] <- file.size(dest_path[exists])
    close_enough <- exists &
      !is.na(files$bytes) &
      !is.na(actual_size) &
      abs(actual_size - files$bytes) <= 1024
    action[close_enough] <- "skip"
  }

  plan <- dplyr::mutate(files, dest_path = dest_path, action = action)

  structure(
    plan,
    class = c("fbds_plan", class(plan)),
    dest_dir = dest_dir,
    path_pattern = path_pattern,
    recursive = recursive,
    created_at = Sys.time()
  )
}

#' @export
format.fbds_plan <- function(x, ...) {
  n_files <- nrow(x)
  n_municipios <- length(unique(x$geocode))
  total_bytes <- sum(x$bytes, na.rm = TRUE)
  n_skip <- sum(x$action == "skip")
  n_download <- sum(x$action == "download")

  c(
    sprintf(
      "<fbds_plan> %d municipio(s), %d arquivo(s), %s",
      n_municipios,
      n_files,
      format_bytes(total_bytes)
    ),
    sprintf("  %d para baixar, %d ja presente(s) (skip)", n_download, n_skip),
    sprintf("  destino: %s", attr(x, "dest_dir"))
  )
}

#' @export
print.fbds_plan <- function(x, ...) {
  cli::cat_line(format(x))
  invisible(x)
}
