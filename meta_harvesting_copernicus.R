

library(httr)
library(xml2)
library(XML)

identifier <- "a8e683b1-2f96-45c8-827f-580a79413018"


# 1. Download the XML content from a URL
url <- paste0("https://sdi.eea.europa.eu/catalogue/srv/api/records/",identifier,"/formatters/xml")  # replace with your URL
response <- GET(url)

# 2. Check the status
stop_for_status(response)

# 3. Parse XML (optional step, if you want to inspect it)
xml_content <- content(response, as = "text")
xml_doc <- read_xml(xml_content)

# 4. Save it locally
writeLines(xml_content, paste0("xml_metadata/copernicus/",identifier,".xml"))

xml <- xmlParse(paste0("xml_metadata/copernicus/",identifier,".xml"))
md <- ISOMetadata$new(xml = xml)

#adding extent
ident <- ISODataIdentification$new()

extent <- ISOExtent$new()
bbox <- ISOGeographicBoundingBox$new(minx = as.numeric(shp_params$bbox$xmin), miny = as.numeric(shp_params$bbox$ymin), maxx = as.numeric(shp_params$bbox$xmax), maxy = as.numeric(shp_params$bbox$ymax))
extent$addGeographicElement(bbox)
ident$addExtent(extent)

md$addIdentificationInfo(ident)


GN <- GNManager$new(
  url = "https://geodata.bac-a-sable.inrae.fr/geonetwork",
  user = "omees", pwd = "HHKcue51!HHKcue51!",
  version = "4.2.8",
  logger = 'DEBUG'
)

created = GN$insertMetadata(file = "xml_metadata/copernicus/a8e683b1-2f96-45c8-827f-580a79413018.xml", group = "1", category = "datasets")
