# Cores padronizadas para classes tematicas dos dados da FBDS

Devolve um vetor de cores nomeado para colorir mapas por classe, sem
redefinir a paleta a cada script. Cobre os campos categoricos mais
comuns dos shapefiles da FBDS: `"CLASSE_USO"` (uso e cobertura do solo,
em `uso/USO` e `app/APP_USO`), `"HIDRO"` (feicao hidrografica que
originou a APP, em `app/APP` e nos conjuntos de `hidrografia`), e
`"NATUREZA"`/`"RIO"` (ambos de `hidrografia/MASSAS_DAGUA`). Classes
conhecidas destes campos recebem sempre a mesma cor; classes
desconhecidas (de outro campo, ou uma categoria nova) recebem uma cor de
reserva estavel, tirada de uma paleta qualitativa (ColorBrewer "Dark2"),
na ordem em que aparecem em `values`.

## Usage

``` r
fbds_palette(field, values = NULL)
```

## Arguments

- field:

  Nome do campo tematico (ex. `"CLASSE_USO"`). Aceita qualquer nome de
  coluna; campos sem cores conhecidas usam so a paleta de reserva.

- values:

  Vetor com as classes a colorir (tipicamente uma coluna de um objeto
  `sf`, ex. `dados$CLASSE_USO`). `NULL` (padrao) devolve todas as cores
  conhecidas de `field`, ou um vetor vazio se `field` nao tiver cores
  conhecidas.

## Value

Vetor de cores nomeado (codigos hex), um elemento por classe distinta.

## Details

As cores de `"CLASSE_USO"` seguem o MapBiomas Colecao 11, para
consistencia visual com a plataforma mais usada para mapas de uso e
cobertura do solo no Brasil (correspondencia classe a classe documentada
em `R/palette.R`).

## Examples

``` r
fbds_palette("CLASSE_USO")
#>                   água       área antropizada         área edificada 
#>              "#2532e4"              "#ffefc3"              "#d4271e" 
#>     formação florestal formação não florestal           silvicultura 
#>              "#1f8d49"              "#d6bc74"              "#7a5900" 
fbds_palette("HIDRO")
#>  curso d'água (0 - 10m) curso d'água (10 - 50m)     curso d'água (>10m) 
#>               "#6baed6"               "#08519c"               "#08519c" 
#>            massa d'água                nascente 
#>               "#31a8c8"               "#756bb1" 

if (FALSE) { # \dontrun{
uso <- fbds_get("serra da saudade", layer = "uso", type = "USO")
cores <- fbds_palette("CLASSE_USO", uso$CLASSE_USO)
plot(uso["CLASSE_USO"], col = cores[uso$CLASSE_USO])
} # }
```
