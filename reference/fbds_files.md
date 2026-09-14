# Listar arquivos disponiveis para municipios x camadas

Listar arquivos disponiveis para municipios x camadas

## Usage

``` r
fbds_files(x, layers = NULL, recursive = FALSE, cache = TRUE)
```

## Arguments

- x:

  Identificadores aceitos por
  [`fbds_resolve()`](https://kguidonimartins.github.io/geofbds/reference/fbds_resolve.md).

- layers:

  Camadas de
  [`fbds_layers()`](https://kguidonimartins.github.io/geofbds/reference/fbds_layers.md).
  `NULL` (padrao) usa todas.

- recursive:

  Se `TRUE`, desce em subdiretorios (ex. `USO/MAPAS`).

- cache:

  Se `TRUE` (padrao), usa e alimenta o cache de listagens (sessao +
  disco, ver
  [`fbds_cache_dir()`](https://kguidonimartins.github.io/geofbds/reference/fbds_cache_dir.md)).

## Value

Um tibble com `geocode`, `uf`, `municipality`, `layer`, `path`, `file`,
`ext`, `bytes`, `modified`, `url` — uma linha por arquivo.

## Examples

``` r
if (FALSE) { # \dontrun{
fbds_files("1100031", layers = "app")
} # }
```
