# PLANO — implementação do pacote R `geofbds`

Plano de execução do que `SPECS.md` propõe. `SPECS.md` avalia e desenha;
este documento diz em que ordem construir, com qual critério de pronto.

## Contexto

O repositório hoje é um projeto de análise com dois scripts soltos:
`get-by-geocode.R` (download por geocódigo, com validação, manifesto e
retomada — a base boa) e `get-full-geo-fbds-data.R` (varredura nacional
exploratória, com `foreach`/`doParallel` e dependência de `misc::view_vd()`,
pacote pessoal não público). O catálogo de 5.470 municípios vive em
`data/raw/TABELA CONSOLIDADA.xls` e é lido em tempo de execução.

Este plano transforma esses scripts em pacote, corrige os 19 problemas
listados em §2.2 do SPECS e entrega o que o repositório ainda não faz —
**download por estado, com paralelismo, retomada e verificação de
integridade**.

Resultado pretendido: `devtools::install_github()` instala o pacote; o usuário
chama `fbds_download_state("RO")` e recebe um manifesto auditável; nenhum
caminho de máquina e nenhum `.xls` são necessários em runtime.

## Decisões já fixadas

| Decisão | Escolha |
| --- | --- |
| Nome | `geofbds` |
| Idioma da API | **Inglês** (`fbds_download_state()`); documentação, vinhetas e mensagens `cli` em português |
| Layout | Pacote **na raiz do repositório** |
| Sondagens ao portal (§7 do SPECS) | **Os scripts são escritos aqui, você executa**; o parser é calibrado com o HTML que você trouxer |
| Motor HTTP | `curl::multi_download()` |
| Destino padrão | `tools::R_user_dir("geofbds", "cache")` |

Ambiente já verificado: R 4.6.1 com `devtools`, `usethis`, `roxygen2`,
`testthat`, `curl`, `cli`, `rlang`, `dplyr`, `tidyr`, `tibble`, `rvest`,
`xml2`, `vroom`, `withr`, `sf`, `readxl`, `janitor`, `httptest2`, `webfakes` e
`pkgdown` instalados. Nenhuma instalação de dependência é necessária.

Planilha já inspecionada: aba `Levantamento do Uso do Solo`, `skip = 2`, 5.470
linhas, 9 colunas — `...1` (geocódigo numérico), `...2` (município, já em
caixa alta), `...3` (UF) e seis colunas de área (`Água`, `Silvicultura`,
`Formação Florestal`, `Formação não Florestal`, `Área edificada`,
`Área antropizada`). Distribuição por UF confere com o esperado (MG 853,
SP 645, RO 52).

---

## Fase 0 — Esqueleto do pacote

Arquivos: `DESCRIPTION`, `NAMESPACE`, `LICENSE.md`, `.Rbuildignore`,
`R/geofbds-package.R`, `.github/workflows/R-CMD-check.yaml`.

**Reorganização estrutural obrigatória antes de tudo.** Em um pacote, `data/`
é reservado a `.rda`; o `.xls` e as pastas de projeto precisam sair, ou
`R CMD check` falha:

- `data/raw/TABELA CONSOLIDADA.xls` → `data-raw/TABELA CONSOLIDADA.xls` (`git mv`)
- remover `data/temp/`, `data/clean/`, `data/raw/`, `code/`, `output/`,
  `geo-fbds.qgz` (arquivo vazio) — tudo preservado no histórico do git
- `docs/` fica reservado ao `pkgdown` (Fase 7)
- `.Rbuildignore`: `^geo-fbds\.Rproj$`, `^\.Rproj\.user$`, `^data-raw$`,
  `^SPECS\.md$`, `^PLAN\.md$`, `^docs$`, `^\.github$`, `^_pkgdown\.yml$`,
  `^README\.Rmd$`

`DESCRIPTION`: `Package: geofbds`, autoria Karlo Guidoni
(`kguidonimartins@gmail.com`), `License: MIT + file LICENSE`,
`Encoding: UTF-8`, `Depends: R (>= 4.1)` (usa `|>`),
`Config/testthat/edition: 3`.

- `Imports`: `cli`, `curl (>= 5.0.0)`, `dplyr`, `rlang`, `rvest`, `tibble`,
  `tidyr`, `tools`, `utils`, `vroom`, `withr`, `xml2`
- `Suggests`: `sf`, `testthat (>= 3.0.0)`, `webfakes`, `knitr`, `rmarkdown`,
  `readxl`, `janitor`
- **Sem `stringr`, `glue`, `here`, `textclean`**: os poucos usos viram
  helpers base em `R/utils.R` (`trimws`, `toupper`, `sub`, `grepl`,
  `iconv(..., to = "ASCII//TRANSLIT")`) e um `interp_path()` de ~10 linhas
  para o `path_pattern`. `readxl`/`janitor` só existem para `data-raw/`.

`R/geofbds-package.R` define `.onLoad()` com os padrões de opção
(`geofbds.base_url = "https://geo.fbds.org.br"`, `geofbds.workers = 4`,
`geofbds.timeout = 300`, `geofbds.retries = 3`, `geofbds.user_agent`,
`geofbds.progress`, `geofbds.quiet`, `geofbds.listing_ttl = 7` dias,
`geofbds.confirm_bytes = 1e9`) via `op.geofbds`/`options()` — nunca com
valores calculados no build.

**Pronto quando:** `devtools::check()` limpo (0 errors/warnings/notes) em
pacote vazio.

## Fase 1 — Catálogo (camada 1, offline)

`data-raw/build_catalog.R`: lê o `.xls` com `readxl`, renomeia `...1/...2/...3`
para `geocode`/`municipality`/`uf`, converte o geocódigo para caractere de 7
dígitos **abortando se houver `NA`** (corrige §2.2-12, onde `sprintf("%.0f")`
transformava `NA` em `"NA"`), aplica `janitor::make_clean_names()` às seis
colunas de área (`area_agua`, `area_silvicultura`, …), deriva
`uf_code = substr(geocode, 1, 2)` e
`slug = toupper(janitor::make_clean_names(municipality))`, marca
`slug_status = "unverified"` e grava com `usethis::use_data(fbds_municipios)`.

`R/catalog.R`:

| Função | Nota de implementação |
| --- | --- |
| `fbds_catalog(uf, name, geocode)` | filtro simples sobre o dataset |
| `fbds_resolve(x, uf = NULL, strict = TRUE)` | ponto de entrada universal |
| `fbds_layers()` | `app`/`APP`, `hidrografia`/`HIDROGRAFIA`, `uso`/`USO` |
| `fbds_url(geocode, layer = NULL)` | `utils::URLencode()` em cada segmento (§2.2-11) |
| `fbds_ufs()` | 27 UFs com contagem |

`fbds_resolve()` aceita: geocódigo numérico ou texto; sigla de UF (expande
para todos os municípios); nome sem acento e com caixa indiferente; forma
`"Cabixi/RO"`. Normalização por `iconv` + `toupper` + colapso de espaços.
**Ambiguidade nunca é resolvida em silêncio**: `"Bom Jesus"` aborta com
`fbds_ambiguous_municipality` listando os candidatos.

`R/conditions.R`: `abort_fbds(message, class, ...)` sobre `rlang::abort()`,
com as classes `fbds_bad_geocode`, `fbds_unknown_municipality`,
`fbds_ambiguous_municipality`, `fbds_http_error`, `fbds_incomplete_shapefile`
(§2.2-18). Mensagens em português via `cli`.

Testes: `tests/testthat/test-catalog.R`, `test-resolve.R` — 100% offline,
incluindo `expect_error(class = "fbds_ambiguous_municipality")`.

**Pronto quando:** `fbds_resolve("1100031")`, `fbds_resolve("cabixi")`,
`fbds_resolve("Cabixi/RO")` e `fbds_resolve("RO")` devolvem geocódigos
corretos, sem rede.

## Fase 2 — Verificação contra o portal (scripts que **você** executa)

Dois scripts de manutenção são escritos aqui; você roda e devolve as saídas.

1. `data-raw/verify_slugs.R` — faz uma requisição por município
   (`curl::multi_download()` com `nobody = TRUE`, `workers` conservador,
   pausa entre blocos), registra o status HTTP de
   `{base_url}/{uf}/{slug}/APP/` e, para as falhas, testa variantes do slug
   (apóstrofo removido vs. virando `_`, acentos preservados, `%20` no lugar
   de `_`). Saída: `data-raw/slug_check.csv` com `geocode`, `slug_tentado`,
   `http_status`, `slug_final`.
2. `data-raw/capture_fixtures.R` — salva 4 páginas de listagem em
   `tests/testthat/fixtures/`: um `APP`, um `HIDROGRAFIA`, um `USO` com
   subdiretório (`MAPAS`/`info`/`USO.rar`) e um caso de 404.

Com o `slug_check.csv` em mãos, `build_catalog.R` passa a gravar o `slug`
verificado e `slug_status ∈ {ok, fixed, missing}` — a tabela congelada que o
SPECS §7.1 identifica como o maior risco técnico do pacote. Com as fixtures,
`parse_h5ai_listing()` é calibrado ao HTML real (resolvendo §7.2: se tamanho e
data só existirem via JavaScript, o parser passa a usar o endpoint
`?action=get` do h5ai, com `HEAD` como último recurso) e a lista de exclusão
de §7.3 fica fixada.

**Pronto quando:** `slug` congelado no dataset, cobertura conhecida e
fixtures HTML versionadas.

## Fase 3 — Descoberta (camada 2)

`R/http.R`: `fbds_request(url, ...)` com user-agent do pacote, timeout,
`retries` e backoff exponencial com jitter; converte HTTP ≥ 400 em
`fbds_http_error` classificado (§2.2-9).

`R/discover.R`:

- `parse_h5ai_listing(html, base_url)` → `file`, `url`, `bytes`, `modified`,
  `is_dir`; descarta o lixo do h5ai (`Parent Directory`, `powered by h5ai`,
  `navegadores modernos`, `Thumbs.db`) como já fazia o script antigo.
- `list_remote_dir(url, recursive)` — **entradas de diretório deixam de
  sumir em silêncio** (§2.2-7): com `recursive = FALSE` viram um aviso `cli`
  informando o que foi ignorado; com `recursive = TRUE` são percorridas.
- `fbds_files(x, layers = NULL, recursive = FALSE, cache = TRUE)` — expansão
  município × camada com `tidyr::expand_grid()`, **não** `crossing()`, que
  reordenava o resultado (§2.2-6); ordem de entrada preservada.
- `fbds_coverage(uf = NULL, layers = NULL)` — `n_files`, `bytes`,
  `has_shapefile`, `complete` por município × camada.

`R/cache.R`: `fbds_cache_dir()` (padrão `tools::R_user_dir("geofbds",
"cache")`, com confirmação no primeiro uso em sessão interativa — §2.2-2),
`fbds_cache_set()`, `fbds_cache_status()`, `fbds_cache_clean()`. Listagens
ficam em cache duplo: ambiente de sessão + `{cache}/listings/{uf}/{slug}/{layer}.rds`
com TTL (`geofbds.listing_ttl`).

Testes: `test-discover.R` com as fixtures da Fase 2, sem rede.

**Pronto quando:** `fbds_files()` reproduz, a partir das fixtures, a lista
esperada com tamanho e data.

## Fase 4 — Download por município (camada 3)

`R/plan.R`: `fbds_plan(x, layers = NULL, dest_dir = fbds_cache_dir(),
recursive = FALSE, skip_existing = TRUE,
path_pattern = "{uf}/{geocode}/{layer}/{file}")` devolve um objeto
`<fbds_plan>` (tibble + metadados) com `print()`/`format()` em `cli` mostrando
municípios, arquivos e volume estimado. Separar planejar de executar é o que
dá `dry_run` de verdade e testabilidade.

`R/fetch.R`: `fbds_fetch(plan, workers = 4, retries = 3, timeout = 300,
progress = TRUE, dry_run = FALSE)` sobre `curl::multi_download()` com
`resume = TRUE` — substitui o laço sequencial e a lógica manual de `.part`
(§2.2-14), mantendo a atomicidade. Após cada rodada, as linhas falhas são
re-tentadas com backoff até `retries`.

`R/manifest.R`:

- verificação de integridade: `bytes` baixados vs. `expected_bytes` da
  listagem; `cached` só é declarado quando o tamanho confere (§2.2-8);
  `sha256` via `cli::hash_file_sha256()` (sem dependência nova).
- `shapefile_sets()` + `fbds_validate(manifest)`: agrupa por nome-base e
  exige `.shp`/`.shx`/`.dbf`/`.prj`; conjunto incompleto vira
  `fbds_incomplete_shapefile` (§2.2-10).
- `write_manifest()` grava em `{dest}/_manifests/{run_id}.csv` com
  `vroom::vroom_write()` e atualiza `{dest}/_manifests/_index.csv` — nada de
  `manifesto.csv` sobrescrito na raiz (§2.2-13).

Colunas do manifesto: `run_id`, `geocode`, `uf`, `municipality`, `layer`,
`file`, `url`, `path`, `status` (`downloaded`|`cached`|`failed`|`skipped`),
`bytes`, `expected_bytes`, `sha256`, `http_status`, `attempts`, `error`,
`timestamp`.

`R/download.R`: `fbds_download_municipality(x, layers = NULL, ...)`, invólucro
fino de `fbds_plan() |> fbds_fetch()`.

Testes: `test-plan.R` (offline) e `test-fetch.R` servindo as fixtures por um
servidor local `webfakes` — inclusive os casos de 500 transitório (verifica o
retry) e de resposta truncada (verifica a detecção de tamanho).

**Pronto quando:** `fbds_download_municipality(c("1100031", "1100049"))`
entrega os mesmos arquivos que `get-by-geocode.R`, com manifesto mais rico.

## Fase 5 — Download por estado (o ganho principal)

`fbds_download_state(uf, layers = NULL, ..., ask = interactive())`:

- estimativa prévia de volume a partir de `fbds_coverage()`, com confirmação
  quando ultrapassa `geofbds.confirm_bytes`;
- execução em blocos por município (evita um plano de dezenas de milhares de
  linhas na memória e dá granularidade de retomada);
- `resume_state()` lê e atualiza `{dest}/_progress.csv` ao fim de cada bloco,
  de modo que uma execução interrompida na metade de Minas Gerais recomeça de
  onde parou;
- aceita mais de uma UF e `layers = NULL` (todas).

`fbds_download_all(..., ask = interactive())` existe para o espelho nacional,
com confirmação explícita e volume documentado.

**Pronto quando:** RO (52 municípios) baixa inteiro, é interrompido no meio e
retomado sem rebaixar o que já existe.

## Fase 6 — Leitura (camada 4)

`R/read.R`: `fbds_read(x, layer, type = NULL, crs = NULL)` aceita manifesto,
geocódigos ou diretório; usa `sf::st_read(options = "ENCODING=LATIN1")`,
harmoniza CRS com `sf::st_transform()` quando `crs` é dado, empilha municípios
e avisa quando um conjunto de shapefile está incompleto.
`fbds_get(x, layer, ...)` faz download + leitura em um passo (padrão `geobr`).

`sf` fica em `Suggests` com `rlang::check_installed("sf")` no ponto de uso —
quem só quer baixar não precisa de GDAL. Testes com
`skip_if_not_installed("sf")`.

## Fase 7 — CLI, documentação e CI

- `inst/exec/geofbds`: subcomandos `municipality`, `state`, `files`, com
  `--layers`, `--dest`, `--workers`, `--dry-run`; parsing em base R
  (`commandArgs()`), sem dependência nova. Preserva a ergonomia atual de
  `Rscript get-by-geocode.R 1100031 1100049` e acrescenta o modo estadual.
- `vignettes/geofbds.Rmd` (uso básico) e `vignettes/estados.Rmd` (escala) —
  trechos de rede com `eval = FALSE`.
- `README.Rmd` → `README.md`, reaproveitando o texto atual (que já é bom);
  `_pkgdown.yml` publicando em `docs/`; `inst/CITATION` com os termos de uso
  da FBDS (§7.4 — depende de você confirmar a licença dos dados).
- `.github/workflows/R-CMD-check.yaml` via
  `usethis::use_github_action("check-standard")`; testes de rede protegidos
  por `skip_on_cran()` + `skip_if_offline()`.

## Fase 8 — Aposentadoria dos scripts

Remover `get-by-geocode.R` e `get-full-geo-fbds-data.R` (preservados no
histórico do git) quando a paridade estiver verificada. `SPECS.md` e `PLAN.md`
ficam no repositório, fora do build via `.Rbuildignore`.

---

## Higiene aplicada em todas as fases

- Sem `.data$` em contexto *tidyselect* — nomes nus ou `all_of()`; `.data$`
  permanece só em `mutate()`/`filter()` (§2.2-15).
- `mutate() |> select()` no lugar de `transmute()` (§2.2-16).
- Toda mensagem via `cli` (`cli_inform`, `cli_warn`, `cli_progress_bar`),
  respeitando `geofbds.quiet` (§2.2-17).
- Nenhum estado global avaliado no carregamento — opções e funções (§2.2-1).
- Nada escrito fora de `tempdir()` sem consentimento (§2.2-2).

## Verificação

```r
devtools::load_all()
devtools::test()          # offline: catálogo, resolve, parser, plan; webfakes: fetch
devtools::check()         # meta: 0 errors, 0 warnings, 0 notes
```

Ponta a ponta, depois da Fase 5:

```r
fbds_coverage("RO")
plano <- fbds_plan("RO", layers = "app"); plano       # volume antes de baixar
ro <- fbds_fetch(plano, workers = 6)
dplyr::count(ro, status)
fbds_validate(ro)                                     # conjuntos de shapefile completos
app_ro <- fbds_read(ro, layer = "app")                # sf empilhado
```

Interromper `fbds_download_state("RO")` com `Ctrl-C` na metade e rodar de novo
deve continuar de onde parou, com o restante marcado `cached`.

E pela linha de comando:

```bash
Rscript inst/exec/geofbds municipality 1100031 1100049 --layers app,uso
Rscript inst/exec/geofbds state RO --workers 6
```

## Ordem de execução e dependências

Fases 0 → 1 são independentes da rede e podem ser concluídas de imediato. A
Fase 2 depende de você rodar os dois scripts de sondagem; enquanto isso não
acontece, a Fase 3 pode avançar com fixtures sintéticas, mas **não deve ser
declarada pronta** — o parser precisa do HTML real. Fases 4–8 seguem em
sequência. As fases 1–4 já entregam um pacote útil; a 5 é o ganho principal
da migração.
