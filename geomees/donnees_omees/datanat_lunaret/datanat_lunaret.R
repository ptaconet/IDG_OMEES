library(sf)
library(tidyverse)
library(readxl)
library(janitor)

# Lire les 3 shapefiles
points <- st_read("geomees/donnees_omees/datanat_lunaret/Point SfN.shp")
lignes <- st_read("geomees/donnees_omees/datanat_lunaret/Linéaire SfN.shp")
polygones <- st_read("geomees/donnees_omees/datanat_lunaret/Surface SfN.shp")

polygones <- polygones %>% dplyr::filter(ID != "S1.1")

# Fonction : regrouper les géométries par ID
regrouper <- function(x, colonne) {
  x |>
    group_by(ID) |>
    summarise(do_union = FALSE) |>
    rename(!!colonne := geometry)
}

# Regroupement des attributs
attributs <- bind_rows(points, lignes, polygones) |>
  st_drop_geometry() |>
  group_by(ID) |>
  summarise()

# Géométries regroupées
gp <- regrouper(points, "geom_points")
gl <- regrouper(lignes, "geom_lignes")
gs <- regrouper(polygones, "geom_polygones")

# Construction d'une géométrie complète par SfN
datanat_lunaret <- bind_rows(points, lignes, polygones) |>
  group_by(ID) |>
  summarise(do_union = FALSE)

# Jointure des géométries spécifiques
# sf conserve une seule colonne géométrique active.
# sfn <- toutes_geometries |>
#   left_join(attributs, by = "ID") |>
#   left_join(
#     st_drop_geometry(gp) |>
#       mutate(geom_points = st_geometry(gp)),
#     by = "ID"
#   ) |>
#   left_join(
#     st_drop_geometry(gl) |>
#       mutate(geom_lignes = st_geometry(gl)),
#     by = "ID"
#   ) |>
#   left_join(
#     st_drop_geometry(gs) |>
#       mutate(geom_polygones = st_geometry(gs)),
#     by = "ID"
#   )

# names(sfn)[names(sfn) == "geometry"] <- "geom"
# st_geometry(sfn) <- "geom"

datanat_lunaret <- datanat_lunaret %>%
  rename(id = ID) %>%
  filter(id != "NC") %>%
  mutate(id = case_when(id=="S.10.3.2" ~ "S10.3.2",
                        TRUE ~ id))


  # joindre la table attributaire complete
  table_attributaire <- read_xlsx("geomees/donnees_omees/datanat_lunaret/Grille SfN.xlsx") %>%
    rename(ID = Identifiant)

  table_attributaire <- janitor::clean_names(table_attributaire)

  datanat_lunaret <- datanat_lunaret %>%
    left_join(table_attributaire)


## push in DB

source("geomees/credentials_geomees.R")

con <- DBI::dbConnect(
  RPostgres::Postgres(),
  host = geomees_db_host,
  dbname = geomees_db_dbname,
  port = geomees_db_port,
  user = geomees_db_user,
  password = geomees_db_password
)


st_write(datanat_lunaret, dsn = con, layer = "datanat_lunaret",append = FALSE)









#
#
#
#
#
#vsetwd(file.path("geomees","donnees_omees","datanat_lunaret"))
#
#
# # Chemin du GeoPackage de sortie
# gpkg <- "datanat_lunaret.gpkg"
#
# # nom des couches dans geoserver
# layers <- c(
#   "datanat_lunaret_points",
#   "datanat_lunaret_lignes",
#   "datanat_lunaret_polygones"
# )
#
# # Supprimer l'ancien fichier s'il existe
# if (file.exists(gpkg)) {
#   file.remove(gpkg)
# }
#
#
# # Écrire les 3 couches dans le même GeoPackage
# st_write(
#   points,
#   gpkg,
#   layer = layers[1]
# )
#
# st_write(
#   lignes,
#   gpkg,
#   layer = layers[2],
#   append = FALSE
# )
#
# st_write(
#   polygones,
#   gpkg,
#   layer = layers[3],
#   append = FALSE
# )
#
#
# library(geosapi)
#
# GSman <- GSManager$new(
#   url = "https://geodata.bac-a-sable.inrae.fr/geoserver",
#   user = "omees", pwd = "N2nw'b}yJ?,9yi)t",
#   logger = 'DEBUG'
# )
#
# deleted <- GSman$deleteDataStore("omees", "datanat_lunaret", recurse = TRUE)
#
# ds = GSGeoPackageDataStore$new(name="datanat_lunaret",
#                                description = "Datanat Lunaret",
#                                enabled = TRUE,
#                                database = paste0("/mnt/geoserver_geodata/datanat_lunaret.gpkg"))
#
# created <- GSman$createDataStore("omees", ds)
#
# uploaded <- GSman$uploadGeoPackage(
#   ws = "omees", ds = "datanat_lunaret",
#   endpoint = "file", configure = "first", update = "overwrite",
#   charset = "UTF-8", filename = file.path(getwd(),"datanat_lunaret.gpkg")
# )
#
#
# deleted <- GSman$deleteStyle("omees-datanaet-lunaret-point", recurse = TRUE, purge = TRUE)
# deleted <- GSman$deleteStyle("omees-datanaet-lunaret-ligne", recurse = TRUE, purge = TRUE)
# deleted <- GSman$deleteStyle("omees-datanaet-lunaret-polygone", recurse = TRUE, purge = TRUE)
#
# created <- GSman$createStyle(file = file.path(getwd(),"style_sld_point.sld"), name = "omees-datanaet-lunaret-point")
# created <- GSman$createStyle(file = file.path(getwd(),"style_sld_lineaire.sld"), name = "omees-datanaet-lunaret-ligne")
# created <- GSman$createStyle(file = file.path(getwd(),"style_sld_surface.sld"), name = "omees-datanaet-lunaret-polygone")
#
#
#
# for(i in 1:length(layers)){
#   #create featuretype object
#   featureType <- GSFeatureType$new()
#   featureType$setName(layers[i])
#   featureType$setNativeName(layers[i])
#   featureType$setSrs("EPSG:2154")
#   featureType$setNativeCRS("EPSG:2154")
#   featureType$setEnabled(TRUE)
#   featureType$setProjectionPolicy("REPROJECT_TO_DECLARED")
#   featureType$setLatLonBoundingBox(-769424.8,6282415.0,772090.3,6284462.3, crs = "EPSG:2154")
#   featureType$setNativeBoundingBox(-769424.8,6282415.0,772090.3,6284462.3, crs ="EPSG:2154")
#
#   published <- GSman$unpublishLayer("omees", "datanat_lunaret", layers[i])
# #create the feature type in GeoServer
# created <- GSman$createFeatureType("omees", "datanat_lunaret", featureType)
#
# }
#
#
# deleted <- GSman$deleteLayerGroup("datanat_lunaret")
#
# lyr <- GSLayerGroup$new()
# lyr$setName("datanat_lunaret")
# lyr$setTitle("Cartographie des Solutions fondées sur la Nature du Grand Parc de Lunaret, Montpellier")
# lyr$setAbstract("Une cartographie sur les Solutions fondées sur la Nature du Grand Parc de Lunaret à été crée dans le cadre d'un stage de Master 2. Cette cartographie est basé sur des entretiens avec des acteurs qui ont travaillé sur l'éllaboration du Grand Parc de Lunaret.
#
#  Cette étude est un collaboration de plusieurs acteurs, les décideurs publics avec la Ville et la Métropole de Montpellier, le CNRS - Living Lab LLUNAM et l'IRD. Elle a pour but de recenser les SfN présentes et futures sur le Grand Parc, avec l'optique de la visibilisation de celles-ci auprès du grand public et des élus. C'est également un moyen de mettre en lien les acteurs du territoires sur une thématique commune.
#
#  La cartographie est formé à partir de la documentation apporté par l'enquêté, ainsi que d'une carte qui était fournit lors de l'entretien et qui permettait, à termes, de rendre compte des différentes actions. Cette cartographie comprend les SfN sous différentes formes (points, lignes, surfaces), avec différentes emprises, allant de l'échelle d'une rûche jusqu'au Grand Parc lui même.")
# lyr$setMode("SINGLE")
# lyr$addLayer(layer = paste0("omees:",layers[3]), style = "omees-datanaet-lunaret-polygone")
# lyr$addLayer(layer = paste0("omees:",layers[2]), style = "omees-datanaet-lunaret-ligne")
# lyr$addLayer(layer = paste0("omees:",layers[1]), style = "omees-datanaet-lunaret-point")
# lyr$setBounds(-769424.8,6282415.0,772090.3,6284462.3, crs = "EPSG:2154")
# md1 <- GSMetadataLink$new(type = "text/xml", metadataType = "ISO19115:2003", content = "https://geodata.bac-a-sable.inrae.fr/geonetwork/PROJET_OMEES/api/records/dataset_datanat_lunaret/formatters/xml")
# lyr$addMetadataLink(md1)
#
# GSman$createLayerGroup(layerGroup = lyr)
