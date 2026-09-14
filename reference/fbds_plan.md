# Planejar um download

Separa planejar de executar: `fbds_plan()` so consulta a listagem remota
(via
[`fbds_files()`](https://kguidonimartins.github.io/geofbds/reference/fbds_files.md),
cacheada) e decide os destinos locais;
[`fbds_fetch()`](https://kguidonimartins.github.io/geofbds/reference/fbds_fetch.md)
e quem baixa. Isso da `dry_run` de verdade e permite inspecionar o
volume antes de aceitar um download grande.

## Usage

``` r
fbds_plan(
  x,
  layers = NULL,
  dest_dir = fbds_cache_dir(),
  recursive = FALSE,
  skip_existing = TRUE,
  path_pattern = "{uf}/{geocode}/{layer}/{file}"
)
```

## Arguments

- x:

  Identificadores aceitos por
  [`fbds_resolve()`](https://kguidonimartins.github.io/geofbds/reference/fbds_resolve.md).

- layers:

  Camadas de
  [`fbds_layers()`](https://kguidonimartins.github.io/geofbds/reference/fbds_layers.md).
  `NULL` (padrao) usa todas.

- dest_dir:

  Diretorio de destino. Padrao
  [`fbds_cache_dir()`](https://kguidonimartins.github.io/geofbds/reference/fbds_cache_dir.md).

- recursive:

  Se `TRUE`, inclui subdiretorios (ex. `USO/MAPAS`).

- skip_existing:

  Se `TRUE` (padrao), um arquivo ja presente em `dest_dir` com tamanho a
  ate 1 KB do esperado e marcado para pular (sem nova requisicao). A
  listagem do portal so informa tamanho em KB, daí a tolerancia; a
  palavra final sobre integridade e de
  [`fbds_fetch()`](https://kguidonimartins.github.io/geofbds/reference/fbds_fetch.md),
  que confere o arquivo de verdade apos a transferencia.

- path_pattern:

  Padrao do caminho local, com placeholders `{uf}`, `{geocode}`,
  `{layer}`, `{file}`. Quando um arquivo vem de um subdiretorio remoto
  (`recursive = TRUE`), `{file}` ja inclui esse subdiretorio como
  prefixo.

## Value

Um objeto `<fbds_plan>` (tibble + metadados), com
[`print()`](https://rdrr.io/r/base/print.html) mostrando municipios,
arquivos e volume estimado.

## Examples

``` r
if (FALSE) { # \dontrun{
fbds_plan("1100031", layers = "app")
} # }
```
