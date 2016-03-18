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


-- Creation superposition bruit

DROP TABLE IF EXISTS superpositionbruit;
CREATE TABLE superpositionbruit AS
SELECT (ST_DUMP(ST_Union(ST_SnapToGrid(ST_MakeValid(geom),0.0)))).geom,sensiblesp
FROM oca1032s_affectation_com 
WHERE sensiblesp > 0
GROUP BY sensiblesp