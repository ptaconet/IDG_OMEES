
library(geonapi)
library(rjson)

identifier <- "occupation-du-sol-2018-herault"

openig_create_iso19115 <- function(identifier){

  cat("creating ISO19115 for identifier ",identifier,"...\n")

  fiche_meta = rjson::fromJSON(file = paste0("https://ckan.openig.org/api/3/action/package_show?id=",identifier))

  md = ISOMetadata$new()
  md$setFileIdentifier(fiche_meta$result$name) # alternative : meta_dkan$result$id
  md$setCharacterSet("utf8")
  md$setLanguage("fre")
  md$setDateStamp(Sys.time())
  md$setMetadataStandardName("ISO 19115:2003/19139")
  md$setHierarchyLevel("dataset")
  md$setMetadataStandardVersion("1.0")
  md$setDataSetURI(fiche_meta$result$url)
