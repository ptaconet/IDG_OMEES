library(rjson)
library(geometa)
library(geosapi)
library(geonapi)
library(sf)
library(tidyverse)
library(ows4R)
library(readxl)


catalogues <- read_xlsx("geomees/entities_catalogues.xlsx")
identifiers_to_harvest <- read.csv("geomees/data_identifiers.csv")
contacts <- read_xlsx("geomees/contacts.xlsx")  # if no contact is associated with the metadata sheet, we put that one

contacts$Identifier <- gsub("id:","",contacts$Identifier)
catalogues$Creator <-  gsub("pointOfContact:","",catalogues$Creator)

identifiers_to_harvest <- identifiers_to_harvest %>%
  left_join(catalogues, by = c("catalogue_identifier"="Identifier")) %>%
  left_join(contacts, by = c("Creator" = "Identifier"))


######################
# connection à l'IDG
######################

source("geomees/credentials.R")

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
# moissonnage des catalogues
######################

geometa::setMetadataStandard("19139")

get_api_url <- function(linkage) {
  lines <- strsplit(linkage, "\n", fixed = TRUE)[[1]]
  api_line <- lines[grepl("API catalogue", lines, fixed = TRUE)]
  sub("_$", "", sub(".*@", "", api_line))
}

safe_geomees_identifier <- function(x) {
  x |>
    iconv(to = "ASCII//TRANSLIT") |>
    stringr::str_replace_all("[^A-Za-z0-9._-]+", "_") |>
    stringr::str_replace_all("_+", "_") |>
    stringr::str_remove("^_") |>
    stringr::str_remove("_$")
}


for(id in 1:nrow(identifiers_to_harvest)){

  cat(paste0("moissonage en cours du catalogue ",identifiers_to_harvest$catalogue_identifier[id]," - identifiant (meta)donnée ",identifiers_to_harvest$data_identifier[id],"\n"))

  destfile <- file.path("xml_metadata",paste0(safe_geomees_identifier(identifiers_to_harvest$data_identifier[id]),".xml"))

  if(identifiers_to_harvest$catalogue_metadata_standard[id] == "dkan"){

    source("geomees/scripts/fonctions_moissonage_catalogues/fonctions_moissonnage_dkan.R")

    meta_dkan <- dkan_get_meta(identifiers_to_harvest$data_identifier[id])
    shp_params <- dkan_get_shp(meta_dkan)
    if(!is.null(shp_params)){
      dkan_create_featuretype(meta_dkan,
                             shp_params)
    }
    md <- dkan_create_iso19115(meta_dkan,
                                shp_params,
                               catalogue_url = get_api_url(identifiers_to_harvest$Relation[id])
                               )
  }


  if(identifiers_to_harvest$catalogue_metadata_standard[id] == "dataverse"){

    source("geomees/scripts/fonctions_moissonage_catalogues/fonctions_moissonnage_dataverse.R")

    md <- dataverse_create_iso19115(
      identifier =  identifiers_to_harvest$data_identifier[id] ,
      catalogue_url = get_api_url(identifiers_to_harvest$Relation[id])
      )

  }

  if(identifiers_to_harvest$catalogue_metadata_standard[id] %in% c("geonetwork_api","geonetwork_csw_19115_3","opendatasoft")){

    source("geomees/scripts/fonctions_moissonage_catalogues/fonctions_moissonnage_geonetwork.R")

    md <- geonetwork_create_iso19115(
      identifier =  identifiers_to_harvest$data_identifier[id],
      catalogue_url = get_api_url(identifiers_to_harvest$Relation[id]),
      catalogue_type = identifiers_to_harvest$catalogue_metadata_standard[id]
      )
  }

  if(identifiers_to_harvest$catalogue_metadata_standard[id] == "ddi"){

    source("geomees/scripts/fonctions_moissonage_catalogues/fonctions_moissonnage_ddi.R")

    md <- ddi_create_iso19115(
      identifier =  identifiers_to_harvest$data_identifier[id] ,
      catalogue_url = get_api_url(identifiers_to_harvest$Relation[id])
    )

  }

  # Get the existing data identification
  ident <- md$identificationInfo[[1]]

  # Delete the existing data identification
  md$delIdentificationInfo(ident)

  #### complete metadata

  topic_categories <- str_split_1(identifiers_to_harvest$topics[id], "_\n")
  topic_categories <- tolower(topic_categories)

  if (length(topic_categories) == 0L) {
    topic_categories <- "environment"
  }

  for (topic in topic_categories) {
    ident$addTopicCategory(topic)
  }


  ##Ajout lien vers fiche mère
  if(!is.na(identifiers_to_harvest$catalogue_identifier[id])) {
    md$setParentIdentifier(identifiers_to_harvest$catalogue_identifier[id])
  }

  #supplementalInformation
  ident$setSupplementalInformation(
    paste0(
      "Métadonnée et donnée générée automatiquement à partir du catalogue ",
      gsub("title:Catalogue de données : ","",identifiers_to_harvest$Title[id])
    )
  )

  #abstract
  lineage_statement <- sprintf(
    '<b><i>Ce jeu de données provient d\'un portail externe. Voir la source originale : %s </i></b>',
    identifiers_to_harvest$url[id]
  )

  ident$setAbstract(paste0(ident$abstract,
                           "<p>",
                           lineage_statement,
                           "</p>"))

  # thumbnail
    go1 <- ISOBrowseGraphic$new(
      fileName = stringr::str_match(identifiers_to_harvest$Relation[id], "thumbnail:[^@]+@(https?://[^\\s]+)")[, 2],
      fileDescription = "thumbnail"
    )
    ident$addGraphicOverview(go1)


  # keywords
  kwds <- ISOKeywords$new()
  kwds$addKeyword("omees")

  ident$descriptiveKeywords <- c(
    ident$descriptiveKeywords,
    list(kwds)
  )


  md$addIdentificationInfo(ident)

  # contacts if empty
  if(length(md$contact) == 0){
    rp <- ISOResponsibleParty$new()
    rp$setOrganisationName(identifiers_to_harvest$OrganizationName[id])
    rp$setRole("pointOfContact")
    contact <- ISOContact$new()
    address <- ISOAddress$new()
    address$setDeliveryPoint(identifiers_to_harvest$PostalAddress[id])
    address$setCity(identifiers_to_harvest$LastName[id])
    address$setPostalCode(identifiers_to_harvest$PostalCode[id])
    address$setCountry(identifiers_to_harvest$Country[id])
    address$setEmail(identifiers_to_harvest$Email[id])
    contact$setAddress(address)
    res <- ISOOnlineResource$new()
    res$setLinkage(identifiers_to_harvest$WebsiteUrl[id])
    res$setName(identifiers_to_harvest$WebsiteName[id])
    contact$setOnlineResource(res)
    rp$setContactInfo(contact)
    md$addContact(rp)
  }


  #### write metadata

  md$save(destfile)


  #### push metadata in GN

  md <- geometa::readISO(file = destfile)
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


