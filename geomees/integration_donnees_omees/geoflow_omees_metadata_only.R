library(geoflow)
library(jsonlite)


source("geomees/credentials_geomees.R")

geomees_prod_or_bacasable <- "prod"  # "prod" ou "bacasable"


update_geoflow_config <- function(
    config_file,
    gn_url,
    gn_gs_user,
    gn_gs_pwd) {

  config <- jsonlite::fromJSON(
    config_file,
    simplifyVector = FALSE
  )

  config$software[[1]]$parameters$url <- gn_url
  config$software[[1]]$parameters$user <- gn_gs_user
  config$software[[1]]$parameters$pwd <- gn_gs_pwd

  jsonlite::write_json(
    config,
    config_file,
    pretty = TRUE,
    auto_unbox = TRUE
  )

  return(config_file)
}


config_file <- update_geoflow_config(
  config_file = "geomees/integration_donnees_omees/geoflow_config_files/config_geomees_metadata_only.json",
  gn_url = eval(parse(text = paste0("geomees_gn_",geomees_prod_or_bacasable,"_url"))),
  gn_gs_user = eval(parse(text = paste0("geomees_gn_gs_",geomees_prod_or_bacasable,"_user"))),
  gn_gs_pwd = eval(parse(text = paste0("geomees_gn_gs_",geomees_prod_or_bacasable,"_pwd")))
)


config <- initWorkflow("/home/ptaconet/IDG_OMEES/geomees/integration_donnees_omees/geoflow_config_files/config_geomees_metadata_only.json", dir = "/home/ptaconet/IDG_OMEES/geomees/integration_donnees_omees/geoflow_logs")
executeWorkflow("/home/ptaconet/IDG_OMEES/geomees/integration_donnees_omees/geoflow_config_files/config_geomees_metadata_only.json", dir = "/home/ptaconet/IDG_OMEES/geomees/integration_donnees_omees/geoflow_logs")
