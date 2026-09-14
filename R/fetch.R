#' Executar um plano de download
#'
#' Sobre [curl::multi_download()] com `resume = TRUE`: substitui o laco
#' sequencial e a logica manual de `.part` do script original
#' (SPECS.md §2.2-14). `curl::multi_download()` nao expoe um parametro de
#' concorrencia real, entao `workers` particiona as linhas em blocos
#' desse tamanho, cada um resolvido em uma chamada. Apos cada rodada, as
#' linhas que falharam sao re-tentadas com backoff, ate `retries` vezes.
#'
#' @param plan Um objeto `<fbds_plan>` de [fbds_plan()].
#' @param workers Tamanho do bloco de download concorrente.
#' @param retries Numero de novas tentativas para arquivos que falharem.
#' @param timeout Tempo maximo (segundos) por arquivo, por tentativa.
#' @param progress Se `TRUE` (padrao), informa o andamento via `cli`.
#' @param dry_run Se `TRUE`, nao baixa nada: devolve o manifesto que
#'   resultaria (`status` `"cached"` ou `"skipped"`) sem tocar a rede.
#'
#' @return Um manifesto (tibble), tambem gravado em
#'   `{dest_dir}/_manifests/{run_id}.csv`.
#' @export
#'
#' @examples
#' \dontrun{
#' plano <- fbds_plan("1100031", layers = "app")
#' fbds_fetch(plano)
#' }
fbds_fetch <- function(
  plan,
  workers = getOption("geofbds.workers", 4L),
  retries = getOption("geofbds.retries", 3L),
  timeout = getOption("geofbds.timeout", 300),
  progress = getOption("geofbds.progress", TRUE),
  dry_run = FALSE
) {
  if (!inherits(plan, "fbds_plan")) {
    abort_fbds(
      "{.arg plan} precisa ser um objeto <fbds_plan> (ver {.fn fbds_plan}).",
      "fbds_bad_plan"
    )
  }

  run_id <- gsub("[^0-9A-Za-z]", "", format(Sys.time(), "%Y%m%dT%H%M%OS3"))
  n <- nrow(plan)
  status <- ifelse(plan$action == "skip", "cached", "pending")
  http_status <- rep(NA_integer_, n)
  attempts <- rep(0L, n)
  error <- rep(NA_character_, n)

  if (isTRUE(dry_run)) {
    status[status == "pending"] <- "skipped"
    return(build_manifest(
      run_id = run_id,
      plan = plan,
      status = status,
      http_status = http_status,
      attempts = attempts,
      error = error,
      compute_hash = FALSE
    ))
  }

  if (n > 0L) {
    dirs_needed <- unique(dirname(plan$dest_path))
    for (d in dirs_needed) {
      dir.create(d, recursive = TRUE, showWarnings = FALSE)
    }
  }

  download_idx <- which(status == "pending")
  attempt <- 0L
  repeat {
    if (length(download_idx) == 0L) {
      break
    }
    attempt <- attempt + 1L
    if (attempt > 1L) {
      Sys.sleep(backoff_delay(attempt))
    }

    chunks <- split(
      download_idx,
      ceiling(seq_along(download_idx) / workers)
    )
    for (chunk in chunks) {
      if (isTRUE(progress)) {
        cli::cli_inform(
          "Baixando {length(chunk)} arquivo(s) (tentativa {attempt})"
        )
      }
      res <- curl::multi_download(
        plan$url[chunk],
        destfiles = plan$dest_path[chunk],
        resume = TRUE,
        progress = FALSE,
        failonerror = TRUE,
        useragent = getOption("geofbds.user_agent"),
        timeout = timeout,
        connecttimeout = 15
      )
      attempts[chunk] <- attempts[chunk] + 1L
      http_status[chunk] <- res$status_code
      ok <- res$success
      status[chunk[ok]] <- "downloaded"
      error[chunk[!ok]] <- res$error[!ok]
    }

    download_idx <- download_idx[status[download_idx] == "pending"]
    if (attempt > retries) {
      status[download_idx] <- "failed"
      break
    }
  }

  manifest <- build_manifest(
    run_id = run_id,
    plan = plan,
    status = status,
    http_status = http_status,
    attempts = attempts,
    error = error,
    compute_hash = TRUE
  )

  if (n > 0L) {
    write_manifest(manifest, attr(plan, "dest_dir"))
  }

  n_failed <- sum(manifest$status == "failed")
  if (n_failed > 0L) {
    cli::cli_warn(
      "{n_failed} arquivo(s) falharam apos {retries} nova(s) tentativa(s). Veja o manifesto."
    )
  }

  manifest
}
