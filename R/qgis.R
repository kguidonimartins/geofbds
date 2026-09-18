#' Diretorio dos estilos do QGIS empacotados
#'
#' `inst/qgis/*.qml` so fica acessivel de dentro do pacote instalado (via
#' [system.file()]) -- nao ha como o usuario abri-los direto no QGIS sem
#' antes copia-los para fora. [fbds_qgis_style()] resolve isso.
#'
#' @noRd
qgis_style_dir <- function() {
  dir <- system.file("qgis", package = "geofbds")
  if (!nzchar(dir)) {
    abort_fbds(
      "Estilos do QGIS nao encontrados no pacote instalado.",
      "fbds_qgis_style_missing"
    )
  }
  dir
}

#' Campos com estilo do QGIS disponivel
#'
#' @return Vetor de nomes de campo (ex. `"CLASSE_USO"`), um por arquivo
#'   `.qml` empacotado em `inst/qgis/`.
#' @export
#'
#' @examples
#' fbds_qgis_style_fields()
fbds_qgis_style_fields <- function() {
  files <- list.files(qgis_style_dir(), pattern = "\\.qml$")
  sort(tools::file_path_sans_ext(files))
}

#' Copiar os estilos do QGIS para o projeto do usuario
#'
#' Os arquivos `.qml` (estilos categorizados do QGIS, com as mesmas cores de
#' [fbds_palette()]) ficam dentro do pacote instalado -- em
#' `system.file("qgis", package = "geofbds")` --, um lugar que quem instala o
#' pacote via CRAN, `remotes::install_github()` ou similar normalmente nunca
#' abre. Sem copia-los para fora, o QGIS nao enxerga esses arquivos: esta
#' funcao faz essa copia, por padrao para o diretorio de trabalho atual
#' (tipicamente a raiz do projeto do usuario).
#'
#' @param field Nome de um ou mais campos com estilo disponivel (ex.
#'   `"CLASSE_USO"`). `NULL` (padrao) copia todos. Ver
#'   [fbds_qgis_style_fields()] para os disponiveis.
#' @param dest_dir Diretorio de destino. Padrao `"."` (diretorio de trabalho
#'   atual). Criado se nao existir.
#' @param overwrite Sobrescrever arquivo(s) ja existentes em `dest_dir`?
#'   Padrao `FALSE`: para sem copiar nada se algum arquivo de destino ja
#'   existir.
#'
#' @return Vetor com os caminhos dos arquivos copiados, invisivelmente.
#' @export
#'
#' @examples
#' dest <- tempfile("qgis-styles-")
#' fbds_qgis_style(dest_dir = dest)
#' list.files(dest)
#' unlink(dest, recursive = TRUE)
fbds_qgis_style <- function(field = NULL, dest_dir = ".", overwrite = FALSE) {
  available <- fbds_qgis_style_fields()

  if (is.null(field)) {
    field <- available
  }

  unknown <- setdiff(field, available)
  if (length(unknown) > 0L) {
    abort_fbds(
      c(
        "Estilo(s) desconhecido(s): {.val {unknown}}",
        "i" = "Disponiveis: {.val {available}}."
      ),
      "fbds_bad_qgis_style"
    )
  }

  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)

  filenames <- paste0(field, ".qml")
  src <- file.path(qgis_style_dir(), filenames)
  dest <- file.path(dest_dir, filenames)

  clashes <- file.exists(dest)
  if (any(clashes) && !isTRUE(overwrite)) {
    abort_fbds(
      c(
        "Ja existe(m) em {.path {dest_dir}}: {.val {filenames[clashes]}}",
        "i" = "Use {.arg overwrite = TRUE} para sobrescrever."
      ),
      "fbds_qgis_style_exists"
    )
  }

  ok <- file.copy(src, dest, overwrite = overwrite)
  if (!all(ok)) {
    abort_fbds(
      "Falha ao copiar um ou mais estilos do QGIS para {.path {dest_dir}}.",
      "fbds_qgis_style_copy_failed"
    )
  }

  cli::cli_inform(
    "Estilo(s) do QGIS copiado(s) para {.path {dest_dir}}: {.val {filenames}}"
  )
  invisible(dest)
}
