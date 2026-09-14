# Diretorio de cache do pacote

Padrao [`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html),
sobreponivel via `options(geofbds.cache_dir = ...)` ou
[`fbds_cache_set()`](https://kguidonimartins.github.io/geofbds/reference/fbds_cache_set.md).
Se o diretorio ainda nao existe e a sessao e interativa, pede
confirmacao antes de criar (politica do CRAN); fora de sessao
interativa, cria direto.

## Usage

``` r
fbds_cache_dir()
```

## Value

O caminho do diretorio de cache (character).
