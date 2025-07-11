
library(httr)
library(xml2)
library(XML)

identifier="49d986b4-c998-4e7a-8431-0989ad9d99e0"

url <- paste0("https://catalogue.picto-occitanie.fr/geonetwork/srv/api/records/",identifier,"/formatters/xml")

download.file(url, paste0("xml_metadata/pictooccitanie/",identifier,".xml"))

# Extract only the <gmd:MD_Metadata> or your target root node
lines <- readLines(paste0("xml_metadata/pictooccitanie/",identifier,".xml"))
writeLines(lines[-1], paste0("xml_metadata/pictooccitanie/",identifier,".xml"))


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
  user = "omees", pwd = "HHKcue51!HHKcue51!",
  version = "4.2.8",
  logger = 'DEBUG'
)

created = GN$insertMetadata(file = paste0("xml_metadata/pictooccitanie/",identifier,".xml"), group = "1", category = "datasets")

