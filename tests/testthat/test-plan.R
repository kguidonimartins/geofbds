# Offline: seeds the session listing cache directly (same key format
# get_listing_cached() uses) so fbds_plan() never touches the network.

seed_listing <- function(geocode, layer, listing, recursive = FALSE) {
  key <- paste(geocode, layer, recursive, sep = "|")
  assign(key, listing, envir = geofbds:::listing_cache_env)
}

withr::defer(
  rm(
    list = ls(envir = geofbds:::listing_cache_env),
    envir = geofbds:::listing_cache_env
  ),
  teardown_env()
)

cabixi_app_listing <- tibble::tibble(
  file = c("RO_1100031_APP.shp", "RO_1100031_APP.shx", "RO_1100031_APP.dbf"),
  url = paste0(
    "https://geo.fbds.org.br/RO/CABIXI/APP/",
    c("RO_1100031_APP.shp", "RO_1100031_APP.shx", "RO_1100031_APP.dbf")
  ),
  bytes = c(3080192, 47104, 1868800),
  modified = as.POSIXct("2023-08-23 17:37:00", tz = "UTC"),
  path = ""
)

test_that("fbds_plan builds destination paths from path_pattern", {
  seed_listing("1100031", "app", cabixi_app_listing)
  dest_dir <- withr::local_tempdir()

  plano <- fbds_plan("1100031", layers = "app", dest_dir = dest_dir)

  expect_s3_class(plano, "fbds_plan")
  expect_equal(nrow(plano), 3L)
  expect_equal(
    plano$dest_path[plano$file == "RO_1100031_APP.shp"],
    file.path(dest_dir, "RO/1100031/app/RO_1100031_APP.shp")
  )
  expect_true(all(plano$action == "download"))
})

test_that("fbds_plan supports a custom path_pattern", {
  seed_listing("1100031", "app", cabixi_app_listing)
  dest_dir <- withr::local_tempdir()

  plano <- fbds_plan(
    "1100031",
    layers = "app",
    dest_dir = dest_dir,
    path_pattern = "{geocode}/{file}"
  )

  expect_equal(
    plano$dest_path[plano$file == "RO_1100031_APP.shx"],
    file.path(dest_dir, "1100031/RO_1100031_APP.shx")
  )
})

test_that("fbds_plan folds a remote subdirectory into {file}", {
  nested_listing <- tibble::tibble(
    file = "mapa.pdf",
    url = "https://geo.fbds.org.br/RO/CABIXI/USO/MAPAS/mapa.pdf",
    bytes = 1024,
    modified = as.POSIXct("2023-08-23 17:38:00", tz = "UTC"),
    path = "MAPAS"
  )
  seed_listing("1100031", "uso", nested_listing, recursive = TRUE)
  dest_dir <- withr::local_tempdir()

  plano <- fbds_plan(
    "1100031",
    layers = "uso",
    dest_dir = dest_dir,
    recursive = TRUE
  )

  expect_equal(
    plano$dest_path,
    file.path(dest_dir, "RO/1100031/uso/MAPAS/mapa.pdf")
  )
})

test_that("fbds_plan marks a matching existing file to skip", {
  seed_listing("1100031", "app", cabixi_app_listing)
  dest_dir <- withr::local_tempdir()

  shp_path <- file.path(dest_dir, "RO/1100031/app/RO_1100031_APP.shp")
  dir.create(dirname(shp_path), recursive = TRUE)
  writeBin(raw(3080192), shp_path)

  plano <- fbds_plan("1100031", layers = "app", dest_dir = dest_dir)

  expect_equal(plano$action[plano$file == "RO_1100031_APP.shp"], "skip")
  expect_true(all(
    plano$action[plano$file != "RO_1100031_APP.shp"] == "download"
  ))
})

test_that("fbds_plan does not skip a file whose size is off by more than 1 KB", {
  seed_listing("1100031", "app", cabixi_app_listing)
  dest_dir <- withr::local_tempdir()

  shp_path <- file.path(dest_dir, "RO/1100031/app/RO_1100031_APP.shp")
  dir.create(dirname(shp_path), recursive = TRUE)
  writeBin(raw(3080192 - 5000), shp_path) # truncated

  plano <- fbds_plan("1100031", layers = "app", dest_dir = dest_dir)

  expect_equal(plano$action[plano$file == "RO_1100031_APP.shp"], "download")
})

test_that("fbds_plan(skip_existing = FALSE) always downloads", {
  seed_listing("1100031", "app", cabixi_app_listing)
  dest_dir <- withr::local_tempdir()

  shp_path <- file.path(dest_dir, "RO/1100031/app/RO_1100031_APP.shp")
  dir.create(dirname(shp_path), recursive = TRUE)
  writeBin(raw(3080192), shp_path)

  plano <- fbds_plan(
    "1100031",
    layers = "app",
    dest_dir = dest_dir,
    skip_existing = FALSE
  )

  expect_true(all(plano$action == "download"))
})

test_that("format/print.fbds_plan summarize municipalities, files and volume", {
  seed_listing("1100031", "app", cabixi_app_listing)
  dest_dir <- withr::local_tempdir()
  plano <- fbds_plan("1100031", layers = "app", dest_dir = dest_dir)

  out <- format(plano)
  expect_match(out[[1]], "1 municipio")
  expect_match(out[[1]], "3 arquivo")
  expect_output(print(plano), "fbds_plan")
})
