library(geoflow)

config <- initWorkflow("/home/ptaconet/IDG_OMEES/geomees/config_geomees_spatial.json", dir = "/home/ptaconet/IDG_OMEES/geomees/dir_test")
executeWorkflow("/home/ptaconet/IDG_OMEES/geomees/config_geomees_spatial.json", dir = "/home/ptaconet/IDG_OMEES/geomees/dir_test")

config <- initWorkflow("/home/ptaconet/IDG_OMEES/geomees/config_geomees_catalogues.json", dir = "/home/ptaconet/IDG_OMEES/geomees/dir_test")
executeWorkflow("/home/ptaconet/IDG_OMEES/geomees/config_geomees_catalogues.json", dir = "/home/ptaconet/IDG_OMEES/geomees/dir_test")

config <- initWorkflow("/home/ptaconet/IDG_OMEES/geomees/config_geomees_applications.json", dir = "/home/ptaconet/IDG_OMEES/geomees/dir_test")
executeWorkflow("/home/ptaconet/IDG_OMEES/geomees/config_geomees_applications.json", dir = "/home/ptaconet/IDG_OMEES/geomees/dir_test")
