#' Catalogo de municipios brasileiros da Geo FBDS
#'
#' Catalogo interno e congelado dos 5.470 municipios levantados pela FBDS,
#' derivado de `data-raw/build_catalog.R`. Usado por [fbds_resolve()] e
#' [fbds_catalog()] para dispensar leitura de planilha em tempo de execucao.
#'
#' @format Um tibble com 5.470 linhas e as colunas:
#' \describe{
#'   \item{geocode}{Geocodigo do IBGE, texto com 7 digitos.}
#'   \item{municipality}{Nome do municipio, em caixa alta.}
#'   \item{uf}{Sigla da unidade federativa.}
#'   \item{uf_code}{Codigo numerico da UF (2 primeiros digitos do geocodigo).}
#'   \item{area_agua}{Area de massas d'agua.}
#'   \item{area_silvicultura}{Area de silvicultura.}
#'   \item{area_formacao_florestal}{Area de formacao florestal.}
#'   \item{area_formacao_nao_florestal}{Area de formacao nao florestal.}
#'   \item{area_edificada}{Area edificada.}
#'   \item{area_antropizada}{Area antropizada.}
#'   \item{slug}{Segmento de URL do municipio no portal da Geo FBDS.}
#'   \item{slug_status}{Um de `"unverified"`, `"ok"`, `"fixed"` ou
#'     `"missing"`, conforme a verificacao contra o portal
#'     (`data-raw/verify_slugs.R`).}
#' }
#'
#' @source Fundacao Brasileira para o Desenvolvimento Sustentavel (FBDS),
#'   `TABELA CONSOLIDADA.xls`, aba "Levantamento do Uso do Solo".
"fbds_municipios"
