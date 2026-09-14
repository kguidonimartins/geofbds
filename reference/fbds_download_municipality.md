# Baixar dados de um ou mais municipios

Involucro fino de `fbds_plan() |> fbds_fetch()`.

## Usage

``` r
fbds_download_municipality(
  x,
  layers = NULL,
  dest_dir = fbds_cache_dir(),
  recursive = FALSE,
  skip_existing = TRUE,
  path_pattern = "{uf}/{geocode}/{layer}/{file}",
  workers = getOption("geofbds.workers", 4L),
  retries = getOption("geofbds.retries", 3L),
  timeout = getOption("geofbds.timeout", 300),
  progress = getOption("geofbds.progress", TRUE),
  dry_run = FALSE
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

- workers:

  Tamanho do bloco de download concorrente.

- retries:

  Numero de novas tentativas para arquivos que falharem.

- timeout:

  Tempo maximo (segundos) por arquivo, por tentativa.

- progress:

  Se `TRUE` (padrao), informa o andamento via `cli`.

- dry_run:

  Se `TRUE`, nao baixa nada: devolve o manifesto que resultaria
  (`status` `"cached"` ou `"skipped"`) sem tocar a rede.

## Value

O manifesto (tibble) de
[`fbds_fetch()`](https://kguidonimartins.github.io/geofbds/reference/fbds_fetch.md).

## Examples

``` r
if (FALSE) { # \dontrun{
fbds_download_municipality(c("1100031", "1100049"), layers = "app")
fbds_download_municipality("Cabixi/RO")
} # }
```
