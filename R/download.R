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

#' Baixar todos os municipios de uma ou mais UFs, com retomada
#'
#' Difere de [fbds_download_municipality()] em tres pontos: estima o
#' volume antes de baixar (via [fbds_coverage()]) e pede confirmacao
#' quando ultrapassa `confirm_bytes`; processa os municipios em blocos,
#' em vez de montar um unico plano com todos os arquivos da UF; e grava
#' `{dest_dir}/_progress.csv` ao final de cada bloco, de modo que uma
#' execucao interrompida (`Ctrl-C`, queda de rede) possa ser retomada
#' chamando a mesma funcao de novo — municipios ja `"complete"` (nenhum
#' arquivo com `status == "failed"`) sao pulados, sem nova requisicao.
#'
#' @param uf Sigla(s) de UF. Aceita mais de uma.
#' @param block_size Numero de municipios por bloco.
#' @param ask Se `TRUE` (padrao em sessao interativa) e o volume
#'   estimado ultrapassar `confirm_bytes`, pede confirmacao antes de
#'   baixar. Fora de sessao interativa, nada e perguntado.
#' @param confirm_bytes Limite (bytes) acima do qual `ask = TRUE` pede
#'   confirmacao. Padrao `getOption("geofbds.confirm_bytes")`.
#' @inheritParams fbds_plan
#' @inheritParams fbds_fetch
#'
#' @return O manifesto (tibble) dos blocos processados nesta chamada —
#'   nao inclui os municipios ja completos de chamadas anteriores.
#' @export
#'
#' @examples
#' \dontrun{
#' fbds_download_state("RO", layers = "app")
#' fbds_download_state("RO") # retoma de onde parou, se interrompida
#' }
fbds_download_state <- function(
  uf,
  layers = NULL,
  dest_dir = fbds_cache_dir(),
  recursive = FALSE,
  skip_existing = TRUE,
  path_pattern = "{uf}/{geocode}/{layer}/{file}",
  block_size = 10L,
  workers = getOption("geofbds.workers", 4L),
  retries = getOption("geofbds.retries", 3L),
  timeout = getOption("geofbds.timeout", 300),
  progress = getOption("geofbds.progress", TRUE),
  ask = interactive(),
  confirm_bytes = getOption("geofbds.confirm_bytes", 1e9)
) {
  catalog <- fbds_catalog(uf = uf)
  if (nrow(catalog) == 0L) {
    abort_fbds(
      "Nenhum municipio encontrado para UF(s): {.val {uf}}",
      "fbds_unknown_municipality"
    )
  }

  progress_path <- file.path(dest_dir, "_progress.csv")
  done <- resume_state(progress_path)
  already_complete <- done$geocode[done$status == "complete"]
  remaining <- catalog[!catalog$geocode %in% already_complete, ]

  if (nrow(remaining) == 0L) {
    cli::cli_inform(
      "Os {nrow(catalog)} municipio(s) de {.val {uf}} ja estao completos em {.path {progress_path}}."
    )
    return(empty_manifest())
  }

  if (isTRUE(progress) && length(already_complete) > 0L) {
    cli::cli_inform(
      "Retomando: {length(already_complete)} municipio(s) ja completos, {nrow(remaining)} restante(s)."
    )
  }

  coverage <- fbds_coverage(uf = uf, layers = layers)
  total_bytes <- sum(coverage$bytes, na.rm = TRUE)

  if (isTRUE(ask) && total_bytes > confirm_bytes) {
    cli::cli_inform(
      "Download estimado: {nrow(remaining)} municipio(s), {format_bytes(total_bytes)}."
    )
    proceed <- isTRUE(utils::askYesNo(
      sprintf("Continuar com o download (~%s)?", format_bytes(total_bytes)),
      default = FALSE
    ))
    if (!proceed) {
      abort_fbds(
        "Download cancelado: volume estimado ({format_bytes(total_bytes)}) nao confirmado.",
        "fbds_download_declined"
      )
    }
  }

  blocks <- split(
    seq_len(nrow(remaining)),
    ceiling(seq_len(nrow(remaining)) / block_size)
  )
  manifests <- vector("list", length(blocks))

  for (i in seq_along(blocks)) {
    block_geocodes <- remaining$geocode[blocks[[i]]]
    if (isTRUE(progress)) {
      cli::cli_inform(
        "Bloco {i}/{length(blocks)}: {length(block_geocodes)} municipio(s)"
      )
    }

    plano <- fbds_plan(
      block_geocodes,
      layers = layers,
      dest_dir = dest_dir,
      recursive = recursive,
      skip_existing = skip_existing,
      path_pattern = path_pattern
    )
    manifest <- fbds_fetch(
      plano,
      workers = workers,
      retries = retries,
      timeout = timeout,
      progress = progress
    )
    manifests[[i]] <- manifest

    if (nrow(manifest) > 0L) {
      update_progress_state(progress_path, manifest, catalog)
    }
  }

  dplyr::bind_rows(manifests)
}

#' Baixar o espelho nacional
#'
#' Invólucro de [fbds_download_state()] para todas as 27 UFs. Dado o
#' volume, `ask` deveria quase sempre ficar em `TRUE`.
#'
#' @inheritParams fbds_download_state
#'
#' @return O manifesto (tibble) dos blocos processados nesta chamada.
#' @export
#'
#' @examples
#' \dontrun{
#' fbds_download_all(layers = "app")
#' }
fbds_download_all <- function(
  layers = NULL,
  dest_dir = fbds_cache_dir(),
  recursive = FALSE,
  skip_existing = TRUE,
  path_pattern = "{uf}/{geocode}/{layer}/{file}",
  block_size = 10L,
  workers = getOption("geofbds.workers", 4L),
  retries = getOption("geofbds.retries", 3L),
  timeout = getOption("geofbds.timeout", 300),
  progress = getOption("geofbds.progress", TRUE),
  ask = interactive(),
  confirm_bytes = getOption("geofbds.confirm_bytes", 1e9)
) {
  fbds_download_state(
    uf = fbds_ufs()$uf,
    layers = layers,
    dest_dir = dest_dir,
    recursive = recursive,
    skip_existing = skip_existing,
    path_pattern = path_pattern,
    block_size = block_size,
    workers = workers,
    retries = retries,
    timeout = timeout,
    progress = progress,
    ask = ask,
    confirm_bytes = confirm_bytes
  )
}
