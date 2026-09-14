# Resolver identificadores de municipio em geocodigos canonicos

Ponto de entrada universal do pacote: aceita geocodigo (numerico ou
texto), sigla de UF (expande para todos os municipios), nome de
municipio (sem acento, caixa indiferente) e a forma `"Municipio/UF"`.
Ambiguidade (o mesmo nome em mais de uma UF) nunca e resolvida em
silencio: gera um erro classificado (`fbds_ambiguous_municipality`)
listando os candidatos.

## Usage

``` r
fbds_resolve(x, uf = NULL, strict = TRUE)
```

## Arguments

- x:

  Vetor de geocodigos, nomes, UFs ou `"Municipio/UF"`.

- uf:

  UF usada para desambiguar um nome de municipio informado sem UF.
  Ignorada para entradas que ja trazem geocodigo, UF ou
  `"Municipio/UF"`.

- strict:

  Se `TRUE` (padrao), um identificador que nao resolve a nenhum
  municipio interrompe a execucao com `fbds_unknown_municipality`. Se
  `FALSE`, o identificador e ignorado com um aviso.

## Value

Vetor de geocodigos (texto, 7 digitos), sem duplicatas, na ordem de
primeira ocorrencia.

## Examples

``` r
fbds_resolve("1100031")
#> [1] "1100031"
fbds_resolve("cabixi")
#> [1] "1100031"
fbds_resolve("Cabixi/RO")
#> [1] "1100031"
fbds_resolve("RO")
#>  [1] "1100015" "1100023" "1100031" "1100049" "1100056" "1100064" "1100072"
#>  [8] "1100080" "1100098" "1100106" "1100114" "1100122" "1100130" "1100148"
#> [15] "1100155" "1100189" "1100205" "1100254" "1100262" "1100288" "1100296"
#> [22] "1100304" "1100320" "1100338" "1100346" "1100379" "1100403" "1100452"
#> [29] "1100502" "1100601" "1100700" "1100809" "1100908" "1100924" "1100940"
#> [36] "1101005" "1101104" "1101203" "1101302" "1101401" "1101435" "1101450"
#> [43] "1101468" "1101476" "1101484" "1101492" "1101500" "1101559" "1101609"
#> [50] "1101708" "1101757" "1101807"
```
