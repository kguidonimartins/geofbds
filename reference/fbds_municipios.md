# Catalogo de municipios brasileiros da Geo FBDS

Catalogo interno e congelado dos 5.470 municipios levantados pela FBDS,
derivado de `data-raw/build_catalog.R`. Usado por
[`fbds_resolve()`](https://kguidonimartins.github.io/geofbds/reference/fbds_resolve.md)
e
[`fbds_catalog()`](https://kguidonimartins.github.io/geofbds/reference/fbds_catalog.md)
para dispensar leitura de planilha em tempo de execucao. As seis colunas
`area_*` sao a classificacao de uso do solo do levantamento da FBDS (nao
a cobertura em si dos shapefiles baixaveis pelo pacote) e somam a area
total do municipio.

## Usage

``` r
fbds_municipios
```

## Format

Um tibble com 5.470 linhas e as colunas:

- geocode:

  Geocodigo do IBGE, texto com 7 digitos.

- municipality:

  Nome do municipio, em caixa alta.

- uf:

  Sigla da unidade federativa.

- uf_code:

  Codigo numerico da UF (2 primeiros digitos do geocodigo).

- area_agua:

  Area de massas d'agua, em hectares.

- area_silvicultura:

  Area de silvicultura, em hectares.

- area_formacao_florestal:

  Area de formacao florestal, em hectares, conforme classificacao da
  FBDS.

- area_formacao_nao_florestal:

  Area de formacao nao florestal, em hectares, conforme classificacao da
  FBDS.

- area_edificada:

  Area edificada, em hectares.

- area_antropizada:

  Area antropizada, em hectares.

- slug:

  Segmento de URL do municipio no portal da Geo FBDS.

- slug_status:

  Um de `"unverified"`, `"ok"`, `"fixed"` ou `"missing"`, conforme a
  verificacao contra o portal (`data-raw/verify_slugs.R`). Ver Detalhes.

## Source

Fundacao Brasileira para o Desenvolvimento Sustentavel (FBDS),
`TABELA CONSOLIDADA.xls`, aba "Levantamento do Uso do Solo" (colunas de
area sob o cabecalho "Areas do Uso do Solo (ha)"). Os metadados oficiais
do mapeamento
(<https://geo.fbds.org.br/Metadados%20Mapeamento%20FBDS.pdf>, campo
"Restricoes Legais": "Irrestrito", 30/04/2023) cobrem o mapeamento como
um todo, do qual esta tabela consolidada faz parte.

## Details

`slug_status` comeca `"unverified"` para todo o catalogo (o slug e so
uma estimativa derivada do nome do municipio). Rodar
`data-raw/verify_slugs.R` contra o portal e regerar o catalogo atualiza
esse campo para os municipios verificados: `"ok"` (o slug estimado
respondeu), `"fixed"` (uma variante do slug respondeu) ou `"missing"`
(nenhuma variante respondeu). Na versao atual do pacote, apenas os
municipios de RO (52) foram verificados; os demais permanecem
`"unverified"` ate uma nova rodada do script.

## Examples

``` r
fbds_municipios
#> # A tibble: 5,470 × 12
#>    geocode municipality          uf    uf_code area_agua area_silvicultura
#>    <chr>   <chr>                 <chr> <chr>       <dbl>             <dbl>
#>  1 1100015 ALTA FLORESTA D'OESTE RO    11          5967.             0.671
#>  2 1100023 ARIQUEMES             RO    11          6338.             0    
#>  3 1100031 CABIXI                RO    11          1069.             0    
#>  4 1100049 CACOAL                RO    11          1497.             0    
#>  5 1100056 CEREJEIRAS            RO    11           568.             0    
#>  6 1100064 COLORADO DO OESTE     RO    11           314.             0    
#>  7 1100072 CORUMBIARA            RO    11           743.             0    
#>  8 1100080 COSTA MARQUES         RO    11          6408.             0    
#>  9 1100098 ESPIGÃO D'OESTE       RO    11           789.             0    
#> 10 1100106 GUAJARÁ-MIRIM         RO    11         24231.             0    
#> # ℹ 5,460 more rows
#> # ℹ 6 more variables: area_formacao_florestal <dbl>,
#> #   area_formacao_nao_florestal <dbl>, area_edificada <dbl>,
#> #   area_antropizada <dbl>, slug <chr>, slug_status <chr>
dplyr::count(fbds_municipios, slug_status)
#> # A tibble: 2 × 2
#>   slug_status     n
#>   <chr>       <int>
#> 1 fixed         274
#> 2 ok           5196
```
