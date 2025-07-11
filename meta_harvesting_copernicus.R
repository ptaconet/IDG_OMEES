library(ows4R)
library(geometa)
library(geonapi)



identifier <- "a8e683b1-2f96-45c8-827f-580a79413018"


#### The short version
CSW <- CSWClient$new("https://sdi.eea.europa.eu/catalogue/srv/eng/csw", "2.0.2", logger = "INFO")
md <- CSW$getRecordById(identifier, outputSchema = "http://www.isotc211.org/2005/gmd")
md$save(paste0("xml_metadata/copernicus/",identifier,".xml"))
####

#### The long version
# library(httr)
# library(xml2)
# library(XML)
# 1. Download the XML content from a URL
# url <- paste0("https://sdi.eea.europa.eu/catalogue/srv/api/records/",identifier,"/formatters/xml")  # replace with your URL
# response <- GET(url)
#
# # 2. Check the status
# stop_for_status(response)
#
# # 3. Parse XML (optional step, if you want to inspect it)
# xml_content <- content(response, as = "text")
# xml_doc <- read_xml(xml_content)
#
# # 4. Save it locally
# writeLines(xml_content, paste0("xml_metadata/copernicus/",identifier,".xml"))




#adding keywords
# à faire à la main pour l'instant... en attendant de comprendre comment on le fait avec geometa
#  <gmd:keyword>
# <gco:CharacterString>omees</gco:CharacterString>
#  </gmd:keyword>

 # xml <- xmlParse(paste0("xml_metadata/copernicus/",identifier,".xml"))
 # md <- ISOMetadata$new(xml = xml)
 #
 # ident <- ISODataIdentification$new()
 # kwds <- ISOKeywords$new()
 # kwds$addKeyword("omees")
 # ident$addKeywords(kwds)
 # md$addIdentificationInfo(ident)
 #
 # md$save(paste0("xml_metadata/copernicus/",identifier,".xml"))
 #

GN <- GNManager$new(
  url = "https://geodata.bac-a-sable.inrae.fr/geonetwork",
  user = Sys.getenv("idgomees_inrae_user"), pwd = Sys.getenv("idgomees_inrae_pw"),
  version = "4.2.8",
  logger = 'DEBUG'
)

created = GN$insertMetadata(file = paste0("xml_metadata/copernicus/",identifier,".xml"), group = "1", category = "datasets")
