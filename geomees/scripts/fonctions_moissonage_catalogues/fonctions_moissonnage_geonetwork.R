library(geometa)
library(httr)
library(xml2)


geonetwork_create_iso19115 <- function(identifier, catalogue_url, catalogue_type){

  destfile <- paste0(identifier,".xml")

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

  } else if (catalogue_type == "opendatasoft"){

    url <- paste0(
      catalogue_url,
      "api/csw",
      "?service=CSW",
      "&request=GetRecordById",
      "&version=2.0.2",
      "&outputschema=http://www.isotc211.org/2005/gmd",
      "&ElementSetName=full",
      "&id=",identifier
    )

    res <- GET(url)
    stop_for_status(res)

    doc <- read_xml(content(res, "raw"))

    md <- xml_find_first(
      doc,
      ".//*[local-name()='MD_Metadata' and namespace-uri()='http://www.isotc211.org/2005/gmd']"
    )

    if (inherits(md, "xml_missing")) {
      stop("No ISO 19139 MD_Metadata element found in CSW response.")
    }

      write_xml(md, destfile, options = "format")

    xml <- XML::xmlParse(destfile)
    md <- ISOMetadata$new(xml = xml)

  }

  # # Get the existing data quality
  # dq <- md$dataQualityInfo[[1]]
  #
  # # Delete the existing data quality info
  # md$delDataQualityInfo(dq)
  #
  # dq$lineage$statement <- trimws(lineage_statement)
  #
  # md$addDataQualityInfo(dq)

  file.remove(destfile)



  return(md)

}

