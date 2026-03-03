
library(ggplot2)
library(sf)

source_data_dir <- "/home/dan/pulled/existing"

cncpal <- corenc::palettes[["combined"]]
color_boundary <- "#ffffff"
color_blank <- "#888888"
map_lwd <- 0.6


doc_index <-
  file.path(source_data_dir, "index.rds") |>
  readRDS()
auth_sum <-
  file.path(source_data_dir, "auth_summary.rds") |>
  readRDS() |>
  dplyr::filter(status == "ok") |>
  dplyr::left_join(
    dplyr::filter(doc_index, doc_kind == "auth") |>
      dplyr::select(as_response_id = response_id, doc_path),
    by = "as_response_id"
  ) |>
  corenc::with_longname()
auth_det <-
  file.path(source_data_dir, "auth_detail.rds") |>
  readRDS() |>
  dplyr::filter(as_response_id %in% auth_sum[["as_response_id"]]) |>
  corenc::with_slugs() |>
  cncp3::with_strat_or_cat()

make_sgry_plot <- function(sgry) {
  sgry_name <-
    cncp3::strats_or_cats |>
    dplyr::filter(strat_or_cat == sgry) |>
    dplyr::select(strat_or_cat_name) |>
    unlist() |>
    unname()
  sgry_color <- if (sgry %in% cncp3::strat_or_cat_levels[1L:12L]) {
    cncpal[["lake"]]
  } else {
    cncpal[["brick"]]
  }

  auth_det |>
    dplyr::filter(strat_or_cat == sgry) |>
    dplyr::select(govt_name, govt_type) |>
    dplyr::distinct() |>
    dplyr::mutate(has_lsa = TRUE) |>
    dplyr::right_join(corenc::govt_geo, by = c("govt_name", "govt_type")) |>
    dplyr::mutate(has_lsa = !is.na(has_lsa)) |>
    ggplot(aes(geometry = geometry, fill = has_lsa)) +
    geom_sf(color = color_boundary, lwd = map_lwd) +
    scale_fill_manual(
      values = c(
        "TRUE" = sgry_color,
        "FALSE" = color_blank
      ),
      guide = NULL
    ) +
    ggthemes::theme_map()
}

make_sgry_table <- function(sgry) {
  auth_det |>
    dplyr::filter(strat_or_cat == sgry) |>
    dplyr::select(as_response_id) |>
    dplyr::distinct() |>
    dplyr::left_join(auth_sum, by = "as_response_id") |>
    dplyr::select(
      govt_name, govt_type, govt_longname,
      as_auth_date, as_auth_id, doc_path
    )
}

for (sgry in cncp3::strat_or_cat_levels) {
  p <- make_sgry_plot(sgry)
  fname <- paste0(as.character(sgry), "_map.svg")
  ggsave(fname, p)

  auth_tab <- make_sgry_table(sgry)
  fname <- paste0(as.character(sgry), "_lsas.json")
  jsonlite::toJSON(auth_tab, auto_unbox = TRUE, pretty = TRUE) |> write(fname)
}
