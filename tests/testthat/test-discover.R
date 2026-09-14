# Parser tests, offline, against real HTML captured from the portal via
# data-raw/capture_fixtures.R (see PLAN.md Fase 2/3).

test_that("parse_h5ai_listing parses a real APP listing", {
  html <- paste(
    readLines(test_path("fixtures/listing_app.html"), warn = FALSE),
    collapse = "\n"
  )
  out <- geofbds:::parse_h5ai_listing(
    html,
    "https://geo.fbds.org.br/RO/CABIXI/APP/"
  )

  expect_equal(nrow(out), 12L)
  expect_false(any(out$is_dir))
  expect_true(all(c("RO_1100031_APP.shp", "RO_1100031_APP.shx") %in% out$file))
  expect_equal(out$bytes[out$file == "RO_1100031_APP.shp"], 3008 * 1024)
  expect_equal(
    out$url[out$file == "RO_1100031_APP.cpg"],
    "https://geo.fbds.org.br/RO/CABIXI/APP/RO_1100031_APP.cpg"
  )
})

test_that("parse_h5ai_listing parses HIDROGRAFIA with four shapefile sets", {
  html <- paste(
    readLines(test_path("fixtures/listing_hidrografia.html"), warn = FALSE),
    collapse = "\n"
  )
  out <- geofbds:::parse_h5ai_listing(
    html,
    "https://geo.fbds.org.br/RO/CABIXI/HIDROGRAFIA/"
  )

  expect_equal(nrow(out), 24L)
  set_ids <- unique(geofbds:::shapefile_basename(out$file))
  expect_setequal(
    intersect(
      set_ids,
      c(
        "RO_1100031_MASSAS_DAGUA",
        "RO_1100031_NASCENTES",
        "RO_1100031_RIOS_DUPLOS",
        "RO_1100031_RIOS_SIMPLES"
      )
    ),
    c(
      "RO_1100031_MASSAS_DAGUA",
      "RO_1100031_NASCENTES",
      "RO_1100031_RIOS_DUPLOS",
      "RO_1100031_RIOS_SIMPLES"
    )
  )
})

test_that("parse_h5ai_listing parses USO", {
  html <- paste(
    readLines(test_path("fixtures/listing_uso.html"), warn = FALSE),
    collapse = "\n"
  )
  out <- geofbds:::parse_h5ai_listing(
    html,
    "https://geo.fbds.org.br/RO/CABIXI/USO/"
  )
  expect_equal(nrow(out), 6L)
})

test_that("parse_h5ai_listing returns an empty tibble for a 404 page", {
  html <- paste(
    readLines(test_path("fixtures/listing_404.html"), warn = FALSE),
    collapse = "\n"
  )
  out <- geofbds:::parse_h5ai_listing(
    html,
    "https://geo.fbds.org.br/RO/XXX/APP/"
  )
  expect_equal(nrow(out), 0L)
  expect_named(out, c("file", "url", "bytes", "modified", "is_dir"))
})

test_that("parse_h5ai_size handles KB/MB/GB/B and blanks", {
  expect_equal(
    geofbds:::parse_h5ai_size(c("0 KB", "1825 KB", "3 MB", "120 B", "")),
    c(0, 1825 * 1024, 3 * 1024^2, 120, NA_real_)
  )
})

test_that("parse_h5ai_modified parses timestamps and blanks", {
  out <- geofbds:::parse_h5ai_modified(c("2023-08-23 17:37", ""))
  expect_equal(out[[1]], as.POSIXct("2023-08-23 17:37", tz = "UTC"))
  expect_true(is.na(out[[2]]))
})

# Network tests, against a local webfakes server serving the same real
# fixtures (plus a synthetic subdirectory case, since no captured
# municipality has one — see data-raw/capture_fixtures.R comments).
#
# webfakes runs the app in a separate process: route handlers only see
# what they close over locally (factory functions below), never objects
# from this file's top-level/global scope.

make_listing_route <- function(fixture_path) {
  force(fixture_path)
  function(req, res) {
    res$set_type("text/html")$send(
      paste(readLines(fixture_path, warn = FALSE), collapse = "\n")
    )
  }
}

make_html_route <- function(html) {
  force(html)
  function(req, res) res$set_type("text/html")$send(html)
}

make_flaky_route <- function(fail_times) {
  force(fail_times)
  count <- 0L
  function(req, res) {
    count <<- count + 1L
    if (count <= fail_times) {
      res$set_status(500L)$send("retry me")
    } else {
      res$set_status(200L)$send("ok")
    }
  }
}

subdir_html <- paste0(
  "<html><body><div id=\"fallback\"><table>",
  "<tr><th class=\"fb-i\"></th><th class=\"fb-n\"><span>Name</span></th>",
  "<th class=\"fb-d\"><span>Last modified</span></th>",
  "<th class=\"fb-s\"><span>Size</span></th></tr>",
  "<tr><td class=\"fb-i\"><img src=\"p.png\" alt=\"folder-parent\"/></td>",
  "<td class=\"fb-n\"><a href=\"..\">Parent Directory</a></td>",
  "<td class=\"fb-d\"></td><td class=\"fb-s\"></td></tr>",
  "<tr><td class=\"fb-i\"><img src=\"f.png\" alt=\"folder\"/></td>",
  "<td class=\"fb-n\"><a href=\"/RO/CABIXI/USO_SUBDIR/MAPAS/\">MAPAS</a></td>",
  "<td class=\"fb-d\"></td><td class=\"fb-s\"></td></tr>",
  "<tr><td class=\"fb-i\"><img src=\"f.png\" alt=\"file\"/></td>",
  "<td class=\"fb-n\"><a href=\"/RO/CABIXI/USO_SUBDIR/USO.rar\">USO.rar</a></td>",
  "<td class=\"fb-d\">2023-08-23 17:38</td><td class=\"fb-s\">120 KB</td></tr>",
  "</table></div></body></html>"
)
nested_html <- paste0(
  "<html><body><div id=\"fallback\"><table>",
  "<tr><th class=\"fb-i\"></th><th class=\"fb-n\"><span>Name</span></th>",
  "<th class=\"fb-d\"><span>Last modified</span></th>",
  "<th class=\"fb-s\"><span>Size</span></th></tr>",
  "<tr><td class=\"fb-i\"><img src=\"p.png\" alt=\"folder-parent\"/></td>",
  "<td class=\"fb-n\"><a href=\"..\">Parent Directory</a></td>",
  "<td class=\"fb-d\"></td><td class=\"fb-s\"></td></tr>",
  "<tr><td class=\"fb-i\"><img src=\"f.png\" alt=\"file\"/></td>",
  "<td class=\"fb-n\"><a href=\"/RO/CABIXI/USO_SUBDIR/MAPAS/mapa.pdf\">mapa.pdf</a></td>",
  "<td class=\"fb-d\">2023-08-23 17:38</td><td class=\"fb-s\">300 KB</td></tr>",
  "</table></div></body></html>"
)

fixtures_app <- webfakes::new_app()
fixtures_app$get(
  "/RO/CABIXI/APP/",
  make_listing_route(test_path("fixtures/listing_app.html"))
)
fixtures_app$get(
  "/RO/CABIXI/HIDROGRAFIA/",
  make_listing_route(test_path("fixtures/listing_hidrografia.html"))
)
fixtures_app$get(
  "/RO/CABIXI/USO/",
  make_listing_route(test_path("fixtures/listing_uso.html"))
)
fixtures_app$get("/RO/CABIXI/USO_SUBDIR/", make_html_route(subdir_html))
fixtures_app$get("/RO/CABIXI/USO_SUBDIR/MAPAS/", make_html_route(nested_html))
fixtures_app$get(
  "/RO/MUNICIPIO_INEXISTENTE_XYZ/APP/",
  function(req, res) res$set_status(404L)$send("not found")
)
fixtures_app$get(
  "/always-500/",
  function(req, res) res$set_status(500L)$send("oops")
)
fixtures_app$get("/flaky-once/", make_flaky_route(1L))

fixtures_web <- webfakes::new_app_process(fixtures_app)
withr::defer(fixtures_web$stop(), teardown_env())
fixtures_base_url <- sub("/$", "", fixtures_web$url())

reset_listing_cache <- function() {
  rm(
    list = ls(envir = geofbds:::listing_cache_env),
    envir = geofbds:::listing_cache_env
  )
}

local_fixtures_server <- function(.local_envir = parent.frame()) {
  withr::local_options(
    list(
      geofbds.base_url = fixtures_base_url,
      geofbds.cache_dir = withr::local_tempdir(.local_envir = .local_envir)
    ),
    .local_envir = .local_envir
  )
  reset_listing_cache()
}

test_that("list_remote_dir warns and skips subdirectories by default", {
  local_fixtures_server()
  expect_warning(
    out <- geofbds:::list_remote_dir(
      paste0(fixtures_base_url, "/RO/CABIXI/USO_SUBDIR/"),
      recursive = FALSE
    ),
    class = "rlang_warning"
  )
  expect_equal(out$file, "USO.rar")
})

test_that("list_remote_dir descends into subdirectories when recursive = TRUE", {
  local_fixtures_server()
  out <- geofbds:::list_remote_dir(
    paste0(fixtures_base_url, "/RO/CABIXI/USO_SUBDIR/"),
    recursive = TRUE
  )
  expect_setequal(out$file, c("USO.rar", "mapa.pdf"))
  expect_equal(out$path[out$file == "mapa.pdf"], "MAPAS")
  expect_equal(out$path[out$file == "USO.rar"], "")
})

test_that("fbds_files aggregates municipality x layer into one tibble", {
  local_fixtures_server()
  out <- fbds_files("1100031", layers = c("app", "hidrografia", "uso"))

  expect_equal(nrow(out), 12L + 24L + 6L)
  expect_setequal(out$layer, c("app", "hidrografia", "uso"))
  expect_true(all(out$geocode == "1100031"))
  expect_named(
    out,
    c(
      "geocode",
      "uf",
      "municipality",
      "layer",
      "path",
      "file",
      "ext",
      "bytes",
      "modified",
      "url"
    )
  )
})

test_that("fbds_files continues past a municipality that errors", {
  local_fixtures_server()
  expect_warning(
    out <- fbds_files(
      c("1100031", "1100015"), # 1100015 has no mock route -> 404
      layers = "app"
    ),
    class = "rlang_warning"
  )
  expect_setequal(out$geocode, "1100031")
})

test_that("get_listing_cached serves from the session cache without a new request", {
  local_fixtures_server()
  first <- fbds_files("1100031", layers = "app", cache = TRUE)

  # stop the server: a second call can only succeed by hitting the cache
  fixtures_web$stop()
  second <- fbds_files("1100031", layers = "app", cache = TRUE)
  expect_equal(first, second)

  # restart for subsequent tests in this file
  fixtures_web <<- webfakes::new_app_process(fixtures_app)
  fixtures_base_url <<- sub("/$", "", fixtures_web$url())
})

test_that("fbds_coverage flags complete shapefile sets", {
  local_fixtures_server()
  # the mock server only has routes for CABIXI; the other 51 RO
  # municipalities 404 and are skipped (see the resilience test above)
  out <- suppressWarnings(
    fbds_coverage("RO", layers = c("app", "hidrografia", "uso"))
  )
  cabixi <- out[out$geocode == "1100031", ]

  expect_equal(nrow(cabixi), 3L)
  expect_true(all(cabixi$has_shapefile))
  expect_true(all(cabixi$complete))
  expect_equal(cabixi$n_files[cabixi$layer == "hidrografia"], 24L)
})

test_that("fbds_request raises fbds_http_error for a 404", {
  expect_error(
    geofbds:::fbds_request(
      paste0(fixtures_base_url, "/RO/MUNICIPIO_INEXISTENTE_XYZ/APP/")
    ),
    class = "fbds_http_error"
  )
})

test_that("fbds_request retries a transient 500 and succeeds", {
  resp <- geofbds:::fbds_request(
    paste0(fixtures_base_url, "/flaky-once/"),
    retries = 2L
  )
  expect_equal(resp$status_code, 200L)
})

test_that("fbds_request gives up after exhausting retries", {
  expect_error(
    geofbds:::fbds_request(
      paste0(fixtures_base_url, "/always-500/"),
      retries = 1L
    ),
    class = "fbds_http_error"
  )
})
