/* Dans le système actuel il n'y a pas de gestion des périmètres superposés: 
donc lorsqu'un secteur PAD, de danger, de protection... affecte un des polygons de 
affectation_com, ce polygon est découpé et une remarque est placé dans le champ remarque 
afin de préciser la nature de la superposition.

Puisque le nouveau modèle sépare ces superpositions d'affectation_com, ces découpages de polygons
ne sont plus nécessaires et les polygons adjacents ayant le même typstandard doivent être "mergé".

PAR CONTRE ET C'EST IMPORTANT, il faut récupérer l'information qui découpait les polygons dans des couches "superposition"
IL FAUT RECUPERER:
- Sensibilité au bruit
- Danger 
- Protection non répertorié par typprot ou typstd (genre protec archéologique)
Le PAD est déjà vectorisé.
*/

-- Unification (géométrie + typstd uniquement) des géomètries découpées.
 DROP TABLE IF EXISTS merged;
 CREATE TABLE merged AS
 SELECT (ST_DUMP(ST_Union(ST_SnapToGrid(geom,0.0001)))).geom,typstd
 FROM oca1032s_affectation_com -- A changé pour affectation_2015 une fois chaque typstd_2015 attribué.
 GROUP BY typstd;
