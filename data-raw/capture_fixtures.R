# Salva paginas de listagem reais do portal da Geo FBDS em
# tests/testthat/fixtures/, para calibrar parse_h5ai_listing() (Fase 3 do
# PLAN.md) sem depender de rede nos testes. Roda uma unica vez, ou quando o
# layout do portal mudar; nao faz parte do pacote instalado.
#
# Captura 4 casos:
#  - listing_app.html: listagem normal (APP)
#  - listing_hidrografia.html: listagem normal (HIDROGRAFIA)
#  - listing_uso.html: listagem com subdiretorio (deve conter MAPAS/, info/
#    e USO.rar — confira o HTML depois; se RO/CABIXI/USO nao tiver esse
#    layout, troque `uso_uf`/`uso_slug` abaixo por um municipio que tenha)
#  - listing_404.html: um caminho inexistente no portal
#
# Uso:
#   Rscript data-raw/capture_fixtures.R

devtools::load_all(quiet = TRUE)

fixtures_dir <- "tests/testthat/fixtures"
dir.create(fixtures_dir, recursive = TRUE, showWarnings = FALSE)

base_url <- getOption("geofbds.base_url")
handle <- curl::new_handle(useragent = getOption("geofbds.user_agent"))

save_listing <- function(url, destfile) {
  path <- file.path(fixtures_dir, destfile)
  cli::cli_inform("Baixando {url} -> {path}")

  tryCatch(
    {
      req <- curl::curl_fetch_memory(url, handle = handle)
      writeBin(req$content, path)
      cli::cli_inform("  status {req$status_code}, {length(req$content)} bytes")
    },
    error = function(e) cli::cli_warn("  falhou: {conditionMessage(e)}")
  )
}

app_uf <- "RO"
app_slug <- "CABIXI"
save_listing(
  paste0(base_url, "/", app_uf, "/", app_slug, "/APP/"),
  "listing_app.html"
)

hidro_uf <- "RO"
hidro_slug <- "CABIXI"
save_listing(
  paste0(base_url, "/", hidro_uf, "/", hidro_slug, "/HIDROGRAFIA/"),
  "listing_hidrografia.html"
)

uso_uf <- "RO"
uso_slug <- "CABIXI"
save_listing(
  paste0(base_url, "/", uso_uf, "/", uso_slug, "/USO/"),
  "listing_uso.html"
)

save_listing(
  paste0(base_url, "/", app_uf, "/MUNICIPIO_INEXISTENTE_XYZ/APP/"),
  "listing_404.html"
)

cli::cli_inform(c(
  "v" = "Fixtures gravadas em {fixtures_dir}.",
  "i" = paste(
    "Confira o conteudo de cada arquivo antes da Fase 3 — em especial",
    "listing_uso.html, que precisa mostrar MAPAS/, info/ e USO.rar para",
    "validar o argumento `recursive` de fbds_files()."
  )
))
