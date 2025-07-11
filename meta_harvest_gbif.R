library(xslt)
library(xml2)
#library(emld)
library(httr)

identifier <- "8e52f35a-2522-4865-8361-5c249310a7cf"

u <- httr::GET(paste0("https://api.gbif.org/v1/dataset/",identifier,"/document"))
httr::GET(u$url, httr::write_disk(paste0('xml_metadata/gbif/eml/',identifier,".xml"), overwrite=T))

#eml <- as_emld(paste0('xml_metadata/gbif/eml/',identifier,".xml"))


# Read input XML and XSLT
doc <- read_xml(paste0('xml_metadata/gbif/eml/',identifier,".xml"))
style <- read_xml("xml_metadata/gbif/eml2iso19115_xslt1_compatible_v2.xslt")

# Apply transformation
transformed <- xslt::xml_xslt(doc, style)

# Save result
write_xml(transformed, paste0("xml_metadata/gbif/iso/",identifier,".xml"))

library(geonapi)
library(XML)
#read XML file
xml <- xmlParse(paste0("xml_metadata/gbif/iso/",identifier,".xml"))

#read XML as ISOMetadata object
md <- ISOMetadata$new(xml = xml)


#Distribution
distrib <- ISODistribution$new()
dto <- ISODigitalTransferOptions$new()
or <- ISOOnlineResource$new()
or$setLinkage("https://doi.org/10.15468/4qafbu")
or$setName("Link to dataset hosted on the GBIF")
#or$setDescription(paste0("description",i))
or$setProtocol("WWW:LINK-1.0-http--link")
or$setOnLineFunction("download")
dto$addOnlineResource(or)

distrib$addDigitalTransferOptions(dto)
md$setDistributionInfo(distrib)

xml <- md$encode()

md$save(paste0("xml_metadata/gbif/iso/",identifier,".xml"))


#rgif::dataset_get(identifier)


## The data
events <- read.csv("/home/ptaconet/contributions_diverses_projets_mivegec/modeling_vector_mtp/data_gbif/events.csv")
events <- events %>%
  dplyr::select(decimalLatitude, decimalLongitude) %>%
  unique()

points_sf <- st_as_sf(events, coords = c("decimalLongitude", "decimalLatitude"), crs = 4326)
points_utm <- st_transform(points_sf, crs = 32631)  # UTM zone 31N, fits southern France

squares <- st_make_grid(points_utm, cellsize = 50, square = TRUE, what = "polygons")

squares2 <- squares[as.numeric(st_intersects(points_utm,squares))]

squares2 <- st_transform(squares2, crs = 4326)

st_write(squares2,"/home/ptaconet/IDG_OMEES/data/gbif_test.gpkg")
