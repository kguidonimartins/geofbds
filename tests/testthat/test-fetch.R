# Network tests against a local webfakes server. See test-discover.R for
# why route handlers must be self-contained closures (webfakes runs the
# app in a separate process).

make_content_route <- function(bytes) {
  force(bytes)
  function(req, res) {
    res$set_type("application/octet-stream")$send(as.raw(rep(0L, bytes)))
  }
}

make_flaky_content_route <- function(fail_times, bytes) {
  force(fail_times)
  force(bytes)
  count <- 0L
  function(req, res) {
    count <<- count + 1L
    if (count <= fail_times) {
      res$set_status(500L)$send("retry me")
    } else {
      res$set_type("application/octet-stream")$send(as.raw(rep(0L, bytes)))
    }
  }
}

fetch_app <- webfakes::new_app()
fetch_app$get("/RO/CABIXI/APP/a.shp", make_content_route(3000L))
fetch_app$get("/RO/CABIXI/APP/b.shx", make_content_route(500L))
fetch_app$get("/RO/CABIXI/APP/c.dbf", make_content_route(200L))
fetch_app$get("/RO/CABIXI/APP/small.txt", make_content_route(10L))
fetch_app$get("/RO/CABIXI/APP/flaky.shp", make_flaky_content_route(1L, 1000L))
fetch_app$get(
  "/RO/CABIXI/APP/always-fails.shp",
  function(req, res) res$set_status(500L)$send("nope")
)

fetch_web <- webfakes::new_app_process(fetch_app)
withr::defer(fetch_web$stop(), teardown_env())
fetch_base_url <- sub("/$", "", fetch_web$url())

seed_listing <- function(geocode, layer, listing, recursive = FALSE) {
  key <- paste(geocode, layer, recursive, sep = "|")
  assign(key, listing, envir = geofbds:::listing_cache_env)
}

local_fetch_env <- function(.local_envir = parent.frame()) {
  withr::local_options(
    list(geofbds.base_url = fetch_base_url),
    .local_envir = .local_envir
  )
  rm(
    list = ls(envir = geofbds:::listing_cache_env),
    envir = geofbds:::listing_cache_env
  )
}

listing_for <- function(files) {
  tibble::tibble(
    file = names(files),
    url = paste0(fetch_base_url, "/RO/CABIXI/APP/", names(files)),
    bytes = unname(unlist(files)),
    modified = as.POSIXct("2023-08-23 17:37:00", tz = "UTC"),
    path = ""
  )
}

test_that("fbds_fetch downloads files and writes a manifest with sha256", {
  local_fetch_env()
  seed_listing(
    "1100031",
    "app",
    listing_for(list(
      "a.shp" = 3000L,
      "b.shx" = 500L,
      "c.dbf" = 200L
    ))
  )
  dest_dir <- withr::local_tempdir()

  plano <- fbds_plan("1100031", layers = "app", dest_dir = dest_dir)
  manifest <- fbds_fetch(plano, workers = 2, progress = FALSE)

  expect_equal(nrow(manifest), 3L)
  expect_true(all(manifest$status == "downloaded"))
  expect_true(all(!is.na(manifest$sha256)))
  expect_equal(manifest$bytes, c(3000, 500, 200))
  expect_true(file.exists(file.path(
    dest_dir,
    "_manifests",
    paste0(manifest$run_id[[1]], ".csv")
  )))
  expect_true(file.exists(file.path(dest_dir, "_manifests", "_index.csv")))
  expect_true(file.exists(file.path(dest_dir, "manifest.json")))

  summary <- fbds_manifest_status(dest_dir)
  expect_equal(summary$n_files, 3L)
  expect_equal(summary$bytes_total, 3700)
  expect_equal(summary$n_downloaded, 3L)
  expect_equal(summary$n_cached, 0L)
  expect_equal(summary$n_failed, 0L)
  expect_equal(summary$n_skipped, 0L)
  expect_equal(
    summary$pkg_version,
    as.character(utils::packageVersion("geofbds"))
  )
  expect_equal(summary$run_ids[[1]], manifest$run_id[[1]])

  manifest_on_disk <- jsonlite::read_json(
    file.path(dest_dir, "manifest.json"),
    simplifyVector = TRUE
  )
  expect_equal(as.integer(manifest_on_disk$n_files), 3L)
  expect_equal(manifest_on_disk$pkg_version, summary$pkg_version)

  manifest_json <- jsonlite::read_json(
    file.path(dest_dir, "manifest.json"),
    simplifyVector = FALSE
  )
  expect_type(manifest_json$run_ids, "list")
  expect_equal(manifest_json$run_ids[[1]], manifest$run_id[[1]])
})

test_that("fbds_fetch(dry_run = TRUE) touches no network and downloads nothing", {
  local_fetch_env()
  seed_listing("1100031", "app", listing_for(list("small.txt" = 10L)))
  dest_dir <- withr::local_tempdir()

  plano <- fbds_plan("1100031", layers = "app", dest_dir = dest_dir)
  manifest <- fbds_fetch(plano, dry_run = TRUE)

  expect_equal(manifest$status, "skipped")
  expect_false(file.exists(file.path(
    dest_dir,
    "RO/1100031/app/small.txt"
  )))
  expect_false(dir.exists(file.path(dest_dir, "_manifests")))
})

test_that("fbds_fetch retries a transient failure and succeeds", {
  local_fetch_env()
  seed_listing("1100031", "app", listing_for(list("flaky.shp" = 1000L)))
  dest_dir <- withr::local_tempdir()

  plano <- fbds_plan("1100031", layers = "app", dest_dir = dest_dir)
  manifest <- fbds_fetch(plano, retries = 2L, progress = FALSE)

  expect_equal(manifest$status, "downloaded")
  expect_equal(manifest$attempts, 2L)
})

test_that("fbds_fetch marks a file failed after exhausting retries", {
  local_fetch_env()
  seed_listing("1100031", "app", listing_for(list("always-fails.shp" = 1000L)))
  dest_dir <- withr::local_tempdir()

  plano <- fbds_plan("1100031", layers = "app", dest_dir = dest_dir)
  warned <- FALSE
  manifest <- withCallingHandlers(
    fbds_fetch(plano, retries = 1L, progress = FALSE),
    warning = function(w) {
      warned <<- TRUE
      invokeRestart("muffleWarning")
    }
  )

  expect_true(warned)
  expect_equal(manifest$status, "failed")
  expect_equal(manifest$attempts, 2L)
  expect_false(is.na(manifest$error))
})

test_that("fbds_fetch flags a size mismatch against the listing", {
  local_fetch_env()
  # listing claims 50000 bytes, server actually serves 3000 -> a
  # "truncated response" from the plan's perspective
  listing <- listing_for(list("a.shp" = 3000L))
  listing$bytes <- 50000
  seed_listing("1100031", "app", listing)
  dest_dir <- withr::local_tempdir()

  plano <- fbds_plan("1100031", layers = "app", dest_dir = dest_dir)
  msg <- NULL
  manifest <- withCallingHandlers(
    fbds_fetch(plano, progress = FALSE),
    warning = function(w) {
      msg <<- conditionMessage(w)
      invokeRestart("muffleWarning")
    }
  )

  expect_match(msg, "tamanho diferente")
  expect_equal(manifest$status, "downloaded")
  expect_equal(manifest$bytes, 3000)
  expect_equal(manifest$expected_bytes, 50000)
})

test_that("fbds_fetch rejects a non-fbds_plan argument", {
  expect_error(fbds_fetch(list()), class = "fbds_bad_plan")
})

test_that("fbds_download_municipality is a thin fbds_plan |> fbds_fetch wrapper", {
  local_fetch_env()
  seed_listing("1100031", "app", listing_for(list("c.dbf" = 200L)))
  dest_dir <- withr::local_tempdir()

  manifest <- fbds_download_municipality(
    "1100031",
    layers = "app",
    dest_dir = dest_dir,
    progress = FALSE
  )

  expect_equal(manifest$status, "downloaded")
  expect_equal(manifest$file, "c.dbf")
})
