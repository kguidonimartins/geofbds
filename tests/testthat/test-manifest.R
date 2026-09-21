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
