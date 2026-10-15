

dataverse_create_iso19115 <- function(
    identifier,
    catalogue_url = NULL,
    default_language = "fre",
    additional_online_resources = NULL
) {


  stopifnot(requireNamespace("geometa", quietly = TRUE))
  geometa::setMetadataStandard("19139")


  # Classes geometa
  ISOMetadata                  <- geometa::ISOMetadata
  ISODataIdentification        <- geometa::ISODataIdentification
  ISOCitation                  <- geometa::ISOCitation
  ISODate                      <- geometa::ISODate
  ISOResponsibleParty          <- geometa::ISOResponsibleParty
  ISOContact                   <- geometa::ISOContact
  ISOAddress                   <- geometa::ISOAddress
  ISOOnlineResource            <- geometa::ISOOnlineResource
  ISOKeywords                  <- geometa::ISOKeywords
  ISOExtent                    <- geometa::ISOExtent
  ISOGeographicBoundingBox     <- geometa::ISOGeographicBoundingBox
  ISOLegalConstraints          <- geometa::ISOLegalConstraints
  ISODistribution              <- geometa::ISODistribution
  ISODigitalTransferOptions    <- geometa::ISODigitalTransferOptions
  ISOMetaIdentifier            <- geometa::ISOMetaIdentifier
  ISOReferenceSystem           <- geometa::ISOReferenceSystem
  ISOReferenceIdentifier       <- geometa::ISOReferenceIdentifier
  ISOBrowseGraphic             <- geometa::ISOBrowseGraphic
  ISODataQuality               <- geometa::ISODataQuality
  ISODataQualityScope          <- geometa::ISODataQualityScope
  ISOLineage                   <- geometa::ISOLineage

  # ---------------------------------------------------------------------------
  # Fonctions utilitaires
  # ---------------------------------------------------------------------------

  `%||%` <- function(x, y) {
    if (is.null(x)  || all(is.na(x))) y else x
  }

  first_non_empty <- function(x, default = NULL) {
    if (is.null(x)) {
      return(default)
    }

    x <- unlist(x, recursive = TRUE, use.names = FALSE)
    x <- x[!is.na(x)]
    x <- trimws(as.character(x))
    x <- x[nzchar(x)]

    if (length(x) == 0L) default else x[[1]]
  }

  clean_text <- function(x) {
    x <- first_non_empty(x)

    if (is.null(x)) {
      return(NULL)
    }

    if (requireNamespace("textutils", quietly = TRUE)) {
      x <- textutils::HTMLdecode(x)
    }

    # Suppression simple des balises HTML de Dataverse
    x <- gsub("<br\\s*/?>", "\n", x, ignore.case = TRUE)
    x <- gsub("</p\\s*>", "\n\n", x, ignore.case = TRUE)
    x <- gsub("</li\\s*>", "\n", x, ignore.case = TRUE)
    x <- gsub("<[^>]+>", "", x)

    # Nettoyage des espaces sans supprimer les paragraphes
    x <- gsub("[ \t]+", " ", x)
    x <- gsub(" *\n *", "\n", x)
    x <- gsub("\n{3,}", "\n\n", x)

    trimws(x)
  }

  safe_date <- function(x) {
    x <- first_non_empty(x)

    if (is.null(x)) {
      return(NULL)
    }

    # Gère les dates ISO complètes et les dates YYYY-MM-DD
    out <- suppressWarnings(as.POSIXct(
      x,
      tz = "UTC",
      tryFormats = c(
        "%Y-%m-%dT%H:%M:%OSZ",
        "%Y-%m-%dT%H:%M:%S%z",
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%d"
      )
    ))

    if (is.na(out)) {
      return(NULL)
    }

    out
  }

  safe_filename <- function(x) {
    x <- first_non_empty(x, "dataverse_metadata")
    x <- gsub("^doi:", "", x, ignore.case = TRUE)
    x <- gsub("[^A-Za-z0-9._-]+", "_", x)
    x
  }

  get_named_element <- function(x, name) {
    if (is.null(x)) {
      return(NULL)
    }

    if (is.list(x) && !is.null(names(x)) && name %in% names(x)) {
      return(x[[name]])
    }

    NULL
  }

  # Extrait un champ d'un metadata block Dataverse.
  # Fonctionne avec :
  # - une liste nommée ;
  # - un data.frame contenant typeName et value ;
  # - une liste de champs contenant chacun typeName et value.
  get_dv_field <- function(block, field_name) {

    if (is.null(block)) {
      return(NULL)
    }

    direct <- get_named_element(block, field_name)
    if (!is.null(direct)) {
      if (is.list(direct) && !is.null(direct$value)) {
        return(direct$value)
      }
      return(direct)
    }

    if (is.data.frame(block) &&
        all(c("typeName", "value") %in% names(block))) {

      idx <- which(as.character(block$typeName) == field_name)

      if (length(idx) > 0L) {
        return(block$value[[idx[[1]]]])
      }
    }

    if (is.list(block)) {
      for (element in block) {

        if (is.list(element) &&
            !is.null(element$typeName) &&
            identical(as.character(element$typeName[[1]]), field_name)) {

          return(element$value)
        }

        found <- get_dv_field(element, field_name)

        if (!is.null(found)) {
          return(found)
        }
      }
    }

    NULL
  }

  as_rows <- function(x) {

    if (is.null(x)) {
      return(list())
    }

    if (is.data.frame(x)) {
      return(lapply(seq_len(nrow(x)), function(i) {
        as.list(x[i, , drop = FALSE])
      }))
    }

    # Certains champs composés sont encapsulés dans $value
    if (is.list(x) && !is.null(x$value)) {
      return(as_rows(x$value))
    }

    if (is.list(x)) {
      # Une liste nommée représentant directement un enregistrement
      if (!is.null(names(x)) &&
          any(nzchar(names(x))) &&
          !all(vapply(x, is.list, logical(1)))) {
        return(list(x))
      }

      return(x)
    }

    list(x)
  }

  get_row_value <- function(row, field_name) {

    if (is.null(row)) {
      return(NULL)
    }

    if (is.data.frame(row) && field_name %in% names(row)) {
      return(row[[field_name]])
    }

    if (is.list(row) && field_name %in% names(row)) {
      value <- row[[field_name]]

      if (is.list(value) && !is.null(value$value)) {
        return(value$value)
      }

      return(value)
    }

    get_dv_field(row, field_name)
  }

  get_metadata_blocks <- function(meta) {

    version <- meta$datasetVersion %||%
      meta$data$latestVersion %||%
      meta$latestVersion

    blocks <- version$metadataBlocks %||%
      meta$metadataBlocks

    list(
      version = version,
      blocks = blocks,
      citation = blocks$citation$fields %||%
        blocks$citation,
      geospatial = blocks$geospatial$fields %||%
        blocks$geospatial
    )
  }

  make_responsible_party <- function(
    name = NULL,
    organisation = NULL,
    email = NULL,
    role = "pointOfContact",
    identifier = NULL,
    identifier_scheme = NULL,
    online_url = NULL
  ) {

    if (is.null(name) &&
        is.null(organisation) &&
        is.null(email)) {
      return(NULL)
    }

    rp <- ISOResponsibleParty$new()

    if (!is.null(name)) {
      rp$setIndividualName(clean_text(name))
    }

    if (!is.null(organisation)) {
      rp$setOrganisationName(clean_text(organisation))
    }

    rp$setRole(role)

    contact <- ISOContact$new()
    address <- ISOAddress$new()

    if (!is.null(email)) {
      address$setEmail(first_non_empty(email))
    }

    contact$setAddress(address)

    if (!is.null(online_url)) {
      online <- ISOOnlineResource$new()
      online$setLinkage(online_url)
      online$setName("Page institutionnelle ou page du catalogue")
      online$setProtocol("WWW:LINK-1.0-http--link")
      contact$setOnlineResource(online)
    }

    rp$setContactInfo(contact)

    # L'ORCID ne dispose pas toujours d'un emplacement simple dans
    # ISOResponsibleParty 19139. Il sera également conservé dans la citation
    # ou les informations supplémentaires.
    if (!is.null(identifier) && !is.null(identifier_scheme)) {
      message(
        identifier_scheme,
        " associé à ",
        name %||% organisation,
        " : ",
        identifier
      )
    }

    rp
  }

  language_to_iso3 <- function(x) {

    x <- tolower(first_non_empty(x, default_language))

    dictionary <- c(
      "french" = "fre",
      "français" = "fre",
      "francais" = "fre",
      "fr" = "fre",
      "fre" = "fre",
      "english" = "eng",
      "anglais" = "eng",
      "en" = "eng",
      "eng" = "eng",
      "spanish" = "spa",
      "es" = "spa",
      "spa" = "spa"
    )

    dictionary[[x]] %||% default_language
  }

  subject_to_iso_topic <- function(subject) {

    subject <- tolower(subject)

    mapping <- c(
      "agricultural sciences" = "farming",
      "arts and humanities" = "society",
      "astronomy and astrophysics" = "climatologyMeteorologyAtmosphere",
      "business and management" = "economy",
      "chemistry" = "environment",
      "computer and information science" = "utilitiesCommunication",
      "earth and environmental sciences" = "environment",
      "engineering" = "structure",
      "law" = "society",
      "mathematical sciences" = "location",
      "medicine, health and life sciences" = "health",
      "physics" = "environment",
      "social sciences" = "society"
    )

    unname(mapping[subject])
  }

  mime_to_protocol <- function(content_type, filename = NULL) {

    content_type <- tolower(first_non_empty(content_type, ""))
    extension <- tolower(tools::file_ext(first_non_empty(filename, "")))

    if (content_type == "application/pdf") {
      return("WWW:DOWNLOAD-1.0-http--download")
    }

    if (extension %in% c("gpkg", "shp", "geojson", "tif", "tiff", "csv", "zip")) {
      return("WWW:DOWNLOAD-1.0-http--download")
    }

    "WWW:LINK-1.0-http--link"
  }

  # ---------------------------------------------------------------------------
  # Extraction des blocs Dataverse
  # ---------------------------------------------------------------------------

  url <- paste0(catalogue_url,"api/datasets/export?exporter=dataverse_json&persistentId=doi%3A",identifier)

  meta_dataverse = jsonlite::fromJSON(url)

  dv <- get_metadata_blocks(meta_dataverse)

  version <- dv$version
  citation_block <- dv$citation
  geospatial_block <- dv$geospatial

  identifier <- first_non_empty(
    meta_dataverse$datasetPersistentId %||%
      meta_dataverse$persistentId %||%
      meta_dataverse$identifier %||%
      version$datasetPersistentId
  )

  identifier_code <- first_non_empty(
    meta_dataverse$identifier,
    identifier
  )

  persistent_url <- first_non_empty(
    meta_dataverse$persistentUrl %||%
      meta_dataverse$pidURL
  )

  if (is.null(persistent_url) &&
      !is.null(identifier) &&
      grepl("^doi:", identifier, ignore.case = TRUE)) {
    persistent_url <- paste0(
      "https://doi.org/",
      sub("^doi:", "", identifier, ignore.case = TRUE)
    )
  }

  title <- clean_text(get_dv_field(citation_block, "title"))

  description_rows <- as_rows(
    get_dv_field(citation_block, "dsDescription")
  )

  abstracts <- vapply(
    description_rows,
    function(x) {
      clean_text(get_row_value(x, "dsDescriptionValue"))
    },
    character(1)
  )

  abstracts <- abstracts[nzchar(abstracts)]
  abstract <- paste(unique(abstracts), collapse = "\n\n")

  description_languages <- vapply(
    description_rows,
    function(x) {
      first_non_empty(
        get_row_value(x, "dsDescriptionLanguage"),
        default_language
      )
    },
    character(1)
  )

  metadata_language <- language_to_iso3(
    first_non_empty(
      meta_dataverse$metadataLanguage,
      first_non_empty(description_languages, default_language)
    )
  )

  # ---------------------------------------------------------------------------
  # Métadonnée racine
  # ---------------------------------------------------------------------------

  md <- ISOMetadata$new()

  md$setFileIdentifier(identifier %||% identifier_code)
  md$setCharacterSet("utf8")
  md$setLanguage(metadata_language)
  md$setDateStamp(Sys.time())
  md$setMetadataStandardName("ISO 19115:2003/19139")
  md$setMetadataStandardVersion("1.0")
  #md$setHierarchyLevel("dataset")
  md$addHierarchyLevel("dataset")

  if (!is.null(persistent_url)) {
    md$setDataSetURI(persistent_url)
  }

  # ---------------------------------------------------------------------------
  # Contact de la métadonnée
  # ---------------------------------------------------------------------------

  contact_rows <- as_rows(
    get_dv_field(citation_block, "datasetContact")
  )

  for (contact_row in contact_rows) {

    rp <- make_responsible_party(
      name = get_row_value(contact_row, "datasetContactName"),
      organisation = get_row_value(
        contact_row,
        "datasetContactAffiliation"
      ),
      email = get_row_value(contact_row, "datasetContactEmail"),
      role = "pointOfContact",
      online_url = catalogue_url
    )

    if (!is.null(rp)) {
      md$addContact(rp)
    }
  }

  # Contact de repli, utile si datasetContact est absent
  if (length(contact_rows) == 0L && !is.null(metadata_contact)) {

    rp <- make_responsible_party(
      name = metadata_contact$name,
      organisation = metadata_contact$organisation,
      email = metadata_contact$email,
      role = metadata_contact$role %||% "pointOfContact",
      online_url = metadata_contact$url %||% catalogue_url
    )

    if (!is.null(rp)) {
      md$addContact(rp)
    }
  }

  # ---------------------------------------------------------------------------
  # Identification de la ressource
  # ---------------------------------------------------------------------------

  ident <- ISODataIdentification$new()

  ident$setAbstract(abstract)

  ident$addStatus(
    if (identical(version$versionState, "RELEASED")) {
      "completed"
    } else {
      "onGoing"
    }
  )

  ident$addLanguage(metadata_language)
  ident$addCharacterSet("utf8")


  # ---------------------------------------------------------------------------
  # Citation
  # ---------------------------------------------------------------------------

  ct <- ISOCitation$new()
  ct$setTitle(paste0(title %||% identifier))

  production_date <- safe_date(
    get_dv_field(citation_block, "productionDate")
  )

  publication_date <- safe_date(
    version$publicationDate %||%
      meta_dataverse$publicationDate %||%
      version$releaseTime
  )

  revision_date <- safe_date(
    version$lastUpdateTime
  )

  creation_date <- safe_date(
    version$createTime %||%
      get_dv_field(citation_block, "dateOfDeposit")
  )

  if (!is.null(production_date)) {
    d <- ISODate$new()
    d$setDate(production_date)
    d$setDateType("creation")
    ct$addDate(d)
  } else if (!is.null(creation_date)) {
    d <- ISODate$new()
    d$setDate(creation_date)
    d$setDateType("creation")
    ct$addDate(d)
  }

  if (!is.null(publication_date)) {
    d <- ISODate$new()
    d$setDate(publication_date)
    d$setDateType("publication")
    ct$addDate(d)
  }

  if (!is.null(revision_date)) {
    d <- ISODate$new()
    d$setDate(revision_date)
    d$setDateType("revision")
    ct$addDate(d)
  }

  if (!is.null(identifier)) {
    ct$addIdentifier(
      ISOMetaIdentifier$new(code = identifier)
    )
  }

  version_number <- first_non_empty(
    paste0(
      version$versionNumber %||% "",
      if (!is.null(version$versionMinorNumber)) {
        paste0(".", version$versionMinorNumber)
      } else {
        ""
      }
    )
  )

  if (!is.null(version_number)) {
    ct$setEdition(version_number)
  }

  # ---------------------------------------------------------------------------
  # Auteurs
  # ---------------------------------------------------------------------------

  author_rows <- as_rows(
    get_dv_field(citation_block, "author")
  )

  author_orcid_notes <- character()

  for (author_row in author_rows) {

    author_name <- first_non_empty(
      get_row_value(author_row, "authorName")
    )

    author_affiliation <- first_non_empty(
      get_row_value(author_row, "authorAffiliation")
    )

    author_identifier_scheme <- first_non_empty(
      get_row_value(author_row, "authorIdentifierScheme")
    )

    author_identifier <- first_non_empty(
      get_row_value(author_row, "authorIdentifier")
    )

    rp <- make_responsible_party(
      name = author_name,
      organisation = author_affiliation,
      role = "author",
      identifier = author_identifier,
      identifier_scheme = author_identifier_scheme
    )

    if (!is.null(rp)) {
      ct$addCitedResponsibleParty(rp)
    }

    if (!is.null(author_identifier)) {
      author_orcid_notes <- c(
        author_orcid_notes,
        paste0(
          author_name,
          " — ",
          author_identifier_scheme %||% "identifiant",
          ": ",
          author_identifier
        )
      )
    }
  }

  ident$setCitation(ct)


  # ---------------------------------------------------------------------------
  # Mots-clés libres et mots-clés de thésaurus
  # ---------------------------------------------------------------------------

  keyword_rows <- as_rows(
    get_dv_field(citation_block, "keyword")
  )

  # On crée un objet ISOKeywords par vocabulaire afin de conserver
  # les informations de thésaurus.
  keyword_groups <- list()

  for (keyword_row in keyword_rows) {

    keyword_value <- clean_text(
      get_row_value(keyword_row, "keywordValue")
    )

    keyword_url <- first_non_empty(
      get_row_value(keyword_row, "keywordTermURL")
    )

    vocabulary_name <- first_non_empty(
      get_row_value(keyword_row, "keywordVocabulary"),
      "Mots-clés libres"
    )

    vocabulary_uri <- first_non_empty(
      get_row_value(keyword_row, "keywordVocabularyURI")
    )

    group_key <- paste(
      vocabulary_name,
      vocabulary_uri %||% "",
      sep = "||"
    )

    if (is.null(keyword_groups[[group_key]])) {
      keyword_groups[[group_key]] <- list(
        name = vocabulary_name,
        uri = vocabulary_uri,
        keywords = character(),
        urls = character()
      )
    }

    if (!is.null(keyword_value)) {
      keyword_groups[[group_key]]$keywords <- c(
        keyword_groups[[group_key]]$keywords,
        keyword_value
      )

      keyword_groups[[group_key]]$urls <- c(
        keyword_groups[[group_key]]$urls,
        keyword_url %||% ""
      )
    }
  }

  for (group in keyword_groups) {

    kwds <- ISOKeywords$new()
    kwds$setKeywordType("theme")

    for (keyword_value in unique(group$keywords)) {
      kwds$addKeyword(keyword_value)
    }

    if (!identical(group$name, "Mots-clés libres")) {

      thesaurus <- ISOCitation$new()
      thesaurus$setTitle(group$name)

      d <- ISODate$new()
      d$setDate(Sys.Date())
      d$setDateType("revision")
      thesaurus$addDate(d)

      if (!is.null(group$uri)) {
        thesaurus$addIdentifier(
          ISOMetaIdentifier$new(code = group$uri)
        )
      }

      kwds$setThesaurusName(thesaurus)
    }

    ident$addKeywords(kwds)
  }

  # Type de données comme mots-clés
  kind_of_data <- unlist(
    get_dv_field(citation_block, "kindOfData"),
    recursive = TRUE,
    use.names = FALSE
  )

  kind_of_data <- unique(
    trimws(as.character(kind_of_data))
  )
  kind_of_data <- kind_of_data[nzchar(kind_of_data)]

  if (length(kind_of_data) > 0L) {
    kwds <- ISOKeywords$new()
    kwds$setKeywordType("theme")

    for (x in kind_of_data) {
      kwds$addKeyword(x)
    }

    ident$addKeywords(kwds)
  }

  # ---------------------------------------------------------------------------
  # Emprise géographique
  # ---------------------------------------------------------------------------

  bbox_rows <- as_rows(
    get_dv_field(geospatial_block, "geographicBoundingBox")
  )

  for (bbox_row in bbox_rows) {

    west <- suppressWarnings(as.numeric(
      first_non_empty(
        get_row_value(bbox_row, "westLongitude")
      )
    ))

    east <- suppressWarnings(as.numeric(
      first_non_empty(
        get_row_value(bbox_row, "eastLongitude")
      )
    ))

    north <- suppressWarnings(as.numeric(
      first_non_empty(
        get_row_value(bbox_row, "northLongitude")
      )
    ))

    south <- suppressWarnings(as.numeric(
      first_non_empty(
        get_row_value(bbox_row, "southLongitude")
      )
    ))

    if (all(is.finite(c(west, east, south, north)))) {

      extent <- ISOExtent$new()

      bbox <- ISOGeographicBoundingBox$new(
        minx = west,
        miny = south,
        maxx = east,
        maxy = north
      )

      extent$addGeographicElement(bbox)
      ident$addExtent(extent)
    }
  }

  # Le bbox Dataverse est exprimé en longitude/latitude
  if (length(bbox_rows) > 0L) {

    rs <- ISOReferenceSystem$new()

    rs_id <- ISOReferenceIdentifier$new(
      code = "4326",
      codeSpace = "EPSG"
    )

    rs$setReferenceSystemIdentifier(rs_id)
    md$addReferenceSystemInfo(rs)
  }

  # Couverture administrative comme mots-clés de lieu
  coverage_rows <- as_rows(
    get_dv_field(geospatial_block, "geographicCoverage")
  )

  place_keywords <- character()

  for (coverage_row in coverage_rows) {
    place_keywords <- c(
      place_keywords,
      first_non_empty(get_row_value(coverage_row, "country")),
      first_non_empty(get_row_value(coverage_row, "state")),
      first_non_empty(get_row_value(coverage_row, "city")),
      first_non_empty(get_row_value(coverage_row, "otherGeographicCoverage"))
    )
  }

  place_keywords <- unique(place_keywords[!is.na(place_keywords)])
  place_keywords <- place_keywords[nzchar(place_keywords)]

  if (length(place_keywords) > 0L) {

    kwds <- ISOKeywords$new()
    kwds$setKeywordType("place")

    for (place in place_keywords) {
      kwds$addKeyword(place)
    }

    ident$addKeywords(kwds)
  }

  # ---------------------------------------------------------------------------
  # Résolution spatiale
  # ---------------------------------------------------------------------------

  spatial_resolution <- clean_text(
    get_dv_field(geospatial_block, "spatialResolution")
  )

  # Dataverse fournit ici une chaîne libre, par exemple "résolution : 25 cm".
  # Elle est donc placée dans supplementalInformation plutôt que convertie
  # arbitrairement en équivalent d'échelle.
  supplemental <- character()

  if (!is.null(spatial_resolution)) {
    supplemental <- c(
      supplemental,
      paste0("Résolution spatiale : ", spatial_resolution)
    )
  }

  # ---------------------------------------------------------------------------
  # Logiciels
  # ---------------------------------------------------------------------------

  software_rows <- as_rows(
    get_dv_field(citation_block, "software")
  )

  software_notes <- character()

  for (software_row in software_rows) {

    software_name <- clean_text(
      get_row_value(software_row, "softwareName")
    )

    software_version <- clean_text(
      get_row_value(software_row, "softwareVersion")
    )

    if (!is.null(software_name)) {
      software_notes <- c(
        software_notes,
        paste0(
          software_name,
          if (!is.null(software_version)) {
            paste0(" ", software_version)
          } else {
            ""
          }
        )
      )
    }
  }

  if (length(software_notes) > 0L) {
    supplemental <- c(
      supplemental,
      paste0(
        "Logiciels utilisés : ",
        paste(unique(software_notes), collapse = ", ")
      )
    )
  }

  if (length(author_orcid_notes) > 0L) {
    supplemental <- c(
      supplemental,
      paste0(
        "Identifiants des auteurs : ",
        paste(author_orcid_notes, collapse = "; ")
      )
    )
  }

  supplemental <- c(
    supplemental,
    "Métadonnée générée automatiquement à partir de l'API Dataverse."
  )

  ident$setSupplementalInformation(
    paste(supplemental, collapse = "\n")
  )

  # ---------------------------------------------------------------------------
  # Type de représentation spatiale
  # ---------------------------------------------------------------------------

  kind_lower <- tolower(paste(kind_of_data, collapse = " "))

  if (grepl("raster|grid|image|geotiff|tiff", kind_lower)) {
    ident$addSpatialRepresentationType("grid")
  }

  if (grepl("vector|vecteur|feature|geopackage|shapefile", kind_lower)) {
    ident$addSpatialRepresentationType("vector")
  }

  # Le jeu observé contient à la fois un GeoPackage et un GeoTIFF.
  # Lorsque le type ne peut pas être déterminé depuis kindOfData,
  # il sera aussi inféré plus bas depuis les fichiers.
  md$addIdentificationInfo(ident)

  # ---------------------------------------------------------------------------
  # Licence et contraintes
  # ---------------------------------------------------------------------------

  licence <- version$license %||%
    meta_dataverse$license

  licence_name <- clean_text(
    licence$name %||%
      licence$displayName
  )

  licence_uri <- first_non_empty(
    licence$uri
  )

  if (!is.null(licence_name) || !is.null(licence_uri)) {

    constraints <- ISOLegalConstraints$new()

    if (!is.null(licence_name)) {
      constraints$addUseLimitation(licence_name)
    }

    if (!is.null(licence_uri)) {
      constraints$addUseLimitation(licence_uri)
    }

    ident$addResourceConstraints(constraints)
  }

  # ---------------------------------------------------------------------------
  # Distribution et fichiers
  # ---------------------------------------------------------------------------

  distribution <- ISODistribution$new()
  transfer_options <- ISODigitalTransferOptions$new()

  files <- version$files %||%
    meta_dataverse$files

  file_rows <- as_rows(files)

  detected_spatial_types <- character()

  for (file_row in file_rows) {

    data_file <- file_row$dataFile %||%
      get_row_value(file_row, "dataFile") %||%
      file_row

    filename <- first_non_empty(
      data_file$filename %||%
        get_row_value(data_file, "filename") %||%
        file_row$label
    )

    content_type <- first_non_empty(
      data_file$contentType %||%
        get_row_value(data_file, "contentType")
    )

    file_description <- clean_text(
      file_row$description %||%
        data_file$description %||%
        get_row_value(file_row, "description")
    )

    file_pid <- first_non_empty(
      data_file$persistentId %||%
        get_row_value(data_file, "persistentId")
    )

    file_url <- first_non_empty(
      data_file$pidURL %||%
        get_row_value(data_file, "pidURL")
    )

    if (is.null(file_url) &&
        !is.null(file_pid) &&
        grepl("^doi:", file_pid, ignore.case = TRUE)) {

      file_url <- paste0(
        "https://doi.org/",
        sub("^doi:", "", file_pid, ignore.case = TRUE)
      )
    }

    # URL API de repli lorsque le DOI du fichier n'est pas disponible
    root_file_id <- first_non_empty(
      data_file$rootDataFileId %||%
        data_file$id %||%
        get_row_value(data_file, "rootDataFileId")
    )

    if (is.null(file_url) && !is.null(root_file_id)) {
      file_url <- paste0(
        "https://data-recherche-gouv.fr/api/access/datafile/",
        root_file_id
      )
    }

    if (!is.null(file_url)) {

      online <- ISOOnlineResource$new()
      online$setLinkage(file_url)

      if (!is.null(filename)) {
        online$setName(filename)
      }

      if (!is.null(file_description)) {
        online$setDescription(file_description)
      } else if (!is.null(content_type)) {
        online$setDescription(content_type)
      }

      online$setProtocol(
        mime_to_protocol(content_type, filename)
      )

      online$setOnLineFunction("download")

      transfer_options$addOnlineResource(online)
    }

    extension <- tolower(tools::file_ext(filename %||% ""))

    if (extension %in% c(
      "gpkg", "shp", "geojson", "gml", "kml"
    )) {
      detected_spatial_types <- c(
        detected_spatial_types,
        "vector"
      )
    }

    if (extension %in% c(
      "tif", "tiff", "nc", "grd"
    )) {
      detected_spatial_types <- c(
        detected_spatial_types,
        "grid"
      )
    }
  }

  # Page principale du dataset
  if (!is.null(persistent_url)) {

    online <- ISOOnlineResource$new()
    online$setLinkage(persistent_url)
    online$setName(title %||% "Page du jeu de données")
    online$setDescription("Page de présentation du jeu de données dans Dataverse")
    online$setProtocol("WWW:LINK-1.0-http--link")
    online$setOnLineFunction("information")

    transfer_options$addOnlineResource(online)
  }

  # Ressources additionnelles : WMS, WFS, visualiseur, etc.
  #
  # Exemple :
  # list(
  #   list(
  #     url = "https://geodata.inrae.fr/geoserver/workspace/ows?service=WMS",
  #     name = "workspace:layer",
  #     description = "OGC Web Map Service",
  #     protocol = "OGC:WMS",
  #     function = "information"
  #   )
  # )
  if (!is.null(additional_online_resources)) {

    for (resource in additional_online_resources) {

      if (is.null(resource$url)) {
        next
      }

      online <- ISOOnlineResource$new()
      online$setLinkage(resource$url)

      if (!is.null(resource$name)) {
        online$setName(resource$name)
      }

      if (!is.null(resource$description)) {
        online$setDescription(resource$description)
      }

      online$setProtocol(
        resource$protocol %||%
          "WWW:LINK-1.0-http--link"
      )



      transfer_options$addOnlineResource(online)
    }
  }

  distribution$addDigitalTransferOptions(transfer_options)
  md$setDistributionInfo(distribution)

  # Ajout des types spatiaux inférés à partir des fichiers
  for (spatial_type in unique(detected_spatial_types)) {
    ident$addSpatialRepresentationType(spatial_type)
  }

  # ---------------------------------------------------------------------------
  # Linéage
  # ---------------------------------------------------------------------------


  dq <- ISODataQuality$new()

  scope <- ISODataQualityScope$new()
  scope$setLevel("dataset")
  dq$setScope(scope)

  # lineage <- ISOLineage$new()
  # lineage$setStatement(trimws(lineage_statement))
  # dq$setLineage(lineage)

  md$addDataQualityInfo(dq)

  return(md)

}



# push_metadata <- function(result){
#
#   md <- readISO19139(result$output_file)
#   mdId <- md$fileIdentifier
#   GN$insertMetadata(geometa = md, group = "2", category = "2", uuidProcessing = "OVERWRITE", geometa_inspireValidator = INSPIRE_VALIDATOR)
#
#   # for geodata inrae bac à sable :
#   # group = "20838" is for PROJET_OMEES  (voir GN$getGroups()  pour tous les groupes dispos)
#   # category = "2" is for "datasets"     (voir GN$getCategories()  pour toutes les catégories dispos)
#
#   config <- GNPrivConfiguration$new()
#   config$setPrivileges("2", c("view","download", "dynamic"))
#   config$setPrivileges("all", c("view","download","dynamic"))
#   config$setPrivileges("20838", c("view","download","dynamic","featured"))
#   GN$setPrivConfiguration(id = mdId, config = config)
#
# }


 #
 # result <- dataverse_create_iso19115(
 #   doi = identifier ,
 #   output_dir = "xml_metadata/dataverse",
 #   catalogue_url = identifiers_to_harvest$catalogue_url[id]
 # )
 #
 # push_metadata(result)
