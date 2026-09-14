# Confere, para cada municipio do catalogo, se o slug derivado do nome
# (ver data-raw/build_catalog.R) responde no portal da Geo FBDS. Roda uma
# unica vez por atualizacao do catalogo; nao faz parte do pacote instalado
# (SPECS.md secao 7.1 — maior risco tecnico do pacote).
#
# Faz uma requisicao HEAD por municipio contra {base_url}/{uf}/{slug}/APP/,
# em blocos pequenos com pausa entre eles para nao sobrecarregar o portal.
# Para os que falham na tentativa direta, testa variantes do slug:
# apostrofo virando "_", acentos preservados e "%20" no lugar de "_".
#
# Saida: data-raw/slug_check.csv, com geocode, slug_tentado, http_status,
# slug_final (NA quando nenhuma variante respondeu 200).
#
# Uso:
#   Rscript data-raw/verify_slugs.R
# Para testar so uma UF (mais rapido, util para calibrar o script):
#   Rscript data-raw/verify_slugs.R --uf=RO

devtools::load_all(quiet = TRUE)

args <- commandArgs(trailingOnly = TRUE)
uf_arg <- sub("^--uf=", "", grep("^--uf=", args, value = TRUE))
uf_filter <- if (length(uf_arg) == 1L) toupper(uf_arg) else NULL

catalog <- fbds_municipios
if (!is.null(uf_filter)) {
  catalog <- catalog[catalog$uf == uf_filter, ]
}

if (nrow(catalog) == 0L) {
  stop("Nenhum municipio para verificar (confira --uf).", call. = FALSE)
}

base_url <- getOption("geofbds.base_url")
block_size <- 20L
pause_sec <- 2

slug_variants <- function(name) {
  clean <- toupper(janitor::make_clean_names(name))

  apostrophe_underscore <- toupper(gsub("['’]", "_", name))
  apostrophe_underscore <- gsub("[^A-Z0-9_]+", "_", apostrophe_underscore)
  apostrophe_underscore <- gsub("_+", "_", apostrophe_underscore)
  apostrophe_underscore <- gsub("^_|_$", "", apostrophe_underscore)

  accented <- toupper(gsub("'", "", name, fixed = TRUE))
  accented <- gsub("[[:space:]]+", "_", trimws(accented))

  percent20 <- gsub("_", "%20", clean, fixed = TRUE)

  unique(c(clean, apostrophe_underscore, accented, percent20))
}

check_urls_head <- function(urls) {
  n <- length(urls)
  if (n == 0L) {
    return(integer(0))
  }

  destfiles <- vapply(
    seq_len(n),
    function(i) tempfile(fileext = ".head"),
    character(1)
  )
  on.exit(unlink(destfiles), add = TRUE)

  res <- tryCatch(
    curl::multi_download(
      urls,
      destfiles = destfiles,
      resume = FALSE,
      progress = FALSE,
      nobody = TRUE,
      failonerror = FALSE,
      connecttimeout = 15,
      timeout = 30,
      useragent = getOption("geofbds.user_agent")
    ),
    error = function(e) NULL
  )

  if (is.null(res)) {
    return(rep(NA_integer_, n))
  }

  res$status_code
}

run_in_blocks <- function(items, fun) {
  n <- length(items)
  if (n == 0L) {
    return(list())
  }

  blocks <- split(items, ceiling(seq_along(items) / block_size))
  out <- vector("list", length(blocks))

  for (b in seq_along(blocks)) {
    cli::cli_inform("Bloco {b}/{length(blocks)} ({length(blocks[[b]])} itens)")
    out[[b]] <- fun(blocks[[b]])
    if (b < length(blocks)) {
      Sys.sleep(pause_sec)
    }
  }

  out
}

# Fase 1: tentativa direta com o slug do catalogo -----------------------

primary_slug <- toupper(janitor::make_clean_names(catalog$municipality))
primary_urls <- paste(
  base_url,
  catalog$uf,
  primary_slug,
  "APP",
  "",
  sep = "/"
)

cli::cli_inform("Verificando {nrow(catalog)} municipios (slug direto).")
primary_status <- unlist(run_in_blocks(
  seq_len(nrow(catalog)),
  fun = function(idx) check_urls_head(primary_urls[idx])
))

slug_check <- tibble::tibble(
  geocode = catalog$geocode,
  slug_tentado = primary_slug,
  http_status = primary_status,
  slug_final = ifelse(
    !is.na(primary_status) & primary_status == 200L,
    primary_slug,
    NA_character_
  )
)

# Fase 2: variantes de slug para quem falhou -----------------------------

failed <- which(is.na(slug_check$slug_final))
cli::cli_inform(
  "{length(failed)} municipio(s) sem confirmacao direta; testando variantes."
)

resolve_failure <- function(i) {
  name <- catalog$municipality[[i]]
  uf <- catalog$uf[[i]]
  variants <- setdiff(slug_variants(name), primary_slug[[i]])

  if (length(variants) == 0L) {
    return(list(
      slug_final = NA_character_,
      http_status = slug_check$http_status[[i]]
    ))
  }

  urls <- paste(base_url, uf, variants, "APP", "", sep = "/")
  statuses <- check_urls_head(urls)
  ok <- which(!is.na(statuses) & statuses == 200L)

  if (length(ok) > 0L) {
    list(slug_final = variants[[ok[[1]]]], http_status = statuses[[ok[[1]]]])
  } else {
    list(
      slug_final = NA_character_,
      http_status = slug_check$http_status[[i]]
    )
  }
}

fixed <- run_in_blocks(
  failed,
  fun = function(idx) lapply(idx, resolve_failure)
)
fixed <- unlist(fixed, recursive = FALSE)

for (j in seq_along(failed)) {
  i <- failed[[j]]
  slug_check$slug_final[[i]] <- fixed[[j]]$slug_final
  if (!is.na(fixed[[j]]$slug_final)) {
    slug_check$http_status[[i]] <- fixed[[j]]$http_status
  }
}

vroom::vroom_write(slug_check, "data-raw/slug_check.csv", delim = ",")

n_ok <- sum(!is.na(slug_check$slug_final))
n_missing <- sum(is.na(slug_check$slug_final))
cli::cli_inform(c(
  "v" = "Gravado data-raw/slug_check.csv ({nrow(slug_check)} municipios).",
  "i" = "{n_ok} confirmados, {n_missing} pendentes (slug_status = 'missing')."
))
