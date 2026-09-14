#' Baixar dados de um ou mais municipios
#'
#' Involucro fino de `fbds_plan() |> fbds_fetch()`.
#'
#' @inheritParams fbds_plan
#' @inheritParams fbds_fetch
#'
#' @return O manifesto (tibble) de [fbds_fetch()].
#' @export
#'
#' @examples
#' \dontrun{
#' fbds_download_municipality(c("1100031", "1100049"), layers = "app")
#' fbds_download_municipality("Cabixi/RO")
#' }
fbds_download_municipality <- function(
  x,
  layers = NULL,
  dest_dir = fbds_cache_dir(),
  recursive = FALSE,
  skip_existing = TRUE,
  path_pattern = "{uf}/{geocode}/{layer}/{file}",
  workers = getOption("geofbds.workers", 4L),
  retries = getOption("geofbds.retries", 3L),
  timeout = getOption("geofbds.timeout", 300),
  progress = getOption("geofbds.progress", TRUE),
  dry_run = FALSE
) {
  plan <- fbds_plan(
    x,
    layers = layers,
    dest_dir = dest_dir,
    recursive = recursive,
    skip_existing = skip_existing,
    path_pattern = path_pattern
  )

  fbds_fetch(
    plan,
    workers = workers,
    retries = retries,
    timeout = timeout,
    progress = progress,
    dry_run = dry_run
  )
}
