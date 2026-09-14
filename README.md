# Download de dados municipais da Geo FBDS

Este projeto contém scripts para consultar o repositório público da
[Geo FBDS](https://geo.fbds.org.br) e obter dados geográficos municipais.

O script `get-by-geocode.R` recebe uma lista de geocódigos do IBGE e baixa os
arquivos disponíveis para os municípios correspondentes. O script anterior,
`get-full-geo-fbds-data.R`, foi preservado sem alterações para consultas em
escala nacional.

## Dados baixados

Para cada município, `get-by-geocode.R` consulta três conjuntos de dados no
repositório da FBDS:

- `APP`: Áreas de Preservação Permanente;
- `HIDROGRAFIA`: massas d'água, nascentes, rios simples e rios duplos;
- `USO`: uso e cobertura do solo.

O script baixa todos os arquivos listados diretamente nesses três diretórios.
Isso inclui os componentes necessários para abrir shapefiles, como `.shp`,
`.dbf`, `.shx`, `.prj`, `.cpg` e arquivos de metadados `.xml`, quando
existentes no portal.

## Pré-requisitos

O projeto requer R e os seguintes pacotes:

```r
install.packages(c(
  "curl",
  "dplyr",
  "here",
  "janitor",
  "readr",
  "readxl",
  "rvest",
  "stringr",
  "tibble",
  "tidyr",
  "xml2"
))
```

A tabela municipal da FBDS deve estar disponível em:

```text
data/raw/TABELA CONSOLIDADA.xls
```

O script lê a planilha `Levantamento do Uso do Solo` desse arquivo para
relacionar cada geocódigo ao município, à UF e ao endereço correspondente no
portal.

## Uso pela linha de comando

Execute o script a partir da raiz do projeto e informe um ou mais geocódigos,
separados por espaço:

```bash
Rscript get-by-geocode.R 1100031 1100049
```

Os geocódigos devem ter exatamente sete dígitos. Valores repetidos são
removidos antes do processamento.

Sem argumentos, o script encerra com uma mensagem mostrando a forma correta
de uso.

## Uso em uma sessão R

Também é possível carregar as funções e passar um vetor de geocódigos:

```r
source("get-by-geocode.R")

resultado <- baixar_dados_fbds(
  geocodigos = c("1100031", "1100049")
)
```

Ao ser carregado com `source()`, o script apenas define as funções. O download
automático ocorre somente quando o arquivo é executado diretamente com
`Rscript`.

### Diretório de saída personalizado

Por padrão, os arquivos são gravados em `data/raw/geo-fbds`. Para usar outro
diretório:

```r
resultado <- baixar_dados_fbds(
  geocodigos = c("1100031", "1100049"),
  diretorio_saida = "output/geo-fbds"
)
```

Também é possível fornecer outra cópia da tabela municipal:

```r
resultado <- baixar_dados_fbds(
  geocodigos = "1100031",
  caminho_catalogo = "caminho/TABELA CONSOLIDADA.xls"
)
```

## Estrutura dos arquivos

A saída padrão é organizada por geocódigo e tipo de dado:

```text
data/raw/geo-fbds/
├── manifesto.csv
├── 1100031/
│   ├── app/
│   ├── hidrografia/
│   └── uso/
└── 1100049/
    ├── app/
    ├── hidrografia/
    └── uso/
```

Essa separação mantém juntos os componentes de cada shapefile e evita colisões
entre arquivos de municípios diferentes.

## Manifesto

Ao final, o script cria `manifesto.csv` no diretório de saída. Cada linha
representa um arquivo encontrado no portal e contém:

| Coluna | Descrição |
| --- | --- |
| `geocodigo` | Geocódigo do município |
| `municipio` | Nome do município |
| `uf` | Unidade federativa |
| `tipo` | Conjunto de dados: `app`, `hidrografia` ou `uso` |
| `arquivo` | Nome do arquivo no portal |
| `url_download` | URL de origem |
| `caminho` | Caminho local de destino |
| `status` | Resultado da transferência |
| `erro` | Mensagem de erro, quando aplicável |

Os valores possíveis de `status` são:

- `baixado`: arquivo transferido nesta execução;
- `existente`: arquivo já estava no destino e não foi baixado novamente;
- `erro`: a transferência não pôde ser concluída.

A função `baixar_dados_fbds()` também devolve esse manifesto como um tibble,
permitindo inspecionar o resultado imediatamente no R:

```r
dplyr::count(resultado, status)

dplyr::filter(resultado, status == "erro")
```

## Como o código funciona

1. `ler_municipios_fbds()` lê a tabela consolidada e transforma o geocódigo em
   texto, preservando seus sete dígitos.
2. `validar_geocodigos()` remove duplicatas, rejeita códigos fora do formato e
   verifica se todos existem na tabela da FBDS.
3. `descobrir_arquivos_fbds()` monta os endereços de `APP`, `HIDROGRAFIA` e
   `USO` para cada município.
4. `listar_arquivos_fbds()` lê cada página HTML, converte os links em URLs
   absolutas e mantém apenas arquivos pertencentes ao diretório consultado.
5. `baixar_dados_fbds()` cria a estrutura de diretórios e transfere os arquivos
   sequencialmente usando uma conexão `curl` reutilizável.
6. `baixar_arquivo_fbds()` grava primeiro em um arquivo temporário com extensão
   `.part`. Somente após uma transferência bem-sucedida o arquivo recebe o nome
   definitivo. Assim, um download interrompido não é tratado como completo.
7. O manifesto é gravado depois que todas as transferências foram tentadas.

## Falhas e retomada

A disponibilidade e a velocidade dependem do servidor da FBDS. Se uma página
não puder ser consultada, o script informa o endereço e continua com os demais
conjuntos. Se um arquivo falhar, o erro é registrado no manifesto e o arquivo
parcial é removido.

Para retomar uma execução, repita o mesmo comando. Arquivos completos recebem o
status `existente`; arquivos ausentes ou que falharam são tentados novamente.
