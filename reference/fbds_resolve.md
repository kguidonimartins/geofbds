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

Vetor nomeado de geocodigos (texto, 7 digitos), com o nome do municipio
do catalogo em cada elemento, sem duplicatas e na ordem de primeira
ocorrencia.

## Examples

``` r
fbds_resolve("1100031")
#>    CABIXI 
#> "1100031" 
fbds_resolve("cabixi")
#>    CABIXI 
#> "1100031" 
fbds_resolve("Cabixi/RO")
#>    CABIXI 
#> "1100031" 
fbds_resolve("RO")
#>     ALTA FLORESTA D'OESTE                 ARIQUEMES                    CABIXI 
#>                 "1100015"                 "1100023"                 "1100031" 
#>                    CACOAL                CEREJEIRAS         COLORADO DO OESTE 
#>                 "1100049"                 "1100056"                 "1100064" 
#>                CORUMBIARA             COSTA MARQUES           ESPIGÃO D'OESTE 
#>                 "1100072"                 "1100080"                 "1100098" 
#>             GUAJARÁ-MIRIM                      JARU                 JI-PARANÁ 
#>                 "1100106"                 "1100114"                 "1100122" 
#>        MACHADINHO D'OESTE  NOVA BRASILÂNDIA D'OESTE       OURO PRETO DO OESTE 
#>                 "1100130"                 "1100148"                 "1100155" 
#>             PIMENTA BUENO               PORTO VELHO         PRESIDENTE MÉDICI 
#>                 "1100189"                 "1100205"                 "1100254" 
#>                RIO CRESPO            ROLIM DE MOURA       SANTA LUZIA D'OESTE 
#>                 "1100262"                 "1100288"                 "1100296" 
#>                   VILHENA     SÃO MIGUEL DO GUAPORÉ               NOVA MAMORÉ 
#>                 "1100304"                 "1100320"                 "1100338" 
#>          ALVORADA D'OESTE   ALTO ALEGRE DOS PARECIS              ALTO PARAÍSO 
#>                 "1100346"                 "1100379"                 "1100403" 
#>                   BURITIS   NOVO HORIZONTE DO OESTE               CACAULÂNDIA 
#>                 "1100452"                 "1100502"                 "1100601" 
#>    CAMPO NOVO DE RONDÔNIA        CANDEIAS DO JAMARI              CASTANHEIRAS 
#>                 "1100700"                 "1100809"                 "1100908" 
#>               CHUPINGUAIA                   CUJUBIM GOVERNADOR JORGE TEIXEIRA 
#>                 "1100924"                 "1100940"                 "1101005" 
#>           ITAPUÃ DO OESTE        MINISTRO ANDREAZZA          MIRANTE DA SERRA 
#>                 "1101104"                 "1101203"                 "1101302" 
#>               MONTE NEGRO                NOVA UNIÃO                   PARECIS 
#>                 "1101401"                 "1101435"                 "1101450" 
#>      PIMENTEIRAS DO OESTE     PRIMAVERA DE RONDÔNIA        SÃO FELIPE D'OESTE 
#>                 "1101468"                 "1101476"                 "1101484" 
#>  SÃO FRANCISCO DO GUAPORÉ              SERINGUEIRAS             TEIXEIRÓPOLIS 
#>                 "1101492"                 "1101500"                 "1101559" 
#>                 THEOBROMA                     URUPÁ             VALE DO ANARI 
#>                 "1101609"                 "1101708"                 "1101757" 
#>           VALE DO PARAÍSO 
#>                 "1101807" 
```
