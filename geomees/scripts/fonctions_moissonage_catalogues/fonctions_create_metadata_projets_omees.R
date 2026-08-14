library(geometa)
library(sf)
library(stringr)
library(XML)


# ============================================================
# Fonctions utilitaires
# ============================================================

is_empty <- function(x) {

  is.null(x) ||
    length(x) == 0 ||
    all(is.na(x)) ||
    all(trimws(as.character(x)) %in% c("", "NA", "- - -"))
}


split_values <- function(x, sep = ";") {

  if (is_empty(x))
    return(character(0))

  x |>
    as.character() |>
    str_split(sep) |>
    unlist() |>
    trimws() |>
    (\(x) x[!x %in% c("", "NA", "- - -")])() |>
    unique()
}


clean_id <- function(x) {

  x |>
    iconv(to = "ASCII//TRANSLIT") |>
    tolower() |>
    str_replace_all("[^a-z0-9]+", "-") |>
    str_replace_all("(^-+|-+$)", "")
}


# ============================================================
# Mapping automatique vers MD_TopicCategoryCode
# ============================================================

get_topic_categories <- function(row) {

  txt <- paste(
    c(
      row$milieux,
      row$thematiques,
      row$sous_thematiques
    ),
    collapse = " "
  ) |>
    tolower()

  topics <- character(0)


  # Environnement
  if (
    str_detect(
      txt,
      "environnement|pollution|expos|air|eau|sol|climat"
    )
  ) {
    topics <- c(topics, "environment")
  }


  # Santé
  if (
    str_detect(
      txt,
      "santé|epid|épid|maladie|infect|pathog|parasite|virus"
    )
  ) {
    topics <- c(topics, "health")
  }


  # Biodiversité
  if (
    str_detect(
      txt,
      "biodivers|écolog|ecolog|faune|flore|espèce|espece"
    )
  ) {
    topics <- c(topics, "biota")
  }


  # Climat
  if (
    str_detect(
      txt,
      "climat|météo|meteo|atmosph"
    )
  ) {
    topics <- c(topics, "climatologyMeteorologyAtmosphere")
  }


  # Eaux
  if (
    str_detect(
      txt,
      "eau|aquatique|hydro"
    )
  ) {
    topics <- c(topics, "inlandWaters")
  }


  # Société
  if (
    str_detect(
      txt,
      "sociolog|social|politique|gouvernance|comportement"
    )
  ) {
    topics <- c(topics, "society")
  }


  # Valeur par défaut
  if (length(topics) == 0) {
    topics <- "environment"
  }


  unique(topics)
}


# ============================================================
# Fonction principale
# ============================================================

project_omees_create_iso19115 <- function(row) {


  # ==========================================================
  # 1. IDENTIFIANT
  # ==========================================================

  identifier <- paste0(
    "omees-project-",
    clean_id(row$projet_acronyme)
  )


  # ==========================================================
  # 2. METADATA
  # ==========================================================

  md <- ISOMetadata$new()

  md$setFileIdentifier(identifier)

  md$setLanguage("fre")
  md$setCharacterSet("utf8")

  md$setDateStamp(Sys.Date())

  md$setMetadataStandardName(
    "ISO 19115:2003/19139"
  )

  md$setMetadataStandardVersion(
    "1.0"
  )


  # ==========================================================
  # 3. CONTACT DE LA FICHE DE METADONNEES
  # ==========================================================
  #
  # À adapter selon l'organisation qui publie les fiches.
  # Ici je mets OMEES, indépendamment du porteur scientifique
  # du projet.
  # ==========================================================

  metadata_contact <- ISOResponsibleParty$new()

  metadata_contact$setOrganisationName(
    "Observatoire Montpelliérain de l'Environnement et de la Santé"
  )

  metadata_contact$setRole(
    "pointOfContact"
  )

  md$addContact(
    metadata_contact
  )


  # ==========================================================
  # 4. CITATION DU PROJET
  # ==========================================================

  citation <- ISOCitation$new()

  citation$setTitle(
    paste0("Projet ",row$projet_acronyme," : ",row$projet_intitule)
  )


  # Acronyme
  if (!is_empty(row$projet_acronyme)) {

    citation$addAlternateTitle(
      row$projet_acronyme
    )
  }


  # Date de début du projet
  if (!is_empty(row$date_debut)) {

    citation$addDate(
      ISODate$new(
        date = as.Date(row$date_debut),
        dateType = "creation"
      )
    )
  }


  # ==========================================================
  # 5. IDENTIFICATION
  # ==========================================================

  identification <- ISODataIdentification$new()

  identification$setCitation(
    citation
  )

  identification$setAbstract(
    row$descriptif
  )

  identification$setLanguage(
    "fre"
  )

  identification$setCharacterSet(
    "utf8"
  )


  # ==========================================================
  # 6. TOPIC CATEGORIES
  # ==========================================================

  topics <- get_topic_categories(row)

  for (topic in topics) {

    identification$addTopicCategory(
      topic
    )
  }


  # ==========================================================
  # 7. MOTS-CLES : THEMATIQUES
  # ==========================================================

  theme_keywords <- unique(
    c(
      split_values(row$thematiques),
      split_values(row$sous_thematiques)
    )
  )


  if (length(theme_keywords) > 0) {

    keywords <- ISOKeywords$new()

    keywords$addKeyword("omees")

    for (keyword in theme_keywords) {
      keywords$addKeyword(keyword)
    }

    keywords$setKeywordType("theme")

    identification$addKeywords(keywords)
  }



  # ==========================================================
  # 8. MOTS-CLES : MILIEUX
  # ==========================================================

  milieu_keywords <- unique(
    c(
      split_values(row$milieux),
      split_values(row$saisisseur_milieux)
    )
  )


  if (length(milieu_keywords) > 0) {

    keywords <- ISOKeywords$new()

    for (keyword in milieu_keywords) {

      keywords$addKeyword(
        keyword
      )
    }

    keywords$setKeywordType(
      "place"
    )

    identification$addKeywords(
      keywords
    )
  }


  # ==========================================================
  # 9. PORTEUR DU PROJET
  # ==========================================================

  if (
    !is_empty(row$porteur_etablissement) ||
    !is_empty(row$porteur_umr) ||
    !is_empty(row$contact)
  ) {

    poc <- ISOResponsibleParty$new()

    # Organisation
    organisation <- c(
      row$porteur_etablissement,
      row$porteur_umr
    )

    organisation <- organisation[
      !is.na(organisation) &
        organisation != "" &
        organisation != "- - -"
    ]

    if (length(organisation) > 0) {

      poc$setOrganisationName(
        paste(
          organisation,
          collapse = " - "
        )
      )
    }

    # Rôle
    poc$setRole(
      "principalInvestigator"
    )

    # Email
    if (!is_empty(row$contact)) {

      contact_info <- ISOContact$new()

      address <- ISOAddress$new()

      address$setEmail(
        row$contact
      )

      contact_info$setAddress(
        address
      )

      poc$setContactInfo(
        contact_info
      )
    }

    identification$addPointOfContact(
      poc
    )
  }

  # ==========================================================
  # 10. PARTENAIRES
  # ==========================================================

  partners <- split_values(
    row$porteurs_partenaires
  )


  for (partner in partners) {

    rp <- ISOResponsibleParty$new()

    rp$setOrganisationName(
      partner
    )

    rp$setRole(
      "collaborator"
    )

    identification$addPointOfContact(
      rp
    )
  }


  # ==========================================================
  # 11. ETENDUE TEMPORELLE
  # ==========================================================

  if (!is_empty(row$date_debut)) {

    extent_temporal <- ISOExtent$new()

    begin <- as.POSIXct(
      as.Date(row$date_debut),
      tz = "UTC"
    )

    if (!is_empty(row$date_fin)) {

      end <- as.POSIXct(
        as.Date(row$date_fin),
        tz = "UTC"
      )

    } else {

      end <- begin
    }

    time_period <- GMLTimePeriod$new(
      beginPosition = begin,
      endPosition = end
    )

    temporal <- ISOTemporalExtent$new()

    temporal$setTimePeriod(
      time_period
    )

    extent_temporal$addTemporalElement(
      temporal
    )

    identification$addExtent(
      extent_temporal
    )
  }

  # ==========================================================
  # 12. ETENDUE GEOGRAPHIQUE
  # ==========================================================

  if (inherits(row, "sf")) {

    geom <- sf::st_geometry(row)

    if (
      length(geom) > 0 &&
      !all(sf::st_is_empty(geom))
    ) {

      # Conversion en WGS84 car l'emprise ISO est exprimée
      # en longitude / latitude
      geom <- sf::st_transform(
        geom,
        4326
      )

      bbox <- sf::st_bbox(
        geom
      )

      geographic_bbox <- ISOGeographicBoundingBox$new(
        minx = as.numeric(bbox["xmin"]),
        miny = as.numeric(bbox["ymin"]),
        maxx = as.numeric(bbox["xmax"]),
        maxy = as.numeric(bbox["ymax"])
      )

      extent_spatial <- ISOExtent$new()

      extent_spatial$addGeographicElement(
        geographic_bbox
      )

      identification$addExtent(
        extent_spatial
      )
    }
  }


  # ==========================================================
  # SITE WEB DU PROJET
  # ==========================================================

  if (!is_empty(row$site_web)) {

    online <- ISOOnlineResource$new()

    online$setLinkage(
      row$site_web
    )

    online$setName(
      "Site web du projet"
    )

    online$setDescription(
      paste0(
        "Site web du projet ",
        row$projet_acronyme
      )
    )

    online$setOnLineFunction(
      "information"
    )


    # Options de transfert
    transfer <- ISODigitalTransferOptions$new()

    transfer$addOnlineResource(
      online
    )


    # Distribution
    distribution <- ISODistribution$new()

    distribution$addDigitalTransferOptions(
      transfer
    )


    # Ajout à la métadonnée
    md$setDistributionInfo(
      distribution
    )
  }
  # ==========================================================
  # 14. INFORMATIONS SUPPLEMENTAIRES
  # ==========================================================

  supplemental <- character(0)


  # statut
  if (!is_empty(row$projet_statut)) {

    supplemental <- c(
      supplemental,
      paste0(
        "Statut du projet : ",
        row$projet_statut
      )
    )
  }


  # données
  if (!is_empty(row$donnees)) {

    supplemental <- c(
      supplemental,
      paste0(
        "Données disponibles : ",
        row$donnees
      )
    )
  }


  # échantillons
  if (!is_empty(row$existence_echantillons)) {

    supplemental <- c(
      supplemental,
      paste0(
        "Échantillons disponibles : ",
        row$existence_echantillons
      )
    )
  }


  # zone d'étude
  if (!is_empty(row$saisisseur_sites_etude)) {

    supplemental <- c(
      supplemental,
      paste0(
        "Zone d'étude : ",
        row$saisisseur_sites_etude
      )
    )
  }


  # publications
  if (!is_empty(row$publications_scientifiques)) {

    supplemental <- c(
      supplemental,
      paste0(
        "Publications scientifiques : ",
        row$publications_scientifiques
      )
    )
  }


  if (length(supplemental) > 0) {

    identification$setSupplementalInformation(
      paste(
        supplemental,
        collapse = "\n\n"
      )
    )
  }


  # ==========================================================
  # 15. AJOUT IDENTIFICATION
  # ==========================================================

  md$setIdentificationInfo(
    identification
  )


  # ==========================================================
  # 16. RETOUR
  # ==========================================================

  return(md)
}



