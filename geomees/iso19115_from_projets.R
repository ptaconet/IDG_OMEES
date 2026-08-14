library(DBI)
library(geometa)

con <- dbConnect(
  RPostgres::Postgres(),
  host = "postgresql-taconet.alwaysdata.net",
  dbname = "taconet_albopictus",
  port = 5432,
  user = "taconet",
  password = "HHKcue51"
)

projets_omees <- st_read("projets_omees", dsn = con)


source("geomees/scripts/fonctions_moissonage_catalogues/fonctions_create_metadata_projets_omees.R")


for(i in 1:nrow(projets_omees)){

  md <- project_omees_create_iso19115(projets_omees[i,])

  destfile <- file.path("xml_metadata",paste0(projets_omees[i,]$projet_acronyme,".xml"))

  md$save(destfile)


  #### push metadata in GN

  md <- geometa::readISO(file = destfile)
  mdId <- md$fileIdentifier
  GN$insertMetadata(geometa = md, group = "20838", category = "2", uuidProcessing = "OVERWRITE", geometa_inspireValidator = INSPIRE_VALIDATOR)

  # for geodata inrae bac à sable :
  # group = "20838" is for PROJET_OMEES  (voir GN$getGroups()  pour tous les groupes dispos)
  # category = "2" is for "datasets"     (voir GN$getCategories()  pour toutes les catégories dispos)

  config <- GNPrivConfiguration$new()
  config$setPrivileges("2", c("view","download", "dynamic"))
  config$setPrivileges("all", c("view","download","dynamic"))
  config$setPrivileges("20838", c("view","download","dynamic","featured"))
  GN$setPrivConfiguration(id = mdId, config = config)

}
