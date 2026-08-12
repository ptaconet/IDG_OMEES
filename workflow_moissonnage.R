library(rjson)
library(geometa)
library(geosapi)
library(geonapi)
library(sf)
library(tidyverse)
library(ows4R)

catalogues <- read.csv("dataflow_gn/data_catalogues.csv")
identifiers_to_harvest <- read.csv("dataflow_gn/data_identifiers.csv")

identifiers_to_harvest <- identifiers_to_harvest %>%
  left_join(catalogues, by = "catalogue_name")

######################
# connection à l'IDG
######################

source("dataflow_gn/params/credentials.R")

GN <- GNManager$new(
  url = url_gn_bacasable,
  version = "4.2.8",
  user = user_gn_bacasable,
  pwd = pwd_gn_bacasable,
  logger = "DEBUG"
)

GSman <- GSManager$new(
  url = url_gs_bacasable,
  user = user_gn_bacasable,
  pwd = pwd_gn_bacasable,
  logger = 'DEBUG'
)


######################
# fonction pour pousser les fiches de métadonnée dans GN
######################


push_metadata <- function(xml_output){

  md <- readISO(xml_output)
  mdId <- md$fileIdentifier
  GN$insertMetadata(geometa = md, group = "20838", category = "2", uuidProcessing = "OVERWRITE", geometa_inspireValidator = INSPIRE_VALIDATOR)

  # for geodata inrae bac à sable :
  # group = "20838" is for PROJET_OMEES  (voir GN$getGroups()  pour tous les groupes dispos)
  # category = "2" is for "datasets"     (voir GN$getCategories()  pour toutes les catégories dispos)

  config <- GNPrivConfiguration$new()
  config$setPrivileges("2", c("view","download", "dynamic"))
  config$setPrivileges("all", c("view","download","dynamic"))
  config$setPrivileges("20838", c("view","download","dynamic","featured"))
  GN$setPrivConfiguration(id = mdId, config = config)

}



######################
# moissonnage des catalogues
######################

for(id in 1:nrow(identifiers_to_harvest)){

  cat(paste0("moissonage en cours du catalogue ",identifiers_to_harvest$catalogue_name[id]," - identifiant (meta)donnée ",identifiers_to_harvest$identifier[id],"\n"))

  if(identifiers_to_harvest$catalogue_type[id] == "DKAN"){

   # geometa::setMetadataStandard("19139")

    source("fonctions_moissonnage_dkan.R")

    topics <- str_split_1(identifiers_to_harvest$topics[id], "_\n")
    topics <- tolower(topics)

    meta_dkan <- dkan_get_meta(identifiers_to_harvest$identifier[id])
    shp_params <- dkan_get_shp(meta_dkan)
    if(!is.null(shp_params)){
      dkan_create_featuretype(meta_dkan,
                             shp_params)
    }
    result <- dkan_create_iso19115(meta_dkan,
                                   output_dir = "xml_metadata/dkan",
                                  shp_params,
                                  topic_categories = topics,
                                  catalogue_name = identifiers_to_harvest$catalogue_name[id],
                                  catalogue_url = identifiers_to_harvest$catalogue_url[id])

    push_metadata(result)

  }


  if(identifiers_to_harvest$catalogue_type[id] == "dataverse"){

   # geometa::setMetadataStandard("19139")

    source("fonctions_moissonnage_dataverse.R")

    topics <- str_split_1(identifiers_to_harvest$topics[id], "_\n")
    topics <- tolower(topics)

    result <- dataverse_create_iso19115(
      identifier =  identifiers_to_harvest$identifier[id] ,
      output_dir = "xml_metadata/dataverse",
      catalogue_url = identifiers_to_harvest$catalogue_url[id],
      catalogue_name = identifiers_to_harvest$catalogue_name[id],
      topic_categories = topics
    )

    push_metadata(result$output_file)

  }

  if(identifiers_to_harvest$catalogue_type[id] %in% c("geonetwork_api","geonetwork_csw_19115_3")){

    source("fonctions_moissonnage_geonetwork.R")

    topics <- str_split_1(identifiers_to_harvest$topics[id], "_\n")
    topics <- tolower(topics)

    result <- geonetwork_create_iso19115(
      identifier =  identifiers_to_harvest$identifier[id] ,
      output_dir = "xml_metadata/geonetwork",
      catalogue_url = identifiers_to_harvest$catalogue_url[id],
      catalogue_name = identifiers_to_harvest$catalogue_name[id],
      catalogue_type = identifiers_to_harvest$catalogue_type[id],
      topic_categories = topics
    )

    push_metadata(result)

  }

  if(identifiers_to_harvest$catalogue_type[id] == "ddi"){

    source("fonctions_moissonnage_ddi.R")

    topics <- str_split_1(identifiers_to_harvest$topics[id], "_\n")
    topics <- tolower(topics)

    result <- ddi_create_iso19115(
      identifier =  identifiers_to_harvest$identifier[id] ,
      output_dir = "xml_metadata/ddi",
      catalogue_url = identifiers_to_harvest$catalogue_url[id],
      catalogue_name = identifiers_to_harvest$catalogue_name[id],
      topic_categories = topics
    )

    push_metadata(result)


  }


}


