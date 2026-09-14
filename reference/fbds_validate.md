# Validar completude dos conjuntos de shapefile de um manifesto

Agrupa os arquivos `.shp`/`.shx`/`.dbf`/`.prj` por nome-base e avisa
(classe `fbds_incomplete_shapefile`) para cada conjunto com algum
componente faltando.

## Usage

``` r
fbds_validate(manifest)
```

## Arguments

- manifest:

  Um manifesto de
  [`fbds_fetch()`](https://kguidonimartins.github.io/geofbds/reference/fbds_fetch.md)
  ou
  [`fbds_download_municipality()`](https://kguidonimartins.github.io/geofbds/reference/fbds_download_municipality.md).

## Value

`manifest`, invisivelmente.

## Examples

``` r
if (FALSE) { # \dontrun{
m <- fbds_download_municipality("1100031", layers = "app")
fbds_validate(m)
} # }
```
