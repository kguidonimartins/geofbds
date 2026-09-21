# Consultar o resumo do historico de downloads

Le o resumo em `{dest_dir}/manifest.json`, gerado por
[`fbds_fetch()`](https://kguidonimartins.github.io/geofbds/reference/fbds_fetch.md),
ou reconstroi o resultado a partir de `{dest_dir}/_manifests/_index.csv`
quando o destino foi criado por uma versao anterior do pacote.

## Usage

``` r
fbds_manifest_status(dest_dir = fbds_cache_dir())
```

## Arguments

- dest_dir:

  Diretorio que contem os downloads. Padrao
  [`fbds_cache_dir()`](https://kguidonimartins.github.io/geofbds/reference/fbds_cache_dir.md).

## Value

Um tibble de uma linha com `last_updated`, `pkg_version`, `n_files`,
`bytes_total`, contagens por status (`n_downloaded`, `n_cached`,
`n_failed`, `n_skipped`) e a lista de `run_ids`. Se ainda nao houver
manifesto, devolve um tibble vazio com essas colunas.

## Examples

``` r
if (FALSE) { # \dontrun{
fbds_manifest_status()
fbds_manifest_status("/dados/fbds")
} # }
```
