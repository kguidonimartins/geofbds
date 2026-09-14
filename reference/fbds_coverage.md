# Estimar cobertura de dados por municipio x camada

Verificacao aproximada, a partir da listagem remota: `has_shapefile` e
`complete` agrupam arquivos pelo nome-base (um municipio pode ter mais
de um conjunto de shapefile por camada, ex. `HIDROGRAFIA` tem quatro). A
verificacao autoritativa, sobre arquivos ja baixados, e
[`fbds_validate()`](https://kguidonimartins.github.io/geofbds/reference/fbds_validate.md)
(Fase 4).

## Usage

``` r
fbds_coverage(uf = NULL, layers = NULL)
```

## Arguments

- uf:

  UF(s) a cobrir. `NULL` (padrao) usa todo o catalogo — caro, uma
  requisicao por municipio x camada.

- layers:

  Camadas de
  [`fbds_layers()`](https://kguidonimartins.github.io/geofbds/reference/fbds_layers.md).
  `NULL` (padrao) usa todas.

## Value

Um tibble com uma linha por municipio x camada: `geocode`, `uf`,
`municipality`, `layer`, `n_files`, `bytes`, `has_shapefile`,
`complete`.

## Examples

``` r
if (FALSE) { # \dontrun{
fbds_coverage("RO")
} # }
```
