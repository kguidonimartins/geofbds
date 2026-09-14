# Limpar o cache do pacote

Limpar o cache do pacote

## Usage

``` r
fbds_cache_clean(what = c("listings", "all"))
```

## Arguments

- what:

  `"listings"` (padrao) remove so as listagens cacheadas; `"all"` remove
  todo o
  [`fbds_cache_dir()`](https://kguidonimartins.github.io/geofbds/reference/fbds_cache_dir.md),
  inclusive downloads.

## Value

`NULL`, invisivelmente.
