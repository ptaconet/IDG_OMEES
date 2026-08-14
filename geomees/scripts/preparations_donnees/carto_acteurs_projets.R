# https://mmontpellier.sharepoint.com/sites/PJT_BP2A_Ecologie-de-la-sant-Montpellier-REFERENCEMENTPROJETSIDGOMEES

library(readxl)
library(sf)
library(DBI)
library(tidyverse)

df_projets <- read_xlsx("geomees/data/carto_acteurs_projets/projets/data.xlsx")

thematiques <- read_xlsx("geomees/data/carto_acteurs_projets/projets/thematiques_omees.xlsx")

colnames(df_projets) <- c("saisisseur_nom",
                    "saisisseur_prenom",
                    "saisisseur_etablissement",
                    "saisisseur_umr",
                    "saisisseur_contact",
                    "projet_statut",
                    "projet_acronyme",
                    "projet_intitule",
                    "descriptif",
                    "porteur_etablissement",
                    "porteur_umr",
                    "porteur_partenaire_1",
                    "porteur_partenaire_2",
                    "porteur_partenaire_3",
                    "porteur_partenaire_autres",
                    "date_debut",
                    "date_fin",
                    "contact",
                    "contact_autorisationpartage",
                    "site_web",
                    "lien_doc_presentation",
                    "doc_presentation_autorisationpartage",
                    "publications_scientifiques",
                    "lien_rapport_scientifique_1",
                    "rapport_scientifique_autorisationpartage",
                    "lien_rapport_scientifique_2",
                    "lien_rapport_scientifique_3",
                    "donnee_1",
                    "donnee_2",
                    "saisisseur_sites_etude",
                    "carte_etude",
                    "existence_echantillons",
                    "milieux",
                    "thematique_1",
                    "thematique_2",
                    "thematique_3",
                    "thematique_4",
                    "thematique_5",
                    "thematique_6",
                    "thematique_7",
                    "thematique_8",
                    "thematique_9",
                    "thematique_10",
                    "todel1",
                    "todel2",
                    "todel3",
                    "date_saisie",
                    "todel4",
                    "todel5",
                    "todel6")

df_projets <- df_projets %>%
  left_join(thematiques, by = c("thematique_1"="sous_thematique")) %>%
  rename(grandethematique_1 = thematique) %>%
  left_join(thematiques, by = c("thematique_2"="sous_thematique")) %>%
  rename(grandethematique_2 = thematique) %>%
  left_join(thematiques, by = c("thematique_3"="sous_thematique")) %>%
  rename(grandethematique_3 = thematique) %>%
  left_join(thematiques, by = c("thematique_4"="sous_thematique")) %>%
  rename(grandethematique_4 = thematique) %>%
  left_join(thematiques, by = c("thematique_5"="sous_thematique")) %>%
  rename(grandethematique_5 = thematique) %>%
  left_join(thematiques, by = c("thematique_6"="sous_thematique")) %>%
  rename(grandethematique_6 = thematique) %>%
  left_join(thematiques, by = c("thematique_7"="sous_thematique")) %>%
  rename(grandethematique_7 = thematique) %>%
  left_join(thematiques, by = c("thematique_8"="sous_thematique")) %>%
  rename(grandethematique_8 = thematique) %>%
  left_join(thematiques, by = c("thematique_9"="sous_thematique")) %>%
  rename(grandethematique_9 = thematique) %>%
  left_join(thematiques, by = c("thematique_10"="sous_thematique")) %>%
  rename(grandethematique_10 = thematique) %>%
  mutate(porteurs_partenaires = pmap_chr(across(starts_with("porteur_partenaire_")), ~ paste(na.omit(c(...)), collapse = ";"))) %>%
  mutate(liens_rapport_scientifique = pmap_chr(across(starts_with("lien_rapport_scientifique_")), ~ paste(na.omit(c(...)), collapse = ";"))) %>%
  mutate(donnees = pmap_chr(across(starts_with("donnee_")), ~ paste(na.omit(c(...)), collapse = ";"))) %>%
  mutate(sous_thematiques = pmap_chr(across(starts_with("thematique_")), ~ paste(na.omit(c(...)), collapse = ";"))) %>%
  mutate(thematiques = pmap_chr(across(starts_with("grandethematique_")), ~ paste(na.omit(unique(c(...))), collapse = ";"))) %>%
  mutate(date_debut = as.Date(date_debut, format = '%d-%m-%Y'), date_fin = as.Date(date_fin, format = '%d-%m-%Y')) %>%
  mutate(visualiseur_projet_statut = case_when(grepl("Accepté, financé et en cours",projet_statut) ~ "En cours",
                                               grepl("Au stade d'idée ou en cours de montage",projet_statut) ~ "En montage",
                                               grepl("Fini",projet_statut) ~ "Fini")) %>%
  mutate(visualiseur_annee_debut = as.character(lubridate::year(date_debut)), visualiseur_annee_fin = as.character(lubridate::year(date_fin))) %>%
  select(-contains("todel")) %>%
  select(-contains("porteur_partenaire_")) %>%
  select(-contains("lien_rapport_scientifique_")) %>%
  select(-contains("donnee_")) %>%
  select(-contains("thematique_")) %>%
  select(-contains("grandethematique_"))




## connect geometry
sites <- read.csv("geomees/data/carto_acteurs_projets/projets/sites_geo_wkt.csv", sep = ";")

sites <- sites %>%
  separate_rows(projet_acronyme, sep = "\\|") %>%
  dplyr::select(-wkt_v1)

sites_sf <- st_as_sf(sites, wkt = "wkt", crs = 4326, na.fail = FALSE)

df_projets <- df_projets %>%
  left_join(sites_sf) %>%
  st_as_sf(crs = 4326) %>%
  dplyr::select(-wkt) %>%
  rename(geometry = wkt) %>%
  mutate(visualiseur_aire_zone_etude = as.numeric(st_area(.))) %>%
  arrange(desc(visualiseur_aire_zone_etude))  # pour que ca aparaisse dans le bon ordre en wms

df_projets <- df_projets %>%
  mutate(contact=ifelse(contact_autorisationpartage=="non",NA,contact)) %>%
  dplyr::select(projet_acronyme, projet_intitule, projet_statut, milieux, thematiques, sous_thematiques, descriptif, porteur_etablissement,porteur_umr, porteurs_partenaires, date_debut, date_fin, contact,site_web,publications_scientifiques,saisisseur_sites_etude, existence_echantillons, date_saisie, donnees, visualiseur_sites_etude, visualiseur_projet_statut, visualiseur_annee_debut, visualiseur_annee_fin, visualiseur_aire_zone_etude)


## push in DB
con <- dbConnect(
  RPostgres::Postgres(),
  host = "postgresql-taconet.alwaysdata.net",
  dbname = "taconet_albopictus",
  port = 5432,
  user = "taconet",
  password = "HHKcue51"
)

########################################################
## A SUPPRIMER APRES 19 JUIN 2026
df_projets <- df_projets %>%
  mutate(site_web = case_when(projet_acronyme == "BEHAVE-WILD" ~ "https://nextcloud.inrae.fr/s/z9NDYyorrzEMbKo",
                               projet_acronyme == "Arbocc" ~ "https://nextcloud.inrae.fr/s/J6HorX3erJM5oG2",
                               projet_acronyme == "LeptoNex" ~ "https://nextcloud.inrae.fr/s/HREpfd8SF8BBaz9",
                               projet_acronyme == "URBIS" ~ "https://nextcloud.inrae.fr/s/fMxjXBQ2QTbi9AA",
                              projet_acronyme == "PMTfocus" ~ "https://nextcloud.inrae.fr/s/FGPdHPr8LYKZkyc",
                              projet_acronyme == "MOUTONS" ~ "https://nextcloud.inrae.fr/s/CQjF8Sbe5jFsiPa",
                              projet_acronyme == "Escoola" ~ "https://nextcloud.inrae.fr/s/9tyq4gBGpb5gwoP",
                              projet_acronyme == "EXPOMITE" ~ "https://nextcloud.inrae.fr/s/oqn9x4yEN8AKQYL",
                              projet_acronyme == "INFERNO" ~ "https://nextcloud.inrae.fr/s/FtbfxBciz5PoXgX",
                              projet_acronyme == "MISARBO" ~ "https://nextcloud.inrae.fr/s/By9TZXwpQckzmBd",
                              projet_acronyme == "RADEMERS" ~ "https://nextcloud.inrae.fr/s/cWznT9pkpyZyfpW",
                              projet_acronyme == "RESTALBOC" ~ "https://nextcloud.inrae.fr/s/cXq2NNmsRc7Gn6c",
                              projet_acronyme == "Smartbo" ~ "https://nextcloud.inrae.fr/s/MWbTKzy7DZo7AzS",
                              projet_acronyme == "TtA OH" ~ "https://nextcloud.inrae.fr/s/HZFrWj367fHLtD4",
                              projet_acronyme == "URBIS" ~ "https://nextcloud.inrae.fr/s/r5g9QTNaTsny9Ay",
                              projet_acronyme == "VECGETO" ~ "https://nextcloud.inrae.fr/s/zPj5NrmNXZXPeKF",
                              projet_acronyme == "MALBOPICTIS" ~ "https://nextcloud.inrae.fr/s/PFiTfZQ5sGYr5Ej",
                              projet_acronyme == "DysUrban" ~ "https://nextcloud.inrae.fr/s/iXi5cboxmfkt974",
                               TRUE ~ site_web))
##########
## Milieux
###########
reclasser_milieux <- function(x) {
  grands <- c()

  if (str_detect(x, "Eaux|Eau de mer|Eau du robinet|Sédiments")) {
    grands <- c(grands, "Milieux aquatiques")
  }

  if (str_detect(x, "Sols|Occupation du sol|Usage du sol")) {
    grands <- c(grands, "Milieux terrestres et territoires")
  }

  if (str_detect(x, "Air extérieur|Air intérieur|Environnement sonore")) {
    grands <- c(grands, "Milieux atmosphériques et physiques")
  }

  if (str_detect(x, "Faune|Flore|Réservoir biologique|Aliments|Autre")) {
    grands <- c(grands, "Biodiversité et socio-écosystèmes")
  }

  paste(unique(grands), collapse = "; ")
}

df_projets <- df_projets %>%
  mutate(grands_milieux = map_chr(milieux, reclasser_milieux)) %>%
  rename(saisisseur_milieux = milieux, milieux = grands_milieux)

##############
## Thématiques
##################
reclasser_thematiques <- function(x) {

  if (is.na(x) || x == "") return(NA_character_)

  grands <- c()

  # 1. Santé globale / One Health
  if (str_detect(x,
                 "SantéS|Maladies zoonotiques|Maladies vectorielles|Surveillance One Health")) {
    grands <- c(grands, "Santé globale / One Health")
  }

  # 2. Biodiversité et écologie
  if (str_detect(x,
                 "Biodiversité|Espèces exotiques envahissantes|Nature en ville|Santé des plantes")) {
    grands <- c(grands, "Biodiversité et écologie")
  }

  # 3. Surveillance, politiques publiques et gestion des risques
  if (str_detect(x,
                 "Surveillance environnementale et politiques publiques|Evaluation, modélisation et gestion des risques")) {
    grands <- c(grands, "Surveillance, politiques et risques")
  }

  # 4. Transitions, pratiques et systèmes alimentaires
  if (str_detect(x,
                 "Changement de pratiques et transitions|Agroécologie et alimentation")) {
    grands <- c(grands, "Transitions et systèmes alimentaires")
  }

  # 5. Climat et changements environnementaux
  if (str_detect(x, "Climat")) {
    grands <- c(grands, "Climat et changements environnementaux")
  }

  paste(unique(grands), collapse = "; ")
}

df_projets <- df_projets %>%
  mutate(grandes_thematiques = map_chr(thematiques, reclasser_thematiques)) %>%
  rename(saisisseur_thematiques = thematiques, thematiques = grandes_thematiques)

df_projets <- df_projets %>%
  relocate(milieux, .after = saisisseur_milieux) %>%
  relocate(thematiques, .after = saisisseur_thematiques)
########################################################



st_write(df_projets, dsn = con, layer = "projets_omees",append = FALSE)



###### acteurs

library(readxl)

fichiers <- list.files("data/carto_acteurs_projets/acteurs/RNSR", full.names = T, pattern = "RNSR")
df_projets <- purrr::map_dfr(fichiers, ~read_xlsx(.))
colnames(df_projets) <- c("type_structure","numero_national","libelle_structure","sigle_structure", "annee_fermeture","lien_etablissement","adresse","mail","domaines_scientifiques","discipline","responsable")

df_projets <- df_projets %>%
  distinct() %>%
  filter(str_detect(adresse, "34[0-9]{3}")) %>%
  mutate(latitude = NA, longitude = NA) %>%
  mutate(adresse_geocodage = tolower(adresse)) %>%
  mutate(adresse_geocodage = str_extract(adresse, "(?i)(rue|place|chemin|avenue|boulevard|route|baillarguet|bd|av)\\s+.*"))


df_acteurs <- read.csv("geomees/data/carto_acteurs_projets/acteurs/acteurs_avec_adresse_propre.csv", sep =",")

for(i in 1:nrow(df_acteurs)){

  cat(i)
  res <- jsonlite::fromJSON(URLencode(paste0("https://data.geopf.fr/geocodage/search?q=",df_acteurs$adresse_geocodage[i])))
  res <- res$features$properties

  res <- res %>% arrange(desc(score)) %>% slice(1)

  if (nrow(res) == 1) {
    df_acteurs$latitude[i] <- res$y
    df_acteurs$longitude[i] <- res$x
    df_acteurs$geocodage_adresse[i] <- res$label

  }

}

df_acteurs$domaines_scientifiques = gsub("\\s{2,}", "; ", df_acteurs$domaines_scientifiques)
df_acteurs$domaines_scientifiques =  gsub("\\d+-", "", df_acteurs$domaines_scientifiques)
df_acteurs$tutelles_carto =  gsub("\\d+-", "", df_acteurs$domaines_scientifiques)

df_acteurs$X = NULL
df_acteurs$geocodage_adresse = NULL
df_acteurs$adresse_geocodage = NULL

df_acteurs <- df_acteurs %>%
  mutate(latitude = ifelse(sigle_structure %in% c("CBGP","ASTRE","PHIM"), 6287594, latitude)) %>%
  mutate(longitude = ifelse(sigle_structure %in% c("CBGP","ASTRE","PHIM"), 770714 , longitude)) %>%
  mutate(site_web = "www.mivegec.fr")  # a corriger

write.csv(df_acteurs,"geomees/data/carto_acteurs_projets/acteurs/acteurs_post_geocodage.csv", row.names = F, sep = ";")




df_acteurs = read.csv("geomees/data/carto_acteurs_projets/acteurs/acteurs_post_geocodage.csv")

df_acteurs <- df_acteurs %>%
  mutate(type_acteur = "Recherche") %>%
  rename(contact = mail, tutelles = lien_etablissement) %>%
  dplyr::select(sigle_structure,libelle_structure,type_acteur,type_structure,tutelles,domaines_scientifiques, site_web, adresse,contact,responsable, latitude,longitude )


## push in DB
con <- dbConnect(
  RPostgres::Postgres(),
  host = "postgresql-taconet.alwaysdata.net",
  dbname = "taconet_albopictus",
  port = 5432,
  user = "taconet",
  password = "HHKcue51"
)

df_acteurs <- st_as_sf(df_acteurs, coords = c("longitude", "latitude"), crs = 2154, na.fail = FALSE)

st_write(df_acteurs, dsn = con, layer = "acteurs_omees",append = FALSE)
