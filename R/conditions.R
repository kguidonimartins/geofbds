#' Raise a classified geofbds error
#'
#' Thin wrapper over [rlang::abort()] (via [cli::cli_abort()], so `message`
#' supports cli's inline markup) that always adds the `"fbds_error"` parent
#' class, letting users `tryCatch()` on either the specific condition class
#' or on any geofbds error.
#'
#' @param message Character vector passed to [cli::cli_abort()].
#' @param class One or more condition classes, e.g. `"fbds_bad_geocode"`.
#' @param ... Additional data fields attached to the condition.
#' @param call The calling environment, forwarded to [cli::cli_abort()].
#'
#' @noRd
abort_fbds <- function(
  message,
  class,
  ...,
  call = rlang::caller_env(),
  .envir = parent.frame()
) {
  cli::cli_abort(
    message,
    class = c(class, "fbds_error"),
    ...,
    call = call,
    .envir = .envir
  )
}
