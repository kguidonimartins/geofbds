# Download em escala: por estado

``` r

library(geofbds)
```

Baixar todos os municípios de uma UF — em vez de um por um — é o
principal ganho deste pacote sobre o script original que o antecedeu.
Esta vinheta cobre \[fbds_download_state()\]: estimativa de volume,
execução em blocos e retomada após interrupção.

Os trechos abaixo fazem requisições reais ao portal (dezenas a centenas
de municípios) e não rodam durante o `R CMD check`; rode-os você mesmo.

## Dimensionando antes de baixar

[`fbds_coverage()`](https://kguidonimartins.github.io/geofbds/reference/fbds_coverage.md)
consulta a listagem de cada município × camada e resume volume e
completude — Rondônia tem 52 municípios, um bom primeiro teste:

``` r

cobertura <- fbds_coverage("RO", layers = "app")
sum(cobertura$bytes, na.rm = TRUE)
```

[`fbds_plan()`](https://kguidonimartins.github.io/geofbds/reference/fbds_plan.md)
faz o mesmo, mas já monta os destinos locais e tem um
[`print()`](https://rdrr.io/r/base/print.html) direto:

``` r

plano <- fbds_plan("RO", layers = "app")
plano
#> <fbds_plan> 52 municipio(s), N arquivo(s), X.X MB
#>   N para baixar, 0 ja presente(s) (skip)
#>   destino: ...
```

## Baixando a UF inteira

``` r

ro <- fbds_download_state("RO", layers = "app")
dplyr::count(ro, status)
```

Diferente de \[fbds_download_municipality()\],
[`fbds_download_state()`](https://kguidonimartins.github.io/geofbds/reference/fbds_download_state.md):

- estima o volume via
  [`fbds_coverage()`](https://kguidonimartins.github.io/geofbds/reference/fbds_coverage.md)
  e pede confirmação quando ultrapassa
  `getOption("geofbds.confirm_bytes")` (1 GB por padrão) — só quando
  `ask = TRUE` (o padrão em sessão interativa) e a sessão consegue de
  fato perguntar;
- processa os municípios em blocos (`block_size`, padrão 10), não um
  plano único com todos os arquivos da UF;
- grava `{dest_dir}/_progress.csv` ao final de cada bloco.

## Interrompendo e retomando

Se a execução cair no meio — `Ctrl-C`, queda de rede, falha de um
município — rodar o mesmo comando de novo continua de onde parou.
Municípios já `"complete"` (nenhum arquivo com `status == "failed"` no
bloco) são pulados, sem nova requisição:

``` r

# interrompida na metade...
ro <- fbds_download_state("RO", layers = "app")

# ...roda de novo: só os municipios pendentes sao processados
ro <- fbds_download_state("RO", layers = "app")
```

O progresso fica em `{dest_dir}/_progress.csv`, com uma linha por
município:

``` r

vroom::vroom(file.path(fbds_cache_dir(), "_progress.csv"))
```

## Mais de uma UF, ou o Brasil inteiro

``` r

fbds_download_state(c("RO", "AC"), layers = "app")

# espelho nacional -- confirme o volume antes
fbds_download_all(layers = "app")
```

## Pela linha de comando

``` bash
Rscript inst/scripts/geofbds state RO --workers=6

# sem prompt de confirmacao (necessario em execucao nao interativa)
Rscript inst/scripts/geofbds state RO --yes
```
