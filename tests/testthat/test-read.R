skip_if_not_installed("sf")

make_test_shp <- function(dir, uf, geocode, type, n = 3, crs = 4326, seed = 1) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  withr::local_seed(seed)
  pts <- sf::st_sfc(
    lapply(seq_len(n), function(i) {
      sf::st_point(c(stats::runif(1, -60, -50), stats::runif(1, -10, 0)))
    }),
    crs = crs
  )
  df <- sf::st_sf(
    id = seq_len(n),
    nome = paste0("feat", seq_len(n)),
    geometry = pts
  )
  path <- file.path(dir, sprintf("%s_%s_%s.shp", uf, geocode, type))
  suppressWarnings(sf::st_write(df, path, quiet = TRUE, delete_dsn = TRUE))
  path
}

test_that("fbds_read stacks municipalities from a directory", {
  root <- withr::local_tempdir()
  make_test_shp(
    file.path(root, "RO", "1100031", "app"),
    "RO",
    "1100031",
    "APP",
    seed = 1
  )
  make_test_shp(
    file.path(root, "RO", "1100049", "app"),
    "RO",
    "1100049",
    "APP",
    seed = 2
  )

  out <- fbds_read(root, layer = "app", type = "APP")

  expect_s3_class(out, "sf")
  expect_equal(nrow(out), 6L)
  expect_setequal(out$geocode, c("1100031", "1100049"))
  expect_true(all(out$uf == "RO"))
})

test_that("fbds_read locates files by geocode via the default cache layout", {
  root <- withr::local_tempdir()
  make_test_shp(
    file.path(root, "RO", "1100031", "app"),
    "RO",
    "1100031",
    "APP",
    seed = 1
  )
  make_test_shp(
    file.path(root, "RO", "1100049", "app"),
    "RO",
    "1100049",
    "APP",
    seed = 2
  )
  withr::local_options(list(geofbds.cache_dir = root))

  out <- fbds_read("1100031", layer = "app", type = "APP")

  expect_equal(nrow(out), 3L)
  expect_equal(unique(out$geocode), "1100031")
})

test_that("fbds_read reads from a manifest", {
  root <- withr::local_tempdir()
  shp_path <- make_test_shp(
    file.path(root, "RO", "1100031", "app"),
    "RO",
    "1100031",
    "APP",
    seed = 1
  )
  dir <- dirname(shp_path)

  manifest <- tibble::tibble(
    run_id = "r1",
    geocode = "1100031",
    uf = "RO",
    municipality = "CABIXI",
    layer = "app",
    file = c(
      "RO_1100031_APP.shp",
      "RO_1100031_APP.shx",
      "RO_1100031_APP.dbf",
      "RO_1100031_APP.prj"
    ),
    path = file.path(
      dir,
      c(
        "RO_1100031_APP.shp",
        "RO_1100031_APP.shx",
        "RO_1100031_APP.dbf",
        "RO_1100031_APP.prj"
      )
    ),
    status = "downloaded",
    timestamp = Sys.time()
  )

  out <- fbds_read(manifest, layer = "app", type = "APP")
  expect_equal(nrow(out), 3L)
})

test_that("fbds_read requires type when a layer has more than one", {
  root <- withr::local_tempdir()
  make_test_shp(
    file.path(root, "RO", "1100031", "hidrografia"),
    "RO",
    "1100031",
    "MASSAS_DAGUA",
    seed = 1
  )
  make_test_shp(
    file.path(root, "RO", "1100031", "hidrografia"),
    "RO",
    "1100031",
    "NASCENTES",
    seed = 2
  )

  expect_error(
    fbds_read(root, layer = "hidrografia"),
    class = "fbds_ambiguous_type"
  )

  out <- fbds_read(root, layer = "hidrografia", type = "MASSAS_DAGUA")
  expect_equal(nrow(out), 3L)
})

test_that("fbds_read errors on an unknown type", {
  root <- withr::local_tempdir()
  make_test_shp(
    file.path(root, "RO", "1100031", "app"),
    "RO",
    "1100031",
    "APP",
    seed = 1
  )

  expect_error(
    fbds_read(root, layer = "app", type = "NAO_EXISTE"),
    class = "fbds_ambiguous_type"
  )
})

test_that("fbds_read skips an incomplete shapefile set with a warning", {
  root <- withr::local_tempdir()
  make_test_shp(
    file.path(root, "RO", "1100031", "app"),
    "RO",
    "1100031",
    "APP",
    seed = 1
  )
  broken <- make_test_shp(
    file.path(root, "RO", "1100056", "app"),
    "RO",
    "1100056",
    "APP",
    seed = 3
  )
  file.remove(sub("\\.shp$", ".shx", broken))

  warned <- FALSE
  out <- withCallingHandlers(
    fbds_read(root, layer = "app", type = "APP"),
    fbds_incomplete_shapefile = function(w) {
      warned <<- TRUE
      invokeRestart("muffleWarning")
    }
  )
  expect_true(warned)
  expect_equal(unique(out$geocode), "1100031")
})

test_that("fbds_read errors when nothing is found", {
  root <- withr::local_tempdir()
  expect_error(
    fbds_read(root, layer = "app"),
    class = "fbds_empty_plan"
  )
})

test_that("fbds_read errors on an unknown layer", {
  root <- withr::local_tempdir()
  expect_error(
    fbds_read(root, layer = "nao_existe"),
    class = "fbds_bad_layer"
  )
})

test_that("fbds_read harmonizes CRS with the crs argument", {
  root <- withr::local_tempdir()
  make_test_shp(
    file.path(root, "RO", "1100031", "app"),
    "RO",
    "1100031",
    "APP",
    seed = 1
  )

  out <- fbds_read(root, layer = "app", type = "APP", crs = 5880)
  expect_equal(sf::st_crs(out), sf::st_crs(5880))
})

test_that("fbds_get downloads then reads in one step", {
  root <- withr::local_tempdir()
  shp_path <- make_test_shp(
    file.path(root, "src"),
    "RO",
    "1100031",
    "APP",
    seed = 1
  )
  src_dir <- dirname(shp_path)

  serve_file <- function(path) {
    force(path)
    function(req, res) {
      res$set_type("application/octet-stream")$send(readBin(
        path,
        "raw",
        file.info(path)$size
      ))
    }
  }
  app <- webfakes::new_app()
  app$get("/RO/CABIXI/APP/", function(req, res) {
    html <- paste0(
      "<html><body><div id=\"fallback\"><table>",
      "<tr><th class=\"fb-i\"></th><th class=\"fb-n\"><span>Name</span></th>",
      "<th class=\"fb-d\"><span>Last modified</span></th>",
      "<th class=\"fb-s\"><span>Size</span></th></tr>",
      "<tr><td class=\"fb-i\"><img src=\"p.png\" alt=\"folder-parent\"/></td>",
      "<td class=\"fb-n\"><a href=\"..\">Parent Directory</a></td>",
      "<td class=\"fb-d\"></td><td class=\"fb-s\"></td></tr>",
      paste(
        vapply(
          c("shp", "shx", "dbf", "prj"),
          function(ext) {
            sprintf(
              paste0(
                "<tr><td class=\"fb-i\"><img src=\"f.png\" alt=\"file\"/></td>",
                "<td class=\"fb-n\"><a href=\"/RO/CABIXI/APP/RO_1100031_APP.%s\">RO_1100031_APP.%s</a></td>",
                "<td class=\"fb-d\">2023-08-23 17:38</td><td class=\"fb-s\">1 KB</td></tr>"
              ),
              ext,
              ext
            )
          },
          character(1)
        ),
        collapse = ""
      ),
      "</table></div></body></html>"
    )
    res$set_type("text/html")$send(html)
  })
  for (ext in c("shp", "shx", "dbf", "prj")) {
    app$get(
      sprintf("/RO/CABIXI/APP/RO_1100031_APP.%s", ext),
      serve_file(file.path(src_dir, paste0("RO_1100031_APP.", ext)))
    )
  }

  web <- webfakes::new_app_process(app)
  withr::defer(web$stop())
  base_url <- sub("/$", "", web$url())
  withr::local_options(list(
    geofbds.base_url = base_url,
    geofbds.cache_dir = withr::local_tempdir()
  ))
  rm(
    list = ls(envir = geofbds:::listing_cache_env),
    envir = geofbds:::listing_cache_env
  )
  dest_dir <- withr::local_tempdir()

  out <- fbds_get(
    "1100031",
    layer = "app",
    type = "APP",
    dest_dir = dest_dir,
    progress = FALSE
  )

  expect_s3_class(out, "sf")
  expect_equal(nrow(out), 3L)
  expect_equal(unique(out$geocode), "1100031")
})

test_that("fbds_read decodes UTF-8 attributes and drops duplicate metadata", {
  root <- withr::local_tempdir()
  dir <- file.path(root, "ES", "3205309", "hidrografia")
  dir.create(dir, recursive = TRUE)
  source <- sf::st_sf(
    GEOCODIGO = 3205309,
    MUNICIPIO = "VITÓRIA",
    UF = "ES",
    CD_UF = 32L,
    HIDRO = "nascente",
    geometry = sf::st_sfc(sf::st_point(c(-40, -20)), crs = 4326)
  )
  path <- file.path(dir, "ES_3205309_NASCENTES.shp")
  suppressWarnings(sf::st_write(
    source,
    path,
    quiet = TRUE,
    layer_options = "ENCODING=UTF-8"
  ))

  out <- fbds_read(root, layer = "hidrografia", type = "NASCENTES")

  expect_equal(unique(out$MUNICIPIO), "VITÓRIA")
  expect_setequal(
    names(out),
    c("MUNICIPIO", "CD_UF", "HIDRO", "geocode", "uf", "geometry")
  )
  expect_identical(anyDuplicated(tolower(names(out))), 0L)
})

test_that("fbds_read rejects more than one layer", {
  root <- withr::local_tempdir()
  expect_error(
    fbds_read(root, layer = c("app", "uso")),
    class = "fbds_bad_layer"
  )
})

test_that("fbds_read errors when every shapefile set is incomplete", {
  root <- withr::local_tempdir()
  broken <- make_test_shp(
    file.path(root, "RO", "1100031", "app"),
    "RO",
    "1100031",
    "APP"
  )
  file.remove(sub("\\.shp$", ".dbf", broken))

  expect_error(
    suppressWarnings(fbds_read(root, layer = "app", type = "APP")),
    class = "fbds_incomplete_shapefile"
  )
})

test_that("fbds_read ignores layer directories without a .shp", {
  root <- withr::local_tempdir()
  make_test_shp(file.path(root, "RO", "1100031", "app"), "RO", "1100031", "APP")
  empty_dir <- file.path(root, "RO", "1100049", "app")
  dir.create(empty_dir, recursive = TRUE)
  writeLines("x", file.path(empty_dir, "leiame.txt"))

  out <- fbds_read(root, layer = "app", type = "APP")
  expect_equal(unique(out$geocode), "1100031")
})

test_that("fbds_read errors on a manifest with no shapefile for the layer", {
  manifest <- tibble::tibble(
    run_id = "r1",
    geocode = "1100031",
    uf = "RO",
    municipality = "CABIXI",
    layer = "app",
    file = "RO_1100031_APP.shp",
    path = "nao/existe/RO_1100031_APP.shp",
    status = "failed",
    timestamp = Sys.time()
  )
  expect_error(fbds_read(manifest, layer = "app"), class = "fbds_empty_plan")
})
