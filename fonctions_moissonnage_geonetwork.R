library(geometa)

# url <- paste0("https://sig.oreme.org/geonetwork/srv/api/records/",identifier,"/formatters/xml?approved=true")
#
# identifier <- "c4660136-cfdd-4918-8d56-4db1124c3df1"


geonetwork_create_iso19115 <- function(identifier, output_dir, catalogue_url, catalogue_name, catalogue_type, topic_categories){

  destfile <- paste0(output_dir,"/",identifier,".xml")

  lineage_statement <- paste(
    "<b><i>Cette fiche de métadonnée et les éventuelle(s) donnée(s) associées ont été moissonnée(s) automatiquement depuis le jeu de données",
    identifier %||% "",
    "hébergé sur le catalogue ",catalogue_name," (",catalogue_url,")</b></i>",
    "\n"
  )


  if (catalogue_type == "geonetwork_api") {

    url <- paste0(
      catalogue_url,
      "srv/api/records/",
      identifier,
      "/formatters/xml?approved=true"
    )

    download.file(
      url,
      destfile = destfile,
      mode = "wb"
    )

    #read XML as ISOMetadata object
    md <- readISO(destfile)


  } else if (catalogue_type == "geonetwork_csw_19115_3") {

    CSW <- CSWClient$new(paste0(catalogue_url,"csw"), "2.0.2", logger = "INFO")
    md <- CSW$getRecordById(identifier, outputSchema = "http://standards.iso.org/iso/19115/-3/mdb/2.0")
    md$save(destfile)

    xml <- XML::xmlParse(destfile)
    md <- ISOMetadata$new(xml = xml)

  }


  # Get the existing data identification
  ident <- md$identificationInfo[[1]]

  # Delete the existing data identification
  md$delIdentificationInfo(ident)

  # add keywords
  kwds <- ISOKeywords$new()
  kwds$addKeyword("omees")

  ident$descriptiveKeywords <- c(
    ident$descriptiveKeywords,
    list(kwds)
  )

  #supplementalInformation
  ident$setSupplementalInformation(
    paste0(
      "Métadonnée et donnée générée automatiquement à partir du catalogue ",
      catalogue_name
    )
  )

  #abstract

  ident$setAbstract(paste0(ident$abstract,
                           "<p>",
                           lineage_statement,
                           "</p>"))


  md$addIdentificationInfo(ident)


  # # Get the existing data quality
  # dq <- md$dataQualityInfo[[1]]
  #
  # # Delete the existing data quality info
  # md$delDataQualityInfo(dq)
  #
  # dq$lineage$statement <- trimws(lineage_statement)
  #
  # md$addDataQualityInfo(dq)


  md$save(destfile)

  return(destfile)

}

