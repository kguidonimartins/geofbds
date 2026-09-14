# Camadas de dados disponiveis no portal

Camadas de dados disponiveis no portal

## Usage

``` r
fbds_layers()
```

## Value

Um tibble com uma linha por camada: `layer` (identificador curto usado
nas funcoes do pacote), `dir` (nome do diretorio no portal) e
`description`.

## Examples

``` r
fbds_layers()
#> # A tibble: 3 × 3
#>   layer       dir         description                    
#>   <chr>       <chr>       <chr>                          
#> 1 app         APP         Areas de Preservacao Permanente
#> 2 hidrografia HIDROGRAFIA Massas d'agua, nascentes e rios
#> 3 uso         USO         Uso e cobertura do solo        
```
