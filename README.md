# IDG OMEES — données, métadonnées et publication

Ce dépôt rassemble les scripts R, les données de travail et les configurations utilisés pour alimenter **GéOMEES**, l’infrastructure de données géographiques (IDG) du projet OMEES. Il contribue au référencement et à la mise à disposition de ressources en écologie de la santé, notamment sur le territoire montpelliérain.

Il couvre trois activités principales :

- **Préparer des données OMEES** : atlas des projets et des acteurs en écologie de la santé, cartographie des Solutions fondées sur la Nature (SfN) du Grand Parc de Lunaret.
- **Décrire et publier les ressources** : production de métadonnées ISO 19115/19139 et publication dans GeoNetwork ; exposition de données géographiques avec GeoServer.
- **Moissonner des catalogues externes** : récupération de notices sélectionnées, conversion ou reprise de leurs métadonnées, puis intégration à GéOMEES.

> **État de cette documentation.** Première version établie par lecture du code de la branche `master` au commit `af4f61462f6b5bb1280e74265a086fa7cadc0376` (15 octobre 2026). Les chaînes n’ont pas été exécutées pour rédiger ce README. Le dépôt contient des scripts opérationnels et des essais ; plusieurs traitements nécessitent encore une préparation manuelle et des accès aux services distants.

## Quel script utiliser ?

Les chemins ci-dessous sont relatifs à la racine du dépôt.

| Je veux… | Script ou fichiers | Résultat / effet principal |
| --- | --- | --- |
| Préparer les projets et les acteurs de l’atlas écosanté | [`atlas_ecosante.R`](geomees/donnees_omees/atlas_ecosante/atlas_ecosante.R) | Transformation des données sources et écriture des tables PostGIS `projets_omees` et `acteurs_omees`. Des étapes manuelles restent à vérifier. |
| Préparer la cartographie des SfN de Lunaret | [`datanat_lunaret.R`](geomees/donnees_omees/datanat_lunaret/datanat_lunaret.R) | Regroupement des géométries par identifiant, jointure des attributs et écriture de la table PostGIS `datanat_lunaret`. |
| Publier uniquement des fiches de métadonnées | [`geoflow_omees_metadata_only.R`](geomees/integration_donnees_omees/geoflow_omees_metadata_only.R) | Génération des métadonnées et publication dans GeoNetwork à partir des classeurs geoflow. |
| Publier des métadonnées et des couches provenant de PostGIS | [`geoflow_omees_metadata_with_data.R`](geomees/integration_donnees_omees/geoflow_omees_metadata_with_data.R) | Publication des métadonnées dans GeoNetwork et des services OGC dans GeoServer. |
| Créer une fiche GeoNetwork pour chaque projet de l’atlas | [`iso19115_from_projets.R`](geomees/donnees_omees/atlas_ecosante/atlas_ecosante_to_geonetwork/iso19115_from_projets.R) | Lecture de `projets_omees`, création d’un XML par projet et insertion dans GeoNetwork. La connexion `GN` doit être initialisée au préalable. |
| Importer des notices sélectionnées dans des catalogues externes | [`catalogues_exterieurs_workflow_moissonnage.R`](geomees/moissonnage_catalogues_exterieurs/catalogues_exterieurs_workflow_moissonnage.R) | Récupération et enrichissement des métadonnées, enregistrement XML, puis insertion dans GeoNetwork ; publication de shapefiles pour le cas DKAN prévu dans le code. |
| Explorer la conversion de métadonnées GBIF | [`meta_harvest_gbif.R`](geomees/moissonnage_catalogues_exterieurs/catalogues_exterieurs_fonctions_moissonnage/meta_harvest_gbif.R) | Essai autonome EML → ISO par XSLT, avec ressources locales manquantes dans ce dépôt. Non intégré au workflow général. |

## Organisation du dépôt

| Dossier / fichier | Contenu et rôle |
| --- | --- |
| `geomees/credentials_geomees.R` | Variables de connexion utilisées par les scripts : base de données, GeoNetwork et GeoServer. À configurer localement, sans publier les secrets. |
| `geomees/donnees_omees/atlas_ecosante/` | Préparation de l’atlas des projets et acteurs. Le sous-dossier `projets/` contient les réponses au formulaire, les thématiques et les géométries WKT ; `acteurs/` contient les exports RNSR et les étapes de préparation/géocodage. |
| `geomees/donnees_omees/atlas_ecosante/atlas_ecosante_to_geonetwork/` | Fonction de création d’une métadonnée de projet et script de publication des fiches. |
| `geomees/donnees_omees/datanat_lunaret/` | Shapefiles de points, lignes et surfaces, périmètre du parc, grilles attributaires Excel, projet QGIS, GeoPackages et styles SLD. |
| `geomees/integration_donnees_omees/` | Deux points d’entrée geoflow : métadonnées seules ou métadonnées avec données géographiques. |
| `geomees/integration_donnees_omees/geoflow_config_files/` | Configurations JSON des sources, services cibles et actions geoflow. |
| `geomees/integration_donnees_omees/geoflow_entities/` | Classeurs `entities_metadata_only.xlsx`, `entities_metadata_with_data.xlsx` et `contacts.xlsx`. |
| `geomees/moissonnage_catalogues_exterieurs/` | Liste des notices à moissonner, workflow et fonctions adaptées aux différents catalogues. |

Les dossiers de sortie `xml_metadata/`, `geomees/moissonnage_catalogues_exterieurs/data/` et `geomees/integration_donnees_omees/geoflow_logs/` ne sont pas versionnés dans l’état examiné. Leur absence après clonage est donc normale.

## Architecture des traitements

- Les scripts de préparation construisent des objets `sf` et les écrivent dans **PostgreSQL/PostGIS**.
- **geoflow** lit les descriptions et contacts dans Excel, génère les métadonnées avec **geometa**, puis pilote leur publication avec **geonapi** et celle des couches avec **geosapi**.
- **GeoNetwork** catalogue les ressources ; **GeoServer** diffuse les couches géographiques sous forme de services OGC, notamment WMS/WFS.
- Le moissonnage externe récupère les notices via les API ou protocoles des catalogues sources et les rattache à une fiche de catalogue parent dans GéOMEES.

Ces traitements sont des parcours distincts. Il n’est pas nécessaire de lancer tous les scripts pour mettre à jour une seule ressource.

## Préparer l’environnement

### 1. Cloner le dépôt et travailler depuis sa racine

```bash
git clone https://github.com/ptaconet/IDG_OMEES.git
cd IDG_OMEES
```

Ouvrir ensuite une session R avec ce dossier comme répertoire de travail. Les appels `source("geomees/...")` et les lectures de fichiers utilisent cette racine.

```r
stopifnot(dir.exists("geomees"))
```

### 2. Installer les dépendances nécessaires au parcours choisi

Les dépendances ci-dessous sont repérées dans les scripts ; leurs versions compatibles restent à documenter. Aucun fichier de verrouillage `renv.lock` n’est présent dans l’état examiné.

| Usage | Paquets R |
| --- | --- |
| Préparation des données | `sf`, `tidyverse`, `readxl`, `DBI`, `RPostgres`, `janitor`, `jsonlite` |
| Publication geoflow | `geoflow`, `jsonlite`, `geometa`, `geonapi`, `geosapi` ; pilote PostgreSQL requis par la configuration DBI |
| Moissonnage externe | `rjson`, `geometa`, `geosapi`, `geonapi`, `sf`, `tidyverse`, `ows4R`, `readxl`, `httr`, `xml2`, `XML`, `textutils`, `jsonlite` |
| Essai GBIF | `xslt`, `xml2`, `httr`, `geonapi`, `geometa`, `XML`, `sf`, `dplyr` |

`sf` nécessite un environnement disposant des bibliothèques géospatiales correspondantes (GDAL, GEOS, PROJ). Les traitements PostGIS supposent également une base accessible et les droits d’écriture appropriés.

### 3. Configurer les connexions et les chemins

Les scripts attendent notamment les variables suivantes dans `geomees/credentials_geomees.R` :

- Base de données : `geomees_db_host`, `geomees_db_dbname`, `geomees_db_port`, `geomees_db_user`, `geomees_db_password`.
- GeoNetwork : `geomees_gn_prod_url`, `geomees_gn_bacasable_url`.
- GeoServer : `geomees_gs_prod_url`, `geomees_gs_bacasable_url`.
- Comptes des services : `geomees_gn_gs_prod_user`, `geomees_gn_gs_prod_pwd`, `geomees_gn_gs_bacasable_user`, `geomees_gn_gs_bacasable_pwd`.

Cette liste est déduite des variables appelées par les workflows. Une configuration locale peut, par exemple, lire les secrets depuis des variables d’environnement plutôt que les écrire en clair.

Avant exécution :

1. Remplacer les chemins absolus `/home/ptaconet/IDG_OMEES/...` dans les scripts geoflow et les JSON par ceux du clone local.
2. Vérifier la valeur `geomees_prod_or_bacasable` **dans chaque script** : `"prod"` ou `"bacasable"` (orthographe attendue par le code).
3. Vérifier les sources Excel, le workspace GeoServer et les paramètres des services.
4. Créer les dossiers de sortie nécessaires :

```r
dir.create("xml_metadata", recursive = TRUE, showWarnings = FALSE)
dir.create("geomees/moissonnage_catalogues_exterieurs/data",
           recursive = TRUE, showWarnings = FALSE)
dir.create("geomees/integration_donnees_omees/geoflow_logs",
           recursive = TRUE, showWarnings = FALSE)
```

> Les valeurs par défaut diffèrent : le script geoflow « métadonnées seules » et le workflow de moissonnage ciblent `prod`, tandis que geoflow « avec données » cible `bacasable`. Ce sélecteur concerne les services GeoNetwork/GeoServer ; les scripts de préparation utilisent les variables de base `geomees_db_*`, sans sélecteur équivalent.

## Parcours d’utilisation

### A. Préparer et publier l’atlas écosanté

**Entrées principales :**

- `projets/data.xlsx` : données des projets issues du formulaire.
- `projets/thematiques_omees.xlsx` : correspondances des sous-thématiques et thématiques.
- `projets/sites_geo_wkt.csv` : géométries des sites d’étude, lues en WGS84 (`EPSG:4326`).
- `acteurs/RNSR/` et fichiers CSV d’acteurs : sources et étapes de préparation des structures de recherche.

**Étapes :**

1. Mettre à jour les fichiers sources dans `geomees/donnees_omees/atlas_ecosante/`.
2. Examiner puis exécuter par sections `atlas_ecosante.R` : préparation des projets, association aux sites, regroupements thématiques, puis préparation/géocodage des acteurs.
3. Contrôler les tables PostGIS `projets_omees` et `acteurs_omees`.
4. Pour diffuser les couches, renseigner les entités correspondantes dans `entities_metadata_with_data.xlsx`, puis utiliser le parcours D.
5. Pour créer des fiches individuelles de projets, utiliser le script `iso19115_from_projets.R` après initialisation d’un objet GeoNetwork `GN`, chargement de `sf` et `geonapi`, et vérification de `INSPIRE_VALIDATOR` dans l’environnement R.

La fonction `project_omees_create_iso19115()` décrit un projet : titre, résumé, contacts, thématiques, dates, emprise et liens disponibles. L’identifiant de fiche est construit sous la forme `omees-project-<acronyme-normalisé>`.

**À vérifier avant une relance complète :** le renommage des colonnes de `data.xlsx` repose sur leur ordre ; le script contient un bloc temporaire annoté « à supprimer après 19 juin 2026 ». La partie acteurs reprend des CSV intermédiaires et comporte des corrections manuelles. Vérifier le système de coordonnées avant l’affectation finale en `EPSG:2154`, les adresses géocodées et les sites web.

`iso19115_from_projets.R` utilise le groupe GeoNetwork `20838` (bac à sable selon les commentaires), sans initialiser lui-même `GN`. Ce n’est donc pas encore un point d’entrée autonome.

### B. Préparer la cartographie SfN de Lunaret

**Entrées :** `Point SfN.shp`, `Linéaire SfN.shp`, `Surface SfN.shp` et leurs fichiers associés, ainsi que `Grille SfN.xlsx`, dans `geomees/donnees_omees/datanat_lunaret/`.

Le script `datanat_lunaret.R` :

1. Lit les trois types de géométrie.
2. Applique les exclusions/corrections d’identifiants présentes dans le code.
3. Regroupe les géométries par `ID`, avec conservation possible de géométries mixtes.
4. Joint la grille attributaire après nettoyage des noms de colonnes.
5. Écrit le résultat dans PostGIS, table `datanat_lunaret`.

Après configuration et contrôle des entrées :

```r
source("geomees/donnees_omees/datanat_lunaret/datanat_lunaret.R")
```

Les blocs de création de GeoPackage, styles et groupes de couches GeoServer en fin de fichier sont **commentés**. Ils constituent des exemples de travail et ne sont pas exécutés par cet appel. Les GeoPackages présents dans le dépôt ne sont pas régénérés par la partie active du script.

### C. Publier des métadonnées seules

1. Renseigner `geomees/integration_donnees_omees/geoflow_entities/entities_metadata_only.xlsx` et `contacts.xlsx`.
2. Adapter `config_geomees_metadata_only.json` et les chemins du script ; choisir l’environnement cible.
3. Exécuter :

```r
source("geomees/integration_donnees_omees/geoflow_omees_metadata_only.R")
```

Le script complète le JSON avec les paramètres de connexion, appelle `initWorkflow()`, puis `executeWorkflow()`. La configuration active la création des métadonnées ISO et leur publication dans GeoNetwork, avec les vignettes. Elle utilise le séparateur `"_\n"` (underscore suivi d’un saut de ligne) pour les valeurs multiples et `skipDataDownload = true`.

### D. Publier des métadonnées avec des couches PostGIS

1. Préparer et contrôler les tables PostGIS nécessaires, par exemple via A ou B.
2. Renseigner `entities_metadata_with_data.xlsx` et `contacts.xlsx`.
3. Adapter `config_geomees_metadata_with_data.json` : sources, connexion DBI/PostgreSQL, GeoServer, GeoNetwork et workspace `omees`.
4. Choisir l’environnement cible et exécuter :

```r
source("geomees/integration_donnees_omees/geoflow_omees_metadata_with_data.R")
```

Cette configuration ajoute l’action `geosapi-publish-ogc-services` à la génération/publication des métadonnées. Elle ne remplace pas les traitements de préparation des tables en amont. Les journaux geoflow sont dirigés vers `geomees/integration_donnees_omees/geoflow_logs/`.

### E. Moissonner une sélection de notices externes

**Fichier de sélection :** `geomees/moissonnage_catalogues_exterieurs/catalogues_exterieurs_fiches_a_moissonner.csv`.

| Colonne | Rôle |
| --- | --- |
| `catalogue_identifier` | Identifiant du catalogue parent, utilisé pour la jointure avec les entités geoflow et pour le rattachement de la notice. |
| `url` | Page source de la ressource, ajoutée à la description de provenance. |
| `data_identifier` | Identifiant de la notice ou du jeu de données attendu par le catalogue source, par exemple UUID ou DOI. |
| `topics` | Catégories thématiques ISO ajoutées à la notice ; valeurs multiples séparées par underscore et saut de ligne. Vérifier les valeurs manquantes avant lancement. |

**Étapes :**

1. Décrire les catalogues dans `entities_metadata_only.xlsx` avec `Type == "directories"`. Le workflow attend notamment `catalogue_metadata_standard` et une entrée « API catalogue » dans `Relation` pour extraire l’URL d’accès.
2. Vérifier les contacts associés dans `contacts.xlsx` et la correspondance des identifiants.
3. Sélectionner les notices dans le CSV. Pour un premier essai, limiter la sélection à une notice.
4. Vérifier l’environnement cible, les dossiers de sortie et les dépendances.
5. Exécuter le workflow après contrôle des actions de publication :

```r
source("geomees/moissonnage_catalogues_exterieurs/catalogues_exterieurs_workflow_moissonnage.R")
```

| Valeur de `catalogue_metadata_standard` | Traitement appelé |
| --- | --- |
| `dkan` | Fonctions `dkan_*` : récupération via l’API du portail Montpellier 3M, conversion ISO et publication éventuelle du shapefile ZIP dans GeoServer. |
| `dataverse` | `dataverse_create_iso19115()` : conversion des métadonnées Dataverse. |
| `geonetwork_api` | `geonetwork_create_iso19115()` : récupération XML par l’API GeoNetwork. |
| `geonetwork_csw_19115_3` | Même fonction, via CSW avec le schéma ISO 19115-3. |
| `opendatasoft` | Même fonction, récupération de la notice ISO via CSW. |
| `ddi` | `ddi_create_iso19115()` : récupération DDI via OAI-PMH et conversion ISO, prévue pour PROGEDO. |

Le workflow ajoute notamment le catalogue parent, la provenance, une vignette et le mot-clé `omees`, puis sauvegarde les XML dans `xml_metadata/`. Il insère ensuite les fiches dans GeoNetwork avec `uuidProcessing = "OVERWRITE"` et configure leurs droits, dont ceux du groupe `all`.

**Limites actuelles :** le cas DKAN comporte des URL spécifiques à Montpellier 3M et des liens vers le bac à sable codés en dur ; le sélecteur d’environnement ne les remplace pas. Vérifier aussi la lecture des ZIP via `/vsizip/`, les emprises et projections. Le traitement GBIF n’est pas appelé par cette boucle et dépend d’une feuille XSLT absente du dépôt.

## Effets à connaître avant exécution

- Les scripts de préparation écrivent dans PostGIS avec `st_write(..., append = FALSE)` : considérer ces sorties comme des écritures de remplacement, pas comme un ajout incrémental.
- Les scripts de publication peuvent créer ou mettre à jour des ressources distantes. Les deux scripts d’insertion directe dans GeoNetwork utilisent `OVERWRITE` et modifient les privilèges, y compris pour `all`.
- Les scripts geoflow **réécrivent les JSON de configuration avec les identifiants de connexion**. Ne pas committer ces fichiers après exécution sans retirer les secrets ; vérifier le diff Git.
- Des identifiants sont présents dans le code examiné, y compris dans des exemples commentés. Les retirer du code et de l’historique partagé, et renouveler tout secret encore actif. Ce README ne les reproduit pas.

## Vérifier le résultat

| Après… | Vérifications utiles |
| --- | --- |
| Préparation PostGIS | Présence de la table, nombre d’entités, attributs, valeurs manquantes, géométries et SCR. |
| Publication geoflow | Journaux d’exécution, fiche GeoNetwork, liens vers les données et couches GeoServer attendues. |
| Création des fiches projets | XML produits, unicité des identifiants construits à partir des acronymes, dates, contacts et emprises. |
| Moissonnage | Correspondance avec la notice source, catalogue parent, provenance, thématiques, droits et éventuels services WMS/WFS. |

## À compléter

- Confirmer l’intitulé institutionnel d’OMEES : les formulations diffèrent actuellement entre scripts.
- Documenter les URL officielles des environnements et les procédures d’accès.
- Décrire les colonnes des classeurs geoflow, avec un exemple minimal validé pour chaque parcours.
- Préciser les versions R/paquets utilisées et fournir un environnement reproductible.
- Isoler les étapes manuelles de l’atlas et rendre les points d’entrée autonomes.
- Harmoniser les chemins, paramètres d’environnement et liens codés en dur.
- Préciser la fréquence et les responsables de mise à jour des sources et du moissonnage.
- Définir les conditions de réutilisation du code et des données : aucun fichier de licence n’est présent dans l’état examiné ; les ressources externes conservent leurs conditions propres.
