library(rvest)
library(xml2)
library(tidyverse)
library(here)
library(glue)
library(textclean)
library(readxl)
library(janitor)

if (!require("tictoc")) install.packages("tictoc")

url <- "https://geo.fbds.org.br"

municipios <-
  here("TABELA CONSOLIDADA.xls") %>%
  read_excel(sheet = "Levantamento do Uso do Solo", skip = 2) %>%
  select(
    geocodigo = `...1`,
    municipio = `...2`,
    uf = `...3`
  ) %>%
  mutate(municipio_clean = str_to_upper(make_clean_names(municipio, allow_dupes = TRUE))) %>%
  mutate(
    url_muni_base = glue::glue("{url}/{uf}/{municipio_clean}"),
    url_muni_app = glue::glue("{url_muni_base}/APP"),
    url_muni_hidro = glue::glue("{url_muni_base}/HIDROGRAFIA"),
    url_muni_uso = glue::glue("{url_muni_base}/USO"),
    )

scraplinks <- function(url){
  # Create an html document from the url
  webpage <- xml2::read_html(url)
  # Extract the URLs
  url_ <- webpage %>%
    rvest::html_nodes("a") %>%
    rvest::html_attr("href")
  # Extract the link text
  link_ <- webpage %>%
    rvest::html_nodes("a") %>%
    rvest::html_text()
  return(tibble(link = link_, url = url_))
}

## app_link_raw_list <- list()

## start_time <- tic()

## for (i in seq_len(nrow(municipios))) {

##   base_url <-
##     municipios %>%
##     slice(i) %>%
##     pull(url_muni_app)

##   message(glue::glue("getting app link -------- {i} ------- {base_url}"))

##   df_files <-
##     try({
##       base_url %>%
##         scraplinks()
##     })

##   if (!class(df_files)[1] == "try-error") {

##     app_link_raw_list[[i]] <- df_files

##   }

## }

## end_time <- toc()

tic()

cl <- parallel::makeCluster(9) # not to overload your computer

doParallel::registerDoParallel(cl)

if (!require("foreach")) install.packages("foreach")

app_raw_links <-
  foreach::foreach(
    i = seq_len(nrow(municipios)),
    .packages = c("tidyverse", "rvest", "xml2"),
    .combine = rbind
  ) %dopar% {

    base_df <-
      municipios %>%
      slice(i)

    base_url <-
      base_df %>%
      pull(url_muni_app)

    geocodigo <-
      base_df %>%
      pull(geocodigo)

    df_files <-
      try({
        base_url %>%
          scraplinks()
      })

    if (!class(df_files)[1] == "try-error") {

      df_files %>%
        mutate(
          datatype = "app",
          url_muni_app = base_url,
          geocodigo = geocodigo
        )

    }

  } # end foreach

parallel::stopCluster(cl) # stop cluster

toc()

## TODO 2024-12-05: inform duplicates
app_raw_links %>%
  mutate(across(everything(), ~ str_squish(str_trim((.x))))) %>%
  filter(!link %in% c("navegadores modernos", "powered by h5ai", "Parent Directory", "Thumbs.db")) %>%
  mutate(geocod_from_file = str_extract(link, "\\d{7}")) %>%
  mutate(check_geocod = if_else(geocodigo == geocod_from_file, TRUE, FALSE)) %>%
  left_join(mutate(municipios, geocodigo = as.character(geocodigo))) %>%
  misc::view_vd() %>%
  write_csv("data/app-links_v2.csv")


####

tic()

cl <- parallel::makeCluster(9) # not to overload your computer

doParallel::registerDoParallel(cl)

if (!require("foreach")) install.packages("foreach")

hidro_raw_links <-
  foreach::foreach(
    i = seq_len(nrow(municipios)),
    .packages = c("tidyverse", "rvest", "xml2"),
    .combine = rbind
  ) %dopar% {

    base_df <-
      municipios %>%
      slice(i)

    base_url <-
      base_df %>%
      pull(url_muni_hidro)

    geocodigo <-
      base_df %>%
      pull(geocodigo)

    df_files <-
      try({
        base_url %>%
          scraplinks()
      })

    if (!class(df_files)[1] == "try-error") {

      df_files %>%
        mutate(
          datatype = "hidro",
          url_muni_hidro = base_url,
          geocodigo = geocodigo
        )

    }

  } # end foreach

parallel::stopCluster(cl) # stop cluster

toc()

## TODO 2024-12-05: inform duplicates
hidro_raw_links %>%
  mutate(across(everything(), ~ str_squish(str_trim((.x))))) %>%
  filter(!link %in% c("navegadores modernos", "powered by h5ai", "Parent Directory", "Thumbs.db")) %>%
  mutate(geocod_from_file = str_extract(link, "\\d{7}")) %>%
  mutate(check_geocod = if_else(geocodigo == geocod_from_file, TRUE, FALSE)) %>%
  left_join(mutate(municipios, geocodigo = as.character(geocodigo))) %>%
  misc::view_vd() %>%
  write_csv("data/hidro-links_v2.csv")

###

tic()

cl <- parallel::makeCluster(9) # not to overload your computer

doParallel::registerDoParallel(cl)

if (!require("foreach")) install.packages("foreach")

uso_raw_links <-
  foreach::foreach(
    i = seq_len(nrow(municipios)),
    .packages = c("tidyverse", "rvest", "xml2"),
    .combine = rbind
  ) %dopar% {

    base_df <-
      municipios %>%
      slice(i)

    base_url <-
      base_df %>%
      pull(url_muni_uso)

    geocodigo <-
      base_df %>%
      pull(geocodigo)

    df_files <-
      try({
        base_url %>%
          scraplinks()
      })

    if (!class(df_files)[1] == "try-error") {

      df_files %>%
        mutate(
          datatype = "uso",
          url_muni_uso = base_url,
          geocodigo = geocodigo
        )

    }

  } # end foreach

parallel::stopCluster(cl) # stop cluster

toc()

## TODO 2024-12-05: inform duplicates
uso_raw_links %>%
  mutate(across(everything(), ~ str_squish(str_trim((.x))))) %>%
  filter(!link %in% c("navegadores modernos", "powered by h5ai", "Parent Directory", "Thumbs.db", "MAPAS", "USO.rar", "info")) %>%
  mutate(geocod_from_file = str_extract(link, "\\d{7}")) %>%
  mutate(check_geocod = if_else(geocodigo == geocod_from_file, TRUE, FALSE)) %>%
  left_join(mutate(municipios, geocodigo = as.character(geocodigo))) %>%
  misc::view_vd() %>%
  write_csv("data/uso-links_v2.csv")
