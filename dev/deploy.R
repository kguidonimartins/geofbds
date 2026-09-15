install_if_needed <- function(package, minimum_version = NULL) {
  installed_version <- tryCatch(
    utils::packageVersion(package),
    error = function(...) NULL
  )

  current_enough <- !is.null(installed_version) &&
    (is.null(minimum_version) || installed_version >= minimum_version)

  if (current_enough) {
    return(invisible())
  }

  install.packages(package, repos = "https://cloud.r-project.org")

  installed_version <- tryCatch(
    utils::packageVersion(package),
    error = function(...) NULL
  )

  if (
    is.null(installed_version) ||
      (!is.null(minimum_version) && installed_version < minimum_version)
  ) {
    requirement <- if (is.null(minimum_version)) {
      package
    } else {
      paste0(package, " >= ", minimum_version)
    }
    stop("Nao foi possivel instalar ", requirement, ".", call. = FALSE)
  }

  invisible()
}

# rsconnect 1.10.0 fixed verbose deployments using the httr2 backend.
install_if_needed("rsconnect", "1.10.0")
install_if_needed("dotenv")

root <- normalizePath(".")

env_file <- file.path(root, ".env")

if (file.exists(env_file)) {
  dotenv::load_dot_env(file = env_file)
}

token <- Sys.getenv("SHINY_TOKEN", unset = "")
secret <- Sys.getenv("SHINY_SECRET", unset = "")

if (!nzchar(token) || !nzchar(secret)) {
  stop(
    "Defina SHINY_TOKEN e SHINY_SECRET no .env ou no ambiente.",
    call. = FALSE
  )
}

rsconnect::setAccountInfo(
  name = "kguidonimartins",
  token = token,
  secret = secret
)

app_dir <- file.path(root, "inst", "shiny")

lockfile <- file.path(root, "renv.lock")
app_lockfile <- file.path(app_dir, "renv.lock")

if (!file.exists(lockfile)) {
  stop("Execute renv::snapshot() antes do deploy.", call. = FALSE)
}
if (!file.copy(lockfile, app_lockfile, overwrite = FALSE)) {
  stop("Nao foi possivel preparar o renv.lock para o deploy.", call. = FALSE)
}

tryCatch(
  {
    lock <- jsonlite::read_json(app_lockfile, simplifyVector = FALSE)
    package <- lock$Packages$geofbds
    remote_fields <- c(
      package$RemoteUsername,
      package$RemoteRepo,
      package$RemoteRef,
      package$RemoteSha
    )

    if (is.null(package) || any(!nzchar(remote_fields))) {
      stop(
        "O renv.lock nao contem a origem GitHub completa de geofbds.",
        call. = FALSE
      )
    }

    package$GithubUsername <- package$RemoteUsername
    package$GithubRepo <- package$RemoteRepo
    package$GithubRef <- package$RemoteRef
    package$GithubSHA1 <- package$RemoteSha
    lock$Packages$geofbds <- package
    jsonlite::write_json(
      lock,
      app_lockfile,
      auto_unbox = TRUE,
      pretty = TRUE
    )

    rsconnect::deployApp(
      appName = "geofbds",
      appDir = app_dir,
      account = "kguidonimartins",
      upload = TRUE,
      launch.browser = TRUE,
      forceUpdate = TRUE,
      logLevel = "verbose",
      lint = TRUE
    )
  },
  finally = unlink(app_lockfile)
)
