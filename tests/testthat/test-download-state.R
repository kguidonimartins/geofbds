# Offline unit tests for the progress bookkeeping -------------------------

test_that("resume_state returns an empty typed tibble when no file exists", {
  out <- geofbds:::resume_state(withr::local_tempfile())
  expect_equal(nrow(out), 0L)
  expect_named(
    out,
    c(
      "geocode",
      "uf",
      "municipality",
      "status",
      "n_files",
      "n_failed",
      "last_run_id",
      "timestamp"
    )
  )
})

test_that("update_progress_state marks a municipality complete or incomplete", {
  progress_path <- withr::local_tempfile()
  catalog <- tibble::tibble(
    geocode = c("1100031", "1100049"),
    uf = c("RO", "RO"),
    municipality = c("CABIXI", "CACOAL")
  )

  ok_manifest <- tibble::tibble(
    run_id = "r1",
    geocode = c("1100031", "1100031"),
    status = c("downloaded", "cached"),
    timestamp = Sys.time()
  )
  failed_manifest <- tibble::tibble(
    run_id = "r2",
    geocode = "1100049",
    status = "failed",
    timestamp = Sys.time()
  )

  geofbds:::update_progress_state(progress_path, ok_manifest, catalog)
  state <- geofbds:::update_progress_state(
    progress_path,
    failed_manifest,
    catalog
  )

  expect_equal(state$status[state$geocode == "1100031"], "complete")
  expect_equal(state$status[state$geocode == "1100049"], "incomplete")
})

test_that("update_progress_state upserts without duplicating a geocode", {
  progress_path <- withr::local_tempfile()
  catalog <- tibble::tibble(
    geocode = "1100031",
    uf = "RO",
    municipality = "CABIXI"
  )

  m1 <- tibble::tibble(
    run_id = "r1",
    geocode = "1100031",
    status = "failed",
    timestamp = Sys.time()
  )
  m2 <- tibble::tibble(
    run_id = "r2",
    geocode = "1100031",
    status = "downloaded",
    timestamp = Sys.time()
  )

  geofbds:::update_progress_state(progress_path, m1, catalog)
  final <- geofbds:::update_progress_state(progress_path, m2, catalog)

  expect_equal(nrow(final), 1L)
  expect_equal(final$status, "complete")
  expect_equal(final$last_run_id, "r2")
})

# Network tests -------------------------------------------------------------
#
# All of these use RR (15 municipalities) rather than RO (52): the resume
# mechanism is UF-agnostic, and a smaller UF keeps a full-catalog mock
# server fast. A single shared app serves every municipality's listing
# and one small file; `flaky_geocode`'s file route fails a fixed number
# of times before succeeding, to simulate a mid-run failure.

make_uf_app <- function(catalog, flaky_geocode = NULL, flaky_fail_times = 2L) {
  make_listing_route <- function(geocode, slug, uf) {
    force(geocode)
    force(slug)
    force(uf)
    function(req, res) {
      html <- paste0(
        "<html><body><div id=\"fallback\"><table>",
        "<tr><th class=\"fb-i\"></th><th class=\"fb-n\"><span>Name</span></th>",
        "<th class=\"fb-d\"><span>Last modified</span></th>",
        "<th class=\"fb-s\"><span>Size</span></th></tr>",
        "<tr><td class=\"fb-i\"><img src=\"p.png\" alt=\"folder-parent\"/></td>",
        "<td class=\"fb-n\"><a href=\"..\">Parent Directory</a></td>",
        "<td class=\"fb-d\"></td><td class=\"fb-s\"></td></tr>",
        "<tr><td class=\"fb-i\"><img src=\"f.png\" alt=\"file\"/></td>",
        sprintf(
          "<td class=\"fb-n\"><a href=\"/%s/%s/APP/%s.shp\">%s.shp</a></td>",
          uf,
          slug,
          geocode,
          geocode
        ),
        "<td class=\"fb-d\">2023-08-23 17:38</td><td class=\"fb-s\">1 KB</td></tr>",
        "</table></div></body></html>"
      )
      res$set_type("text/html")$send(html)
    }
  }

  make_content_route <- function() {
    function(req, res) {
      res$set_type("application/octet-stream")$send(as.raw(rep(0L, 1024L)))
    }
  }

  make_flaky_content_route <- function(fail_times) {
    force(fail_times)
    count <- 0L
    function(req, res) {
      count <<- count + 1L
      if (count <= fail_times) {
        res$set_status(500L)$send("retry me")
      } else {
        res$set_type("application/octet-stream")$send(as.raw(rep(0L, 1024L)))
      }
    }
  }

  app <- webfakes::new_app()
  for (i in seq_len(nrow(catalog))) {
    geocode <- catalog$geocode[[i]]
    slug <- catalog$slug[[i]]
    uf <- catalog$uf[[i]]
    app$get(
      sprintf("/%s/%s/APP/", uf, slug),
      make_listing_route(geocode, slug, uf)
    )
    app$get(
      sprintf("/%s/%s/APP/%s.shp", uf, slug, geocode),
      if (identical(geocode, flaky_geocode)) {
        make_flaky_content_route(flaky_fail_times)
      } else {
        make_content_route()
      }
    )
  }
  app
}

local_uf_server <- function(catalog, ..., .local_envir = parent.frame()) {
  app <- make_uf_app(catalog, ...)
  web <- webfakes::new_app_process(app)
  withr::defer(web$stop(), .local_envir)
  base_url <- sub("/$", "", web$url())
  withr::local_options(
    list(
      geofbds.base_url = base_url,
      # isolate from the real default cache dir: get_listing_cached()'s
      # disk cache is keyed by (uf, slug, layer), not by server, so a
      # stale entry from an earlier (now-dead) mock server would
      # otherwise be served here
      geofbds.cache_dir = withr::local_tempdir(.local_envir = .local_envir)
    ),
    .local_envir = .local_envir
  )
  rm(
    list = ls(envir = geofbds:::listing_cache_env),
    envir = geofbds:::listing_cache_env
  )
  invisible(base_url)
}

test_that("fbds_download_state aborts when the confirmation is declined", {
  testthat::local_mocked_bindings(
    askYesNo = function(...) FALSE,
    .package = "utils"
  )
  local_uf_server(fbds_catalog(uf = "RR"))
  dest_dir <- withr::local_tempdir()

  expect_error(
    fbds_download_state(
      "RR",
      layers = "app",
      dest_dir = dest_dir,
      ask = TRUE,
      confirm_bytes = 0,
      progress = FALSE
    ),
    class = "fbds_download_declined"
  )
  expect_false(file.exists(file.path(dest_dir, "_progress.csv")))
})

test_that("fbds_download_state(dry_run = TRUE) writes no files and no progress", {
  local_uf_server(fbds_catalog(uf = "RR"))
  dest_dir <- withr::local_tempdir()

  m <- fbds_download_state(
    "RR",
    layers = "app",
    dest_dir = dest_dir,
    block_size = 15L,
    dry_run = TRUE,
    progress = FALSE
  )

  expect_equal(nrow(m), 15L)
  expect_true(all(m$status == "skipped"))
  expect_false(file.exists(file.path(dest_dir, "_progress.csv")))
  expect_false(dir.exists(file.path(dest_dir, "_manifests")))
})

test_that("fbds_download_state proceeds when the confirmation is accepted", {
  testthat::local_mocked_bindings(
    askYesNo = function(...) TRUE,
    .package = "utils"
  )
  local_uf_server(fbds_catalog(uf = "RR"))
  dest_dir <- withr::local_tempdir()

  m <- fbds_download_state(
    "RR",
    layers = "app",
    dest_dir = dest_dir,
    ask = TRUE,
    confirm_bytes = 0,
    block_size = 15L,
    progress = FALSE
  )
  expect_equal(nrow(m), 15L)
  expect_true(all(m$status == "downloaded"))
})

# This is PLAN.md's Fase 5 "pronto" bar: a whole UF downloads, gets
# interrupted partway (one municipality fails), and a second call
# resumes without re-downloading what already succeeded.
test_that("fbds_download_state downloads a whole UF, resuming after a partial failure", {
  rr <- fbds_catalog(uf = "RR")
  flaky_geocode <- rr$geocode[[1]]
  local_uf_server(rr, flaky_geocode = flaky_geocode, flaky_fail_times = 2L)
  dest_dir <- withr::local_tempdir()

  # round 1: the flaky municipality fails both attempts (retries = 1) and
  # ends up "incomplete"; everyone else succeeds
  m1 <- fbds_download_state(
    "RR",
    layers = "app",
    dest_dir = dest_dir,
    block_size = 5L,
    retries = 1L,
    progress = FALSE
  )
  expect_equal(nrow(m1), 15L)

  progress1 <- geofbds:::resume_state(file.path(dest_dir, "_progress.csv"))
  expect_equal(nrow(progress1), 15L)
  expect_equal(
    progress1$status[progress1$geocode == flaky_geocode],
    "incomplete"
  )
  expect_equal(sum(progress1$status == "complete"), 14L)

  # round 2 ("resume"): only the previously-incomplete municipality is
  # processed; the flaky route's 3rd call now succeeds
  m2 <- fbds_download_state(
    "RR",
    layers = "app",
    dest_dir = dest_dir,
    block_size = 5L,
    retries = 1L,
    progress = FALSE
  )
  expect_equal(unique(m2$geocode), flaky_geocode)
  expect_equal(m2$status, "downloaded")

  progress2 <- geofbds:::resume_state(file.path(dest_dir, "_progress.csv"))
  expect_true(all(progress2$status == "complete"))
  expect_equal(nrow(progress2), 15L)

  # round 3: everything is complete, nothing left to do
  m3 <- fbds_download_state(
    "RR",
    layers = "app",
    dest_dir = dest_dir,
    progress = FALSE
  )
  expect_equal(nrow(m3), 0L)
})

test_that("fbds_download_all delegates to fbds_download_state for every UF", {
  # Mock fbds_ufs() down to a single small UF so this stays a fast,
  # self-contained test of the delegation, not a full national mock.
  ac <- fbds_catalog(uf = "AC")
  local_uf_server(ac)
  dest_dir <- withr::local_tempdir()

  testthat::local_mocked_bindings(
    fbds_ufs = function() tibble::tibble(uf = "AC", n_municipios = nrow(ac)),
    .package = "geofbds"
  )

  m <- fbds_download_all(
    layers = "app",
    dest_dir = dest_dir,
    block_size = 22L,
    progress = FALSE
  )
  expect_true(all(m$uf == "AC"))
  expect_equal(nrow(m), nrow(ac))
})
