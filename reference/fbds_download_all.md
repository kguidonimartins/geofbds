# Baixar o espelho nacional

Invólucro de
[`fbds_download_state()`](https://kguidonimartins.github.io/geofbds/reference/fbds_download_state.md)
para todas as 27 UFs. Dado o volume, `ask` deveria quase sempre ficar em
`TRUE`.

## Usage

``` r
fbds_download_all(
  layers = NULL,
  dest_dir = fbds_cache_dir(),
  recursive = FALSE,
  skip_existing = TRUE,
  path_pattern = "{uf}/{geocode}/{layer}/{file}",
  block_size = 10L,
  workers = getOption("geofbds.workers", 4L),
  retries = getOption("geofbds.retries", 3L),
  timeout = getOption("geofbds.timeout", 300),
  progress = getOption("geofbds.progress", TRUE),
  dry_run = FALSE,
  ask = interactive(),
  confirm_bytes = getOption("geofbds.confirm_bytes", 1000000000)
)
```

## Arguments

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

- block_size:

  Numero de municipios por bloco.

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

- ask:

  Se `TRUE` (padrao em sessao interativa) e o volume estimado
  ultrapassar `confirm_bytes`, pede confirmacao antes de baixar. Fora de
  sessao interativa, nada e perguntado (nem mesmo confirmado
  automaticamente —
  [`utils::askYesNo()`](https://rdrr.io/r/utils/askYesNo.html) sem
  terminal devolve o padrao, que aqui e `FALSE`).

- confirm_bytes:

  Limite (bytes) acima do qual `ask = TRUE` pede confirmacao. Padrao
  `getOption("geofbds.confirm_bytes")`.

## Value

O manifesto (tibble) dos blocos processados nesta chamada.

## Examples

``` r
if (FALSE) { # \dontrun{
fbds_download_all(layers = "app")
} # }
```
