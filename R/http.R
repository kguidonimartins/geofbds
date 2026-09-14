#' Consultar uma URL do portal, com retry e backoff
#'
#' GET com o user-agent do pacote. Erros de rede e respostas HTTP >= 500 sao
#' tentados novamente ate `retries` vezes, com backoff exponencial e jitter.
#' Uma resposta HTTP >= 400 apos as tentativas vira `fbds_http_error`.
#'
#' @param url URL a consultar.
#' @param retries Numero de tentativas extras apos a primeira falha.
#' @param timeout Tempo maximo (segundos) por tentativa.
#'
#' @return A resposta de [curl::curl_fetch_memory()] (lista com
#'   `status_code`, `content` (raw), `url`, `headers`).
#' @noRd
fbds_request <- function(
  url,
  retries = getOption("geofbds.retries", 3L),
  timeout = getOption("geofbds.timeout", 300)
) {
  handle <- curl::new_handle(
    useragent = getOption("geofbds.user_agent"),
    timeout = timeout,
    connecttimeout = 15,
    followlocation = TRUE
  )

  attempt <- 0L
  repeat {
    attempt <- attempt + 1L
    resp <- tryCatch(
      curl::curl_fetch_memory(url, handle = handle),
      error = function(e) e
    )

    retryable <- inherits(resp, "error") ||
      (is.list(resp) && resp$status_code >= 500L)

    if (!retryable || attempt > retries) {
      break
    }

    Sys.sleep(backoff_delay(attempt))
  }

  if (inherits(resp, "error")) {
    abort_fbds(
      "Falha de rede ao consultar {.url {url}}: {conditionMessage(resp)}",
      "fbds_http_error",
      url = url,
      status_code = NA_integer_
    )
  }

  if (resp$status_code >= 400L) {
    abort_fbds(
      "O portal respondeu {resp$status_code} para {.url {url}}",
      "fbds_http_error",
      url = url,
      status_code = resp$status_code
    )
  }

  resp
}

backoff_delay <- function(attempt) {
  jitter <- sample.int(1000L, 1L) / 1000
  2^(attempt - 1) + jitter
}
