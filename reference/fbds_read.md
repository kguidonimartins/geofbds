# Ler dados espaciais de uma camada

Aceita um manifesto (de
[`fbds_fetch()`](https://kguidonimartins.github.io/geofbds/reference/fbds_fetch.md)
e afins), geocodigos/nomes resolviveis por
[`fbds_resolve()`](https://kguidonimartins.github.io/geofbds/reference/fbds_resolve.md),
ou um diretorio. Para geocodigos ou diretorio, assume o layout padrao de
[`fbds_plan()`](https://kguidonimartins.github.io/geofbds/reference/fbds_plan.md)
(`{uf}/{geocode}/{layer}/arquivo`); um download com `path_pattern`
customizado so e localizavel passando o manifesto.

## Usage

``` r
fbds_read(x, layer, type = NULL, crs = NULL)
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

## Value

Um objeto `sf`, com uma linha por feicao e os municipios empilhados;
inclui as colunas `geocode` e `uf`.

## Details

Uma camada pode ter mais de um conjunto de shapefile (ex. `HIDROGRAFIA`
tem `MASSAS_DAGUA`, `NASCENTES`, `RIOS_DUPLOS` e `RIOS_SIMPLES`) com
geometrias distintas, que nao fazem sentido empilhadas juntas — por isso
`type` e obrigatorio sempre que houver mais de um. Um conjunto de
shapefile incompleto (falta `.shp`, `.shx`, `.dbf` ou `.prj`) e ignorado
com aviso, nunca lido.

## Examples

``` r
if (FALSE) { # \dontrun{
m <- fbds_download_municipality("1100031", layers = "app")
fbds_read(m, layer = "app", type = "APP")
} # }
```
