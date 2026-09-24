reset_listing_cache <- function() {
  rm(
    list = ls(envir = geofbds:::listing_cache_env),
    envir = geofbds:::listing_cache_env
  )
}

test_that("fbds_cache_dir defaults to R_user_dir and creates it", {
  root <- withr::local_tempdir()
  withr::local_envvar(R_USER_CACHE_DIR = root)
  withr::local_options(geofbds.cache_dir = NULL)

  dir <- fbds_cache_dir()

  expect_equal(dir, tools::R_user_dir("geofbds", "cache"))
  expect_true(dir.exists(dir))
})

test_that("fbds_cache_dir asks before creating the directory interactively", {
  dir <- file.path(withr::local_tempdir(), "cache")
  withr::local_options(geofbds.cache_dir = dir, rlang_interactive = TRUE)

  testthat::local_mocked_bindings(
    askYesNo = function(...) FALSE,
    .package = "utils"
  )
  expect_message(
    expect_error(fbds_cache_dir(), class = "fbds_cache_declined"),
    "diretorio de cache"
  )
  expect_false(dir.exists(dir))

  testthat::local_mocked_bindings(
    askYesNo = function(...) TRUE,
    .package = "utils"
  )
  expect_message(out <- fbds_cache_dir(), "diretorio de cache")
  expect_equal(out, dir)
  expect_true(dir.exists(dir))
})

test_that("fbds_cache_set creates the directory and sets the option", {
  withr::local_options(geofbds.cache_dir = NULL)
  dir <- file.path(withr::local_tempdir(), "novo", "cache")

  expect_invisible(out <- fbds_cache_set(dir))
  expect_equal(out, dir)
  expect_true(dir.exists(dir))
  expect_equal(getOption("geofbds.cache_dir"), dir)
})

test_that("fbds_cache_status inventories the cache directory", {
  dir <- withr::local_tempdir()
  withr::local_options(geofbds.cache_dir = dir)

  empty <- fbds_cache_status()
  expect_equal(nrow(empty), 0L)
  expect_named(empty, c("path", "bytes", "modified"))
  expect_type(empty$path, "character")
  expect_s3_class(empty$modified, "POSIXct")

  dir.create(file.path(dir, "listings", "RO"), recursive = TRUE)
  writeLines("abc", file.path(dir, "listings", "RO", "app.rds"))
  writeLines("abcdef", file.path(dir, "outro.txt"))

  out <- fbds_cache_status()
  expect_equal(nrow(out), 2L)
  expect_setequal(basename(out$path), c("app.rds", "outro.txt"))
  expect_true(all(out$bytes > 0))
})

test_that("fbds_cache_clean('listings') keeps the rest of the cache", {
  dir <- withr::local_tempdir()
  withr::local_options(geofbds.cache_dir = dir)
  dir.create(file.path(dir, "listings", "RO"), recursive = TRUE)
  writeLines("x", file.path(dir, "listings", "RO", "app.rds"))
  writeLines("x", file.path(dir, "download.zip"))
  assign("chave", "valor", envir = geofbds:::listing_cache_env)

  expect_message(fbds_cache_clean(), "Cache limpo")

  expect_true(dir.exists(file.path(dir, "listings")))
  expect_length(list.files(file.path(dir, "listings"), recursive = TRUE), 0L)
  expect_true(file.exists(file.path(dir, "download.zip")))
  expect_length(ls(envir = geofbds:::listing_cache_env), 0L)
})

test_that("fbds_cache_clean('all') removes the whole cache directory", {
  dir <- file.path(withr::local_tempdir(), "cache")
  dir.create(file.path(dir, "listings"), recursive = TRUE)
  writeLines("x", file.path(dir, "download.zip"))
  withr::local_options(geofbds.cache_dir = dir)

  expect_message(fbds_cache_clean("all"), "Cache limpo")
  expect_false(dir.exists(dir))
})

test_that("get_listing_cached serves a fresh listing from disk without the network", {
  dir <- withr::local_tempdir()
  withr::local_options(
    geofbds.cache_dir = dir,
    # nothing listens here: any request would fail
    geofbds.base_url = "http://127.0.0.1:9",
    geofbds.retries = 0L
  )
  reset_listing_cache()
  withr::defer(reset_listing_cache())

  listing <- tibble::tibble(file = "RO_1100031_APP.shp", bytes = 10)
  disk_path <- file.path(dir, "listings", "RO", "CABIXI", "app.rds")
  dir.create(dirname(disk_path), recursive = TRUE)
  saveRDS(listing, disk_path)

  out <- geofbds:::get_listing_cached(
    "1100031",
    "RO",
    "CABIXI",
    "app",
    recursive = FALSE,
    cache = TRUE
  )
  expect_equal(out, listing)
  # promoted to the session cache
  expect_true(exists("1100031|app|FALSE", envir = geofbds:::listing_cache_env))
})

test_that("get_listing_cached refetches a listing older than the TTL", {
  dir <- withr::local_tempdir()
  withr::local_options(
    geofbds.cache_dir = dir,
    geofbds.base_url = "http://127.0.0.1:9",
    geofbds.retries = 0L,
    geofbds.listing_ttl = 7
  )
  reset_listing_cache()
  withr::defer(reset_listing_cache())

  disk_path <- file.path(dir, "listings", "RO", "CABIXI", "app.rds")
  dir.create(dirname(disk_path), recursive = TRUE)
  saveRDS(tibble::tibble(file = "velho.shp"), disk_path)
  Sys.setFileTime(disk_path, Sys.time() - 30 * 24 * 3600)

  # stale: goes to the (unreachable) network instead of the disk copy
  expect_error(
    geofbds:::get_listing_cached(
      "1100031",
      "RO",
      "CABIXI",
      "app",
      recursive = FALSE,
      cache = TRUE
    ),
    class = "fbds_http_error"
  )
})
