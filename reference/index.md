# Package index

## Catálogo (offline)

Resolver identificadores e consultar o catálogo interno de municípios.

- [`fbds_resolve()`](https://kguidonimartins.github.io/geofbds/reference/fbds_resolve.md)
  : Resolver identificadores de municipio em geocodigos canonicos
- [`fbds_catalog()`](https://kguidonimartins.github.io/geofbds/reference/fbds_catalog.md)
  : Consultar o catalogo de municipios
- [`fbds_layers()`](https://kguidonimartins.github.io/geofbds/reference/fbds_layers.md)
  : Camadas de dados disponiveis no portal
- [`fbds_ufs()`](https://kguidonimartins.github.io/geofbds/reference/fbds_ufs.md)
  : Listar as 27 UFs com contagem de municipios
- [`fbds_url()`](https://kguidonimartins.github.io/geofbds/reference/fbds_url.md)
  : Montar URLs do portal para um municipio
- [`fbds_municipios`](https://kguidonimartins.github.io/geofbds/reference/fbds_municipios.md)
  : Catalogo de municipios brasileiros da Geo FBDS

## Descoberta

Listar o que existe no portal antes de baixar.

- [`fbds_files()`](https://kguidonimartins.github.io/geofbds/reference/fbds_files.md)
  : Listar arquivos disponiveis para municipios x camadas
- [`fbds_coverage()`](https://kguidonimartins.github.io/geofbds/reference/fbds_coverage.md)
  : Estimar cobertura de dados por municipio x camada

## Download

Planejar e executar downloads, por município.

- [`fbds_plan()`](https://kguidonimartins.github.io/geofbds/reference/fbds_plan.md)
  : Planejar um download
- [`fbds_fetch()`](https://kguidonimartins.github.io/geofbds/reference/fbds_fetch.md)
  : Executar um plano de download
- [`fbds_download_municipality()`](https://kguidonimartins.github.io/geofbds/reference/fbds_download_municipality.md)
  : Baixar dados de um ou mais municipios
- [`fbds_validate()`](https://kguidonimartins.github.io/geofbds/reference/fbds_validate.md)
  : Validar completude dos conjuntos de shapefile de um manifesto

## Download em escala

Por estado ou nacional, com retomada.

- [`fbds_download_state()`](https://kguidonimartins.github.io/geofbds/reference/fbds_download_state.md)
  : Baixar todos os municipios de uma ou mais UFs, com retomada
- [`fbds_download_all()`](https://kguidonimartins.github.io/geofbds/reference/fbds_download_all.md)
  : Baixar o espelho nacional

## Leitura

Ler os dados baixados como `sf`.

- [`fbds_read()`](https://kguidonimartins.github.io/geofbds/reference/fbds_read.md)
  : Ler dados espaciais de uma camada
- [`fbds_get()`](https://kguidonimartins.github.io/geofbds/reference/fbds_get.md)
  : Baixar e ler dados espaciais em um passo

## Cache

- [`fbds_cache_dir()`](https://kguidonimartins.github.io/geofbds/reference/fbds_cache_dir.md)
  : Diretorio de cache do pacote
- [`fbds_cache_set()`](https://kguidonimartins.github.io/geofbds/reference/fbds_cache_set.md)
  : Definir o diretorio de cache do pacote
- [`fbds_cache_status()`](https://kguidonimartins.github.io/geofbds/reference/fbds_cache_status.md)
  : Inventario do cache do pacote
- [`fbds_cache_clean()`](https://kguidonimartins.github.io/geofbds/reference/fbds_cache_clean.md)
  : Limpar o cache do pacote

## Pacote

- [`geofbds`](https://kguidonimartins.github.io/geofbds/reference/geofbds-package.md)
  [`geofbds-package`](https://kguidonimartins.github.io/geofbds/reference/geofbds-package.md)
  : geofbds: Download and Read Municipal Data from Geo FBDS
