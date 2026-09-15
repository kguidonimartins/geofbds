if (!requireNamespace("shiny", quietly = TRUE)) {
  stop("Instale o pacote 'shiny' para executar o aplicativo.", call. = FALSE)
}
if (!requireNamespace("leaflet", quietly = TRUE)) {
  stop("Instale o pacote 'leaflet' para executar o aplicativo.", call. = FALSE)
}
if (!requireNamespace("bslib", quietly = TRUE)) {
  stop("Instale o pacote 'bslib' para executar o aplicativo.", call. = FALSE)
}
if (!requireNamespace("sf", quietly = TRUE)) {
  stop("Instale o pacote 'sf' para executar o aplicativo.", call. = FALSE)
}
if (!requireNamespace("geofbds", quietly = TRUE)) {
  stop(
    "Instale o pacote 'geofbds' antes de executar o aplicativo.",
    call. = FALSE
  )
}

source("helpers.R", local = TRUE)

app_config <- list(
  max_bytes = shiny_env_number(
    "GEOFBDS_SHINY_MAX_BYTES",
    250 * 1024^2
  ),
  max_features = shiny_env_number(
    "GEOFBDS_SHINY_MAX_FEATURES",
    250000
  )
)

catalog <- geofbds::fbds_catalog()
municipality_choices <- stats::setNames(
  catalog$geocode,
  sprintf("%s — %s (%s)", catalog$municipality, catalog$uf, catalog$geocode)
)
layer_info <- geofbds::fbds_layers()
layer_choices <- stats::setNames(layer_info$layer, layer_info$description)
shiny_log(
  "app_loaded",
  municipalities = nrow(catalog),
  max_bytes = app_config$max_bytes,
  max_features = app_config$max_features
)

app_theme <- bslib::bs_theme(
  version = 5,
  bootswatch = "flatly",
  primary = "#1b9e77"
)

ui <- bslib::page_sidebar(
  theme = app_theme,
  title = "Explorador Geo FBDS",
  fillable = FALSE,
  sidebar = bslib::sidebar(
    width = 400,
    bslib::input_dark_mode(),
    bslib::accordion(
      open = TRUE,
      bslib::accordion_panel(
        "Como usar",
        shiny::tags$ol(
          lapply(
            shiny_usage_steps(),
            function(step) shiny::tags$li(step)
          )
        )
      )
    ),
    shiny::uiOutput("next_step"),
    shiny::selectizeInput(
      "municipality",
      "Município",
      choices = NULL,
      selected = NULL,
      options = list(placeholder = "Digite para buscar...")
    ),
    shiny::selectInput("layer", "Camada", choices = layer_choices),
    shiny::actionButton("discover", "Descobrir tipos", class = "btn-primary"),
    shiny::selectInput(
      "type",
      "Tipo do conjunto",
      choices = NULL,
      selected = NULL
    ),
    shiny::actionButton("plan", "Planejar consulta"),
    shiny::actionButton(
      "download_data",
      "Baixar e visualizar",
      class = "btn-success"
    ),
    shiny::uiOutput("theme_ui"),
    shiny::uiOutput("limits"),
    shiny::verbatimTextOutput("status")
  ),
  bslib::card(
    bslib::card_header("Plano"),
    shiny::verbatimTextOutput("plan_summary")
  ),
  shiny::uiOutput("download_ui"),
  bslib::card(
    bslib::card_header("Mapa"),
    leaflet::leafletOutput("map", height = "650px")
  ),
  bslib::card(
    bslib::card_header("Estatísticas"),
    shiny::tableOutput("stats")
  )
)

server <- function(input, output, session) {
  session_dir <- tempfile("geofbds-session-")
  dir.create(session_dir, recursive = TRUE, showWarnings = FALSE)
  session_id <- basename(session_dir)
  log_event <- function(event, ...) {
    shiny_log(event, session_id = session_id, ...)
  }
  log_event("session_started")
  session$onSessionEnded(function() {
    log_event("session_ended")
    unlink(session_dir, recursive = TRUE, force = TRUE)
  })

  values <- shiny::reactiveValues(
    files = NULL,
    plan = NULL,
    manifest = NULL,
    data = NULL,
    step = "selection",
    status = "Escolha um município e descubra os tipos disponíveis."
  )
  log_event(
    "initial_selection",
    municipality = catalog$geocode[[1]],
    layer = layer_info$layer[[1]]
  )

  shiny::updateSelectizeInput(
    session,
    "municipality",
    choices = municipality_choices,
    selected = catalog$geocode[[1]],
    server = TRUE
  )

  set_status <- function(message) {
    values$status <- message
    log_event("status_changed", message = message)
  }

  set_step <- function(step) {
    values$step <- step
    log_event("step_changed", step = step)
  }

  with_session_cache <- function(code) {
    old <- options(geofbds.cache_dir = session_dir)
    on.exit(options(old), add = TRUE)
    force(code)
  }

  clear_results <- function() {
    log_event(
      "results_cleared",
      had_plan = !is.null(values$plan),
      had_manifest = !is.null(values$manifest),
      had_data = !is.null(values$data)
    )
    values$plan <- NULL
    values$manifest <- NULL
    values$data <- NULL
  }

  show_error <- function(error) {
    previous_step <- values$step
    clear_results()
    fallback <- switch(
      previous_step,
      discovering = "selection",
      planning = "type",
      downloading = "plan",
      previous_step
    )
    set_step(fallback)
    set_status(paste("Erro:", conditionMessage(error)))
    log_event(
      "error",
      class = paste(class(error), collapse = ","),
      message = conditionMessage(error)
    )
    shiny::showNotification(
      conditionMessage(error),
      type = "error",
      duration = NULL
    )
  }

  shiny::observeEvent(
    list(input$municipality, input$layer),
    {
      log_event(
        "selection_changed",
        municipality = input$municipality,
        layer = input$layer
      )
      if (
        is.null(values$files) &&
          is.null(values$plan) &&
          identical(input$municipality, catalog$geocode[[1]]) &&
          identical(input$layer, layer_info$layer[[1]])
      ) {
        return()
      }
      values$files <- NULL
      clear_results()
      set_step("selection")
      set_status("A consulta mudou. Descubra os tipos novamente.")
    },
    ignoreInit = TRUE
  )

  shiny::observeEvent(
    input$type,
    {
      log_event("type_changed", type = input$type)
      if (!is.null(values$plan)) {
        clear_results()
        set_status("O tipo mudou. Planeje a consulta novamente.")
      }
      if (!is.null(values$files)) {
        set_step("type")
      }
    },
    ignoreInit = TRUE
  )

  shiny::observeEvent(
    input$theme_field,
    {
      log_event(
        "theme_field_changed",
        field = input$theme_field,
        data_rows = if (is.null(values$data)) 0L else nrow(values$data)
      )
    },
    ignoreInit = TRUE
  )

  shiny::observeEvent(input$discover, {
    log_event(
      "discover_clicked",
      municipality = input$municipality,
      layer = input$layer
    )
    values$files <- NULL
    clear_results()
    shiny::req(input$municipality, input$layer)
    set_step("discovering")
    set_status("Descobrindo arquivos no portal...")
    tryCatch(
      {
        files <- shiny::withProgress(
          message = "Descobrindo arquivos",
          value = 0,
          {
            found <- with_session_cache(geofbds::fbds_files(
              input$municipality,
              layers = input$layer,
              cache = FALSE
            ))
            shiny::incProgress(1, detail = "Identificando conjuntos")
            found
          }
        )

        shp <- files[files$ext == "shp", , drop = FALSE]
        if (nrow(shp) == 0L) {
          stop(
            "Nenhum shapefile foi encontrado para essa combinação.",
            call. = FALSE
          )
        }
        types <- unique(shiny_shapefile_type(
          shp$file,
          shp$uf,
          shp$geocode
        ))
        values$files <- files
        set_step("type")
        log_event(
          "discovery_completed",
          files = nrow(files),
          shapefiles = nrow(shp),
          types = types
        )
        shiny::updateSelectizeInput(
          session,
          "type",
          choices = types,
          selected = types[[1]],
          server = TRUE
        )
        set_status(sprintf(
          "Descoberta concluída: %d arquivo(s), %d tipo(s).",
          nrow(files),
          length(types)
        ))
      },
      error = show_error
    )
  })

  shiny::observeEvent(input$plan, {
    log_event(
      "plan_clicked",
      municipality = input$municipality,
      layer = input$layer,
      type = input$type,
      files_available = !is.null(values$files)
    )
    shiny::req(input$municipality, input$layer, input$type)
    if (is.null(values$files)) {
      show_error(structure(
        list(message = "Descubra os tipos antes de planejar a consulta."),
        class = c("simpleError", "error", "condition")
      ))
      return()
    }

    set_step("planning")
    clear_results()
    set_status("Planejando arquivos e verificando o limite de tamanho...")
    tryCatch(
      {
        plan <- shiny::withProgress(
          message = "Planejando consulta",
          value = 0,
          {
            all_files <- with_session_cache(geofbds::fbds_plan(
              input$municipality,
              layers = input$layer,
              dest_dir = session_dir,
              skip_existing = TRUE
            ))
            shiny::incProgress(0.7, detail = "Selecionando o tipo")
            shiny_filter_plan(all_files, input$type)
          }
        )

        if (nrow(plan) == 0L) {
          stop(
            "Nenhum arquivo do tipo selecionado foi encontrado.",
            call. = FALSE
          )
        }
        if (anyNA(plan$bytes)) {
          stop(
            "A consulta foi recusada porque o portal não informou o tamanho de algum arquivo.",
            call. = FALSE
          )
        }
        expected_bytes <- sum(plan$bytes)
        if (expected_bytes > app_config$max_bytes) {
          stop(
            sprintf(
              "A consulta foi recusada: volume previsto de %s excede o limite de %s.",
              shiny_format_bytes(expected_bytes),
              shiny_format_bytes(app_config$max_bytes)
            ),
            call. = FALSE
          )
        }
        values$plan <- plan
        set_step("plan")
        log_event(
          "plan_completed",
          type = input$type,
          files = nrow(plan),
          expected_bytes = expected_bytes
        )
        set_status(sprintf(
          "Plano pronto: %d arquivo(s), volume previsto de %s.",
          nrow(plan),
          shiny_format_bytes(expected_bytes)
        ))
      },
      error = show_error
    )
  })

  shiny::observeEvent(input$download_data, {
    log_event(
      "download_clicked",
      municipality = input$municipality,
      layer = input$layer,
      type = input$type,
      plan_files = if (is.null(values$plan)) 0L else nrow(values$plan)
    )
    shiny::req(values$plan)
    values$manifest <- NULL
    values$data <- NULL
    set_step("downloading")
    set_status("Baixando arquivos...")
    tryCatch(
      {
        shiny::withProgress(
          message = "Executando consulta",
          value = 0,
          {
            manifest <- with_session_cache(geofbds::fbds_fetch(
              values$plan,
              progress = FALSE
            ))
            manifest_status <- table(manifest$status)
            log_event(
              "fetch_completed",
              files = nrow(manifest),
              statuses = paste(
                names(manifest_status),
                as.integer(manifest_status),
                sep = ":",
                collapse = ","
              )
            )
            shiny::incProgress(0.65, detail = "Validando conjuntos")
            withCallingHandlers(
              geofbds::fbds_validate(manifest),
              warning = function(w) {
                log_event(
                  "validation_warning",
                  message = conditionMessage(w)
                )
                shiny::showNotification(conditionMessage(w), type = "warning")
                invokeRestart("muffleWarning")
              }
            )
            if (!shiny_manifest_complete(manifest)) {
              stop(
                "A consulta falhou ou produziu um shapefile incompleto; nada será exibido.",
                call. = FALSE
              )
            }

            shiny::incProgress(0.8, detail = "Lendo geometrias")
            sf_data <- geofbds::fbds_read(
              manifest,
              layer = input$layer,
              type = input$type,
              crs = 4326
            )
            log_event(
              "data_read",
              rows = nrow(sf_data),
              columns = names(sf_data),
              geometry_types = unique(as.character(
                sf::st_geometry_type(sf_data)
              )),
              crs = sf::st_crs(sf_data)$epsg
            )
            if (nrow(sf_data) > app_config$max_features) {
              stop(
                sprintf(
                  "A consulta foi recusada: %s feições excedem o limite de %s.",
                  format(
                    nrow(sf_data),
                    big.mark = ".",
                    decimal.mark = ",",
                    scientific = FALSE
                  ),
                  format(
                    app_config$max_features,
                    big.mark = ".",
                    decimal.mark = ",",
                    scientific = FALSE
                  )
                ),
                call. = FALSE
              )
            }

            shiny::incProgress(
              0.95,
              detail = "Simplificando geometrias para o mapa"
            )
            values$manifest <- manifest
            values$data <- shiny_prepare_geometry(sf_data)
            log_event(
              "data_loaded",
              rows = nrow(values$data),
              columns = names(values$data),
              geometry_types = unique(as.character(
                sf::st_geometry_type(values$data)
              )),
              crs = sf::st_crs(values$data)$epsg
            )
          }
        )
        set_step("visualization")
        set_status(sprintf(
          "Consulta concluída: %d feição(ões) carregada(s).",
          nrow(values$data)
        ))
      },
      error = show_error
    )
  })

  output$next_step <- shiny::renderUI({
    info <- shiny_next_step(values$step)
    bslib::card(
      bslib::card_body(
        shiny::tags$strong(info$title),
        shiny::tags$p(info$message, class = "mb-0")
      )
    )
  })

  output$limits <- shiny::renderUI({
    shiny::tagList(
      shiny::tags$strong("Limites da sessão"),
      shiny::tags$small(shiny::HTML(sprintf(
        "<br>1 município · 1 camada · 1 tipo<br>Volume máximo: %s<br>Feições máximas: %s",
        shiny_format_bytes(app_config$max_bytes),
        format(
          app_config$max_features,
          big.mark = ".",
          decimal.mark = ",",
          scientific = FALSE
        )
      )))
    )
  })
  output$theme_ui <- shiny::renderUI({
    shiny::req(values$data)
    fields <- shiny_thematic_fields(values$data)
    preferred <- shiny_default_theme_field(
      input$layer,
      input$type,
      values$data
    )
    choices <- c("Cor única" = "", stats::setNames(fields, fields))
    log_event(
      "theme_options_rendered",
      fields = fields,
      preferred = preferred,
      rows = nrow(values$data)
    )
    shiny::tagList(
      shiny::selectInput(
        "theme_field",
        "Colorir por atributo",
        choices = choices,
        selected = if (is.null(preferred)) "" else preferred
      ),
      shiny::helpText(
        "Campos categóricos usam cores distintas; campos numéricos usam escala contínua."
      )
    )
  })

  output$status <- shiny::renderText(values$status)
  output$plan_summary <- shiny::renderText({
    if (is.null(values$plan)) {
      return("Nenhum plano criado.")
    }
    paste(format(values$plan), collapse = "\n")
  })

  output$download_ui <- shiny::renderUI({
    if (is.null(values$manifest)) {
      return(NULL)
    }
    shiny::downloadButton("download_zip", "Baixar ZIP validado")
  })

  output$download_zip <- shiny::downloadHandler(
    filename = function() {
      sprintf("geofbds-%s-%s.zip", input$municipality, input$type)
    },
    content = function(file) {
      log_event(
        "zip_download_started",
        file = file,
        municipality = input$municipality,
        layer = input$layer,
        type = input$type,
        manifest_files = nrow(values$manifest)
      )
      shiny_zip_manifest(values$manifest, file)
      log_event("zip_download_completed", file = file)
    }
  )

  output$stats <- shiny::renderTable({
    shiny::req(values$data)
    data <- values$data
    geometry_types <- unique(as.character(sf::st_geometry_type(data)))
    log_event(
      "stats_rendered",
      rows = nrow(data),
      geometry_types = geometry_types
    )
    data.frame(
      Métrica = c("Feições", "Geometrias", "Município", "Camada", "Tipo"),
      Valor = c(
        format(
          nrow(data),
          big.mark = ".",
          decimal.mark = ",",
          scientific = FALSE
        ),
        paste(geometry_types, collapse = ", "),
        input$municipality,
        input$layer,
        input$type
      ),
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
  })

  output$map <- leaflet::renderLeaflet({
    shiny::req(values$data)
    data <- values$data
    geometry_types <- as.character(sf::st_geometry_type(data))
    theme <- shiny_theme_spec(
      data,
      layer = input$layer,
      type = input$type,
      field = input$theme_field
    )
    log_event(
      "map_render_started",
      rows = nrow(data),
      field = theme$field,
      mode = theme$mode,
      palette_available = !is.null(theme$palette),
      geometry_types = unique(geometry_types)
    )
    colors <- rep("#2c7fb8", nrow(data))
    if (!is.null(theme$field)) {
      colors <- theme$palette(theme$values)
    }
    popup <- shiny_popup_values(data, theme$field)

    map <- leaflet::leaflet(
      options = leaflet::leafletOptions(preferCanvas = TRUE)
    )
    map <- leaflet::addProviderTiles(
      map,
      leaflet::providers$OpenStreetMap,
      group = "OpenStreetMap"
    )
    map <- leaflet::addProviderTiles(
      map,
      leaflet::providers$Esri.WorldImagery,
      group = "Esri.WorldImagery"
    )
    map <- leaflet::addLayersControl(
      map,
      baseGroups = c("OpenStreetMap", "Esri.WorldImagery"),
      options = leaflet::layersControlOptions(collapsed = FALSE)
    )

    polygon_idx <- grepl("POLYGON", geometry_types)
    line_idx <- grepl("LINESTRING", geometry_types)
    point_idx <- grepl("POINT", geometry_types)
    polygons <- data[polygon_idx, , drop = FALSE]
    lines <- data[line_idx, , drop = FALSE]
    points <- data[point_idx, , drop = FALSE]

    if (nrow(polygons) > 0L) {
      map <- leaflet::addPolygons(
        map,
        data = polygons,
        color = "#555555",
        weight = 0.5,
        fillColor = colors[polygon_idx],
        fillOpacity = 0.7,
        popup = popup[polygon_idx]
      )
    }
    if (nrow(lines) > 0L) {
      map <- leaflet::addPolylines(
        map,
        data = lines,
        color = colors[line_idx],
        weight = 2,
        popup = popup[line_idx]
      )
    }
    if (nrow(points) > 0L) {
      map <- leaflet::addCircleMarkers(
        map,
        data = points,
        radius = 3,
        color = colors[point_idx],
        fillColor = colors[point_idx],
        stroke = FALSE,
        fillOpacity = 0.7,
        popup = popup[point_idx]
      )
    }

    if (!is.null(theme$field)) {
      legend_values <- theme$values[!is.na(theme$values)]
      if (is.numeric(legend_values)) {
        legend_values <- legend_values[is.finite(legend_values)]
      }
      if (length(legend_values) > 0L) {
        map <- leaflet::addLegend(
          map,
          position = "bottomright",
          pal = theme$palette,
          values = legend_values,
          title = theme$title,
          opacity = 0.8
        )
      }
    }

    bbox <- sf::st_bbox(data)
    if (all(is.finite(bbox))) {
      map <- leaflet::fitBounds(
        map,
        lng1 = bbox[["xmin"]],
        lat1 = bbox[["ymin"]],
        lng2 = bbox[["xmax"]],
        lat2 = bbox[["ymax"]]
      )
    }
    log_event(
      "map_render_completed",
      rows = nrow(data),
      field = theme$field,
      legend = !is.null(theme$field)
    )
    map
  })
}

shiny::shinyApp(ui, server)
