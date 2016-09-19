# SeCA
## Migration
Ce dossier contient les requêtes SQL nécessaires à la migration de la couche affectation_com dans le nouveau modèle compatible MGDM. En particulier la requête "all in one" contient toutes les étapes.
## Surdimensionnement
Ce dossier contient les requêtes SQL, ainsi que l'équivalent FME, qui permettent d'effectuer le monitoring de la zone à bâtir. 
Trois couches d'informations sont créées par le processus:

* `SR15.shp` Les polygones de surfaces résidentielles construites au cours des 15 dernières années.
* `SRL.shp` Les polygones de surfaces résidentielles libres (non bâti)
* `COMMUNE.shp` Les frontières communales, ainsi que la somme des aires de SR15 et SRL par commune.

De façon analogue une seconde requête SQL permet d'effectuer le monitoring de la zone d'activité.
Deux couches d'informations sont créées par le processus:

* `SA15.shp` Les polygones de surfaces d'activité construites au cours des 15 dernières années.
* `SAL.shp`Les polygones des surfaces d'activité libres (non bâti)
