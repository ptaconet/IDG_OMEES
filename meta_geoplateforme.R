
library(geonapi)

GN <- GNManager$new(
  url = "http://data.geopf.fr/geonetwork",
  user = NULL, pwd = NULL,
  version = "4.2.8",
  logger = 'DEBUG'
)

id <- "fr-120066022-jdd-ebaa4945-19c3-45dd-88c0-35b1f091b608"
md <- GN$getMetadataByUUID(id)
