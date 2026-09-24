test_that("fbds_resolve accepts a numeric or text geocode", {
  expect_equal(fbds_resolve("1100031"), c(CABIXI = "1100031"))
  expect_equal(fbds_resolve(1100031), c(CABIXI = "1100031"))
})

test_that("fbds_resolve accepts a municipality name", {
  expect_equal(fbds_resolve("cabixi"), c(CABIXI = "1100031"))
  expect_equal(fbds_resolve("CABIXI"), c(CABIXI = "1100031"))
  expect_equal(fbds_resolve("  Cabixi  "), c(CABIXI = "1100031"))
})

test_that("fbds_resolve accepts the 'Municipio/UF' form", {
  expect_equal(fbds_resolve("Cabixi/RO"), c(CABIXI = "1100031"))
  expect_equal(fbds_resolve("cabixi/ro"), c(CABIXI = "1100031"))
})

test_that("fbds_resolve expands a UF to all its municipalities", {
  out <- fbds_resolve("RO")
  expect_length(out, 52L)
  expect_true(all(nchar(out) == 7L))
  expect_equal(out["CABIXI"], c(CABIXI = "1100031"))
  expect_equal(names(out), fbds_catalog(uf = "RO")$municipality)
})

test_that("fbds_resolve uses the uf argument to disambiguate a bare name", {
  expect_equal(
    fbds_resolve("Bom Jesus", uf = "RS"),
    c("BOM JESUS" = "4302303")
  )
})

test_that("fbds_resolve preserves order and drops duplicates", {
  out <- fbds_resolve(c("1100049", "1100031", "1100049"))
  expect_equal(out, c(CACOAL = "1100049", CABIXI = "1100031"))
})

test_that("fbds_resolve rejects a malformed geocode", {
  expect_error(fbds_resolve("12345"), class = "fbds_bad_geocode")
})

test_that("fbds_resolve errors on an unknown municipality", {
  expect_error(
    fbds_resolve("Municipio Que Nao Existe"),
    class = "fbds_unknown_municipality"
  )
})

test_that("fbds_resolve never silently picks among ambiguous names", {
  expect_error(fbds_resolve("Bom Jesus"), class = "fbds_ambiguous_municipality")
})

test_that("fbds_resolve with strict = FALSE drops unresolved input with a warning", {
  expect_warning(
    out <- fbds_resolve(
      c("Cabixi/RO", "Municipio Que Nao Existe"),
      strict = FALSE
    ),
    class = "rlang_warning"
  )
  expect_equal(out, c(CABIXI = "1100031"))
})
