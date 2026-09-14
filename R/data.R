#' Catalogo de municipios brasileiros da Geo FBDS
#'
#' Catalogo interno e congelado dos 5.470 municipios levantados pela FBDS,
#' derivado de `data-raw/build_catalog.R`. Usado por [fbds_resolve()] e
#' [fbds_catalog()] para dispensar leitura de planilha em tempo de execucao.
#' As seis colunas `area_*` sao a classificacao de uso do solo do
#' levantamento da FBDS (nao a cobertura em si dos shapefiles baixaveis
#' pelo pacote) e somam a area total do municipio.
#'
#' @format Um tibble com 5.470 linhas e as colunas:
#' \describe{
#'   \item{geocode}{Geocodigo do IBGE, texto com 7 digitos.}
#'   \item{municipality}{Nome do municipio, em caixa alta.}
#'   \item{uf}{Sigla da unidade federativa.}
#'   \item{uf_code}{Codigo numerico da UF (2 primeiros digitos do geocodigo).}
#'   \item{area_agua}{Area de massas d'agua, em hectares.}
#'   \item{area_silvicultura}{Area de silvicultura, em hectares.}
#'   \item{area_formacao_florestal}{Area de formacao florestal, em
#'     hectares, conforme classificacao da FBDS.}
#'   \item{area_formacao_nao_florestal}{Area de formacao nao florestal,
#'     em hectares, conforme classificacao da FBDS.}
#'   \item{area_edificada}{Area edificada, em hectares.}
#'   \item{area_antropizada}{Area antropizada, em hectares.}
#'   \item{slug}{Segmento de URL do municipio no portal da Geo FBDS.}
#'   \item{slug_status}{Um de `"unverified"`, `"ok"`, `"fixed"` ou
#'     `"missing"`, conforme a verificacao contra o portal
#'     (`data-raw/verify_slugs.R`). Ver Detalhes.}
#' }
#'
#' @details
#' `slug_status` comeca `"unverified"` para todo o catalogo (o slug e so
#' uma estimativa derivada do nome do municipio). Rodar
#' `data-raw/verify_slugs.R` contra o portal e regerar o catalogo
#' atualiza esse campo para os municipios verificados: `"ok"` (o slug
#' estimado respondeu), `"fixed"` (uma variante do slug respondeu) ou
#' `"missing"` (nenhuma variante respondeu). Na versao atual do pacote,
#' apenas os municipios de RO (52) foram verificados; os demais
#' permanecem `"unverified"` ate uma nova rodada do script.
#'
#' @source Fundacao Brasileira para o Desenvolvimento Sustentavel (FBDS),
#'   `TABELA CONSOLIDADA.xls`, aba "Levantamento do Uso do Solo" (colunas
#'   de area sob o cabecalho "Areas do Uso do Solo (ha)"). Os metadados
#'   oficiais do mapeamento
#'   (<https://geo.fbds.org.br/Metadados%20Mapeamento%20FBDS.pdf>, campo
#'   "Restricoes Legais": "Irrestrito", 30/04/2023) cobrem o mapeamento
#'   como um todo, do qual esta tabela consolidada faz parte.
#'
#' @examples
#' fbds_municipios
#' dplyr::count(fbds_municipios, slug_status)
"fbds_municipios"
