# Gera os estilos categorizados do QGIS (.qml) em inst/qgis/, um por campo
# tematico conhecido de fbds_palette() (CLASSE_USO, HIDRO, NATUREZA, RIO).
#
# As cores vem de fbds_palette() -- unica fonte de verdade, compartilhada com
# o aplicativo Shiny (inst/shiny/helpers.R) -- entao os arquivos aqui gerados
# nunca divergem das cores usadas no pacote. Rode `make qml` sempre que
# fbds_palette() (R/palette.R) mudar.
#
# Cada campo e categorizado como poligono ("SimpleFill"), porque nos dados da
# FBDS os quatro aparecem em shapefiles de poligono:
#   - CLASSE_USO: uso/USO.shp e app/APP_USO.shp
#   - HIDRO:      app/APP.shp (4 classes; em hidrografia/RIOS_SIMPLES,
#                 RIOS_DUPLOS e NASCENTES o campo existe mas so tem 1 classe
#                 cada, entao categorizar nao ajuda)
#   - NATUREZA e RIO: hidrografia/MASSAS_DAGUA.shp

devtools::load_all(".", quiet = TRUE)

out_dir <- "inst/qgis"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

hex_to_rgba <- function(hex) {
  rgb <- grDevices::col2rgb(hex)
  sprintf("%d,%d,%d,255", rgb[1L, ], rgb[2L, ], rgb[3L, ])
}

xml_escape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}

build_categorized_qml <- function(field) {
  colors <- fbds_palette(field)
  classes <- names(colors)
  idx <- seq_along(classes) - 1L

  categories <- sprintf(
    '    <category symbol="%d" value="%s" label="%s" render="true"/>',
    idx,
    xml_escape(classes),
    xml_escape(classes)
  )

  symbols <- sprintf(
    paste(
      '    <symbol type="fill" name="%d" alpha="1" clip_to_extent="1" force_rhr="0">',
      '      <layer class="SimpleFill" enabled="1" locked="0" pass="0">',
      '        <prop k="color" v="%s"/>',
      '        <prop k="outline_color" v="0,0,0,0"/>',
      '        <prop k="outline_style" v="solid"/>',
      '        <prop k="outline_width" v="0.26"/>',
      '        <prop k="outline_width_unit" v="MM"/>',
      '        <prop k="style" v="solid"/>',
      '      </layer>',
      '    </symbol>',
      sep = "\n"
    ),
    idx,
    hex_to_rgba(unname(colors))
  )

  paste(
    "<!DOCTYPE qgis PUBLIC 'http://mrcc.com/qgis.dtd' 'SYSTEM'>",
    '<qgis version="3.28" styleCategories="Symbology">',
    sprintf(
      '  <renderer-v2 attr="%s" type="categorizedSymbol" symbollevels="0" forceraster="0" enableorderby="0">',
      field
    ),
    "    <categories>",
    paste(categories, collapse = "\n"),
    "    </categories>",
    "    <symbols>",
    paste(symbols, collapse = "\n"),
    "    </symbols>",
    "  </renderer-v2>",
    "</qgis>",
    sep = "\n"
  )
}

fields <- c("CLASSE_USO", "HIDRO", "NATUREZA", "RIO")

for (field in fields) {
  path <- file.path(out_dir, paste0(field, ".qml"))
  con <- file(path, "w", encoding = "UTF-8")
  writeLines(build_categorized_qml(field), con)
  close(con)
  message("Gerado: ", path)
}
