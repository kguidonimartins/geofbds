test_that("fbds_catalog filters by uf", {
  out <- fbds_catalog(uf = "RO")
  expect_equal(nrow(out), 52L)
  expect_setequal(unique(out$uf), "RO")
})

test_that("fbds_catalog filters by name (partial, case/accent-insensitive)", {
  out <- fbds_catalog(name = "cabixi")
  expect_equal(out$geocode, "1100031")

  out2 <- fbds_catalog(name = "espigao d'oeste")
  expect_equal(out2$geocode, "1100098")
})

test_that("fbds_catalog filters by geocode", {
  out <- fbds_catalog(geocode = c("1100031", "1100049"))
  expect_setequal(out$geocode, c("1100031", "1100049"))
})

test_that("fbds_catalog combines filters with AND", {
  out <- fbds_catalog(uf = "RO", name = "cacoal")
  expect_equal(out$geocode, "1100049")

  out_empty <- fbds_catalog(uf = "SP", name = "cabixi")
  expect_equal(nrow(out_empty), 0L)
})

test_that("fbds_layers returns the three known layers", {
  out <- fbds_layers()
  expect_equal(out$layer, c("app", "hidrografia", "uso"))
  expect_equal(out$dir, c("APP", "HIDROGRAFIA", "USO"))
})

test_that("fbds_url builds one URL per geocode x layer", {
  expect_equal(
    fbds_url("1100031", layer = "app"),
    "https://geo.fbds.org.br/RO/CABIXI/APP"
  )

  out <- fbds_url("1100031")
  expect_equal(
    out,
    c(
      "https://geo.fbds.org.br/RO/CABIXI/APP",
      "https://geo.fbds.org.br/RO/CABIXI/HIDROGRAFIA",
      "https://geo.fbds.org.br/RO/CABIXI/USO"
    )
  )
})

test_that("fbds_url rejects an unknown layer", {
  expect_error(
    fbds_url("1100031", layer = "nao_existe"),
    class = "fbds_bad_layer"
  )
})

test_that("fbds_ufs lists 27 UFs with correct counts", {
  out <- fbds_ufs()
  expect_equal(nrow(out), 27L)
  expect_equal(out$n_municipios[out$uf == "RO"], 52L)
  expect_equal(out$n_municipios[out$uf == "SP"], 645L)
  expect_equal(out$n_municipios[out$uf == "MG"], 853L)
})

test_that("o catalogo e alcancavel sem anexar o pacote", {
  ns <- asNamespace("geofbds")

  # `geofbds::fbds_resolve()` carrega so a namespace, sem `library()`: o
  # catalogo (que mora em `data/`) precisa ser um binding dela, senao a
  # resolucao falha com "object 'fbds_municipios' not found".
  expect_true(exists("fbds_municipios", envir = ns, inherits = FALSE))
  expect_s3_class(
    get("fbds_municipios", envir = ns, inherits = FALSE),
    "tbl_df"
  )
})

test_that("municipios_data reads the catalog straight from data/", {
  out <- geofbds:::municipios_data()
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 5470L)
  expect_identical(out, fbds_municipios)
})

test_that("format_bytes formats sizes and treats NA/zero as 0 B", {
  expect_equal(geofbds:::format_bytes(NA), "0 B")
  expect_equal(geofbds:::format_bytes(0), "0 B")
  expect_equal(geofbds:::format_bytes(512), "512.0 B")
  expect_equal(geofbds:::format_bytes(1536), "1.5 KB")
  expect_equal(geofbds:::format_bytes(3 * 1024^3), "3.0 GB")
})
