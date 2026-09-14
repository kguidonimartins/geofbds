# Baixar e ler dados espaciais em um passo

Invólucro de `fbds_download_municipality() |> fbds_read()`.

## Usage

``` r
fbds_get(x, layer, type = NULL, crs = NULL, ...)
```

## Arguments

- x:

  Um manifesto, identificadores aceitos por
  [`fbds_resolve()`](https://kguidonimartins.github.io/geofbds/reference/fbds_resolve.md),
  ou um diretorio.

- layer:

  Uma camada de
  [`fbds_layers()`](https://kguidonimartins.github.io/geofbds/reference/fbds_layers.md).

- type:

  Tipo do conjunto de shapefile (ex. `"APP"`, `"MASSAS_DAGUA"`).
  Obrigatorio quando a camada tem mais de um tipo disponivel entre os
  arquivos encontrados.

- crs:

  Sistema de referencia para o qual harmonizar (via
  [`sf::st_transform()`](https://r-spatial.github.io/sf/reference/st_transform.html))
  antes de empilhar os municipios. `NULL` (padrao) nao transforma — se
  os municipios tiverem CRS diferentes, o empilhamento falha com o erro
  do proprio sf.

- ...:

  Repassado a
  [`fbds_download_municipality()`](https://kguidonimartins.github.io/geofbds/reference/fbds_download_municipality.md)
  (ex. `dest_dir`, `recursive`, `workers`).

## Value

Um objeto `sf`, como em
[`fbds_read()`](https://kguidonimartins.github.io/geofbds/reference/fbds_read.md).

## Examples

``` r
if (FALSE) { # \dontrun{
fbds_get("1100031", layer = "app", type = "APP")
} # }
```
