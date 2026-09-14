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

# 11 municipios do Piauí tem o nome corrompido na planilha de origem: letras
# acentuadas (Ã, Í, Ó, É) viraram minusculas soltas ou sumiram (ex.
# "BOQUEIRlO DO PIAUÍ" em vez de "BOQUEIRÃO DO PIAUÍ"). Confirmado nos bytes
# brutos da celula -- nao e um problema de leitura do readxl, o defeito esta
# no .xls. slug derivado do nome corrompido nao batia com o portal
# (data-raw/verify_slugs.R marcava esses 11 como "missing"). Nomes corretos
# conferidos contra a API do IBGE
# (https://servicodados.ibge.gov.br/api/v1/localidades/municipios/{geocode})
# e o slug derivado deles confirmado contra o portal (ver
# data-raw/slug_check.csv).
corrupted_names <- c(
  "2201945" = "BOQUEIRÃO DO PIAUÍ",
  "2202539" = "CARAÚBAS DO PIAUÍ",
  "2202653" = "CAXINGÓ",
  "2203420" = "DOMINGOS MOURÃO",
  "2205573" = "LAGOA DE SÃO FRANCISCO",
  "2206100" = "MATIAS OLÍMPIO",
  "2206357" = "MILTON BRANDÃO",
  "2206753" = "NOSSA SENHORA DE NAZARÉ",
  "2209872" = "SÃO JOÃO DA FRONTEIRA",
  "2209971" = "SÃO JOÃO DO ARRAIAL",
  "2210052" = "SÃO JOSÉ DO DIVINO"
)
municipality <- raw[["...2"]]
fix_idx <- match(names(corrupted_names), geocode)
municipality[fix_idx] <- corrupted_names

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
  municipality = municipality,
  uf = raw[["...3"]],
  uf_code = substr(geocode, 1, 2)
) |>
  dplyr::bind_cols(area_data) |>
  dplyr::mutate(
    slug = toupper(janitor::make_clean_names(.data$municipality)),
    slug_status = "unverified"
  )

# Fase 2 (data-raw/verify_slugs.R): incorpora o slug confirmado contra o
# portal, quando disponivel. Municipios ainda nao verificados mantem o
# slug derivado do nome e slug_status = "unverified".
slug_check_path <- "data-raw/slug_check.csv"
if (file.exists(slug_check_path)) {
  slug_check <- vroom::vroom(
    slug_check_path,
    col_types = vroom::cols(
      geocode = "c",
      slug_tentado = "c",
      http_status = "d",
      slug_final = "c"
    )
  )

  fbds_municipios <- fbds_municipios |>
    dplyr::left_join(
      dplyr::select(slug_check, "geocode", "slug_final"),
      by = "geocode"
    ) |>
    dplyr::mutate(
      slug_status = dplyr::case_when(
        is.na(.data$slug_final) & .data$geocode %in% slug_check$geocode ~
          "missing",
        .data$slug_final == .data$slug ~ "ok",
        !is.na(.data$slug_final) ~ "fixed",
        .default = .data$slug_status
      ),
      slug = dplyr::coalesce(.data$slug_final, .data$slug)
    ) |>
    dplyr::select(-"slug_final")
}

usethis::use_data(fbds_municipios, overwrite = TRUE)
