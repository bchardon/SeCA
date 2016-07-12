# SeCA
## Migration
Ce dossier contient les requêtes SQL nécessaires à la migration de la couche affectation_com dans le nouveau modèle compatible MGDM. En particulier la requête "all in one" contient toutes les étapes.
## Surdimensionnement
Ce dossier contient les requêtes SQL, ainsi que l'équivalent FME, qui permettent d'effectuer le monitoring de la zone à bâtir. 
Trois couches d'informations sont créées par le processus:

`SR15.shp` Les polygones de surfaces résidentielle construite au cours des 15 dernières années.
`SRL.shp` Les polygones de surface résidentielle libre (non bâti)
`COMMUNE.shp` Les frontières communales, ainsi que la somme des aires de SR15 et SRL par commune.
