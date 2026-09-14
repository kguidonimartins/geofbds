# Gera `fbds_municipios`, o catalogo interno e congelado de municipios.
#
# Fonte: aba "Levantamento do Uso do Solo" de TABELA CONSOLIDADA.xls, com
# 5.470 municipios e 9 colunas. Este script roda uma unica vez por atualizacao
# do catalogo e nunca em tempo de execucao do pacote (SPECS.md §2.2-3).
#
# `slug` comeca como a melhor estimativa derivada do nome do municipio e
# `slug_status = "unverified"`. A Fase 2 do PLAN.md (data-raw/verify_slugs.R)
# confere cada slug contra o portal e este script volta a rodar gravando o
# slug verificado e o `slug_status` correspondente (`ok`/`fixed`/`missing`).

raw <- readxl::read_excel(
  "data-raw/TABELA CONSOLIDADA.xls",
  sheet = "Levantamento do Uso do Solo",
  skip = 2
)

geocode_num <- raw[["...1"]]
geocode <- sprintf("%07.0f", geocode_num)

if (anyNA(geocode_num) || anyNA(geocode) || any(nchar(geocode) != 7L)) {
  stop(
    "Geocodigo invalido na planilha de origem: encontrado NA ou valor que ",
    "nao converte para 7 digitos. Corrija TABELA CONSOLIDADA.xls antes de ",
    "regenerar o catalogo.",
    call. = FALSE
  )
}

area_cols_raw <- c(
  "Água",
  "Silvicultura",
  "Formação Florestal",
  "Formação não Florestal",
  "Área edificada",
  "Área antropizada"
)
area_cols_clean <- paste0(
  "area_",
  sub("^area_", "", janitor::make_clean_names(area_cols_raw))
)

area_data <- raw[area_cols_raw]
names(area_data) <- area_cols_clean

fbds_municipios <- tibble::tibble(
  geocode = geocode,
  municipality = raw[["...2"]],
  uf = raw[["...3"]],
  uf_code = substr(geocode, 1, 2)
) |>
  dplyr::bind_cols(area_data) |>
  dplyr::mutate(
    slug = toupper(janitor::make_clean_names(.data$municipality)),
    slug_status = "unverified"
  )

usethis::use_data(fbds_municipios, overwrite = TRUE)
