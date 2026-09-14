# Consultar o catalogo de municipios

Filtra
[fbds_municipios](https://kguidonimartins.github.io/geofbds/reference/fbds_municipios.md)
por UF, nome (busca parcial, sem acento e sem distincao de caixa) e/ou
geocodigo exato. Todos os filtros informados sao combinados com E. Para
resolver identificadores do usuario em geocodigos canonicos, use
[`fbds_resolve()`](https://kguidonimartins.github.io/geofbds/reference/fbds_resolve.md).

## Usage

``` r
fbds_catalog(uf = NULL, name = NULL, geocode = NULL)
```

## Arguments

- uf:

  Sigla(s) de UF, ex. `"RO"`.

- name:

  Trecho do nome do municipio a buscar.

- geocode:

  Geocodigo(s) exatos, numericos ou texto.

## Value

Um tibble com as linhas de
[fbds_municipios](https://kguidonimartins.github.io/geofbds/reference/fbds_municipios.md)
que casam os filtros.

## Examples

``` r
fbds_catalog(uf = "RO")
#> # A tibble: 52 × 12
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
#> # ℹ 42 more rows
#> # ℹ 6 more variables: area_formacao_florestal <dbl>,
#> #   area_formacao_nao_florestal <dbl>, area_edificada <dbl>,
#> #   area_antropizada <dbl>, slug <chr>, slug_status <chr>
fbds_catalog(name = "cabixi")
#> # A tibble: 1 × 12
#>   geocode municipality uf    uf_code area_agua area_silvicultura
#>   <chr>   <chr>        <chr> <chr>       <dbl>             <dbl>
#> 1 1100031 CABIXI       RO    11          1069.                 0
#> # ℹ 6 more variables: area_formacao_florestal <dbl>,
#> #   area_formacao_nao_florestal <dbl>, area_edificada <dbl>,
#> #   area_antropizada <dbl>, slug <chr>, slug_status <chr>
```
