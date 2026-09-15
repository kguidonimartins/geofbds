skip_if_not_installed("shiny")
skip_if_not_installed("leaflet")
skip_if_not_installed("sf")
skip_if_not_installed("bslib")

app_dir <- system.file("shiny", package = "geofbds")
if (!file.exists(file.path(app_dir, "helpers.R"))) {
  app_dir <- test_path("../../inst/shiny")
}
source(file.path(app_dir, "helpers.R"), local = TRUE)

test_that("the app filters one shapefile type and preserves its plan", {
  plan <- tibble::tibble(
    geocode = rep("1100031", 8),
    uf = rep("RO", 8),
    file = c(
      "RO_1100031_APP.shp",
      "RO_1100031_APP.shx",
      "RO_1100031_APP.dbf",
      "RO_1100031_APP.prj",
      "RO_1100031_NASCENTES.shp",
      "RO_1100031_NASCENTES.shx",
      "RO_1100031_NASCENTES.dbf",
      "RO_1100031_NASCENTES.prj"
    ),
    bytes = rep(1, 8),
    dest_path = file.path(tempdir(), "file"),
    action = rep("download", 8)
  )
  class(plan) <- c("fbds_plan", class(plan))
  attr(plan, "dest_dir") <- tempdir()
  attr(plan, "path_pattern") <- "{file}"

  selected <- shiny_filter_plan(plan, "APP")

  expect_s3_class(selected, "fbds_plan")
  expect_equal(selected$file, plan$file[1:4])
  expect_identical(attr(selected, "dest_dir"), attr(plan, "dest_dir"))
})

test_that("incomplete manifests are rejected before reading", {
  root <- withr::local_tempdir()
  files <- paste0("RO_1100031_APP.", c("shp", "shx", "dbf", "prj"))
  paths <- file.path(root, files)
  for (path in paths) {
    writeBin(charToRaw("x"), path)
  }
  manifest <- tibble::tibble(
    file = files,
    path = paths,
    status = rep("downloaded", length(files))
  )

  expect_true(shiny_manifest_complete(manifest))
  manifest$status[[2]] <- "failed"
  expect_false(shiny_manifest_complete(manifest))
})

test_that("thematic fields and palettes follow layer defaults", {
  data <- data.frame(
    MUNICIPIO = rep("SERRA DA SAUDADE", 3),
    CLASSE_USO = c("água", "formação florestal", "silvicultura"),
    AREA_HA = c(1, 4, 9),
    geometry = I(list(NULL, NULL, NULL))
  )
  attr(data, "sf_column") <- "geometry"

  expect_equal(
    shiny_default_theme_field("app", "APP_USO", data),
    "CLASSE_USO"
  )
  expect_setequal(
    shiny_thematic_fields(data),
    c("CLASSE_USO", "AREA_HA")
  )

  spec <- shiny_theme_spec(data, "app", "APP_USO")
  expect_equal(spec$field, "CLASSE_USO")
  expect_equal(spec$title, "Classe de uso")
  expect_length(spec$palette(data$CLASSE_USO), 3L)

  unknown <- shiny_theme_spec(
    data.frame(CATEGORIA = c("a", "b", "a")),
    "app",
    "UNKNOWN",
    field = "CATEGORIA"
  )
  expect_length(unknown$palette(unknown$values), 3L)

  single <- shiny_theme_spec(data, "app", "APP_USO", field = "")
  expect_null(single$field)
})

test_that("usage guidance follows the workflow", {
  steps <- shiny_usage_steps()

  expect_length(steps, 8L)
  expect_match(steps[[3]], "Descobrir tipos")
  expect_match(steps[[7]], "Baixar e visualizar")

  expect_match(
    shiny_next_step("selection")$message,
    "Descobrir tipos"
  )
  expect_match(
    shiny_next_step("type")$message,
    "Planejar consulta"
  )
  expect_match(
    shiny_next_step("plan")$message,
    "Baixar e visualizar"
  )
  expect_match(
    shiny_next_step("visualization")$message,
    "atributo temático"
  )
  expect_equal(
    shiny_next_step("unknown")$title,
    shiny_next_step("selection")$title
  )
})

test_that("structured logs include event context", {
  messages <- character()
  withCallingHandlers(
    shiny_log(
      "test_event",
      session_id = "session-1",
      municipality = "1100015",
      selected = c("app", "APP")
    ),
    message = function(condition) {
      messages <<- c(messages, conditionMessage(condition))
      invokeRestart("muffleMessage")
    }
  )

  expect_length(messages, 1L)
  expect_match(messages[[1]], "\\[geofbds-shiny\\].*event=test_event")
  expect_match(messages[[1]], "session_id=session-1")
  expect_match(messages[[1]], "selected=app,APP")
})
test_that("the about panel documents provenance, contact and limits", {
  html <- as.character(shiny_about_ui(
    geofbds::fbds_layers(),
    max_bytes = 250 * 1024^2,
    max_features = 250000,
    package_version = "0.0.0.9000"
  ))

  expect_match(html, "https://geo.fbds.org.br", fixed = TRUE)
  expect_match(
    html,
    "https://geo.fbds.org.br/Metadados%20Mapeamento%20FBDS.pdf",
    fixed = TRUE
  )
  expect_match(html, "1:25.000", fixed = TRUE)
  expect_match(html, "Irrestrito", fixed = TRUE)
  expect_match(html, "mailto:kguidonimartins@gmail.com", fixed = TRUE)
  expect_match(
    html,
    "https://github.com/kguidonimartins/geofbds",
    fixed = TRUE
  )
  expect_match(html, "0.0.0.9000", fixed = TRUE)
  expect_match(html, "250.0 MB", fixed = TRUE)
  expect_match(html, "250.000", fixed = TRUE)
  expect_match(html, "hidrografia", fixed = TRUE)
})

test_that("invalid geometries are repaired before mapping", {
  invalid <- sf::st_sf(
    id = 1L,
    geometry = sf::st_sfc(sf::st_polygon(list(rbind(
      c(0, 0),
      c(1, 1),
      c(1, 0),
      c(0, 1),
      c(0, 0)
    ))))
  )

  expect_false(sf::st_is_valid(invalid)[[1]])
  repaired <- shiny_prepare_geometry(invalid)
  expect_true(all(sf::st_is_valid(repaired)))
})

test_that("the deployable app exposes a Shiny UI and server", {
  app_dir <- normalizePath(app_dir)
  withr::local_dir(app_dir)
  app_env <- new.env(parent = globalenv())
  sys.source("app.R", envir = app_env)

  expect_s3_class(app_env$ui, "shiny.tag.list")
  expect_type(app_env$server, "closure")
})
