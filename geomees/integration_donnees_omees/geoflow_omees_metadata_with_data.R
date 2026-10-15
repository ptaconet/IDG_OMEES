library(geoflow)
library(jsonlite)


source("geomees/credentials_geomees.R")


geomees_prod_or_bacasable <- "bacasable"  # "prod" ou "bacasable"


update_geoflow_config <- function(
    config_file,
    postgis_user,
    postgis_pwd,
    postgis_host,
    postgis_port,
    postgis_dbname,
    gn_url,
    gs_url,
    gn_gs_user,
    gn_gs_pwd  ) {

  config <- jsonlite::fromJSON(
    config_file,
    simplifyVector = FALSE
  )

  config$software[[1]]$parameters$user <- postgis_user
  config$software[[1]]$parameters$password <- postgis_pwd
  config$software[[1]]$parameters$host <- postgis_host
  config$software[[1]]$parameters$port <- postgis_port
  config$software[[1]]$parameters$dbname <- postgis_dbname

  config$software[[2]]$parameters$url <- gs_url
  config$software[[2]]$parameters$user <- gn_gs_user
  config$software[[2]]$parameters$pwd <- gn_gs_pwd

  config$software[[3]]$parameters$url <- gn_url
  config$software[[3]]$parameters$user <- gn_gs_user
  config$software[[3]]$parameters$pwd <- gn_gs_pwd

  jsonlite::write_json(
    config,
    config_file,
    pretty = TRUE,
    auto_unbox = TRUE
  )

  return(config_file)
}


config_file <- update_geoflow_config(
  config_file = "geomees/integration_donnees_omees/geoflow_config_files/config_geomees_metadata_with_data.json",
  postgis_user = geomees_db_user,
  postgis_pwd = geomees_db_password,
  postgis_host = geomees_db_host,
  postgis_port = geomees_db_port,
  postgis_dbname = geomees_db_dbname,
  gn_url = eval(parse(text = paste0("geomees_gn_",geomees_prod_or_bacasable,"_url"))),
  gs_url = eval(parse(text = paste0("geomees_gs_",geomees_prod_or_bacasable,"_url"))),
  gn_gs_user =  eval(parse(text = paste0("geomees_gn_gs_",geomees_prod_or_bacasable,"_user"))),
  gn_gs_pwd = eval(parse(text = paste0("geomees_gn_gs_",geomees_prod_or_bacasable,"_pwd")))
)



config <- initWorkflow("/home/ptaconet/IDG_OMEES/geomees/integration_donnees_omees/geoflow_config_files/config_geomees_metadata_with_data.json", dir = "/home/ptaconet/IDG_OMEES/geomees/integration_donnees_omees/geoflow_logs")
executeWorkflow("/home/ptaconet/IDG_OMEES/geomees/integration_donnees_omees/geoflow_config_files/config_geomees_metadata_with_data.json", dir = "/home/ptaconet/IDG_OMEES/geomees/integration_donnees_omees/geoflow_logs")
