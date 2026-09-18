# AGENTS.md

Guia para agentes de IA trabalhando neste repositório. `geofbds` é um
pacote R que descobre, baixa e lê dados geoespaciais municipais da
[Geo FBDS](https://geo.fbds.org.br) — uso do solo, hidrografia e APP.

Contexto de projeto: `dev/PLAN.md` (roteiro de implementação, fases 0-8,
todas concluídas) e `dev/SPECS.md` (proposta original, avaliação do
código legado). Ambos ficam no repositório mas fora do build
(`.Rbuildignore`).

## Comandos essenciais

```bash
make document      # devtools::document()
make tests         # devtools::test()
make check          # devtools::check()
make catalog        # regenera data/fbds_municipios.rda a partir do xls
make qml            # regenera inst/qgis/*.qml a partir de fbds_palette()
air format .        # formata R/*.R (rode antes de commitar)
```

Sempre rode `make tests` e `make check` antes de considerar uma mudança
pronta — o pacote está em 0 errors/0 warnings/0 notes; qualquer regressão
deve ser corrigida, não silenciada.

## Documentação e histórico

- O arquivo-fonte do README é `README.Rmd`. Edite sempre o `.Rmd`; regenere
  `README.md` com `make render`.
- `NEWS.md` registra as mudanças voltadas ao usuário em cada versão. Ao
  implementar uma funcionalidade, correção ou alteração relevante do pacote,
  atualize o `NEWS.md` correspondente.

## Arquitetura: quatro camadas, dependência só para baixo

```
4. Leitura (sf) ──────── fbds_read()  fbds_get()
3. Download ──────────── fbds_plan()  fbds_fetch()  fbds_download_*()
2. Descoberta ────────── fbds_files()  fbds_coverage()
1. Catálogo (offline) ── fbds_catalog()  fbds_resolve()  fbds_layers()  fbds_url()
```

Camadas 1 e 4 nunca tocam rede. Toda função pública aceita geocódigo,
nome de município ou UF via `fbds_resolve()` — não reimplemente essa
resolução em outro lugar.

## Armadilhas reais encontradas nesta base (não são hipotéticas)

- **`ifelse()` em vetor de tamanho zero devolve `logical(0)`, não
  `character(0)`.** Já quebrou `dplyr::bind_rows()` entre blocos de
  `fbds_fetch()` quando um bloco tinha zero linhas. Use indexação
  (`x[cond] <- valor`) ou `dplyr::if_else()` (tipo-estável), nunca
  `ifelse()` puro em código que pode receber entrada vazia.
- **Isole `geofbds.base_url` E `geofbds.cache_dir` em testes/scripts
  manuais que mockam rede.** `get_listing_cached()` grava um cache em
  disco persistente (`fbds_cache_dir()`, padrão
  `tools::R_user_dir("geofbds", "cache")` — fora do repo). Isolar só a
  URL faz um teste servir dados obsoletos de um servidor mock já morto
  de uma sessão anterior. Use `withr::local_options()` com os dois.
- **`webfakes::new_app_process()` roda a app em processo separado.**
  Handlers só enxergam o que fecham localmente (funções-fábrica com
  `force()`); uma variável do `globalenv()` do script de teste não
  existe no processo filho e falha com "object not found" — não com
  um erro óbvio de rede.
- **`expect_warning()`/`expect_error()` com `class = ...` não devolvem
  o valor da expressão** quando o aviso é pego — devolvem o objeto da
  condição. Se precisar do valor de retorno E confirmar a classe do
  aviso, use `withCallingHandlers()` + `invokeRestart("muffleWarning")`
  manualmente.
- **`inst/exec/` dispara WARNING no `R CMD check`** (nome que a
  instalação do R trata de forma especial). O script de CLI está em
  `inst/scripts/geofbds`.
- **`air format .` reformata todo `R/*.R`**, incluindo qualquer script
  legado que ainda exista na raiz. Confira `git diff` depois de
  formatar antes de commitar.

## Testes

Tudo local — `tests/testthat/fixtures/*.html` são páginas reais
capturadas do portal (via `data-raw/capture_fixtures.R`), e os testes
de rede sobem um `webfakes` em loopback. Nenhum teste deveria precisar
de acesso real à internet; se um precisar, pare e reconsidere.

## Catálogo (`fbds_municipios`)

5.470 municípios, gerado por `data-raw/build_catalog.R`. `slug_status`
começa `"unverified"` para todos; `data-raw/verify_slugs.R` confere
contra o portal real e atualiza para `"ok"`/`"fixed"`/`"missing"`. Os
5.470 já estão verificados (nenhum `"missing"`). 11 municípios do
Piauí tinham nome corrompido na planilha de origem (acentos virando
letras soltas ou somem, ex. `BOQUEIRlO` em vez de `BOQUEIRÃO`) — o
defeito está no `.xls`, não na leitura; `build_catalog.R` corrige os
11 nomes com uma tabela hardcoded (conferida contra a API do IBGE),
documentada inline. Depois de rodar `verify_slugs.R` de novo (ex. se a
planilha-fonte mudar), rode `make catalog` para incorporar o
resultado.

## Dados da FBDS

Metadados oficiais
(<https://geo.fbds.org.br/Metadados%20Mapeamento%20FBDS.pdf>): campo
"Restrições Legais" = "Irrestrito" (30/04/2023). Citado em
`inst/CITATION`. Não é aconselhamento jurídico — confira você mesmo
antes de qualquer uso que dependa disso.

## Coisas para não inventar

- Unidades, categorias ou definições dos dados da FBDS que não estejam
  confirmadas em `dev/SPECS.md`, nos metadados oficiais, ou verificadas
  diretamente (ex.: as colunas `area_*` de `fbds_municipios` são em
  hectares — confirmado na própria planilha-fonte, linha acima do
  cabeçalho lido).
- Convenções de licença/repositório sem checar `DESCRIPTION`/`git
  remote -v` primeiro.
