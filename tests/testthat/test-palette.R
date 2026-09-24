test_that("fbds_palette returns the known colors of each thematic field", {
  for (field in c("CLASSE_USO", "HIDRO", "NATUREZA", "RIO")) {
    pal <- fbds_palette(field)
    expect_type(pal, "character")
    expect_true(length(pal) > 0L)
    expect_false(is.null(names(pal)))
    expect_true(all(grepl("^#[0-9a-f]{6}$", pal)))
  }
})

test_that("fbds_palette gives both HIDRO spellings of a wide river one color", {
  pal <- fbds_palette("HIDRO")
  expect_equal(
    pal[["curso d'água (10 - 50m)"]],
    pal[["curso d'água (>10m)"]]
  )
})

test_that("fbds_palette returns an empty vector for an unknown field", {
  expect_identical(fbds_palette("CAMPO_QUALQUER"), character(0))
})

test_that("fbds_palette maps values, falling back for unknown classes", {
  out <- fbds_palette(
    "CLASSE_USO",
    c("silvicultura", NA, "classe nova", "silvicultura", "outra nova")
  )

  expect_named(out, c("silvicultura", "classe nova", "outra nova"))
  expect_equal(
    out[["silvicultura"]],
    fbds_palette("CLASSE_USO")[["silvicultura"]]
  )
  expect_equal(
    unname(out[c("classe nova", "outra nova")]),
    geofbds:::fallback_theme_colors()[1:2]
  )
})

test_that("fbds_palette colors every value of an unknown field from the fallback", {
  out <- fbds_palette("CAMPO_QUALQUER", c("a", "b", "a"))
  expect_equal(
    out,
    c(
      a = geofbds:::fallback_theme_colors()[[1]],
      b = geofbds:::fallback_theme_colors()[[2]]
    )
  )
})
