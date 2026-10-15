library(xml2)
library(geometa)

ddi_create_iso19115 <- function(
    identifier,
    catalogue_url
){

  geometa::setMetadataStandard("19139")


  # ============================================================
  # 1. READ DDI / OAI-PMH RECORD
  # ============================================================
  url <- paste0(catalogue_url,"oai?verb=GetRecord&metadataPrefix=oai_ddi25&identifier=doi%3A",identifier)

  meta_ddi <- xml2::read_xml(url)

  # ------------------------------------------------------------
  # Small helper functions
  # ------------------------------------------------------------

  get_text <- function(xpath){

    x <- xml2::xml_find_first(meta_ddi, xpath)

    if(inherits(x, "xml_missing")){
      return(NA_character_)
    }

    x <- xml2::xml_text(x, trim = TRUE)

    if(x == ""){
      return(NA_character_)
    }

    return(x)
  }


  get_texts <- function(xpath){

    x <- xml2::xml_find_all(meta_ddi, xpath)

    if(length(x) == 0){
      return(character(0))
    }

    x <- xml2::xml_text(x, trim = TRUE)
    x <- x[x != ""]

    unique(x)
  }


  get_date <- function(xpath){

    x <- xml2::xml_find_first(meta_ddi, xpath)

    if(inherits(x, "xml_missing")){
      return(NA_character_)
    }

    # DDI dates can be stored as an attribute
    d <- xml2::xml_attr(x, "date")

    # otherwise use element content
    if(is.na(d) || d == ""){
      d <- xml2::xml_text(x, trim = TRUE)
    }

    if(d == ""){
      return(NA_character_)
    }

    d
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

  safe_filename <- function(x) {
    x <- first_non_empty(x, "dataverse_metadata")
    x <- gsub("^doi:", "", x, ignore.case = TRUE)
    x <- gsub("[^A-Za-z0-9._-]+", "_", x)
    x
  }

  get_ddi_point_of_contact <- function(meta_ddi){

    # ============================================================
    # 1. PRODUCERS - highest priority
    # ============================================================

    producer_nodes <- xml2::xml_find_all(
      meta_ddi,
      ".//*[local-name()='stdyDscr']/*[local-name()='citation']/*[local-name()='prodStmt']/*[local-name()='producer']"
    )

    if(length(producer_nodes) > 0){

      producer_name <- xml2::xml_text(
        producer_nodes[1],
        trim = TRUE
      )

      producer_abbr <- xml2::xml_attr(
        producer_nodes[1],
        "abbr"
      )

      return(list(
        organisation = producer_name,
        abbreviation = ifelse(
          is.na(producer_abbr) || producer_abbr == "",
          NA_character_,
          producer_abbr
        ),
        source = "producer"
      ))
    }


    # ============================================================
    # 2. AUTHORS - fallback
    # ============================================================

    author_nodes <- xml2::xml_find_all(
      meta_ddi,
      ".//*[local-name()='stdyDscr']/*[local-name()='citation']/*[local-name()='rspStmt']/*[local-name()='AuthEnty']"
    )

    if(length(author_nodes) > 0){

      author_name <- xml2::xml_text(
        author_nodes[1],
        trim = TRUE
      )

      author_abbr <- xml2::xml_attr(
        author_nodes[1],
        "abbr"
      )

      return(list(
        organisation = author_name,
        abbreviation = ifelse(
          is.na(author_abbr) || author_abbr == "",
          NA_character_,
          author_abbr
        ),
        source = "AuthEnty"
      ))
    }


    # ============================================================
    # 3. DISTRIBUTOR - last fallback
    # ============================================================

    distributor_nodes <- xml2::xml_find_all(
      meta_ddi,
      ".//*[local-name()='stdyDscr']/*[local-name()='citation']/*[local-name()='distStmt']/*[local-name()='distrbtr']"
    )

    if(length(distributor_nodes) > 0){

      distributor_name <- xml2::xml_text(
        distributor_nodes[1],
        trim = TRUE
      )

      distributor_abbr <- xml2::xml_attr(
        distributor_nodes[1],
        "abbr"
      )

      return(list(
        organisation = distributor_name,
        abbreviation = ifelse(
          is.na(distributor_abbr) || distributor_abbr == "",
          NA_character_,
          distributor_abbr
        ),
        source = "distrbtr"
      ))
    }


    # ============================================================
    # 4. fallback
    # ============================================================

    return(list(
      organisation = "PROGEDO",
      abbreviation = NA_character_,
      source = "fallback"
    ))
  }


  # ============================================================
  # 2. EXTRACT DDI METADATA
  # ============================================================

  # OAI identifier
  oai_identifier <- get_text(
    ".//*[local-name()='GetRecord']/*[local-name()='record']/*[local-name()='header']/*[local-name()='identifier']"
  )

  # DOI
  doi <- sub("^doi:", "", oai_identifier)

  dataset_url <- if(!is.na(doi)){
    paste0("https://doi.org/", doi)
  } else {
    url
  }


  # Title
  title <- get_text(
    ".//*[local-name()='stdyDscr']/*[local-name()='citation']/*[local-name()='titlStmt']/*[local-name()='titl']"
  )


  # Subtitle
  subtitle <- get_text(
    ".//*[local-name()='stdyDscr']/*[local-name()='citation']/*[local-name()='titlStmt']/*[local-name()='subTitl']"
  )


  # Abstract
  abstract <- get_text(
    ".//*[local-name()='stdyDscr']/*[local-name()='stdyInfo']/*[local-name()='abstract']"
  )


  # Authors
  authors <- get_texts(
    ".//*[local-name()='stdyDscr']/*[local-name()='citation']/*[local-name()='rspStmt']/*[local-name()='AuthEnty']"
  )


  # Producers
  producers <- get_texts(
    ".//*[local-name()='stdyDscr']/*[local-name()='citation']/*[local-name()='prodStmt']/*[local-name()='producer']"
  )


  # Distributor
  distributors <- get_texts(
    ".//*[local-name()='stdyDscr']/*[local-name()='citation']/*[local-name()='distStmt']/*[local-name()='distrbtr']"
  )


  # Publication / distribution date
  # Publication date

  publication_date <- get_date(
    ".//*[local-name()='distStmt']/*[local-name()='distDate']"
  )

  if(is.na(publication_date)){
    publication_date <- get_date(
      ".//*[local-name()='prodStmt']/*[local-name()='prodDate']"
    )
  }

  if(is.na(publication_date)){
    publication_date <- get_date(
      ".//*[local-name()='citation']//*[local-name()='version']"
    )
  }

  oai_datestamp <- get_text(
    ".//*[local-name()='GetRecord']/*[local-name()='record']/*[local-name()='header']/*[local-name()='datestamp']"
  )




  # Keywords + topic classifications
  keywords <- unique(c(
    get_texts(".//*[local-name()='stdyInfo']//*[local-name()='subject']/*[local-name()='keyword']"),
    get_texts(".//*[local-name()='stdyInfo']//*[local-name()='subject']/*[local-name()='topcClas']")
  ))


  # Geographic coverage
  geographic_coverage <- get_texts(
    ".//*[local-name()='stdyInfo']//*[local-name()='sumDscr']/*[local-name()='geogCover']"
  )


  # Country
  nations <- get_texts(
    ".//*[local-name()='stdyInfo']//*[local-name()='sumDscr']/*[local-name()='nation']"
  )


  # Analysis unit
  analysis_unit <- get_texts(
    ".//*[local-name()='stdyInfo']//*[local-name()='sumDscr']/*[local-name()='anlyUnit']"
  )


  # Data kind
  data_kind <- get_texts(
    ".//*[local-name()='stdyInfo']//*[local-name()='sumDscr']/*[local-name()='dataKind']"
  )


  # Sampling procedure
  sampling <- get_texts(
    ".//*[local-name()='method']//*[local-name()='dataColl']/*[local-name()='sampProc']"
  )


  # Collection mode
  collection_mode <- get_texts(
    ".//*[local-name()='method']//*[local-name()='dataColl']/*[local-name()='collMode']"
  )


  # Access / use conditions
  conditions <- get_texts(
    ".//*[local-name()='dataAccs']//*[local-name()='conditions']"
  )

  restrictions <- get_texts(
    ".//*[local-name()='dataAccs']//*[local-name()='restrctn']"
  )


  # ============================================================
  # 3. ISO 19115 METADATA
  # ============================================================

  md <- ISOMetadata$new()

  metadata_id <- ifelse(!is.na(doi),  gsub("/", "-", doi),  gsub("/", "-", oai_identifier))

  md$setFileIdentifier(metadata_id)

  md$setCharacterSet("utf8")
  md$setLanguage("fre")
  md$setDateStamp(Sys.time())

  md$setMetadataStandardName("ISO 19115:2003/19139")
  md$setMetadataStandardVersion("1.0")

  md$setDataSetURI(dataset_url)


  # ============================================================
  # 4. METADATA CONTACT
  # ============================================================

  poc <- get_ddi_point_of_contact(meta_ddi)

  rp <- ISOResponsibleParty$new()

  rp$setOrganisationName(
    if(!is.na(poc$abbreviation)){
      poc$abbreviation
    } else {
      poc$organisation
    }
  )

  rp$setRole("pointOfContact")

  contact <- ISOContact$new()
  rp$setContactInfo(contact)

  md$addContact(rp)

  # ============================================================
  # 5. DATA IDENTIFICATION
  # ============================================================

  ident <- ISODataIdentification$new()

  if(!is.na(abstract)){
    if (!is.null(abstract) && nzchar(abstract)) {
      ident$setAbstract(abstract)
    }
  }

  ident$addStatus("completed")
  ident$addLanguage("fre")
  ident$addCharacterSet("utf8")

  # PROGEDO = mainly social science data
  ident$addTopicCategory("society")


  # ============================================================
  # 6. CITATION
  # ============================================================
  ct <- ISOCitation$new()

  ct$setTitle(title)

  if(!is.na(subtitle)){
    ct$addAlternateTitle(subtitle)
  }

  # publication date OR OAI datestamp
  date_citation <- publication_date
  date_type <- "publication"

  if(is.na(date_citation)){
    date_citation <- oai_datestamp
    date_type <- "revision"
  }

  if(!is.na(date_citation)){

    d <- ISODate$new()
    d$setDate(as.Date(substr(date_citation, 1, 10)))
    d$setDateType(date_type)

    ct$addDate(d)
  }

  # if(!is.na(doi)){
  #   ct$addIdentifier(
  #     ISOMetaIdentifier$new(
  #       code = doi,
  #       codeSpace = "doi"
  #     )
  #   )
  # }

  # ONLY NOW add authors
  for(author in authors){

    author_rp <- ISOResponsibleParty$new()
    author_rp$setIndividualName(author)
    author_rp$setRole("author")

    ct$addCitedResponsibleParty(author_rp)
  }

  ident$setCitation(ct)


  # ---------------------------------------------------------------------------
  # Catégories thématiques ISO
  # ---------------------------------------------------------------------------

  # if (is.null(topic_categories)) {
  #
  #   subjects <- unlist(
  #     get_dv_field(citation_block, "subject"),
  #     recursive = TRUE,
  #     use.names = FALSE
  #   )
  #
  #   subjects <- unique(as.character(subjects))
  #   topic_categories <- unique(
  #     na.omit(vapply(
  #       subjects,
  #       subject_to_iso_topic,
  #       character(1)
  #     ))
  #   )
  # }

  # # Valeur de repli pertinente pour le bloc observé
  # if (length(topic_categories) == 0L) {
  #   topic_categories <- "environment"
  # }
  #
  # for (topic in topic_categories) {
  #   ident$addTopicCategory(topic)
  # }


  # ============================================================
  # 7. KEYWORDS
  # ============================================================

  kwds <- ISOKeywords$new()

  if(length(keywords) > 0){

    for(keyword in keywords){

      kwds$addKeyword(keyword)
    }
  }


  # geographic keywords
  if(length(geographic_coverage) > 0){

    for(x in geographic_coverage){
      kwds$addKeyword(x)
    }
  }


  if(length(nations) > 0){

    for(x in nations){
      kwds$addKeyword(x)
    }
  }


  kwds$addKeyword("PROGEDO")

  ident$addKeywords(kwds)


  # ============================================================
  # 8. TEMPORAL EXTENT
  # ============================================================

  time_nodes <- xml2::xml_find_all(
    meta_ddi,
    ".//*[local-name()='stdyInfo']//*[local-name()='sumDscr']/*[local-name()='timePrd']"
  )


  if(length(time_nodes) > 0){

    dates <- xml2::xml_attr(time_nodes, "date")

    dates <- dates[
      !is.na(dates) &
        grepl("^\\d{4}(-\\d{2}(-\\d{2})?)?$", dates)
    ]

    if(length(dates) > 0){

      # Allow year-only / year-month dates
      date_to_iso <- function(x){

        if(grepl("^\\d{4}$", x)){
          x <- paste0(x, "-01-01")
        }

        if(grepl("^\\d{4}-\\d{2}$", x)){
          x <- paste0(x, "-01")
        }

        as.Date(x)
      }


      dates <- as.Date(
        sapply(dates, date_to_iso),
        origin = "1970-01-01"
      )


      start_date <- min(dates, na.rm = TRUE)
      end_date   <- max(dates, na.rm = TRUE)


      extent <- ISOExtent$new()

      te <- ISOTemporalExtent$new()

      tp <- GMLTimePeriod$new(
        beginPosition = as.POSIXct(start_date),
        endPosition   = as.POSIXct(end_date)
      )

      te$setTimePeriod(tp)

      extent$addTemporalElement(te)

      ident$addExtent(extent)
    }
  }


  # ============================================================
  # 9. LEGAL / ACCESS CONSTRAINTS
  # ============================================================

  access_text <- unique(c(conditions, restrictions))
  access_text <- access_text[!is.na(access_text)]


  if(length(access_text) > 0){

    lc <- ISOLegalConstraints$new()

    for(x in access_text){
      lc$addUseLimitation(x)
    }

    ident$addResourceConstraints(lc)
  }


  # ============================================================
  # 10. SUPPLEMENTAL INFORMATION
  # ============================================================

  supplemental <- c()

  if(length(analysis_unit) > 0){
    supplemental <- c(
      supplemental,
      paste0(
        "Unité d'analyse : ",
        paste(analysis_unit, collapse = "; ")
      )
    )
  }

  if(length(data_kind) > 0){
    supplemental <- c(
      supplemental,
      paste0(
        "Type de données : ",
        paste(data_kind, collapse = "; ")
      )
    )
  }

  if(length(sampling) > 0){
    supplemental <- c(
      supplemental,
      paste0(
        "Échantillonnage : ",
        paste(sampling, collapse = "; ")
      )
    )
  }

  if(length(collection_mode) > 0){
    supplemental <- c(
      supplemental,
      paste0(
        "Mode de collecte : ",
        paste(collection_mode, collapse = "; ")
      )
    )
  }


  supplemental <- c(
    supplemental,
    "Métadonnée automatiquement extraite du catalogue PROGEDO à partir du flux OAI-PMH DDI 2.5."
  )


  ident$setSupplementalInformation(
    paste(supplemental, collapse = "\n")
  )


  md$addIdentificationInfo(ident)


  # ============================================================
  # 11. DISTRIBUTION / ONLINE RESOURCE
  # ============================================================

  distrib <- ISODistribution$new()

  dto <- ISODigitalTransferOptions$new()


  # DOI landing page
  or <- ISOOnlineResource$new()

  or$setLinkage(dataset_url)
  or$setName(title)
  or$setDescription("Page du jeu de données dans le catalogue PROGEDO")
  or$setProtocol("WWW:LINK-1.0-http--link")
  or$setOnLineFunction("information")

  dto$addOnlineResource(or)

  # Original OAI record
  or <- ISOOnlineResource$new()

  or$setLinkage(url)
  or$setName("Métadonnée DDI 2.5")
  or$setDescription("Notice source au format DDI 2.5 via OAI-PMH")
  or$setProtocol("WWW:LINK-1.0-http--link")
  or$setOnLineFunction("information")

  dto$addOnlineResource(or)


  distrib$addDigitalTransferOptions(dto)

  md$setDistributionInfo(distrib)

  return(md)

}
