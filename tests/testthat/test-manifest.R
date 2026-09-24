test_that("fbds_manifest_status returns an empty typed tibble without history", {
  dest_dir <- withr::local_tempdir()

  out <- fbds_manifest_status(dest_dir)

  expect_equal(nrow(out), 0L)
  expect_named(
    out,
    c(
      "last_updated",
      "pkg_version",
      "n_files",
      "bytes_total",
      "n_downloaded",
      "n_cached",
      "n_failed",
      "n_skipped",
      "run_ids"
    )
  )
})

test_that("fbds_manifest_status reconstructs summaries from a legacy index", {
  dest_dir <- withr::local_tempdir()
  manifests_dir <- file.path(dest_dir, "_manifests")
  dir.create(manifests_dir)

  index <- tibble::tibble(
    run_id = c("run-1", "run-2"),
    timestamp = as.POSIXct(
      c("2026-09-20 12:00:00", "2026-09-21 12:00:00"),
      tz = "UTC"
    ),
    n_files = c(3L, 2L),
    n_downloaded = c(3L, 1L),
    n_cached = c(0L, 1L),
    n_failed = c(0L, 0L),
    n_skipped = c(0L, 0L),
    bytes = c(3700, 1200),
    path = c("run-1.csv", "run-2.csv")
  )
  vroom::vroom_write(
    index,
    file.path(manifests_dir, "_index.csv"),
    delim = ","
  )

  out <- fbds_manifest_status(dest_dir)

  expect_equal(out$n_files, 5L)
  expect_equal(out$bytes_total, 4900)
  expect_equal(out$n_downloaded, 4L)
  expect_equal(out$n_cached, 1L)
  expect_true(is.na(out$pkg_version))
  expect_equal(out$run_ids[[1]], c("run-1", "run-2"))
  expect_equal(
    format(out$last_updated, "%Y-%m-%d", tz = "UTC"),
    "2026-09-21"
  )
})

test_that("fbds_manifest_status returns an empty status for an empty legacy index", {
  dest_dir <- withr::local_tempdir()
  dir.create(file.path(dest_dir, "_manifests"))
  writeLines(
    "run_id,timestamp,n_files,n_downloaded,n_cached,n_failed,n_skipped,bytes,path",
    file.path(dest_dir, "_manifests", "_index.csv")
  )

  out <- fbds_manifest_status(dest_dir)
  expect_equal(out, geofbds:::empty_manifest_status())
})

test_that("manifest_summary_from_index parses text timestamps and tolerates all-NA", {
  index <- tibble::tibble(
    run_id = c("run-1", "run-2"),
    timestamp = c("2026-09-20 12:00:00", "2026-09-21 08:30:00"),
    n_files = 1L,
    n_downloaded = 1L,
    n_cached = 0L,
    n_failed = 0L,
    n_skipped = 0L,
    bytes = 10,
    pkg_version = c("0.0.0.9000", "")
  )

  out <- geofbds:::manifest_summary_from_index(index)
  expect_s3_class(out$last_updated, "POSIXct")
  expect_equal(
    format(out$last_updated, "%Y-%m-%d %H:%M", tz = "UTC"),
    "2026-09-21 08:30"
  )
  # an empty version string is ignored in favor of the last real one
  expect_equal(out$pkg_version, "0.0.0.9000")

  index$timestamp <- NA_character_
  out_na <- geofbds:::manifest_summary_from_index(index)
  expect_true(is.na(out_na$last_updated))
})

test_that("manifest.json round-trips a summary without timestamp or version", {
  dest_dir <- withr::local_tempdir()
  summary <- tibble::tibble(
    last_updated = as.POSIXct(NA, tz = "UTC"),
    pkg_version = NA_character_,
    n_files = 2L,
    bytes_total = 20,
    n_downloaded = 2L,
    n_cached = 0L,
    n_failed = 0L,
    n_skipped = 0L,
    run_ids = list("run-1")
  )

  geofbds:::write_manifest_summary(summary, dest_dir)
  raw <- paste(readLines(file.path(dest_dir, "manifest.json")), collapse = "")
  expect_match(raw, '"last_updated": null', fixed = TRUE)
  expect_match(raw, '"pkg_version": null', fixed = TRUE)
  json <- jsonlite::read_json(file.path(dest_dir, "manifest.json"))
  expect_null(json$last_updated)
  expect_null(json$pkg_version)

  out <- fbds_manifest_status(dest_dir)
  expect_true(is.na(out$last_updated))
  expect_true(is.na(out$pkg_version))
  expect_equal(out$n_files, 2L)
  expect_equal(out$run_ids[[1]], "run-1")
})

test_that("fbds_manifest_status reads a manifest.json without run_ids", {
  dest_dir <- withr::local_tempdir()
  writeLines(
    '{"n_files": 0, "bytes_total": 0, "n_downloaded": 0, "n_cached": 0,
      "n_failed": 0, "n_skipped": 0}',
    file.path(dest_dir, "manifest.json")
  )

  out <- fbds_manifest_status(dest_dir)
  expect_equal(nrow(out), 1L)
  expect_equal(out$run_ids[[1]], character(0))
})

test_that("write_manifest_summary writes nothing for an empty summary", {
  dest_dir <- withr::local_tempdir()
  geofbds:::write_manifest_summary(
    geofbds:::empty_manifest_status(),
    dest_dir
  )
  expect_false(file.exists(file.path(dest_dir, "manifest.json")))
})

shapefile_manifest <- function(files) {
  tibble::tibble(
    run_id = "r1",
    geocode = "1100031",
    uf = "RO",
    municipality = "CABIXI",
    layer = "app",
    file = files,
    path = files,
    status = "downloaded",
    timestamp = Sys.time()
  )
}

test_that("fbds_validate is silent for complete shapefile sets", {
  manifest <- shapefile_manifest(
    paste0("RO_1100031_APP.", c("shp", "shx", "dbf", "prj", "cpg"))
  )
  expect_no_warning(out <- withVisible(fbds_validate(manifest)))
  expect_false(out$visible)
  expect_identical(out$value, manifest)
})

test_that("fbds_validate warns once per incomplete shapefile set", {
  manifest <- shapefile_manifest(c(
    paste0("RO_1100031_APP.", c("shp", "shx", "dbf", "prj")),
    paste0("RO_1100031_APP_USO.", c("shp", "dbf"))
  ))

  sets <- character()
  withCallingHandlers(
    fbds_validate(manifest),
    fbds_incomplete_shapefile = function(w) {
      sets <<- c(sets, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_length(sets, 1L)
  expect_match(sets, "RO_1100031_APP_USO", fixed = TRUE)
})
