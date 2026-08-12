library(geonapi)
library(geometa)
library(xml2)

source("dataflow_gn/params/credentials.R")

# Connect to GN
gn <- GNManager$new(
  url = "https://geodata.bac-a-sable.inrae.fr/geonetwork",  #"https://geodata.inrae.fr/geonetwork",
  version = "4.2.8",
  user = user_gn,
  pwd = pwd_gn_bacasable,
  logger = "DEBUG"
)



identifier <- "doi:10.13144/lil-1698"

url <- paste0("https://data.progedo.fr/oai?verb=GetRecord&metadataPrefix=oai_ddi25&identifier=",identifier)

meta_xml <- xml2::read_xml(url)


xml_to_list <- function(node) {
  children <- xml_children(node)

  if (length(children) == 0) {
    return(xml_text(node, trim = TRUE))
  }

  out <- lapply(children, xml_to_list)
  names(out) <- xml_name(children)
  out
}

meta_list <- xml_to_list(record)




md = ISOMetadata$new()
md$setFileIdentifier(meta_list$stdyDscr$citation$titlStmt$IDNo)

ct <- ISOCitation$new()
ct$setTitle(meta_list$stdyDscr$citation$titlStmt$titl)




