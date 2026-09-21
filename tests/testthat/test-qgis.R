test_that("fbds_qgis_style_fields lists the packaged .qml files", {
  expect_setequal(
    fbds_qgis_style_fields(),
    c(
      "CLASSE_USO",
      "HIDRO",
      "MAPBIOMAS",
      "NATUREZA",
      "PLANAFLOR-RECOMPOSICAO",
      "RIO"
    )
  )
})

test_that("fbds_qgis_style copies all styles by default", {
  dest <- withr::local_tempdir()

  paths <- fbds_qgis_style(dest_dir = dest)

  expect_setequal(
    basename(paths),
    paste0(fbds_qgis_style_fields(), ".qml")
  )
  expect_true(all(file.exists(paths)))
})

test_that("fbds_qgis_style copies only the requested field", {
  dest <- withr::local_tempdir()

  paths <- fbds_qgis_style("CLASSE_USO", dest_dir = dest)

  expect_equal(basename(paths), "CLASSE_USO.qml")
  expect_equal(list.files(dest), "CLASSE_USO.qml")
})

test_that("fbds_qgis_style errors on an unknown field", {
  dest <- withr::local_tempdir()

  expect_error(
    fbds_qgis_style("NAO_EXISTE", dest_dir = dest),
    class = "fbds_bad_qgis_style"
  )
})

test_that("fbds_qgis_style refuses to overwrite by default", {
  dest <- withr::local_tempdir()

  fbds_qgis_style("HIDRO", dest_dir = dest)

  expect_error(
    fbds_qgis_style("HIDRO", dest_dir = dest),
    class = "fbds_qgis_style_exists"
  )
  expect_no_error(
    fbds_qgis_style("HIDRO", dest_dir = dest, overwrite = TRUE)
  )
})

test_that("fbds_qgis_style creates dest_dir when it does not exist", {
  dest <- file.path(withr::local_tempdir(), "novo", "subdir")

  paths <- fbds_qgis_style("RIO", dest_dir = dest)

  expect_true(dir.exists(dest))
  expect_true(file.exists(paths))
})
