catalogo_municipios <- here::here("data", "raw", "TABELA CONSOLIDADA.xls")
diretorio_padrao <- here::here("data", "raw", "geo-fbds")
url_fbds <- "https://geo.fbds.org.br"

ler_municipios_fbds <- function(caminho = catalogo_municipios) {
  readxl::read_excel(
    caminho,
    sheet = "Levantamento do Uso do Solo",
    skip = 2
  ) |>
    dplyr::transmute(
      geocodigo = sprintf("%.0f", .data$...1),
      municipio = .data$...2,
      uf = .data$...3,
      municipio_url = stringr::str_to_upper(
        janitor::make_clean_names(.data$...2, allow_dupes = TRUE)
      )
    )
}

validar_geocodigos <- function(geocodigos, municipios) {
  geocodigos <- geocodigos |>
    as.character() |>
    stringr::str_trim() |>
    unique()

  if (length(geocodigos) == 0L) {
    stop("Informe pelo menos um geocódigo.", call. = FALSE)
  }

  invalidos <- geocodigos[
    is.na(geocodigos) |
      !stringr::str_detect(geocodigos, "^\\d{7}$")
  ]

  if (length(invalidos) > 0L) {
    stop(
      "Geocódigos inválidos: ",
      paste(invalidos, collapse = ", "),
      ". Cada geocódigo deve ter exatamente sete dígitos.",
      call. = FALSE
    )
  }

  ausentes <- setdiff(geocodigos, municipios$geocodigo)
  if (length(ausentes) > 0L) {
    stop(
      "Geocódigos não encontrados no catálogo da FBDS: ",
      paste(ausentes, collapse = ", "),
      call. = FALSE
    )
  }

  geocodigos
}

listar_arquivos_fbds <- function(url) {
  pagina <- xml2::read_html(url)
  links <- rvest::html_elements(pagina, "a")
  prefixo <- paste0(stringr::str_remove(url, "/$"), "/")

  tibble::tibble(
    url_download = xml2::url_absolute(
      rvest::html_attr(links, "href"),
      prefixo
    )
  ) |>
    dplyr::filter(
      !is.na(.data$url_download),
      startsWith(.data$url_download, prefixo),
      !stringr::str_ends(
        stringr::str_remove(.data$url_download, "[?#].*$"),
        "/"
      )
    ) |>
    dplyr::mutate(
      arquivo = basename(utils::URLdecode(
        stringr::str_remove(.data$url_download, "[?#].*$")
      ))
    ) |>
    dplyr::filter(.data$arquivo != "") |>
    dplyr::distinct(.data$url_download, .keep_all = TRUE) |>
    dplyr::select(.data$arquivo, .data$url_download)
}

descobrir_arquivos_fbds <- function(municipios) {
  tipos <- tibble::tribble(
    ~tipo         , ~pasta        ,
    "app"         , "APP"         ,
    "hidrografia" , "HIDROGRAFIA" ,
    "uso"         , "USO"
  )

  fontes <- tidyr::crossing(municipios, tipos) |>
    dplyr::mutate(
      url = paste(
        url_fbds,
        .data$uf,
        .data$municipio_url,
        .data$pasta,
        sep = "/"
      )
    )

  resultados <- lapply(seq_len(nrow(fontes)), function(i) {
    fonte <- fontes[i, ]
    message(
      "Consultando ",
      fonte$geocodigo,
      " (",
      fonte$tipo,
      ")"
    )

    tryCatch(
      listar_arquivos_fbds(fonte$url) |>
        dplyr::mutate(
          geocodigo = fonte$geocodigo,
          municipio = fonte$municipio,
          uf = fonte$uf,
          tipo = fonte$tipo,
          .before = 1
        ),
      error = function(erro) {
        message(
          "  Não foi possível consultar ",
          fonte$url,
          ": ",
          conditionMessage(erro)
        )
        tibble::tibble()
      }
    )
  })

  dplyr::bind_rows(resultados)
}

baixar_arquivo_fbds <- function(url, destino, handle) {
  dir.create(dirname(destino), recursive = TRUE, showWarnings = FALSE)

  if (file.exists(destino)) {
    return(tibble::tibble(status = "existente", erro = NA_character_))
  }

  arquivo_parcial <- paste0(destino, ".part")
  unlink(arquivo_parcial)

  erro_download <- tryCatch(
    {
      curl::curl_download(
        url,
        arquivo_parcial,
        quiet = TRUE,
        handle = handle
      )

      if (!file.rename(arquivo_parcial, destino)) {
        stop("Não foi possível concluir o arquivo ", destino)
      }

      NULL
    },
    error = conditionMessage
  )

  if (!is.null(erro_download)) {
    unlink(arquivo_parcial)
    return(tibble::tibble(status = "erro", erro = erro_download))
  }

  tibble::tibble(status = "baixado", erro = NA_character_)
}

baixar_dados_fbds <- function(
  geocodigos,
  diretorio_saida = diretorio_padrao,
  caminho_catalogo = catalogo_municipios
) {
  municipios <- ler_municipios_fbds(caminho_catalogo)
  geocodigos <- validar_geocodigos(geocodigos, municipios)

  municipios_selecionados <- municipios |>
    dplyr::filter(.data$geocodigo %in% geocodigos) |>
    dplyr::mutate(
      ordem = match(.data$geocodigo, geocodigos)
    ) |>
    dplyr::arrange(.data$ordem) |>
    dplyr::select(-.data$ordem)

  arquivos <- descobrir_arquivos_fbds(municipios_selecionados)

  if (nrow(arquivos) == 0L) {
    warning(
      "Nenhum arquivo disponível para os geocódigos informados.",
      call. = FALSE
    )
    return(arquivos)
  }

  dir.create(diretorio_saida, recursive = TRUE, showWarnings = FALSE)
  arquivos <- arquivos |>
    dplyr::mutate(
      caminho = file.path(
        diretorio_saida,
        .data$geocodigo,
        .data$tipo,
        .data$arquivo
      )
    )

  handle_download <- curl::new_handle(
    useragent = "geo-fbds-downloader/1.0"
  )

  downloads <- lapply(seq_len(nrow(arquivos)), function(i) {
    message(
      "Baixando ",
      i,
      "/",
      nrow(arquivos),
      ": ",
      arquivos$arquivo[[i]]
    )
    baixar_arquivo_fbds(
      arquivos$url_download[[i]],
      arquivos$caminho[[i]],
      handle_download
    )
  })

  manifesto <- dplyr::bind_cols(
    arquivos,
    dplyr::bind_rows(downloads)
  )

  readr::write_csv(
    manifesto,
    file.path(diretorio_saida, "manifesto.csv")
  )

  erros <- sum(manifesto$status == "erro")
  if (erros > 0L) {
    warning(
      erros,
      " arquivo(s) não puderam ser baixados. Consulte manifesto.csv.",
      call. = FALSE
    )
  }

  manifesto
}

if (sys.nframe() == 0L) {
  geocodigos <- commandArgs(trailingOnly = TRUE)

  if (length(geocodigos) == 0L) {
    stop(
      paste(
        "Informe um ou mais geocódigos.",
        "Exemplo: Rscript get-by-geocode.R 1100031 1100049"
      ),
      call. = FALSE
    )
  }

  resultado <- baixar_dados_fbds(geocodigos)
  print(dplyr::count(resultado, .data$status, name = "arquivos"))
}
