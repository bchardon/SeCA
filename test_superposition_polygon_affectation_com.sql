-- Necessite environ 8-10 minutes pour tourner.

SELECT ST_AREA(ST_INTERSECTION(g1geom,g2geom)) as AREA, g1gid, g2gid
FROM 
(SELECT g1.geom as g1geom, g2.geom as g2geom, g1.gid as g1gid, g2.gid as g2gid
FROM oca1032s_affectation_2015 g1, oca1032s_affectation_2015 g2
WHERE ST_OVERLAPS(g1.geom,g2.geom) = True
AND g1.shape_area <> g2.shape_area
AND ST_IsValid(g1.geom) = TRUE
AND ST_IsValid(g2.geom) = TRUE
) AS ANSq
ORDER BY AREA DESC

