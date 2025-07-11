
mmm_identifiers <- c("ca874786-dbf8-47cb-a51b-7a5a003dfadc",
                     "d718a1c4-95b1-46a6-ad3b-558e03577581",
                     "3408ffbc-74ef-4456-bbdb-6e2d805f890f",
                     "14a8d220-345e-474e-a31a-7eacf68f0b74",
                     "7e090ef5-f167-4264-8204-e5d8219617e4",
                     "f3246317-a3ce-457d-837a-4c99a336cd9e",
                     "ea68bf94-0f14-4b4b-abc4-d562e598ecec")




# tout le catalogue :
# fiche_meta_catalogue = rjson::fromJSON(file = "https://data.montpellier3m.fr/data.json")


# à faire en systèmatique dans la fonction (pour chaque entité de métadonnée)
#txt = textutils::HTMLdecode(a)

library(geonapi)
library(rjson)
library(textutils)

mmm_create_iso19115 <- function(identifier){

  cat("creating ISO19115 for identifier ",identifier,"...\n")

  fiche_meta = rjson::fromJSON(file = paste0("https://data.montpellier3m.fr/api/3/action/package_show?id=",identifier))

  md = ISOMetadata$new()
  md$setFileIdentifier(fiche_meta$result$name) # alternative : fiche_meta$result$id
  #md$setParentIdentifier("my-parent-metadata-identifier")
  md$setCharacterSet("utf8")
  md$setLanguage("fre")
  md$setDateStamp(Sys.time())
  md$setMetadataStandardName("ISO 19115:2003/19139")
  #md$setHierarchyLevel("dataset")
  md$setMetadataStandardVersion("1.0")
  md$setDataSetURI(fiche_meta$result$url)

  #add 3 contacts
  for(i in 1:3){
    rp <- ISOResponsibleParty$new()
    rp$setIndividualName(paste0("someone",i))
    rp$setOrganisationName(textutils::HTMLdecode(fiche_meta$result$maintainer))
    rp$setPositionName(paste0("someposition",i))
    rp$setRole("publisher")
    contact <- ISOContact$new()
    phone <- ISOTelephone$new()
    phone$setVoice(paste0("myphonenumber",i))
    contact$setPhone(phone)
    address <- ISOAddress$new()
    address$setDeliveryPoint("theaddress")
    address$setCity("thecity")
    address$setPostalCode("111")
    address$setCountry("France")
    address$setEmail(fiche_meta$result$maintainer_email)
    contact$setAddress(address)
    res <- ISOOnlineResource$new()
    res$setLinkage("https://data.montpellier3m.fr/")
    res$setName("someresourcename")
    contact$setOnlineResource(res)
    rp$setContactInfo(contact)
    md$addContact(rp)
  }

  #VectorSpatialRepresentation
  vsr <- ISOVectorSpatialRepresentation$new()
  vsr$setTopologyLevel("geometryOnly")
  geomObject <- ISOGeometricObjects$new()
  geomObject$setGeometricObjectType("point")
  geomObject$setGeometricObjectCount(5L)
  vsr$addGeometricObjects(geomObject)
  md$addSpatialRepresentationInfo(vsr)

  #ReferenceSystem
  rs <- ISOReferenceSystem$new()
  rsId <- ISOReferenceIdentifier$new(code = "4326", codeSpace = "EPSG")
  rs$setReferenceSystemIdentifier(rsId)
  md$addReferenceSystemInfo(rs)

  #data identification
  ident <- ISODataIdentification$new()
  ident$setAbstract(textutils::HTMLdecode(fiche_meta$result$notes))
  ident$setPurpose("purpose")
  ident$addCredit("credit1")
  ident$addCredit("credit2")
  ident$addCredit("credit3")
  ident$addStatus("completed")
  ident$addLanguage("fre")
  ident$addCharacterSet("utf8")
  #ident$addTopicCategory("biota")
  ident$addTopicCategory("environment")
  ident$addTopicCategory("health")

  #citation
  ct <- ISOCitation$new()
  ct$setTitle(textutils::HTMLdecode(fiche_meta$result$title))
  d <- ISODate$new()
  d$setDate(ISOdate(2015, 1, 1, 1))
  d$setDateType("publication")
  ct$addDate(d)
  ct$setEdition("1.0")
  ct$setEditionDate(as.Date(ISOdate(2015, 1, 1, 1)))
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

  # go2 <- ISOBrowseGraphic$new(
  #   fileName = "http://www.somefile.org/png2",
  #   fileDescription = "Map Overview 2",
  #   fileType = "image/png"
  # )
  #ident$addGraphicOverview(go2)

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
  lc2$addUseLimitation(fiche_meta$result$license_title)
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
  bbox <- ISOGeographicBoundingBox$new(minx = 3.7, miny = 43.5, maxx = 3.95, maxy = 43.75)
  extent$addGeographicElement(bbox)
  ident$addExtent(extent)

  #add keywords
  kwds <- ISOKeywords$new()

  for(i in 1:length(fiche_meta$result$tags)){
    kwds$addKeyword(fiche_meta$result$tags[[i]]$name)
    # kwds$setKeywordType("theme")
    # th <- ISOCitation$new()
    # th$setTitle("General")
    # th$addDate(d)
    # kwds$setThesaurusName(th)
  }
  ident$addKeywords(kwds)

  #supplementalInformation
  ident$setSupplementalInformation("some additional information")

  #spatial representation type
  ident$addSpatialRepresentationType("vector")
  md$addIdentificationInfo(ident)

  #Distribution
  distrib <- ISODistribution$new()
  dto <- ISODigitalTransferOptions$new()
  for(i in 1:length(fiche_meta$result$resources)){
    or <- ISOOnlineResource$new()
    or$setLinkage(fiche_meta$result$resources[[i]]$url)
    or$setName(fiche_meta$result$resources[[i]]$name)
    #or$setDescription(paste0("description",i))
    or$setProtocol("WWW:LINK-1.0-http--link")
    or$setOnLineFunction("download")
    dto$addOnlineResource(or)
  }
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
  # lineage$setStatement("statement")
  # dq$setLineage(lineage)
  #
  # md$addDataQualityInfo(dq)

  #XML representation of the ISOMetadata
  xml <- md$encode()

  md$save(paste0("xml_metadata/mmm/",identifier,".xml"))

}



purrr::map(mmm_identifiers,~mmm_create_iso19115(.))



