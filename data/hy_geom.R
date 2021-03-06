# https://github.com/usgs-r/nhdplusTools
library(nhdplusTools)
# https://github.com/tidyverse/dplyr
library(dplyr)
# https://github.com/r-spatial/sf
library(sf)

png("demo.png")
plot_nhdplus(outlets = list(8895396), 
             gpkg = "nhdplus_subset.gpkg",
             plot_config = list(basin = list(border = NA),
                                outlets = list(default = list(col = NA))))

catchment_prefix <- "catchment"
nexus_prefix <- "nexus"
waterbody_prefix <- "waterbody"

#st_layers("nhdplus_subset.gpkg")

fline <- read_sf("nhdplus_subset.gpkg", "NHDFlowline_Network") %>%
  align_nhdplus_names() %>%
  filter(COMID %in% get_UT(., 8895396))

cat <- read_sf("nhdplus_subset.gpkg", "CatchmentSP") %>%
  align_nhdplus_names() %>%
  filter(FEATUREID %in% fline$COMID)

nexus <- fline %>%
  st_coordinates() %>%
  as.data.frame() %>%
  group_by(L2) %>%
  filter(row_number() == n()) %>%
  ungroup() %>%
  select(X, Y) %>%
  st_as_sf(coords = c("X", "Y"), crs = st_crs(fline))

nexus$ID <- fline$COMID

plot(st_transform(st_geometry(cat), 3857), add = TRUE)
plot(st_transform(st_geometry(nexus), 3857), add = TRUE)

dev.off()

unlink("rosm.cache", recursive = TRUE)

catchment_edge_list <- bind_rows(
  
  st_drop_geometry(fline) %>%
    select(ID = COMID, toID = ToNode) %>%
    mutate(ID = paste0(catchment_prefix, ID),
           toID = paste0(nexus_prefix, toID)),
  
  tibble(ID = unique(fline$ToNode)) %>%
    left_join(select(st_drop_geometry(fline), 
                     ID = FromNode, toID = COMID), 
              by = "ID") %>%
    mutate(toID = ifelse(is.na(toID), 0, toID)) %>%
    mutate(ID = paste0(nexus_prefix, ID),
           toID = paste0(catchment_prefix, toID))
  
)

waterbody_edge_list <- mutate(catchment_edge_list,
                      ID = gsub(catchment_prefix, waterbody_prefix, ID),
                      toID = gsub(catchment_prefix, waterbody_prefix, toID))

write.csv(catchment_edge_list, "catchment_edge_list.csv", row.names = FALSE)

jsonlite::write_json(catchment_edge_list, "catchment_edge_list.json", pretty = TRUE)

write.csv(waterbody_edge_list, "waterbody_edge_list.csv", row.names = FALSE)

jsonlite::write_json(waterbody_edge_list, "waterbody_edge_list.json", pretty = TRUE)

catchment_data <- select(cat, ID = FEATUREID, area_sqkm = AreaSqKM) %>%
  mutate(ID = paste0(catchment_prefix, ID))

waterbody_data <- select(fline, ID = COMID, 
                 length_km = LENGTHKM, 
                 slope_percent = slope, 
                 main_id = LevelPathI) %>%
  mutate(ID = paste0(waterbody_prefix, ID))

nexus_data <- select(nexus, ID)

write_sf(catchment_data, "catchment_data.geojson")

write_sf(waterbody_data, "waterbody_data.geojson")

write_sf(nexus_data, "nexus_data.geojson")

##### Code below runs hyRefactor of a larger region that
##### is a superset of the subset above.
# https://github.com/dblodgett-usgs/hyRefactor
# library(hyRefactor)
# 
# source(system.file("extdata/new_hope_data.R", package = "hyRefactor"))
# 
# refactor_nhdplus(nhdplus_flines = new_hope_flowline,
#                  split_flines_meters = 10000,
#                  collapse_flines_meters = 1200,
#                  collapse_flines_main_meters = 1200,
#                  split_flines_cores = 1,
#                  out_collapsed = "new_hope_refactor.gpkg",
#                  out_reconciled = "new_hope_reconcile.gpkg",
#                  three_pass = TRUE,
#                  purge_non_dendritic = FALSE,
#                  warn = FALSE)
# 
# fline_ref <- sf::read_sf("new_hope_refactor.gpkg") %>%
#   sf::st_transform(proj)
# fline_rec <- sf::read_sf("new_hope_reconcile.gpkg") %>%
#   sf::st_transform(proj)
# 
# cat_rec <- reconcile_catchment_divides(new_hope_catchment, 
#                                        fline_ref, fline_rec,
#                                 new_hope_fdr, new_hope_fac)
# 
# sf::write_sf(cat_rec, "new_hope_cat_rec.gpkg")


