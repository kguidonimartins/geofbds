# Executar um plano de download

Sobre
[`curl::multi_download()`](https://jeroen.r-universe.dev/curl/reference/multi_download.html)
com `resume = TRUE`: substitui o laco sequencial e a logica manual de
`.part` do script original (SPECS.md §2.2-14).
[`curl::multi_download()`](https://jeroen.r-universe.dev/curl/reference/multi_download.html)
nao expoe um parametro de concorrencia real, entao `workers` particiona
as linhas em blocos desse tamanho, cada um resolvido em uma chamada.
Apos cada rodada, as linhas que falharam sao re-tentadas com backoff,
ate `retries` vezes.

## Usage

``` r
fbds_fetch(
  plan,
  workers = getOption("geofbds.workers", 4L),
  retries = getOption("geofbds.retries", 3L),
  timeout = getOption("geofbds.timeout", 300),
  progress = getOption("geofbds.progress", TRUE),
  dry_run = FALSE
)
```

## Arguments

- plan:

  Um objeto `<fbds_plan>` de
  [`fbds_plan()`](https://kguidonimartins.github.io/geofbds/reference/fbds_plan.md).

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

Um manifesto (tibble), tambem gravado em
`{dest_dir}/_manifests/{run_id}.csv`.

## Examples

``` r
if (FALSE) { # \dontrun{
plano <- fbds_plan("1100031", layers = "app")
fbds_fetch(plano)
} # }
```
