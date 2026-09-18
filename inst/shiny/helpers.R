shiny_log_value <- function(value) {
  if (length(value) == 0L) {
    return("<empty>")
  }
  if (is.data.frame(value)) {
    return(sprintf(
      "<data.frame:%d x %d>",
      nrow(value),
      ncol(value)
    ))
  }
  if (is.list(value)) {
    return(sprintf("<list:%d>", length(value)))
  }
  value <- as.character(value)
  value[is.na(value)] <- "NA"
  value <- paste(value, collapse = ",")
  gsub("[\r\n]+", " ", value)
}

shiny_log <- function(event, ...) {
  fields <- list(...)
  details <- character()
  if (length(fields) > 0L) {
    field_names <- names(fields)
    field_names[field_names == ""] <- "value"
    details <- paste(
      field_names,
      vapply(fields, shiny_log_value, character(1)),
      sep = "="
    )
  }
  timestamp <- format(
    Sys.time(),
    format = "%Y-%m-%dT%H:%M:%OS3Z",
    tz = "UTC"
  )
  suffix <- if (length(details) > 0L) {
    paste(c("", details), collapse = " ")
  } else {
    ""
  }
  message(sprintf(
    "[geofbds-shiny] %s event=%s%s",
    timestamp,
    event,
    suffix
  ))
  invisible(NULL)
}

shiny_env_number <- function(name, default) {
  value <- Sys.getenv(name, unset = "")
  if (!nzchar(value)) {
    return(default)
  }
  parsed <- suppressWarnings(as.numeric(value))
  if (is.na(parsed) || parsed <= 0) {
    warning(
      sprintf("Valor inválido para %s; usando o padrão.", name),
      call. = FALSE
    )
    return(default)
  }
  parsed
}

shiny_format_bytes <- function(bytes) {
  if (is.na(bytes)) {
    return("desconhecido")
  }
  units <- c("B", "KB", "MB", "GB")
  value <- as.numeric(bytes)
  unit <- 1L
  while (value >= 1024 && unit < length(units)) {
    value <- value / 1024
    unit <- unit + 1L
  }
  sprintf("%.1f %s", value, units[[unit]])
}

shiny_shapefile_type <- function(file, uf, geocode) {
  base <- tools::file_path_sans_ext(basename(file))
  prefix <- paste0(uf, "_", geocode, "_")
  type <- base
  has_prefix <- startsWith(base, prefix)
  type[has_prefix] <- substring(base[has_prefix], nchar(prefix) + 1L)
  type
}

shiny_filter_plan <- function(plan, type) {
  ext <- tolower(tools::file_ext(plan$file))
  set_id <- tools::file_path_sans_ext(basename(plan$file))
  file_type <- shiny_shapefile_type(plan$file, plan$uf, plan$geocode)
  shp_sets <- unique(set_id[ext == "shp" & file_type == type])
  keep <- set_id %in% shp_sets & ext %in% c("shp", "shx", "dbf", "prj", "cpg")
  out <- plan[keep, , drop = FALSE]

  attributes(out)$dest_dir <- attr(plan, "dest_dir")
  attributes(out)$path_pattern <- attr(plan, "path_pattern")
  attributes(out)$recursive <- attr(plan, "recursive")
  attributes(out)$created_at <- attr(plan, "created_at")
  class(out) <- class(plan)
  out
}

shiny_manifest_complete <- function(manifest) {
  if (!is.data.frame(manifest) || nrow(manifest) == 0L) {
    return(FALSE)
  }

  ok_status <- manifest$status %in% c("downloaded", "cached")
  if (!all(ok_status)) {
    return(FALSE)
  }

  ext <- tolower(tools::file_ext(manifest$file))
  set_id <- tools::file_path_sans_ext(basename(manifest$file))
  required <- c("shp", "shx", "dbf", "prj")
  sets <- unique(set_id[ext == "shp"])
  if (length(sets) == 0L) {
    return(FALSE)
  }

  all(vapply(
    sets,
    function(set) {
      rows <- manifest[set_id == set, , drop = FALSE]
      present <- unique(tolower(tools::file_ext(rows$file)))
      all(required %in% present) && all(file.exists(rows$path))
    },
    logical(1)
  ))
}

shiny_extract_map_geometry <- function(sf_data) {
  geometry_types <- as.character(sf::st_geometry_type(sf_data))
  is_collection <- geometry_types == "GEOMETRYCOLLECTION"
  if (!any(is_collection)) {
    return(sf_data)
  }
  target <- if (any(grepl("POLYGON", geometry_types))) {
    "POLYGON"
  } else if (any(grepl("LINESTRING", geometry_types))) {
    "LINESTRING"
  } else {
    "POINT"
  }
  ordinary <- sf_data[!is_collection, , drop = FALSE]
  collections <- sf::st_collection_extract(
    sf_data[is_collection, , drop = FALSE],
    target,
    warn = FALSE
  )
  rbind(ordinary, collections)
}

shiny_prepare_geometry <- function(sf_data, simplify_after = 10000L) {
  valid <- sf::st_is_valid(sf_data)
  if (any(!valid, na.rm = TRUE)) {
    sf_data <- sf::st_make_valid(sf_data)
  }
  sf_data <- shiny_extract_map_geometry(sf_data)
  if (nrow(sf_data) > simplify_after) {
    sf::st_simplify(
      sf_data,
      dTolerance = 0.0001,
      preserveTopology = TRUE
    )
  } else {
    sf_data
  }
}

shiny_default_theme_field <- function(layer, type, data) {
  preferred <- switch(
    paste(layer, type, sep = "/"),
    "app/APP" = "HIDRO",
    "app/APP_USO" = "CLASSE_USO",
    "uso/USO" = "CLASSE_USO",
    "hidrografia/MASSAS_DAGUA" = "NATUREZA",
    "hidrografia/RIOS_DUPLOS" = "AREA_HA",
    "hidrografia/RIOS_SIMPLES" = "COMP_KM",
    NULL
  )
  if (!is.null(preferred) && preferred %in% names(data)) {
    return(preferred)
  }
  NULL
}

shiny_thematic_fields <- function(data) {
  geometry_col <- attr(data, "sf_column")
  excluded <- c("MUNICIPIO", "CD_UF", "geocode", "uf", geometry_col)
  candidates <- setdiff(names(data), excluded)

  candidates[vapply(
    candidates,
    function(field) {
      value <- data[[field]]
      if (is.character(value) || is.factor(value) || is.logical(value)) {
        return(
          length(unique(value[!is.na(value)])) > 1L &&
            length(unique(value[!is.na(value)])) <= 30L
        )
      }
      if (is.numeric(value) || is.integer(value)) {
        return(length(unique(value[!is.na(value)])) > 1L)
      }
      FALSE
    },
    logical(1)
  )]
}

shiny_palette_for_field <- function(data, field) {
  value <- data[[field]]
  domain <- unique(value[!is.na(value)])
  is_categorical <- is.character(value) ||
    is.factor(value) ||
    is.logical(value) ||
    length(domain) <= 10L

  if (!is_categorical) {
    palette <- if (field == "COMP_KM") "Blues" else "YlGnBu"
    return(list(
      mode = "numeric",
      palette = leaflet::colorNumeric(
        palette = palette,
        domain = value,
        na.color = "#bdbdbd"
      ),
      values = value
    ))
  }

  colors <- geofbds::fbds_palette(field, value)

  list(
    mode = "categorical",
    palette = leaflet::colorFactor(
      palette = unname(colors),
      domain = names(colors),
      na.color = "#bdbdbd"
    ),
    values = value
  )
}

shiny_theme_spec <- function(data, layer, type, field = NULL) {
  available <- shiny_thematic_fields(data)
  if (identical(field, "")) {
    return(list(
      field = NULL,
      mode = "single",
      title = "Geometrias",
      palette = NULL,
      values = NULL
    ))
  }
  if (is.null(field)) {
    field <- shiny_default_theme_field(layer, type, data)
  }
  if (is.null(field) || !field %in% available) {
    return(list(
      field = NULL,
      mode = "single",
      title = "Geometrias",
      palette = NULL,
      values = NULL
    ))
  }

  palette <- shiny_palette_for_field(data, field)
  title <- if (field == "CLASSE_USO") {
    "Classe de uso"
  } else {
    field
  }
  c(list(field = field, title = title), palette)
}

shiny_popup_values <- function(data, field) {
  popup <- paste0("Município: ", data$geocode)
  if (!is.null(field) && field %in% names(data)) {
    values <- as.character(data[[field]])
    values[is.na(values)] <- "sem informação"
    popup <- paste0(
      popup,
      "<br>",
      field,
      ": ",
      htmltools::htmlEscape(values)
    )
  }
  popup
}

shiny_next_step <- function(step) {
  steps <- list(
    selection = list(
      title = "Próximo passo · seleção",
      message = "Escolha o município e a camada; depois clique em “Descobrir tipos”."
    ),
    discovering = list(
      title = "Próximo passo · descoberta",
      message = "Aguarde enquanto o aplicativo identifica os tipos disponíveis."
    ),
    type = list(
      title = "Próximo passo · tipo",
      message = "Escolha um tipo de conjunto e clique em “Planejar consulta”."
    ),
    planning = list(
      title = "Próximo passo · planejamento",
      message = "Aguarde enquanto o aplicativo estima os arquivos e o volume."
    ),
    plan = list(
      title = "Próximo passo · plano",
      message = "Confira o volume previsto e clique em “Baixar e visualizar”."
    ),
    downloading = list(
      title = "Próximo passo · download",
      message = "Aguarde o download, a validação e a leitura das geometrias."
    ),
    visualization = list(
      title = "Próximo passo · mapa",
      message = "Escolha um atributo temático ou explore o mapa e baixe o ZIP."
    )
  )
  if (!is.null(steps[[step]])) {
    return(steps[[step]])
  }
  steps$selection
}

shiny_usage_steps <- function() {
  c(
    "Escolha o município.",
    "Escolha a camada.",
    "Clique em “Descobrir tipos”.",
    "Escolha o tipo do conjunto.",
    "Clique em “Planejar consulta”.",
    "Confira o volume previsto.",
    "Clique em “Baixar e visualizar”.",
    "Escolha um atributo temático e explore o mapa."
  )
}

shiny_about_metadata <- function() {
  list(
    "Título" = "Mapeamento em Alta Resolução dos Biomas Brasileiros",
    "Autor" = "Fundação Brasileira para o Desenvolvimento Sustentável (FBDS)",
    "Temas" = paste(
      "uso e cobertura do solo; hidrografia; áreas de preservação",
      "permanente ripárias"
    ),
    "Período" = "01/01/2013 a 30/04/2023",
    "Resolução espacial" = "1:25.000",
    "Representação" = paste(
      "vetor (pontos, linhas e polígonos), shapefile articulado por UF e",
      "município"
    ),
    "Referência espacial" = "UTM, SIRGAS 2000 (elipsóide GRS 1980)",
    "Restrições legais" = "Irrestrito (metadados de 30/04/2023)",
    "Padrão dos metadados" = "ISO 19115:2003/19139"
  )
}

shiny_definition_list <- function(items) {
  shiny::tags$dl(
    class = "row",
    lapply(names(items), function(name) {
      shiny::tagList(
        shiny::tags$dt(class = "col-sm-4", name),
        shiny::tags$dd(class = "col-sm-8", items[[name]])
      )
    })
  )
}

shiny_layers_table <- function(layers) {
  shiny::tags$table(
    class = "table table-sm",
    shiny::tags$thead(
      shiny::tags$tr(
        shiny::tags$th("Camada"),
        shiny::tags$th("Diretório no portal"),
        shiny::tags$th("Conteúdo")
      )
    ),
    shiny::tags$tbody(
      lapply(seq_len(nrow(layers)), function(i) {
        shiny::tags$tr(
          shiny::tags$td(shiny::tags$code(layers$layer[[i]])),
          shiny::tags$td(shiny::tags$code(layers$dir[[i]])),
          shiny::tags$td(layers$description[[i]])
        )
      })
    )
  )
}

shiny_about_ui <- function(layers, max_bytes, max_features, package_version) {
  external <- function(href, label) {
    shiny::tags$a(href = href, target = "_blank", rel = "noopener", label)
  }
  metadata_url <- paste0(
    "https://geo.fbds.org.br/Metadados%20Mapeamento%20FBDS.pdf"
  )
  contact <- "kguidonimartins@gmail.com"
  repository <- "https://github.com/kguidonimartins/geofbds"
  feature_limit <- format(
    max_features,
    big.mark = ".",
    decimal.mark = ",",
    scientific = FALSE
  )

  bslib::layout_columns(
    col_widths = c(6, 6, 6, 6, 12),
    bslib::card(
      bslib::card_header("Origem dos dados"),
      bslib::card_body(
        shiny::tags$p(
          "Os dados são publicados pela Fundação Brasileira para o",
          "Desenvolvimento Sustentável (FBDS) no portal",
          external("https://geo.fbds.org.br", "Geo FBDS"),
          ", dentro do projeto “Mapeamento em Alta Resolução dos Biomas",
          "Brasileiros”. O geofbds não produz nem altera os dados:",
          "automatiza a descoberta, o download e a leitura dos shapefiles",
          "publicados por UF e município."
        ),
        shiny_definition_list(shiny_about_metadata()),
        shiny::tags$p(
          class = "mb-0",
          "Metadados oficiais:",
          external(metadata_url, "Metadados do Mapeamento FBDS (PDF)"),
          "."
        )
      )
    ),
    bslib::card(
      bslib::card_header("Camadas disponíveis"),
      bslib::card_body(
        shiny_layers_table(layers),
        shiny::tags$p(
          class = "mb-0",
          "Cada camada é distribuída em vários conjuntos de arquivos por",
          "município; use “Descobrir tipos” na aba Consulta para listar os",
          "tipos disponíveis para a sua seleção."
        )
      )
    ),
    bslib::card(
      bslib::card_header("Como citar"),
      bslib::card_body(
        shiny::tags$p(shiny::tags$strong("O pacote:")),
        shiny::tags$p(paste0(
          "Guidoni, K. (2026). geofbds: Download and Read Municipal Data ",
          "from Geo FBDS. R package. ",
          repository
        )),
        shiny::tags$p(shiny::tags$strong("Os dados:")),
        shiny::tags$p(paste0(
          "Fundação Brasileira para o Desenvolvimento Sustentável (FBDS) ",
          "(2023). Mapeamento em Alta Resolução dos Biomas Brasileiros. ",
          "https://geo.fbds.org.br"
        )),
        shiny::tags$p(
          class = "mb-0",
          shiny::tags$code("citation(\"geofbds\")"),
          "no R mostra as duas entradas prontas."
        )
      )
    ),
    bslib::card(
      bslib::card_header("Contato e código"),
      bslib::card_body(
        shiny::tags$p(
          "Dúvidas, correções, sugestões e problemas no download:",
          shiny::tags$a(href = paste0("mailto:", contact), contact),
          "ou uma",
          external(paste0(repository, "/issues"), "issue no GitHub"),
          "."
        ),
        shiny::tags$ul(
          class = "mb-0",
          shiny::tags$li(external(
            repository,
            "Código do pacote e do aplicativo"
          )),
          shiny::tags$li(external(
            "https://kguidonimartins.github.io/geofbds/",
            "Documentação do pacote"
          )),
          shiny::tags$li(external(
            "https://geo.fbds.org.br",
            "Portal Geo FBDS (dados e metodologia)"
          )),
          shiny::tags$li(external(
            metadata_url,
            "Metadados oficiais da FBDS"
          ))
        )
      )
    ),
    bslib::card(
      bslib::card_header("Sobre este aplicativo"),
      bslib::card_body(
        shiny::tags$p(
          paste0(
            "Esta interface é um aplicativo Shiny (tema Bootstrap 5 via ",
            "bslib) construído sobre o pacote geofbds versão ",
            package_version,
            ", instalado no servidor. O geofbds é um projeto independente: ",
            "não tem vínculo com a FBDS além de consumir os dados que ela ",
            "publica."
          ),
          " O código é aberto sob licença MIT e está em ",
          external(repository, "github.com/kguidonimartins/geofbds"),
          "."
        ),
        shiny::tags$p(
          "Cada sessão usa um diretório temporário próprio. Nenhum dado é",
          "persistido no servidor: ao encerrar a sessão, os arquivos",
          "baixados são removidos. Os limites por consulta são de ",
          shiny::tags$strong(shiny_format_bytes(max_bytes)),
          " e",
          shiny::tags$strong(feature_limit),
          "feições; eles podem ser ajustados no servidor com as variáveis",
          shiny::tags$code("GEOFBDS_SHINY_MAX_BYTES"),
          "e",
          shiny::tags$code("GEOFBDS_SHINY_MAX_FEATURES"),
          "."
        ),
        shiny::tags$p(
          "Os shapefiles são validados antes da leitura e o ZIP",
          "disponibilizado é o mesmo conjunto baixado do portal, sem",
          "recortes nem edições."
        ),
        shiny::tags$p(
          class = "mb-0",
          shiny::tags$em(
            "O campo “Restrições Legais” dos metadados oficiais da FBDS diz",
            "“Irrestrito”, mas confira os metadados antes de redistribuir ou",
            "usar os dados comercialmente. Este aplicativo não é fonte de",
            "aconselhamento jurídico."
          )
        )
      )
    )
  )
}

shiny_zip_manifest <- function(manifest, zip_path) {
  paths <- unique(manifest$path[manifest$status %in% c("downloaded", "cached")])
  if (length(paths) == 0L || any(!file.exists(paths))) {
    stop(
      "Os arquivos do conjunto nao estao disponiveis para download.",
      call. = FALSE
    )
  }

  staging <- tempfile("geofbds-download-")
  dir.create(staging, recursive = TRUE)
  on.exit(unlink(staging, recursive = TRUE, force = TRUE), add = TRUE)

  names <- basename(paths)
  if (anyDuplicated(names)) {
    names <- make.unique(names, sep = "-")
  }
  copied <- file.path(staging, names)
  ok <- file.copy(paths, copied, overwrite = TRUE)
  if (!all(ok)) {
    stop(
      "Nao foi possivel preparar todos os arquivos para download.",
      call. = FALSE
    )
  }

  old_wd <- setwd(staging)
  on.exit(setwd(old_wd), add = TRUE)
  utils::zip(zipfile = zip_path, files = names, flags = "-j", extras = "-q")
  if (!file.exists(zip_path)) {
    stop("Nao foi possivel criar o arquivo ZIP.", call. = FALSE)
  }
  invisible(zip_path)
}
