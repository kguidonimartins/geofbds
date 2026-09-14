# Montar URLs do portal para um municipio

Montar URLs do portal para um municipio

## Usage

``` r
fbds_url(geocode, layer = NULL)
```

## Arguments

- geocode:

  Um ou mais identificadores aceitos por
  [`fbds_resolve()`](https://kguidonimartins.github.io/geofbds/reference/fbds_resolve.md).

- layer:

  Uma ou mais camadas de
  [`fbds_layers()`](https://kguidonimartins.github.io/geofbds/reference/fbds_layers.md).
  `NULL` (padrao) usa todas.

## Value

Vetor de URLs, uma por combinacao de municipio x camada.

## Examples

``` r
fbds_url("1100031", layer = "app")
#> [1] "https://geo.fbds.org.br/RO/CABIXI/APP"
```
