library(ows4R)
library(geometa)
library(geonapi)



identifier = "IGNF_COSIA"


#### The short version
CSW <- CSWClient$new("https://data.geopf.fr/csw", "2.0.2", logger = "INFO")
md <- CSW$getRecordById(identifier, outputSchema = "http://standards.iso.org/iso/19115/-3/mdb/2.0")
md$save(paste0("xml_metadata/geopf/",identifier,".xml"))
####

#### The long version
# library(httr)
# library(xml2)
# library(XML)
# url = paste0("https://data.geopf.fr/geonetwork/srv/fre/csw?service=CSW&version=2.0.2&request=GetRecordById&outputSchema=http://www.isotc211.org/2005/gmd&elementsetname=full&id=",identifier)
# response <- GET(url)
# stop_for_status(response)
#
# # 3. Parse XML (optional step, if you want to inspect it)
# xml_content <- content(response, as = "text")
# xml_doc <- read_xml(xml_content)
#
# # Extract only the <gmd:MD_Metadata> or your target root node
# record <- xml_find_first(xml_doc, ".//gmd:MD_Metadata")
#
# # 4. Save it locally
# write_xml(record, paste0("xml_metadata/geopf/",identifier,".xml"))




#adding keywords
#
# xml <- xmlParse(paste0("xml_metadata/geopf/",identifier,".xml"))
# md <- ISOMetadata$new(xml = xml)
#
# ident <- ISODataIdentification$new()
# kwds <- ISOKeywords$new()
# kwds$addKeyword("omees")
# ident$addKeywords(kwds)
# md$addIdentificationInfo(ident)
#
# md$save(paste0("xml_metadata/geopf/",identifier,".xml"))


GN <- GNManager$new(
  url = "https://geodata.bac-a-sable.inrae.fr/geonetwork",
  user = Sys.getenv("idgomees_inrae_user"), pwd = Sys.getenv("idgomees_inrae_pw"),
  version = "4.2.8",
  logger = 'DEBUG'
)

created = GN$insertMetadata(file = paste0("xml_metadata/geopf/",identifier,".xml"), group = "1", category = "datasets")


