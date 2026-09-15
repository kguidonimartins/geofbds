# geofbds 0.0.0.9000

## Novidades

- Adicionado um aplicativo Shiny em `inst/shiny/` para selecionar um
  município, camada e tipo, estimar o download, carregar os dados como `sf` e
  visualizar as geometrias em um mapa.
- O mapa do aplicativo oferece `OpenStreetMap` como fundo padrão e
  `Esri.WorldImagery` como alternativa.
- O aplicativo Shiny colore as geometrias por atributos temáticos, com
  legendas categóricas ou contínuas, seleção de campo e reparo de geometrias
  inválidas antes da renderização.
- O aplicativo Shiny usa diretórios temporários exclusivos por sessão, valida
  conjuntos de shapefile antes da leitura e disponibiliza um ZIP validado para
  download.
- Adicionados limites configuráveis para o aplicativo Shiny por meio de
  `GEOFBDS_SHINY_MAX_BYTES` e `GEOFBDS_SHINY_MAX_FEATURES`.
- Adicionados os comandos `make run-app` e `make deploy` para executar e
  publicar o aplicativo.
- Adicionados testes comportamentais para seleção de tipos, rejeição de
  manifestos incompletos e carregamento do aplicativo.
- O aplicativo Shiny agora apresenta um guia recolhível com a sequência
  de cliques e um próximo passo contextual para cada etapa da consulta.
- O aplicativo Shiny registra eventos de sessão, seleções, etapas, arquivos,
  dados carregados, renderização do mapa, downloads e erros no log do
  processo.
- O aplicativo Shiny passou a usar um tema Bootstrap 5 com `bslib` (cores
  derivadas de uma cor primária própria, cabeçalhos em cartões, navegação em
  abas e alternância de modo claro/escuro), substituindo o layout padrão do
  Bootstrap 3.
- Adicionada a aba “Sobre” no aplicativo Shiny, com a origem e os metadados
  oficiais dos dados, as camadas disponíveis, a citação recomendada, o
  contato e a relação do aplicativo com o pacote `geofbds`.
- Corrigida a paleta de atributos categóricos sem cores predefinidas.
- Corrigido o acesso ao catálogo `fbds_municipios` quando as funções são
  chamadas pelo operador `::` sem `library(geofbds)`: a resolução falhava com
  `object 'fbds_municipios' not found`.
