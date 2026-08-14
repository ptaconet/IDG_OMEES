library(geonapi)
library(geometa)
library(geosapi)
library(uuid)
library(stringr)


source("dataflow_gn/params/credentials.R")

# Connect to GN

gn <- GNManager$new(
  url = "https://geodata.bac-a-sable.inrae.fr/geonetwork",  #"https://geodata.bac-a-sable.inrae.fr/geonetwork",
  version = "4.2.8",
  user = user_gn,
  pwd = pwd_gn_bacasable,
  logger = "DEBUG"
)

GSman <- GSManager$new(
  url = "https://geodata.bac-a-sable.inrae.fr/geoserver",  #"https://geodata.bac-a-sable.inrae.fr/geoserver",
  user = user_gn, pwd = pwd_gn_bacasable,
  logger = 'DEBUG'
)

# Read params
datasets <- read.csv("dataflow_gn/params/datasets.csv",  sep = ",")
contacts <- read.csv("dataflow_gn/params/contacts.csv",  sep = ",")

for (dataset in datasets$n){
  print(paste0("Working on: ", datasets$titre[dataset]))
  metadata_id <- datasets$uuid[dataset]

  ##Création métadonnée
  md = ISOMetadata$new()
  metadata_id=paste(metadata_id)
  md$setFileIdentifier(metadata_id)
  md$setCharacterSet("utf8")
  md$setMetadataStandardName("ISO 19115:2003/19139")
  md$setLanguage("eng")
  md$setDateStamp(Sys.time())
  md$addHierarchyLevel(datasets$hierarchyLevel[dataset])

  ##Ajout lien vers fiche mère
  if(!is.na(datasets$parent[dataset])) {
    md$setParentIdentifier(paste(datasets$parent[dataset]))
  }

  ##Creation identification
  ident <- ISODataIdentification$new()
  ident$setAbstract(paste(datasets$abstract[dataset]))
  ident$addLanguage("fre")
  for (topic in unlist(strsplit(paste(datasets$topic[dataset]), ", "))){
    ident$addTopicCategory(topic)
  }

  ## keywords
  ### General Keywords
  dynamic_keywords <- ISOKeywords$new()
  for (kw in unlist(strsplit(paste(datasets$keywords[dataset]), ", "))){
    dynamic_keywords$addKeyword(kw)
  }
  dynamic_keywords$addKeyword("omees")
  ident$addKeywords(dynamic_keywords)

  #add link to data access
  distrib <- ISODistribution$new()
  dto <- ISODigitalTransferOptions$new()
  for (link in unlist(strsplit(paste(datasets$web.access[dataset]), ", "))){
    # Remove paranthesis
    tuple <- gsub('\\(',"",link)
    tuple <- gsub('\\)',"",tuple)
    newURL <- ISOOnlineResource$new()
    newURL$setName(paste0(strsplit(paste(tuple), " @ ")[[1]][1],":"))
    newURL$setLinkage(strsplit(paste(tuple), " @ ")[[1]][2])
    newURL$setProtocol("WWW:LINK-1.0-http--link")
    dto$addOnlineResource(newURL)
  }

  # add wms
  or <- ISOOnlineResource$new()
  or$setLinkage("https://geodata.bac-a-sable.inrae.fr/geoserver/omees/ows?service=WMS")
  or$setName(datasets$wxs_layer[dataset])
  or$setDescription(paste0(datasets$wxs_layer[dataset],"- OGC Web Map Service"))
  or$setProtocol("OGC:WMS")
  dto$addOnlineResource(or)

  # add wfs
  or <- ISOOnlineResource$new()
  or$setLinkage("https://geodata.bac-a-sable.inrae.fr/geoserver/omees/ows?service=WFS")
  or$setName(datasets$wxs_layer[dataset])
  or$setDescription(paste0(datasets$wxs_layer[dataset],"- OGC Web Feature Service"))
  or$setProtocol("OGC:WFS")
  dto$addOnlineResource(or)

  distrib$addDigitalTransferOptions(dto)
  md$setDistributionInfo(distrib)



  ##Contacts PI
  for (pi in unlist(strsplit(paste(datasets$PI[dataset]), ", "))){
    rp <- ISOResponsibleParty$new()
    ct <- contacts$name==pi
    contact=contacts[ct,]
    labo <- strsplit(as.character(contact$organisation), "/")[[1]][1]
    rp$setOrganisationName(labo)
    rp$setIndividualName(paste(as.character(contact$name),as.character(contact$firstname),sep=" "))
    rp$setRole("principalInvestigator")
    isocontact <- ISOContact$new()
    address <- ISOAddress$new()
    address$setEmail(as.character(contact$mail))
    isocontact$setAddress(address)
    #isocontact$setContactInstructions(fileName = contact$url_logo_institution)
    rp$setContactInfo(isocontact)
    ident$addPointOfContact(rp) # Ajout contact pour la ressource : le PI
  }

    #adding legal constraint(s)
    if(nchar(as.character(datasets$licence[dataset])) !=0) {
      lc <- ISOLegalConstraints$new()
      lc$addUseLimitation(datasets$licence[dataset])
      ident$addResourceConstraints(lc)
    }
    # Titre et identification
    ct <- ISOCitation$new()
    ct$setTitle(paste(datasets$titre[dataset]))
    isoid=ISOMetaIdentifier$new(code = datasets$uuid[dataset])
    ct$addIdentifier(isoid)
    ident$setCitation(ct)
    ## Aperçu / thumbnail

    #graphic overview
    if(nchar(datasets$thumbnail[dataset])==0){
    go2 <- ISOBrowseGraphic$new(
      fileName = paste0("https://geodata.bac-a-sable.inrae.fr/geoserver/omees/wms?service=WMS&version=1.1.0&request=GetMap&layers=",datasets$wxs_layer[dataset],"&bbox=",datasets$coverage[dataset],"&width=768&height=658&srs=EPSG:2154&styles=&format=image/png"),
      fileDescription = "Map Overview",
      fileType = "image/png"
    )
    ident$addGraphicOverview(go2)
    } else {
     for(thumbnail in unlist(strsplit(paste(datasets$thumbnail[dataset]), ", "))){
      go <- ISOBrowseGraphic$new(
        fileName = thumbnail,
        fileDescription = "thumbnail",
        fileType = "image/png"
      )
      ident$addGraphicOverview(go)
     }
    }

    md$addIdentificationInfo(ident)

  # Conversion en iso19139 et sauvegarde du fichier XML
  md$encode(inspire = FALSE)
  nom_fichier = datasets$uuid[dataset]
  nom_fichier = paste(nom_fichier, "xml", sep=".") # nous ajoutons l'extension de fichier XML
  chemin_fichier = paste("dataflow_gn/xml_generated", nom_fichier, sep="/") # nous cronstruisons le chemin vers le fichier
  md$save(chemin_fichier)


}


library(XML)
filenames = list.files("dataflow_gn/xml_generated", pattern="*.xml")
for (file in filenames) {# nous parcourons l'ensemble des fichiers xml
  chemin_fichier = paste("dataflow_gn/xml_generated", file, sep="/")
  xml = xmlParse(chemin_fichier)
  md = ISOMetadata$new(xml = xml) # création de l'objet ISOMetadata
  created = gn$insertMetadata( # insertion dans GeoNetwork
    xml = md$encode(),
    group = "1",
  )
}


# id <- "601e18d4-f2a2-4257-b47f-fc500e99a581"
# md <- gn$getMetadataByUUID(id)
# metaId <- gn$get(md$fileIdentifier, by = "uuid", output = "id")
# deleted <- gn$deleteMetadata(id = metaId)

#
# for (dataset in datasets$n){
# #update featuretype
# featureType <- GSman$getFeatureType("omees", "postgis_albopictus", datasets$wxs_layer[dataset])
# featureType$setAbstract(paste(datasets$abstract[dataset]))
# featureType$setTitle(paste(datasets$titre[dataset]))
#
# md1 <- GSMetadataLink$new(type = "text/xml", metadataType = "ISO19115:2003", content = paste0("https://geodata.bac-a-sable.inrae.fr/geonetwork/srv/api/records/",datasets$uuid[dataset],"/formatters/xml"))
# featureType$addMetadataLink(md1)
# md2 <- GSMetadataLink$new(type = "text/html", metadataType = "ISO19115:2003", content = paste0("https://geodata.bac-a-sable.inrae.fr/geonetwork/srv/fre/catalog.search#/metadata/",datasets$uuid[dataset]))
# featureType$addMetadataLink(md2)
#
# #update layer
# lyr <- GSman$getLayer(paste(datasets$wxs_layer[dataset]))
# updated <- GSman$updateLayer(lyr)
#
# updated <- GSman$updateFeatureType("omees", "postgis_albopictus", featureType)
# }


