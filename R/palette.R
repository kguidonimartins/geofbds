#' Cores conhecidas por campo tematico
#'
#' `CLASSE_USO` usa as cores do MapBiomas Colecao 11
#' (legend_code_mapbiomas_brazil_collection_11.csv), para manter
#' consistencia visual com a plataforma mais usada para mapas de uso e
#' cobertura do solo no Brasil. Quatro das seis classes tem equivalencia
#' direta (mesmo conceito, so nome diferente): "agua" = "Rio, Lago e
#' Oceano", "area edificada" = "Area Urbanizada", "formacao florestal" =
#' "Formacao Florestal", "silvicultura" = "Silvicultura". As outras duas sao
#' categorias agregadas da FBDS sem uma classe-folha equivalente no
#' MapBiomas, entao usam a aproximacao mais proxima: "area antropizada" ~
#' "Mosaico de Usos" (uso agropecuario heterogeneo) e "formacao nao
#' florestal" ~ "Formacao Campestre" (a formacao natural nao florestal mais
#' comum no Brasil).
#'
#' `HIDRO` tem duas grafias para a mesma classe real (rio com mais de 10m de
#' largura): `"curso d'água (10 - 50m)"` aparece em `app/APP` (a faixa de APP
#' que a largura do rio exige) e `"curso d'água (>10m)"` aparece em
#' `hidrografia/RIOS_DUPLOS` (o mesmo corte de largura, mas so descrevendo por
#' que o rio virou linha dupla). Ambas recebem a mesma cor de proposito.
#'
#' @noRd
known_theme_colors <- function(field) {
  switch(
    field,
    CLASSE_USO = c(
      "\u00e1gua" = "#2532e4",
      "\u00e1rea antropizada" = "#ffefc3",
      "\u00e1rea edificada" = "#d4271e",
      "forma\u00e7\u00e3o florestal" = "#1f8d49",
      "forma\u00e7\u00e3o n\u00e3o florestal" = "#d6bc74",
      "silvicultura" = "#7a5900"
    ),
    HIDRO = c(
      "curso d'\u00e1gua (0 - 10m)" = "#6baed6",
      "curso d'\u00e1gua (10 - 50m)" = "#08519c",
      "curso d'\u00e1gua (>10m)" = "#08519c",
      "massa d'\u00e1gua" = "#31a8c8",
      "nascente" = "#756bb1"
    ),
    NATUREZA = c(
      "natural" = "#2ca25f",
      "artificial" = "#de2d26"
    ),
    RIO = c(
      "presente" = "#2171b5",
      "ausente" = "#bdbdbd"
    ),
    NULL
  )
}

#' Paleta qualitativa de reserva (ColorBrewer "Dark2")
#'
#' @noRd
fallback_theme_colors <- function() {
  c(
    "#1b9e77",
    "#d95f02",
    "#7570b3",
    "#e7298a",
    "#66a61e",
    "#e6ab02",
    "#a6761d",
    "#666666"
  )
}

#' Cores padronizadas para classes tematicas dos dados da FBDS
#'
#' Devolve um vetor de cores nomeado para colorir mapas por classe, sem
#' redefinir a paleta a cada script. Cobre os campos categoricos mais comuns
#' dos shapefiles da FBDS: `"CLASSE_USO"` (uso e cobertura do solo, em
#' `uso/USO` e `app/APP_USO`), `"HIDRO"` (feicao hidrografica que originou a
#' APP, em `app/APP` e nos conjuntos de `hidrografia`), e `"NATUREZA"`/`"RIO"`
#' (ambos de `hidrografia/MASSAS_DAGUA`). Classes conhecidas destes campos
#' recebem sempre a mesma cor; classes desconhecidas (de outro campo, ou uma
#' categoria nova) recebem uma cor de reserva estavel, tirada de uma paleta
#' qualitativa (ColorBrewer "Dark2"), na ordem em que aparecem em `values`.
#'
#' As cores de `"CLASSE_USO"` seguem o MapBiomas Colecao 11, para
#' consistencia visual com a plataforma mais usada para mapas de uso e
#' cobertura do solo no Brasil (correspondencia classe a classe documentada
#' em `R/palette.R`).
#'
#' @param field Nome do campo tematico (ex. `"CLASSE_USO"`). Aceita qualquer
#'   nome de coluna; campos sem cores conhecidas usam so a paleta de reserva.
#' @param values Vetor com as classes a colorir (tipicamente uma coluna de um
#'   objeto `sf`, ex. `dados$CLASSE_USO`). `NULL` (padrao) devolve todas as
#'   cores conhecidas de `field`, ou um vetor vazio se `field` nao tiver
#'   cores conhecidas.
#'
#' @return Vetor de cores nomeado (codigos hex), um elemento por classe
#'   distinta.
#' @export
#'
#' @examples
#' fbds_palette("CLASSE_USO")
#' fbds_palette("HIDRO")
#'
#' \dontrun{
#' uso <- fbds_get("serra da saudade", layer = "uso", type = "USO")
#' cores <- fbds_palette("CLASSE_USO", uso$CLASSE_USO)
#' plot(uso["CLASSE_USO"], col = cores[uso$CLASSE_USO])
#' }
fbds_palette <- function(field, values = NULL) {
  known <- known_theme_colors(field)

  if (is.null(values)) {
    if (is.null(known)) {
      return(character(0))
    }
    return(known)
  }

  domain <- unique(as.character(values[!is.na(values)]))
  colors <- if (is.null(known)) {
    rep(NA_character_, length(domain))
  } else {
    unname(known[domain])
  }
  missing <- is.na(colors) | !nzchar(colors)
  colors[missing] <- rep(fallback_theme_colors(), length.out = sum(missing))
  names(colors) <- domain
  colors
}
