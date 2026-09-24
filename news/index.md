# Changelog

## geofbds 0.0.0.9000

### Novidades

- [`fbds_resolve()`](https://kguidonimartins.github.io/geofbds/reference/fbds_resolve.md)
  agora retorna os geocódigos nomeados pelos municípios do catálogo,
  facilitando a conferência da correspondência entre nome e código.
- Adicionada
  [`fbds_manifest_status()`](https://kguidonimartins.github.io/geofbds/reference/fbds_manifest_status.md),
  que consulta o histórico agregado de downloads em `manifest.json` (ou
  reconstrói o resumo a partir do índice CSV legado), e passou a
  registrar a versão do pacote em cada manifesto
  ([\#5](https://github.com/kguidonimartins/geofbds/issues/5)). Quando a
  data ou a versão não são conhecidas, `manifest.json` grava `null` (e
  não um objeto vazio [`{}`](https://rdrr.io/r/base/Paren.html)).
- Adicionado um aplicativo Shiny em `inst/shiny/` para selecionar um
  município, camada e tipo, estimar o download, carregar os dados como
  `sf` e visualizar as geometrias em um mapa.
- O mapa do aplicativo oferece `OpenStreetMap` como fundo padrão e
  `Esri.WorldImagery` como alternativa.
- O aplicativo Shiny colore as geometrias por atributos temáticos, com
  legendas categóricas ou contínuas, seleção de campo e reparo de
  geometrias inválidas antes da renderização.
- O aplicativo Shiny usa diretórios temporários exclusivos por sessão,
  valida conjuntos de shapefile antes da leitura e disponibiliza um ZIP
  validado para download.
- Adicionados limites configuráveis para o aplicativo Shiny por meio de
  `GEOFBDS_SHINY_MAX_BYTES` e `GEOFBDS_SHINY_MAX_FEATURES`.
- Adicionados os comandos `make run-app` e `make deploy` para executar e
  publicar o aplicativo.
- Adicionados testes comportamentais para seleção de tipos, rejeição de
  manifestos incompletos e carregamento do aplicativo.
- O aplicativo Shiny agora apresenta um guia recolhível com a sequência
  de cliques e um próximo passo contextual para cada etapa da consulta.
- O aplicativo Shiny registra eventos de sessão, seleções, etapas,
  arquivos, dados carregados, renderização do mapa, downloads e erros no
  log do processo.
- O aplicativo Shiny passou a usar um tema Bootstrap 5 com `bslib`
  (cores derivadas de uma cor primária própria, cabeçalhos em cartões,
  navegação em abas e alternância de modo claro/escuro), substituindo o
  layout padrão do Bootstrap 3.
- Adicionada a aba “Sobre” no aplicativo Shiny, com a origem e os
  metadados oficiais dos dados, as camadas disponíveis, a citação
  recomendada, o contato e a relação do aplicativo com o pacote
  `geofbds`.
- Corrigida a paleta de atributos categóricos sem cores predefinidas.
- Corrigido o acesso ao catálogo `fbds_municipios` quando as funções são
  chamadas pelo operador `::` sem
  [`library(geofbds)`](https://github.com/kguidonimartins/geofbds): a
  resolução falhava com `object 'fbds_municipios' not found`.
- Adicionada
  [`fbds_palette()`](https://kguidonimartins.github.io/geofbds/reference/fbds_palette.md),
  que devolve um vetor de cores nomeado para colorir classes temáticas
  dos shapefiles da FBDS (`CLASSE_USO`, `HIDRO`, `NATUREZA`, `RIO`), com
  cores de reserva estáveis para classes sem cor predefinida. O
  aplicativo Shiny passou a usar essa mesma função, em vez de manter sua
  própria cópia da paleta.
- As cores de `CLASSE_USO` passaram a seguir o MapBiomas Coleção 11,
  para consistência visual com a plataforma mais usada para mapas de uso
  e cobertura do solo no Brasil. Quatro das seis classes têm
  equivalência direta (água, área edificada, formação florestal,
  silvicultura); as outras duas (área antropizada, formação não
  florestal) são agregados da FBDS sem classe-folha equivalente no
  MapBiomas e usam a aproximação mais próxima (Mosaico de Usos e
  Formação Campestre, respectivamente).
- Corrigida a cor da classe `HIDRO` `"curso d'água (>10m)"` (presente em
  `hidrografia/RIOS_DUPLOS`), que antes caía na paleta de reserva por
  não estar na lista de cores conhecidas.
- Adicionados estilos categorizados do QGIS (`inst/qgis/*.qml`) para
  `CLASSE_USO`, `HIDRO`, `MAPBIOMAS`, `NATUREZA` e `RIO`, com as mesmas
  cores de
  [`fbds_palette()`](https://kguidonimartins.github.io/geofbds/reference/fbds_palette.md).
  Basta carregá-los em Propriedades da camada \> Simbologia \> Estilo \>
  Carregar Estilo, depois de abrir o shapefile correspondente no QGIS.
  Regenerados por `make qml` (`data-raw/build_qml.R`) sempre que as
  cores de
  [`fbds_palette()`](https://kguidonimartins.github.io/geofbds/reference/fbds_palette.md)
  mudarem.
- Adicionadas
  [`fbds_qgis_style()`](https://kguidonimartins.github.io/geofbds/reference/fbds_qgis_style.md)
  e
  [`fbds_qgis_style_fields()`](https://kguidonimartins.github.io/geofbds/reference/fbds_qgis_style_fields.md):
  os arquivos `.qml` ficam dentro do pacote instalado e não são visíveis
  para quem instala via CRAN/`remotes::install_github()`;
  [`fbds_qgis_style()`](https://kguidonimartins.github.io/geofbds/reference/fbds_qgis_style.md)
  copia os estilos escolhidos para fora do pacote (por padrão, para o
  diretório de trabalho atual), de onde o QGIS consegue carregá-los.
