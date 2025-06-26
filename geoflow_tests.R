library(rjson)
library(geometa)
library(geosapi)
library(geonapi)
library(sf)

mmm_identifiers <- c("ca874786-dbf8-47cb-a51b-7a5a003dfadc",
                     "d718a1c4-95b1-46a6-ad3b-558e03577581",
                     "3408ffbc-74ef-4456-bbdb-6e2d805f890f",
                     "14a8d220-345e-474e-a31a-7eacf68f0b74",
                     "7e090ef5-f167-4264-8204-e5d8219617e4",
                     "f3246317-a3ce-457d-837a-4c99a336cd9e",
                     "ea68bf94-0f14-4b4b-abc4-d562e598ecec")

# tout le catalogue :
# meta_dkan_catalogue = rjson::fromJSON(file = "https://data.montpellier3m.fr/data.json")


# à faire en systèmatique dans la fonction (pour chaque entité de métadonnée)
#txt = textutils::HTMLdecode(a)

GN <- GNManager$new(
  url = "https://geodata.bac-a-sable.inrae.fr/geonetwork",
  user = "omees", pwd = "HHKcue51!HHKcue51!",
  version = "4.2.8",
  logger = 'DEBUG'
)

GSman <- GSManager$new(
  url = "https://geodata.bac-a-sable.inrae.fr/geoserver",
  user = "omees", pwd = "HHKcue51!HHKcue51!",
  logger = 'DEBUG'
)


mmm_get_meta <- function(identifier){

  meta_dkan = rjson::fromJSON(file = paste0("https://data.montpellier3m.fr/api/3/action/package_show?id=",identifier))

  return(meta_dkan)

}

mmm_get_shp <- function(meta_dkan){

  for(i in 1:length(meta_dkan$result$resources)){
    if(meta_dkan$result$resources[[i]]$mimetype == "application/zip"){
      download.file(url = meta_dkan$result$resources[[i]]$url , destfile = paste0("data/mmm/",meta_dkan$result$resources[[i]]$name))
      break()
    }
  }

  # Reading shapefiles (or other data sources) directly from zip files can be done by prepending the path with /vsizip/
  shp <- read_sf(paste0("/vsizip/data/mmm/",meta_dkan$result$resources[[i]]$name))

  shp_layer_name <- st_layers(paste0("/vsizip/data/mmm/",meta_dkan$result$resources[[i]]$name))$name
  crs = st_crs(shp)$epsg
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

}


mmm_create_featuretype <- function(meta_dkan, shp_params){

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


mmm_create_iso19115 <- function(meta_dkan, shp_params){


  md = ISOMetadata$new()
  md$setFileIdentifier(meta_dkan$result$name) # alternative : meta_dkan$result$id
  #md$setParentIdentifier("my-parent-metadata-identifier")
  md$setCharacterSet("utf8")
  md$setLanguage("fre")
  md$setDateStamp(Sys.time())
  md$setMetadataStandardName("ISO 19115:2003/19139")
  #md$setHierarchyLevel("dataset")
  md$setMetadataStandardVersion("1.0")
  md$setDataSetURI(meta_dkan$result$url)


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

  #data identification
  ident <- ISODataIdentification$new()
  ident$setAbstract(textutils::HTMLdecode(meta_dkan$result$notes))
  #ident$setPurpose("purpose")
  #ident$addCredit("Open Data Montpellier Méditerrannée Métropole")
  ident$addStatus("completed")
  ident$addLanguage("fre")
  ident$addCharacterSet("utf8")
  #ident$addTopicCategory("biota")
  ident$addTopicCategory("environment")
  ident$addTopicCategory("health")

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
  ct$addPresentationForm("mapDigital")
  ct$addCitedResponsibleParty(rp)
  ident$setCitation(ct)

  #graphic overview
  go1 <- ISOBrowseGraphic$new(
    fileName = "https://upload.wikimedia.org/wikipedia/fr/e/e0/Logo_Montpellier_M%C3%A9diterran%C3%A9e_M%C3%A9tropole.svg",
    fileDescription = "3M logo",
    fileType = "image/svg"
  )
  ident$addGraphicOverview(go1)

  go2 <- ISOBrowseGraphic$new(
    fileName = paste0("https://geodata.bac-a-sable.inrae.fr/geoserver/omees/wms?service=WMS&version=1.1.0&request=GetMap&layers=omees:",shp_params$shp_layer_name,"&bbox=",as.numeric(shp_params$bbox$xmin),",",as.numeric(shp_params$bbox$ymin),",",as.numeric(shp_params$bbox$xmax),",",as.numeric(shp_params$bbox$ymax),"&width=768&height=658&srs=EPSG:",shp_params$crs,"&styles=&format=image/png"),
    fileDescription = "Map Overview",
    fileType = "image/png"
  )
  ident$addGraphicOverview(go2)

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

  #adding extent
  extent <- ISOExtent$new()
  bbox <- ISOGeographicBoundingBox$new(minx = as.numeric(shp_params$bbox$xmin), miny = as.numeric(shp_params$bbox$ymin), maxx = as.numeric(shp_params$bbox$xmax), maxy = as.numeric(shp_params$bbox$ymax))
  extent$addGeographicElement(bbox)
  ident$addExtent(extent)

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
  ident$setSupplementalInformation("La métadonnée et le jeu de données ont été automatiquement extraits du portail Open Data de la 3M via des scripts ad hoc")

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


  distrib$addDigitalTransferOptions(dto)
  md$setDistributionInfo(distrib)

  #create dataQuality object with a 'dataset' scope
  # dq <- ISODataQuality$new()
  # scope <- ISODataQualityScope$new()
  # scope$setLevel("dataset")
  # dq$setScope(scope)

  #add data quality reports...

  #add a report the data quality
  # dc <- ISODomainConsistency$new()
  # result <- ISOConformanceResult$new()
  # spec <- ISOCitation$new()
  # spec$setTitle("Data Quality check")
  # spec$addAlternateTitle("This is is some data quality check report")
  # d <- ISODate$new()
  # d$setDate(as.Date(ISOdate(2015, 1, 1, 1)))
  # d$setDateType("publication")
  # spec$addDate(d)
  # result$setSpecification(spec)
  # result$setExplanation("some explanation about the conformance")
  # result$setPass(TRUE)
  # dc$addResult(result)
  # dq$addReport(dc)

  #add INSPIRE reports?
  #INSPIRE - interoperability of spatial data sets and services
  # dc_inspire1 <- ISODomainConsistency$new()
  # cr_inspire1 <- ISOConformanceResult$new()
  # cr_inspire_spec1 <- ISOCitation$new()
  # cr_inspire_spec1$setTitle("Commission Regulation (EU) No 1089/2010 of 23 November 2010 implementing Directive 2007/2/EC of the European Parliament and of the Council as regards interoperability of spatial data sets and services")
  # cr_inspire1$setExplanation("See the referenced specification")
  # cr_inspire_date1 <- ISODate$new()
  # cr_inspire_date1$setDate(as.Date(ISOdate(2010,12,8)))
  # cr_inspire_date1$setDateType("publication")
  # cr_inspire_spec1$addDate(cr_inspire_date1)
  # cr_inspire1$setSpecification(cr_inspire_spec1)
  # cr_inspire1$setPass(TRUE)
  # dc_inspire1$addResult(cr_inspire1)
  # dq$addReport(dc_inspire1)
  #INSPIRE - metadata
  # dc_inspire2 <- ISODomainConsistency$new()
  # cr_inspire2 <- ISOConformanceResult$new()
  # cr_inspire_spec2 <- ISOCitation$new()
  # cr_inspire_spec2$setTitle("COMMISSION REGULATION (EC) No 1205/2008 of 3 December 2008 implementing Directive 2007/2/EC of the European Parliament and of the Council as regards metadata")
  # cr_inspire2$setExplanation("See the referenced specification")
  # cr_inspire_date2 <- ISODate$new()
  # cr_inspire_date2$setDate(as.Date(ISOdate(2008,12,4)))
  # cr_inspire_date2$setDateType("publication")
  # cr_inspire_spec2$addDate(cr_inspire_date2)
  # cr_inspire2$setSpecification(cr_inspire_spec2)
  # cr_inspire2$setPass(TRUE)
  # dc_inspire2$addResult(cr_inspire2)
  # dq$addReport(dc_inspire2)

  #add lineage (more example of lineages in ISOLineage documentation)
   # lineage <- ISOLineage$new()
   # lineage$setStatement("La métadonnée et le jeu de données ont été automatiquement extraits du portail Open Data de la 3M via des scripts ad hoc")
   # dq$setLineage(lineage)

  # md$addDataQualityInfo(dq)

  #XML representation of the ISOMetadata
  xml <- md$encode()

  md$save(paste0("xml_metadata/mmm/",meta_dkan$result$id,".xml"))

}

mmm_push_metadata <- function(meta_dkan){

  created = GN$insertMetadata(file = paste0("xml_metadata/mmm/",meta_dkan$result$id,".xml"), group = "1", category = "datasets") #  group = "sample"
  config <- GNPrivConfiguration$new()
  config$setPrivileges("all", c("view","dynamic","featured"))
  GN$setPrivConfiguration(id = created, config = config)

}


identifier = "14aefe94-fdbe-4383-a860-051b54c41879"

meta_dkan <- mmm_get_meta(identifier)

shp_params <- mmm_get_shp(meta_dkan)

mmm_create_featuretype(meta_dkan,shp_params)

mmm_create_iso19115(meta_dkan,shp_params)

mmm_push_metadata(meta_dkan)







## WMS image for montpellier :
## https://image.discomap.eea.europa.eu/arcgis/services/GioLandPublic/HRL_Grassland_2018/ImageServer/WMSServer?service=WMS&request=GetMap&version=1.3.0&layers=HRL_Grassland_2018&styles=&bbox=43.5,3.7,43.75,3.95&crs=EPSG:4326&width=800&height=800&format=image/png






