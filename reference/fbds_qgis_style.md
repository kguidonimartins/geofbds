# Copiar os estilos do QGIS para o projeto do usuario

Os arquivos `.qml` (estilos categorizados do QGIS, com as mesmas cores
de
[`fbds_palette()`](https://kguidonimartins.github.io/geofbds/reference/fbds_palette.md))
ficam dentro do pacote instalado – em
`system.file("qgis", package = "geofbds")` –, um lugar que quem instala
o pacote via CRAN, `remotes::install_github()` ou similar normalmente
nunca abre. Sem copia-los para fora, o QGIS nao enxerga esses arquivos:
esta funcao faz essa copia, por padrao para o diretorio de trabalho
atual (tipicamente a raiz do projeto do usuario).

## Usage

``` r
fbds_qgis_style(field = NULL, dest_dir = ".", overwrite = FALSE)
```

## Arguments

- field:

  Nome de um ou mais campos com estilo disponivel (ex. `"CLASSE_USO"`).
  `NULL` (padrao) copia todos. Ver
  [`fbds_qgis_style_fields()`](https://kguidonimartins.github.io/geofbds/reference/fbds_qgis_style_fields.md)
  para os disponiveis.

- dest_dir:

  Diretorio de destino. Padrao `"."` (diretorio de trabalho atual).
  Criado se nao existir.

- overwrite:

  Sobrescrever arquivo(s) ja existentes em `dest_dir`? Padrao `FALSE`:
  para sem copiar nada se algum arquivo de destino ja existir.

## Value

Vetor com os caminhos dos arquivos copiados, invisivelmente.

## Examples

``` r
dest <- tempfile("qgis-styles-")
fbds_qgis_style(dest_dir = dest)
#> Estilo(s) do QGIS copiado(s) para /tmp/Rtmp110xEN/qgis-styles-69c428e77a4b:
#> "CLASSE_USO.qml", "HIDRO.qml", "MAPBIOMAS.qml", "NATUREZA.qml",
#> "PLANAFLOR-RECOMPOSICAO.qml", and "RIO.qml"
list.files(dest)
#> [1] "CLASSE_USO.qml"             "HIDRO.qml"                 
#> [3] "MAPBIOMAS.qml"              "NATUREZA.qml"              
#> [5] "PLANAFLOR-RECOMPOSICAO.qml" "RIO.qml"                   
unlink(dest, recursive = TRUE)
```
