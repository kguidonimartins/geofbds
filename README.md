
# geofbds

<!-- badges: start -->

[![R-CMD-check](https://github.com/kguidonimartins/geofbds/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/kguidonimartins/geofbds/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

O geofbds descobre, baixa e lê os dados geoespaciais municipais
publicados pela [Geo FBDS](https://geo.fbds.org.br) — uso e cobertura do
solo, hidrografia e Áreas de Preservação Permanente (APP), por município
brasileiro.

## Instalação

O pacote ainda não está no CRAN:

``` r
# install.packages("remotes")
remotes::install_github("kguidonimartins/geofbds")
```

## Dados disponíveis

Para cada município, o portal expõe três conjuntos de dados, em
shapefile:

| Camada | Diretório | Descrição |
|----|----|----|
| `app` | `APP` | Áreas de Preservação Permanente |
| `hidrografia` | `HIDROGRAFIA` | Massas d’água, nascentes, rios simples e duplos |
| `uso` | `USO` | Uso e cobertura do solo |

``` r
library(geofbds)

fbds_layers()
```

## Uso básico

Geocódigo do IBGE, nome de município ou sigla de UF — tudo passa por
`fbds_resolve()`, o resolvedor universal do pacote. Nome ambíguo (existe
em mais de uma UF) nunca é escolhido em silêncio: gera erro
classificado, listando os candidatos.

``` r
fbds_resolve("1100031")
fbds_resolve("Cabixi")
fbds_resolve("Cabixi/RO")
```

O catálogo interno (5.470 municípios) é consultável offline:

``` r
fbds_catalog(uf = "RO")
```

Antes de baixar, dá para ver o que existe:

``` r
fbds_files("1100031")
fbds_coverage("RO")
```

Baixar um ou mais municípios devolve um manifesto — uma linha por
arquivo, com status, tamanho e sha256:

``` r
m <- fbds_download_municipality(c("1100031", "1100049"), layers = "app")
dplyr::count(m, status)
fbds_validate(m) # avisa se algum shapefile estiver incompleto
```

E ler, direto como `sf`:

``` r
app_ro <- fbds_read(m, layer = "app", type = "APP")

# ou baixar + ler em um passo, no padrao do geobr
app_ro <- fbds_get("1100031", layer = "app", type = "APP")
```

## Colorir por classe

`fbds_palette()` devolve um vetor de cores nomeado para os campos
temáticos mais comuns dos dados (`CLASSE_USO`, `HIDRO`, `NATUREZA`,
`RIO`), para não redefinir a paleta a cada script. As cores de
`CLASSE_USO` seguem o [MapBiomas Coleção 11](https://mapbiomas.org/),
para consistência visual com a plataforma mais usada para mapas de uso e
cobertura do solo no Brasil:

``` r
fbds_palette("CLASSE_USO")

uso <- fbds_get("Serra da Saudade", layer = "uso", type = "USO")
plot(uso["CLASSE_USO"], col = fbds_palette("CLASSE_USO", uso$CLASSE_USO))
```

Classes sem cor predefinida (de outro campo, ou uma categoria nova)
recebem uma cor de reserva estável, em vez de erro.

Para quem prefere o QGIS, o pacote traz essas mesmas cores como estilos
categorizados prontos (`.qml`). Como eles ficam dentro do pacote
instalado, `fbds_qgis_style()` copia os que você quiser para o diretório
atual (a raiz do seu projeto, por padrão):

``` r
fbds_qgis_style_fields()
fbds_qgis_style() # copia todos para "."; use dest_dir para outro lugar
```

Depois, no QGIS: abra o shapefile correspondente e carregue o `.qml` em
Propriedades da camada \> Simbologia \> Estilo \> Carregar Estilo.

| Campo        | Arquivo          | Aplica em                |
|--------------|------------------|--------------------------|
| `CLASSE_USO` | `CLASSE_USO.qml` | `USO.shp`, `APP_USO.shp` |
| `HIDRO`      | `HIDRO.qml`      | `APP.shp`                |
| `NATUREZA`   | `NATUREZA.qml`   | `MASSAS_DAGUA.shp`       |
| `RIO`        | `RIO.qml`        | `MASSAS_DAGUA.shp`       |

## Download em escala: por estado

O ganho principal deste pacote sobre o script que o antecedeu:
`fbds_download_state()` estima o volume antes de baixar, processa os
municípios em blocos, e retoma de onde parou se a execução for
interrompida — sem rebaixar o que já está completo.

``` r
ro <- fbds_download_state("RO", layers = "app")

# interrompida no meio? rode de novo: só os pendentes sao processados
ro <- fbds_download_state("RO", layers = "app")
```

Veja `vignette("estados", package = "geofbds")` para o fluxo completo.

## Linha de comando

``` bash
Rscript inst/scripts/geofbds municipality 1100031 1100049 --layers=app,uso
Rscript inst/scripts/geofbds state RO --workers=6 --yes
Rscript inst/scripts/geofbds files RO --layers=app
```

## Aplicativo Shiny

O aplicativo permite selecionar um município, uma camada e um tipo de
dado, planejar o volume, baixar o conjunto validado e visualizar as
geometrias em um mapa.

Na interface, siga esta sequência:

1.  Escolha o município e a camada.
2.  Clique em **Descobrir tipos**.
3.  Escolha o tipo do conjunto.
4.  Clique em **Planejar consulta** e confira o volume previsto.
5.  Clique em **Baixar e visualizar**.
6.  Escolha um atributo temático ou explore o mapa; o ZIP validado fica
    disponível após o carregamento.

Acesse via: <https://kguidonimartins.shinyapps.io/geofbds/>

Também é possível executar o aplicativo localmente. Com o pacote e as
dependências instalados, execute:

``` bash
make run-app
```

O aplicativo usa um diretório temporário por sessão. Os limites padrão
são 250 MB por consulta e 250.000 feições; eles podem ser ajustados com
`GEOFBDS_SHINY_MAX_BYTES` e `GEOFBDS_SHINY_MAX_FEATURES`.

## Cache

Por padrão, tudo fica em `~/.cache/R/geofbds/`, com confirmação no
primeiro uso em sessão interativa. Para outro diretório:

``` r
fbds_cache_set("dados/geo-fbds")
fbds_cache_status()
```

## Dados e termos de uso

Os dados são da Fundação Brasileira para o Desenvolvimento Sustentável
(FBDS), projeto “Mapeamento em Alta Resolução dos Biomas Brasileiros”
(2013–2023). Conforme os metadados publicados pela FBDS
([`Metadados Mapeamento FBDS.pdf`](https://geo.fbds.org.br/Metadados%20Mapeamento%20FBDS.pdf),
30/04/2023), as restrições legais de uso são **irrestritas**. Ainda
assim, confira os metadados você mesmo antes de redistribuir ou usar
comercialmente — este pacote só automatiza o acesso, não os termos.

## Como funciona

Quatro camadas, cada uma testável sozinha:

```
4. Leitura (sf) ──────── fbds_read()  fbds_get()
3. Download ──────────── fbds_plan()  fbds_fetch()  fbds_download_*()
2. Descoberta ────────── fbds_files()  fbds_coverage()
1. Catálogo (offline) ── fbds_catalog()  fbds_resolve()  fbds_layers()  fbds_url()
```

Veja `vignette("geofbds", package = "geofbds")` para mais detalhes.

## Projetos relacionados

[pyFBDS](https://github.com/open-geodata/pyFBDS): desenvolvido em python
