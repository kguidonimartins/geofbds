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

shiny_known_colors <- function(field) {
  switch(
    field,
    CLASSE_USO = c(
      "água" = "#3182bd",
      "área antropizada" = "#e6550d",
      "área edificada" = "#de2d26",
      "formação florestal" = "#006d2c",
      "formação não florestal" = "#74c476",
      "silvicultura" = "#238b8d"
    ),
    HIDRO = c(
      "curso d'água (0 - 10m)" = "#6baed6",
      "curso d'água (10 - 50m)" = "#08519c",
      "massa d'água" = "#31a8c8",
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

  domain <- as.character(domain)
  known <- shiny_known_colors(field)
  fallback <- c(
    "#1b9e77",
    "#d95f02",
    "#7570b3",
    "#e7298a",
    "#66a61e",
    "#e6ab02",
    "#a6761d",
    "#666666"
  )
  colors <- if (is.null(known)) {
    rep(NA_character_, length(domain))
  } else {
    unname(known[domain])
  }
  missing <- is.na(colors) | !nzchar(colors)
  colors[missing] <- rep(
    fallback,
    length.out = sum(missing)
  )

  list(
    mode = "categorical",
    palette = leaflet::colorFactor(
      palette = colors,
      domain = domain,
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
