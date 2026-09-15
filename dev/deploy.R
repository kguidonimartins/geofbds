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

# Localiza o bloco de `geofbds` no lockfile, sem desserializar o JSON: o
# arquivo e gerado pelo renv e so precisamos trocar duas linhas dele.
geofbds_lockfile_block <- function(path) {
  lines <- readLines(path, warn = FALSE)
  start <- grep('^    "geofbds": \\{$', lines)

  if (length(start) != 1L) {
    stop("Registro de geofbds nao encontrado em ", path, ".", call. = FALSE)
  }

  closing <- which(grepl("^    \\},?[[:space:]]*$", lines[-(1:start)]))[[1L]] +
    start

  list(lines = lines, block = (start + 1L):(closing - 1L))
}

lockfile_property <- function(path, key) {
  found <- geofbds_lockfile_block(path)
  hit <- found$block[grepl(
    sprintf('^[[:space:]]*"%s":', key),
    found$lines[found$block]
  )]

  if (length(hit) != 1L) {
    stop("Chave ", key, " nao encontrada em ", path, ".", call. = FALSE)
  }

  sub('^[[:space:]]*"[^"]+":[[:space:]]*"([^"]*)".*$', "\\1", found$lines[hit])
}

# O lockfile guarda o commit de `geofbds` que estava instalado quando rodou
# `renv::snapshot()`, que envelhece a cada push. O shinyapps.io instala o
# pacote a partir desse commit, entao o deploy precisa fixar o ultimo commit
# publicado no remote — senao o aplicativo sobe com uma versao antiga.
set_lockfile_ref <- function(path, sha) {
  found <- geofbds_lockfile_block(path)
  lines <- found$lines

  for (key in c("RemoteRef", "RemoteSha")) {
    hit <- found$block[grepl(
      sprintf('^[[:space:]]*"%s":', key),
      lines[found$block]
    )]

    if (length(hit) != 1L) {
      stop("Chave ", key, " nao encontrada em ", path, ".", call. = FALSE)
    }

    lines[hit] <- sub(
      '"([^"]*)"([[:space:]]*,?[[:space:]]*)$',
      sprintf('"%s"\\2', sha),
      lines[hit]
    )

    if (!grepl(sha, lines[hit], fixed = TRUE)) {
      stop("Nao foi possivel atualizar ", key, " em ", path, ".", call. = FALSE)
    }
  }

  writeLines(lines, path)

  invisible(sha)
}

remote_head_sha <- function(path) {
  host <- lockfile_property(path, "RemoteHost")
  username <- lockfile_property(path, "RemoteUsername")
  repo <- lockfile_property(path, "RemoteRepo")
  url <- sprintf(
    "https://%s/%s/%s.git",
    sub("^api\\.", "", host),
    username,
    repo
  )
  git <- Sys.which("git")

  if (!nzchar(git)) {
    stop(
      "git nao encontrado: necessario para ler o commit de ",
      url,
      ".",
      call. = FALSE
    )
  }

  out <- suppressWarnings(system2(
    git,
    c("ls-remote", "--exit-code", "--quiet", url, "HEAD"),
    stdout = TRUE,
    stderr = TRUE
  ))
  status <- attr(out, "status")

  if (!is.null(status) && status != 0L) {
    stop(
      "Nao foi possivel ler o commit mais recente de ",
      url,
      ": ",
      paste(trimws(out), collapse = " "),
      call. = FALSE
    )
  }

  sha <- sub("[[:space:]].*$", "", out[[1L]])

  if (!grepl("^[0-9a-f]{40}$", sha)) {
    stop("Commit invalido para ", url, ": ", sha, call. = FALSE)
  }

  sha
}

# Commit local, para conferir se o que sera enviado ja esta publicado.
local_head_sha <- function() {
  git <- Sys.which("git")

  if (!nzchar(git)) {
    return(NA_character_)
  }

  out <- suppressWarnings(system2(
    git,
    c("rev-parse", "HEAD"),
    stdout = TRUE,
    stderr = TRUE
  ))
  status <- attr(out, "status")

  if (!is.null(status) && status != 0L) {
    return(NA_character_)
  }

  sub("[[:space:]].*$", "", out[[1L]])
}

# O servidor instala o `geofbds` pela procedencia gravada no DESCRIPTION do
# pacote instalado aqui: o manifest.json leva o DESCRIPTION inteiro e o
# shinyapps.io le dali `GithubRepo`, `GithubUsername`, `GithubRef` e
# `GithubSHA1`. Pacote instalado do diretorio local (ou `load_all()`) nao tem
# esses campos, entao o servidor nao sabe qual commit buscar e reaproveita um
# build antigo do pacote — mesmo com o `renv.lock` correto. A instalacao vai
# para uma biblioteca so dele, sem dependencias, para nao desalinhar as
# versoes que o `renv.lock` declara para o resto do aplicativo.
install_published_geofbds <- function(path, sha) {
  username <- lockfile_property(path, "RemoteUsername")
  repo <- lockfile_property(path, "RemoteRepo")
  lib <- file.path(tempdir(), "geofbds-deploy")

  dir.create(lib, showWarnings = FALSE, recursive = TRUE)
  install_if_needed("pak")
  pak::pkg_install(
    sprintf("%s/%s@%s", username, repo, sha),
    lib = lib,
    dependencies = FALSE,
    ask = FALSE
  )

  installed <- utils::packageDescription("geofbds", lib.loc = lib)

  if (!identical(installed$GithubSHA1, sha)) {
    stop(
      "O geofbds instalado em ",
      lib,
      " nao registra o commit ",
      sha,
      ".",
      call. = FALSE
    )
  }

  .libPaths(unique(c(lib, .libPaths())))

  invisible(lib)
}

# rsconnect 1.10.0 fixed verbose deployments using the httr2 backend.
install_if_needed("rsconnect", "1.10.0")
install_if_needed("dotenv")
global_libraries <- .libPaths()

root <- normalizePath(".")
invisible(loadNamespace("rsconnect"))
invisible(loadNamespace("dotenv"))
source(file.path(root, "renv", "activate.R"))
.libPaths(unique(c(.libPaths(), global_libraries)))

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

sha <- remote_head_sha(lockfile)
local_sha <- local_head_sha()

if (!is.na(local_sha) && !identical(local_sha, sha)) {
  warning(
    "HEAD local (",
    substr(local_sha, 1L, 7L),
    ") difere do commit publicado (",
    substr(sha, 1L, 7L),
    "): o shinyapps.io instalara o geofbds publicado, nao o local. ",
    "Faca push antes do deploy.",
    call. = FALSE
  )
}

cat("geofbds fixado em", substr(sha, 1L, 7L), "(ultimo commit do remote).\n")

install_published_geofbds(lockfile, sha)

if (!file.copy(lockfile, app_lockfile, overwrite = FALSE)) {
  stop("Nao foi possivel preparar o renv.lock para o deploy.", call. = FALSE)
}

set_lockfile_ref(app_lockfile, sha)

tryCatch(
  rsconnect::deployApp(
    appName = "geofbds",
    appDir = app_dir,
    account = "kguidonimartins",
    upload = TRUE,
    launch.browser = TRUE,
    forceUpdate = TRUE,
    logLevel = "verbose",
    lint = TRUE
  ),
  finally = unlink(app_lockfile)
)
