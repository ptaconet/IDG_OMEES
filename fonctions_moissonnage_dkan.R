

# tout le catalogue :
# meta_dkan_catalogue = rjson::fromJSON(file = "https://data.montpellier3m.fr/data.json")


 # cs = GSGeoTIFFCoverageStore$new(name="vegetation_3m", description = "Végétation fine Métropole de Montpellier", enabled = TRUE)
 # created <- GSman$createCoverageStore("projet_omees", cs)
 # uploaded <- GSman$uploadGeoTIFF(
 #   ws = "projet_omees", cs = "vegetation_3m",
 #   endpoint = "file", configure = "none", update = "overwrite",
 #   filename = "/home/ptaconet/Téléchargements/vegetation_mtp/vegetation_3m.tif"
 # )


dkan_get_meta <- function(identifier){

  meta_dkan = rjson::fromJSON(file = paste0("https://data.montpellier3m.fr/api/3/action/package_show?id=",identifier))

  return(meta_dkan)

}

dkan_get_shp <- function(meta_dkan){

  for(i in 1:length(meta_dkan$result$resources)){
    if(meta_dkan$result$resources[[i]]$mimetype == "application/zip"){
      download.file(url = meta_dkan$result$resources[[i]]$url , destfile = paste0("data/mmm/",meta_dkan$result$resources[[i]]$name))
  #     break()
  #   }
  # }

  # Reading shapefiles (or other data sources) directly from zip files can be done by prepending the path with /vsizip/
  shp <- read_sf(paste0("/vsizip/data/mmm/",meta_dkan$result$resources[[i]]$name))

  shp_layer_name <- st_layers(paste0("/vsizip/data/mmm/",meta_dkan$result$resources[[i]]$name))$name
  crs = st_crs(shp)$epsg
  if(is.na(crs)){
    crs <- 2154
  }
  bbox = st_bbox(shp)
  geom_type <- as.character(unique(st_geometry_type(shp)))

  if(grepl("LINE",geom_type)){
    GeometricObjectType <- "curve"
  } else if(grepl("POLYGON",geom_type)){
    GeometricObjectType <- "surface"
  } else if(grepl("POINT",geom_type)){
    GeometricObjectType <- "point"
  }

  return(list(shp_path = meta_dkan$result$resources[[i]]$name, shp_layer_name = shp_layer_name, crs = crs, bbox = bbox, GeometricObjectType = GeometricObjectType))

  break()
    }
  }

}


dkan_create_featuretype <- function(meta_dkan, shp_params){

  uploaded <- GSman$uploadShapefile(
    ws = "omees", ds = "couches_omees",
    endpoint = "file", configure = "first", update = "overwrite",
    charset = "UTF-8", filename = paste0("data/mmm/",shp_params$shp_path)
  )

    #update featuretype
    featureType <- GSman$getFeatureType("omees", "couches_omees", shp_params$shp_layer_name)
    featureType$setName(shp_params$shp_layer_name)
    featureType$setNativeName(shp_params$shp_layer_name)
    featureType$setAbstract(textutils::HTMLdecode(meta_dkan$result$notes))
    featureType$setTitle(textutils::HTMLdecode(meta_dkan$result$title))
    featureType$setSrs(paste0("EPSG:",shp_params$crs))
    featureType$setNativeCRS(paste0("EPSG:",shp_params$crs))
    featureType$setEnabled(TRUE)
    featureType$setProjectionPolicy("REPROJECT_TO_DECLARED")
    featureType$setLatLonBoundingBox(as.numeric(shp_params$bbox$xmin),as.numeric(shp_params$bbox$ymin),as.numeric(shp_params$bbox$xmax),as.numeric(shp_params$bbox$ymax), crs = paste0("EPSG:",shp_params$crs))
    featureType$setNativeBoundingBox(as.numeric(shp_params$bbox$xmin),as.numeric(shp_params$bbox$ymin),as.numeric(shp_params$bbox$xmax),as.numeric(shp_params$bbox$ymax), crs = paste0("EPSG:",shp_params$crs))

    md1 <- GSMetadataLink$new(type = "text/xml", metadataType = "ISO19115:2003", content = paste0("https://geodata.bac-a-sable.inrae.fr/geonetwork/srv/api/records/",meta_dkan$result$name,"/formatters/xml"))
    featureType$addMetadataLink(md1)
    md2 <- GSMetadataLink$new(type = "text/html", metadataType = "ISO19115:2003", content = paste0("https://geodata.bac-a-sable.inrae.fr/geonetwork/srv/fre/catalog.search#/metadata/",meta_dkan$result$name))
    featureType$addMetadataLink(md2)

    #update layer
    lyr <- GSman$getLayer(shp_params$shp_layer_name)
    #lyr$setDefaultStyle("point")
    updated <- GSman$updateLayer(lyr)

    updated <- GSman$updateFeatureType("omees", "couches_omees", featureType)

    return(updated)
}


dkan_create_iso19115 <- function(meta_dkan, output_dir, shp_params, topic_categories, catalogue_name, catalogue_url){


  lineage_statement <- paste(
    "<b><i>Cette fiche de métadonnée et les éventuelle(s) donnée(s) associées ont été moissonnée(s) automatiquement depuis le jeu de données",
    meta_dkan$result$url %||% "",
    "hébergé sur le catalogue ",catalogue_name," (",catalogue_url,")</b></i>",
    "\n"
  )


  md = ISOMetadata$new()
  md$setFileIdentifier(meta_dkan$result$name) # alternative : meta_dkan$result$id
  #md$setParentIdentifier("my-parent-metadata-identifier")
  md$setCharacterSet("utf8")
  md$setLanguage("fre")
  md$setDateStamp(Sys.time())
  md$setMetadataStandardName("ISO 19115:2003/19139")
  md$setMetadataStandardVersion("1.0")
  md$setDataSetURI(meta_dkan$result$url)
  md$addHierarchyLevel("dataset")

  rp <- ISOResponsibleParty$new()
  rp$setOrganisationName(textutils::HTMLdecode(meta_dkan$result$maintainer))
  #rp$setPositionName(paste0("someposition",i))
  rp$setRole("pointOfContact")
  contact <- ISOContact$new()
  address <- ISOAddress$new()
  address$setDeliveryPoint("50 place Zeus")
  address$setCity("Montpellier")
  address$setPostalCode("34961")
  address$setCountry("France")
  address$setEmail(meta_dkan$result$maintainer_email)
  contact$setAddress(address)
  res <- ISOOnlineResource$new()
  res$setLinkage("https://data.montpellier3m.fr/")
  res$setName("Lien vers le catalogue Open Data 3M")
  contact$setOnlineResource(res)
  rp$setContactInfo(contact)
  md$addContact(rp)

  rp <- ISOResponsibleParty$new()
  rp$setOrganisationName(textutils::HTMLdecode(meta_dkan$result$author))
  #rp$setPositionName(paste0("someposition",i))
  rp$setRole("owner")
  contact <- ISOContact$new()
  address <- ISOAddress$new()
  address$setDeliveryPoint("50 place Zeus")
  address$setCity("Montpellier")
  address$setPostalCode("34961")
  address$setCountry("France")
  address$setEmail(meta_dkan$result$author_email)
  contact$setAddress(address)
  res <- ISOOnlineResource$new()
  res$setLinkage("https://data.montpellier3m.fr/")
  res$setName("Lien vers le catalogue Open Data 3M")
  contact$setOnlineResource(res)
  rp$setContactInfo(contact)
  md$addContact(rp)

  if(!is.null(shp_params)){

     #VectorSpatialRepresentation
  vsr <- ISOVectorSpatialRepresentation$new()
  vsr$setTopologyLevel("geometryOnly")
  geomObject <- ISOGeometricObjects$new()
  geomObject$setGeometricObjectType(shp_params$GeometricObjectType)
  geomObject$setGeometricObjectCount(5L)
  vsr$addGeometricObjects(geomObject)
  md$addSpatialRepresentationInfo(vsr)

  #ReferenceSystem
  rs <- ISOReferenceSystem$new()
  rsId <- ISOReferenceIdentifier$new(code = as.character(shp_params$crs), codeSpace = "EPSG")
  rs$setReferenceSystemIdentifier(rsId)
  md$addReferenceSystemInfo(rs)

  }

  #data identification
  ident <- ISODataIdentification$new()
  ident$setAbstract(paste0(textutils::HTMLdecode(meta_dkan$result$notes),
                           "<p>",
                           lineage_statement,
                           "</p>"))

  #ident$setPurpose("purpose")
  #ident$addCredit("Open Data Montpellier Méditerrannée Métropole")
  ident$addStatus("completed")
  ident$addLanguage("fre")
  ident$addCharacterSet("utf8")
  #ident$addTopicCategory("biota")
  for (topic in topic_categories) {
    ident$addTopicCategory(topic)
  }

  #citation
  ct <- ISOCitation$new()
  ct$setTitle(textutils::HTMLdecode(meta_dkan$result$title))
  d <- ISODate$new()
  d$setDate(as.POSIXct(meta_dkan$result$metadata_created))
  d$setDateType("publication")
  ct$addDate(d)
  ct$setEdition("1.0")
  ct$setEditionDate(as.Date(meta_dkan$result$metadata_modified))
  ct$addIdentifier(ISOMetaIdentifier$new(code = "identifier"))
  ct$addCitedResponsibleParty(rp)
  ident$setCitation(ct)

  #graphic overview

  go1 <- ISOBrowseGraphic$new(
    fileName = "https://upload.wikimedia.org/wikipedia/fr/e/e0/Logo_Montpellier_M%C3%A9diterran%C3%A9e_M%C3%A9tropole.svg",
    fileDescription = "3M logo",
    fileType = "image/svg"
  )
  ident$addGraphicOverview(go1)

  # go2 <- ISOBrowseGraphic$new(
  #   fileName = paste0("https://geodata.bac-a-sable.inrae.fr/geoserver/omees/wms?service=WMS&version=1.1.0&request=GetMap&layers=omees:",shp_params$shp_layer_name,"&bbox=",as.numeric(shp_params$bbox$xmin),",",as.numeric(shp_params$bbox$ymin),",",as.numeric(shp_params$bbox$xmax),",",as.numeric(shp_params$bbox$ymax),"&width=768&height=658&srs=EPSG:",shp_params$crs,"&styles=&format=image/png"),
  #   fileDescription = "Map Overview",
  #   fileType = "image/png"
  # )
  # ident$addGraphicOverview(go2)

  #maintenance information
  # mi <- ISOMaintenanceInformation$new()
  # mi$setMaintenanceFrequency("daily")
  # ident$addResourceMaintenance(mi)

  #adding access legal constraints
  #for INSPIRE controlled terms on access legal constraints, please browse the INSPIRE registry:
  # http://inspire.ec.europa.eu/metadata-codelist/LimitationsOnPublicAccess/
  # lc <- ISOLegalConstraints$new()
  # lc$addAccessConstraint("otherRestrictions")
  # lc$addOtherConstraint(ISOAnchor$new(
  #   href = "http://inspire.ec.europa.eu/metadata-codelist/LimitationsOnPublicAccess/INSPIRE_Directive_Article13_1a",
  #   name = "public access limited according to Article 13(1)(a) of the INSPIRE Directive"
  # ))
  # ident$addResourceConstraints(lc)

  #adding use legal constraints
  #for INSPIRE controlled terms on use legal constraints, please browse the INSPIRE registry:
  # http://inspire.ec.europa.eu/metadata-codelist/ConditionsApplyingToAccessAndUse
  lc2 <- ISOLegalConstraints$new()
  lc2$addUseLimitation(meta_dkan$result$license_title)
  # lc2$addUseLimitation("limitation2")
  # lc2$addUseLimitation("limitation3")
  # lc2$addAccessConstraint("otherRestrictions")
  # lc2$addOtherConstraint(ISOAnchor$new(
  #   href = "http://inspire.ec.europa.eu/metadata-codelist/ConditionsApplyingToAccessAndUse/noConditionsApply",
  #   name = "No conditions apply to access and use."
  # ))
  ident$addResourceConstraints(lc2)

  #adding security constraints
  # sc <- ISOSecurityConstraints$new()
  # sc$setClassification("secret")
  # sc$setUserNote("ultra secret")
  # sc$setClassificationSystem("no classification in particular")
  # sc$setHandlingDescription("description")
  # ident$addResourceConstraints(sc)

  if(!is.null(shp_params)){

  #adding extent
  extent <- ISOExtent$new()
  bbox <- ISOGeographicBoundingBox$new(minx = as.numeric(shp_params$bbox$xmin), miny = as.numeric(shp_params$bbox$ymin), maxx = as.numeric(shp_params$bbox$xmax), maxy = as.numeric(shp_params$bbox$ymax))
  extent$addGeographicElement(bbox)
  ident$addExtent(extent)
  }

  #add keywords
  kwds <- ISOKeywords$new()

  for(i in 1:length(meta_dkan$result$tags)){
    kwds$addKeyword(textutils::HTMLdecode(meta_dkan$result$tags[[i]]$name))
    # kwds$setKeywordType("theme")
    # th <- ISOCitation$new()
    # th$setTitle("General")
    # th$addDate(d)
    # kwds$setThesaurusName(th)
  }
  kwds$addKeyword("omees")
  kwds$addKeyword("Montpellier Méditerrannée Métropole")


  ident$addKeywords(kwds)


  #supplementalInformation
  ident$setSupplementalInformation("Métadonnée et donnée générée automatiquement à partir de l'API CKAN.")

  #spatial representation type
  ident$addSpatialRepresentationType("vector")
  md$addIdentificationInfo(ident)

  #Distribution
  distrib <- ISODistribution$new()
  dto <- ISODigitalTransferOptions$new()
  for(i in 1:length(meta_dkan$result$resources)){
    or <- ISOOnlineResource$new()
    or$setLinkage(meta_dkan$result$resources[[i]]$url)
    or$setName(meta_dkan$result$resources[[i]]$name)
    #or$setDescription(paste0("description",i))
    or$setProtocol("WWW:LINK-1.0-http--link")
    or$setOnLineFunction("download")
    dto$addOnlineResource(or)
  }

  if(!is.null(shp_params)){

  # add wms
  or <- ISOOnlineResource$new()
  or$setLinkage("https://geodata.bac-a-sable.inrae.fr/geoserver//omees/ows?service=WMS")
  or$setName(shp_params$shp_layer_name)
  or$setDescription(paste0(shp_params$shp_layer_name,"- OGC Web Map Service"))
  or$setProtocol("OGC:WMS")
  dto$addOnlineResource(or)

  # add wfs
  or <- ISOOnlineResource$new()
  or$setLinkage("https://geodata.bac-a-sable.inrae.fr/geoserver//omees/ows?service=WFS")
  or$setName(shp_params$shp_layer_name)
  or$setDescription(paste0(shp_params$shp_layer_name,"- OGC Web Feature Service"))
  or$setProtocol("OGC:WFS")
  dto$addOnlineResource(or)

}
  distrib$addDigitalTransferOptions(dto)
  md$setDistributionInfo(distrib)

  # ---------------------------------------------------------------------------
  # Linéage
  # ---------------------------------------------------------------------------



  dq <- ISODataQuality$new()

  scope <- ISODataQualityScope$new()
  scope$setLevel("dataset")
  dq$setScope(scope)

  lineage <- ISOLineage$new()
  lineage$setStatement(trimws(lineage_statement))
  dq$setLineage(lineage)

  md$addDataQualityInfo(dq)

  #XML representation of the ISOMetadata
  # xml <- md$encode()

  md$save(paste0(output_dir,"/",meta_dkan$result$id,".xml"))

  return(paste0(output_dir,"/",meta_dkan$result$id,".xml"))

}



# push_metadata <- function(result){
#
#   md <- readISO19139(result$output_file)
#   mdId <- md$fileIdentifier
#   GN$insertMetadata(geometa = md, group = "2", category = "2", uuidProcessing = "OVERWRITE", geometa_inspireValidator = INSPIRE_VALIDATOR)
#
#   # for geodata inrae bac à sable :
#   # group = "20838" is for PROJET_OMEES  (voir GN$getGroups()  pour tous les groupes dispos)
#   # category = "2" is for "datasets"     (voir GN$getCategories()  pour toutes les catégories dispos)
#
#   config <- GNPrivConfiguration$new()
#   config$setPrivileges("2", c("view","download", "dynamic"))
#   config$setPrivileges("all", c("view","download","dynamic"))
#   config$setPrivileges("20838", c("view","download","dynamic"))
#   GN$setPrivConfiguration(id = mdId, config = config)
#
# }





# meta_dkan <- mmm_get_meta(identifier)
#
# shp_params <- mmm_get_shp(meta_dkan)
#
# if(!is.null(shp_params)){
#   mmm_create_featuretype(meta_dkan,shp_params)
# }
#
# mmm_create_iso19115(meta_dkan,shp_params)
#
# push_metadata(meta_dkan)



## styles
# created <- GSman$createStyle(file = "styles/mmm/local-climate-zone.sld", name = "local-climate-zone")



## WMS image for montpellier :
## https://image.discomap.eea.europa.eu/arcgis/services/GioLandPublic/HRL_Grassland_2018/ImageServer/WMSServer?service=WMS&request=GetMap&version=1.3.0&layers=HRL_Grassland_2018&styles=&bbox=43.5,3.7,43.75,3.95&crs=EPSG:4326&width=800&height=800&format=image/png






