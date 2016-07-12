/* 
EN TOUT ET POUR TOUT IL FAUT ENVIRON 15 minutes POUR QUE LA QUERY TOURNE SUR UN BON PC, prend un café

La query crée deux tables principales:
SR15: Qui liste les parcelles construites depuis moins de 15 ans. (SURFACE RESIDENTIELLE 15 ANS, SR15)
SRL : Qui liste les parcelles libres et demi-parcelles libres (construite mais avec un potentiel de construction) (SURFACE RESIDENTIELLE LIBRE, SRL)
	- L'attribut composition, distingue parcelles (valeur 0) et "demi-parcelles" (valeur 1)

Enfin un attribut SRL et SR15 est ajouté à la table commune. Chaque attribut somme l'aire SRL et SR15 dispo par commune. Un attribut RATIO correspond à SRL/SR15, ce ratio de devrait pas théoriquement
excéder le facteur de dimensionnement des ZAB que possède la commune. (1,1.2,1.4,...)

MODE D'EMPLOI:

CHARGER LES COUCHES:

- batiment_h
- couverture_sol
- affectation_com
- bien_fonds
- regbl 
- commune
*/









DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Lancement du processus'; END $$;

/*
ETAPE 0: Création des fonctions de nettoyage des données (UNIQUEMENT LA PREMIERE FOIS, MAIS PAS IMPORTANT SI REFAIT)
*/

DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Création des fonctions de nettoyages des données'; END $$;

CREATE OR REPLACE FUNCTION sliver_killer(geometry,float) RETURNS geometry AS $$
SELECT ST_BuildArea(ST_Collect(a.geom)) AS final_geom
FROM ST_DumpRings($1) AS a
WHERE a.path[1] = 0
  OR (a.path[1] > 0
      AND ST_Area(a.geom) > $2) $$ LANGUAGE 'sql' IMMUTABLE;

CREATE OR REPLACE FUNCTION sliver_murder(geometry,float) RETURNS geometry AS $$
SELECT ST_Buffer(ST_Buffer($1,$2,'join=mitre'),-$2,'join=mitre') AS geom $$ LANGUAGE 'sql' IMMUTABLE;


/*
CREATE OR REPLACE FUNCTION cleangeometry(geometry) RETURNS geometry AS $$
UPDATE $1   
SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(new.geom), 3))
FROM 
(
SELECT geom, gid
FROM couverture_sol  
WHERE ST_ISVALID(couverture_sol .geom) = FALSE 
) as new
WHERE couverture_sol .gid = new.gid;
*/

/*
ETAPE 1: On garde uniquement les routes et trottoires de la couverture du sol (UNIQUEMENT LA PREMIERE FOIS, MAIS PAS IMPORTANT SI REFAIT)
*/

DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Selection des données utiles'; END $$;

DELETE FROM couverture_sol
WHERE GID NOT IN
(
SELECT gid 
WHERE type in (1,2,7,8,11) -- 1: Trottoire, 2: Route, 7: revêtement_dur, 8: champ_pre_paturage, 11: Jardin (donc pas ZAB)
);

DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'ok'; END $$;

UPDATE couverture_sol  
SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(new.geom), 3))
FROM 
(
SELECT geom, gid
FROM couverture_sol  
WHERE ST_ISVALID(couverture_sol .geom) = FALSE 
) as new
WHERE couverture_sol .gid = new.gid;


/* 
ETAPE 2: Quelle commune dispose d'un parcellaire complet ? 
*/

/*
SELECT SUM(ST_AREA(b.geom))/c.shape_area, b.FOSNR
FROM bien_fonds b, commune c
WHERE c.fosnr = b.fosnr
group by b.FOSNR, c.shape_area;
*/

/* 
ETAPE 3: Nettoyage des données (UNIQUEMENT LA PREMIERE FOIS, MAIS PAS IMPORTANT SI REFAIT)
*/


DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Nettoyage des données'; END $$;

UPDATE batiment_h 
SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(new.geom), 3))
FROM 
(
SELECT geom, gid
FROM batiment_h 
WHERE ST_ISVALID(batiment_h.geom) = FALSE 
) as new
WHERE batiment_h.gid = new.gid;

UPDATE affectation_com 
SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(new.geom), 3))
FROM 
(
SELECT geom, gid
FROM affectation_com 
WHERE ST_ISVALID(affectation_com.geom) = FALSE 
) as new
WHERE affectation_com.gid = new.gid;

UPDATE bien_fonds 
SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(new.geom), 3))
FROM 
(
SELECT geom, gid
FROM bien_fonds 
WHERE ST_ISVALID(bien_fonds.geom) = FALSE 
) as new
WHERE bien_fonds.gid = new.gid;

UPDATE commune 
SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(new.geom), 3))
FROM 
(
SELECT geom, gid
FROM commune 
WHERE ST_ISVALID(commune.geom) = FALSE 
) as new
WHERE commune.gid = new.gid; 

/* ETAPE 3.1 Si on prend la couche commune + secteur (196 communes) il faut ajuster le FOSNR et le nom des champs*/


UPDATE commune SET FOSNR = fosnr::integer;

/*
ETAPE 4: On supprime les batiments + bien_fonds qui n'intersectent pas 
les zones d'affectations afin de diminuer la masse de données (et donc de calcule) pour les
opérations suivantes. (UNIQUEMENT LA PREMIERE FOIS, MAIS PAS IMPORTANT SI REFAIT)
*/
DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Suppression des parcelles inutiles'; END $$;

DELETE
FROM bien_fonds b
WHERE b.gid not in
(
SELECT DISTINCT b.gid 
FROM   affectation_com a
WHERE st_intersects(a.geom,b.geom)
);

DELETE
FROM batiment_h b
WHERE b.gid not in
(
SELECT DISTINCT b.gid 
FROM   affectation_com a
WHERE st_intersects(a.geom,b.geom)
);


/*ETAPE 5: On transforme batiment_h en point, le point est situé sur le centroide
de la forme du bâtiment. (UNIQUEMENT LA PREMIERE FOIS, MAIS PAS IMPORTANT SI REFAIT)
*/
DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Transformation des bâtiments polygones en points'; END $$;

DROP TABLE IF EXISTS batiment_h_point;

CREATE TABLE batiment_h_point AS
SELECT * 
FROM batiment_h;


ALTER TABLE batiment_h_point
ALTER COLUMN geom TYPE geometry(Point) USING ST_Centroid(geom);


-- On s'assure que fosnr correspond à notre fosnr de référence (commune.fosnr)

UPDATE batiment_h_point SET fosnr = c.fosnr
FROM commune c
WHERE st_intersects(c.geom,batiment_h_point.geom);

/*ETAPE 6: On intersecte bien_fonds avec commune puis avec affectation_com afin 
de séparer parfaitement les parcelles (environ 5 minutes) (UNIQUEMENT LA PREMIERE FOIS, MAIS PAS IMPORTANT SI REFAIT) */

DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Découpage des parcelles avec la commune et les zones d affectations'; END $$;
-- LE TRICKS: on n'intersecte que les parties qui se chevauche

DROP TABLE IF EXISTS V1;

CREATE TABLE V1 as
SELECT n.fosnr
 , CASE 
   WHEN ST_CoveredBy(p.geom, n.geom) 
   THEN p.geom 
   ELSE 
    ST_Multi(
      ST_Intersection(p.geom,n.geom)
      ) END AS geom 
 FROM bien_fonds AS p 
   INNER JOIN commune AS n 
    ON ST_Intersects(p.geom, n.geom);
    
ALTER TABLE V1
ADD COLUMN gid SERIAL;

UPDATE V1  
SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(new.geom), 3))
FROM 
(
SELECT geom, gid
FROM V1  
WHERE ST_ISVALID(V1 .geom) = FALSE 
OR geometrytype(geom) != 'MULTIPOLYGON'
) as new
WHERE V1.gid = new.gid;


CREATE TABLE bien_fonds_intersected AS
SELECT p.FOSNR,n.TYPSTD
 , CASE 
   WHEN ST_CoveredBy(p.geom, n.geom) 
   THEN p.geom 
   ELSE 
    ST_Multi(
      ST_Intersection(p.geom,n.geom)
      ) END AS geom 
 FROM V1 AS p 
   INNER JOIN affectation_com AS n 
    ON ST_Intersects(p.geom, n.geom);

ALTER TABLE bien_fonds_intersected
ADD COLUMN gid SERIAL;

DROP TABLE IF EXISTS V1;


UPDATE  bien_fonds_intersected   
SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(new.geom), 3))
FROM 
(
SELECT geom, gid
FROM  bien_fonds_intersected   
WHERE ST_ISVALID( bien_fonds_intersected.geom) = FALSE 
OR geometrytype(geom) != 'MULTIPOLYGON'
) as new
WHERE bien_fonds_intersected.gid = new.gid;



/* ETAPE 7 Superficie de ZAB construite par commune (théorique) au cours des 15 dernières années
calculé comme suit: SUPERFICIE ZAB = factor * (surface parcelle construite 15 dernières années) */
DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Calcule de la Surface construite au cours des 15 dernières années'; END $$;

ALTER TABLE commune
DROP COLUMN IF EXISTS SR15,
DROP COLUMN IF EXISTS SRL;

ALTER TABLE commune 
ADD COLUMN SR15 double precision,
ADD COLUMN SRL double precision;

-- Je crée la table SR15 et
-- J'ajoute une colonne SR15 (Surface résidentielle < 15 ans) a la couche commune
-- On regarde les parcelles qui sont construite depuis moins de 15 ans a partir de relevé LIDAR swisstopo + du REGBL (double combo imparable)
-- ATTENTION: PAR CHANCE LES RELEVES LIDAR SWISSTOPO ONT ETE EFFECTUES IL Y A ~ 15 ANS, MAIS DANS 1-2 ANS LA METHODE NE POURRA PLUS ETRE UTILISES.
DROP TABLE IF EXISTS SR15;

CREATE TABLE SR15 AS
	SELECT DISTINCT b.geom as geom,  b.fosnr
	FROM batiment_h_point a, bien_fonds_intersected b
	WHERE st_intersects(a.geom,b.geom)
	AND b.fosnr = a.fosnr
	AND b.typstd IN ('ZRHD', 'ZRMD', 'ZRFD', 'ZM','ZV')
	AND a.shape_area > 25
	group by b.gid, b.fosnr, b.geom
	having max(a.mean_robus) = 0
	UNION
	SELECT DISTINCT b.geom as geom,  b.fosnr
	FROM bien_fonds_intersected b, regbl c
	WHERE ST_INTERSECTS(c.geom,b.geom)
	AND b.typstd IN ('ZRHD', 'ZRMD', 'ZRFD', 'ZM','ZV')
	AND b.fosnr = c.gdenr
	AND c.gbauj > 2001;
	
ALTER TABLE SR15 
ADD COLUMN gid SERIAL;




-- CALCULE DE LA SRL (Surface résidentielle libre) (environ 6 minutes)

DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Calcule de la Surface libre'; END $$;

DROP TABLE IF EXISTS tempSRL_1;
DROP TABLE IF EXISTS tempSRL;
DROP TABLE IF EXISTS SRL;
CREATE TABLE tempSRL_1 AS

		SELECT b.geom as geom, b.fosnr, b.gid, st_area(b.geom) as area
		FROM  bien_fonds_intersected b
		WHERE b.gid NOT IN
		(
			SELECT b.gid
			FROM batiment_h_point a, bien_fonds_intersected b
			WHERE ST_INTERSECTS(a.geom,b.geom)
			AND b.typstd IN ('ZRHD', 'ZRMD', 'ZRFD', 'ZM','ZV')
			AND b.fosnr = a.fosnr
			AND a.shape_area > 25
			UNION 
			SELECT DISTINCT b.gid
			FROM bien_fonds_intersected b, regbl c
			WHERE ST_INTERSECTS(c.geom,b.geom)
			AND b.typstd IN ('ZRHD', 'ZRMD', 'ZRFD', 'ZM','ZV')
			AND b.fosnr = c.gdenr
			-- AND c.gbauj > 2001 -- OPTIONNEL
		)
		AND b.typstd IN ('ZRHD', 'ZRMD', 'ZRFD', 'ZM','ZV');

-- On supprime les polygones dus à l'imprecision des données

DELETE 
FROM tempSRL_1
WHERE st_area(geom) < 1;


UPDATE tempSRL_1 SET geom = sliver_murder(sliver_killer(((st_dump(st_buffer(geom,0))).geom),10),0.1); -- ST_BUFFER necessaire sinon des zones disparaissent de façon random.


-- ON extrait la route et les revêtements dur (parking, etc...), les places de sport, les parcs publiques, les cimetières, les cours d'eau, les rivières
CREATE TABLE tempSRL as
with temp as 
(
  select   b.gid, st_union(a.geom) as geom
  from     tempSRL_1 b join couverture_sol a on st_intersects(a.geom, b.geom)
  where    a.type in (1,2,7) OR a.FR_GEN in (13,17,102,129,130,147)-- 
  group by b.gid
) 
select st_difference(b.geom,coalesce(t.geom, 'GEOMETRYCOLLECTION EMPTY'::geometry)) as geom
from tempSRL_1 b left join temp t on b.gid = t.gid;

-- ON ajoute les bouts de parcelle ayant une couverture du sol de type champ paturage ssi la parcelle possède un bâtiment.DROP TABLE IF EXISTS demiparcelle;


DROP TABLE IF EXISTS demiparcelle;
CREATE TABLE demiparcelle as
SELECT n.type,
   CASE 
   WHEN ST_CoveredBy(p.geom, n.geom) 
   THEN p.geom 
   ELSE 
    (ST_Dump(ST_Multi(
      ST_Intersection(p.geom,n.geom)
      ))).geom END AS geom 
 FROM bien_fonds_intersected AS p 
   INNER JOIN couverture_sol AS n 
    ON ST_Intersects(p.geom, n.geom)
    WHERE n.type = 8 -- CHAMP ET PATURAGE
    AND p.gid IN
    (
	SELECT b.gid
	FROM batiment_h_point a, bien_fonds_intersected b
	WHERE ST_INTERSECTS(a.geom,b.geom)
	AND b.typstd IN ('ZRHD', 'ZRMD', 'ZRFD', 'ZM','ZV')
	AND b.fosnr = a.fosnr
     )
;

ALTER TABLE demiparcelle
ADD COLUMN area double precision,
ADD COLUMN perim double precision,
ADD COLUMN ratio double precision,
ADD COLUMN gid SERIAL;

UPDATE demiparcelle set area = st_area(geom);
UPDATE demiparcelle set perim = st_perimeter(geom);
UPDATE demiparcelle set ratio = area^0.5/(perim+0.01);

DELETE FROM demiparcelle WHERE area < 400;
DELETE FROM demiparcelle WHERE ratio < 0.185;

--- ON COLLE demiparcelle et tempSRL ensemble
DROP TABLE IF EXISTS TEMP;

CREATE TABLE temp AS 
SELECT geom FROM tempSRL
union 
SELECT geom FROM demiparcelle;
DROP TABLE tempSRL;
ALTER TABLE temp
RENAME TO tempSRL;



ALTER TABLE tempSRL
ADD COLUMN gid SERIAL;

UPDATE  tempSRL   
SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(new.geom), 3)) 
FROM 
(
SELECT geom, gid
FROM  tempSRL   
WHERE ST_ISVALID( tempSRL.geom) = FALSE 
OR geometrytype(geom) != 'MULTIPOLYGON'
) as new
WHERE tempSRL.gid = new.gid;

-- DROP TABLE tempSRL_1;

-- Union sur les polygones adjacents

DROP TABLE IF EXISTs tempSRL2;
CREATE TABLE tempSRL2 AS
SELECT (st_dump(st_union(st_multi(st_buffer(st_snaptogrid(geom,0.0001),0))))).geom as geom
FROM
(
SELECT sliver_murder(sliver_killer(((st_dump(st_buffer(st_makevalid(geom),0))).geom),10),0.1) as geom
FROM tempSRL
WHERE st_isvalid(geom) 
) as t;


UPDATE tempSRL2
SET geom = sliver_killer(geom,20::float);
UPDATE tempSRL2
SET geom = sliver_murder(geom,0.1::float);

DROP TABLE IF EXISTS SRL;

CREATE TABLE SRL AS
SELECT (st_dump(st_union(st_multi(st_buffer(geom,0))))).geom as geom 
FROM
(
SELECT sliver_murder(sliver_killer(((st_dump(geom)).geom),10),0.1) as geom
FROM tempSRL2
WHERE st_isvalid(geom) 
) as t;

ALTER TABLE SRL
ADD COLUMN GID SERIAL;

-- La requête suivante indique les parcelles considérées comme libre pour l'instant mais qui se situe sur un jardin et touche une habitation
-- Le but étant d'éliminer les parcelles libre qui se situent en réalité sur un jardin privé.


-- LISTE LES PARCELLES QUI CONTIENNE AU MOINS 5% de jardin ET qui touchent un bâtiment. 
DROP TABLE IF EXISTS garden;
CREATE TABLE garden AS
with t1 as 
(
SELECT gid, count(gid)
FROM
(
SELECT DISTINCT a.gid, b.type
FROM SRL a, couverture_sol b
WHERE ST_INTERSECTS(a.geom,b.geom)
AND b.type in (0,11)
group by a.gid, b.type
) as t
group by gid
having count(gid) > 1
)

SELECT gid, sum(ratio) as ratio, area
FROM
(
SELECT a.gid, st_area(st_intersection(a.geom,b.geom))/st_area(a.geom) as ratio, st_area(a.geom) as area
FROM SRL a, couverture_sol b, t1
WHERE st_overlaps(a.geom,b.geom)
AND b.type = 11 
AND a.gid IN
(
t1.gid
)
) as t2
group by gid, area, ratio
having ratio > 0.05
order by area;


DROP TABLE IF EXISTS nogarden;
CREATE TABLE nogarden AS
with t1 as -- les GID dont le jardin touche le batiment
(
SELECT gid, count(gid)
FROM
(
SELECT DISTINCT a.gid, b.type
FROM SRL a, couverture_sol b
WHERE ST_INTERSECTS(a.geom,b.geom)
AND b.type in (0,11)
group by a.gid, b.type
having count(a.gid) > 1
) as t
group by gid
having count(gid) > 1
)


SELECT st_intersection(a.geom,b.geom) as geom
FROM SRL a, couverture_sol b, t1
WHERE st_overlaps(a.geom,b.geom)
AND b.type = 8
AND a.gid IN
(
t1.gid
)
AND b.FR_GEN not in (129,130) -- place de sport et jardin communautaire ne sont pas constructible, densifier ok, pourrir la vie urbaine non.
;

UPDATE nogarden 
SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(geom), 3));


-- ON SUPPRIME DE SRL LES PARCELLES QUI POSSEDENT AU MOINS 5% DE JARDIN ET QUI TOUCHENT UN BATIMENT, (éviter de considérer comme ZAB un jardin privé)
DELETE FROM SRL
WHERE gid in
(
SELECT a.gid
FROM garden a
WHERE a.ratio > 0.05
);

DROP TABLE IF EXISTS TEMP;


-- LA REQUÈTE JUSTE AU DESSUS SUPPRIME POTENTIELLEMENT AUTRE CHOSE QUE DES JARDINS QUI TOUCHENT UN BATIMENT, ON RECUPERE DONC CETTE PARTIE !

CREATE TABLE TEMP AS
SELECT geom FROM SRL
UNION
SELECT geom FROM NOGARDEN;

DROP TABLE SRL;
ALTER TABLE TEMP 
RENAME TO SRL;

DROP TABLE IF EXISTS TEMP;
CREATE TABLE TEMP AS
SELECT (st_dump(st_union(st_multi(st_buffer(geom,0))))).geom as geom 
FROM SRL;

DROP TABLE SRL;
ALTER TABLE TEMP 
RENAME TO SRL;







ALTER TABLE SRL
ADD COLUMN gid SERIAL;
DROP TABLE tempSRL;

UPDATE SRL
SET geom = sliver_killer(geom,20::float);
UPDATE SRL
SET geom = sliver_murder(geom,0.1::float);


-- On supprime les polygones qui disparaitraient si on appliquait un buffer de -5 m (mais on applique pas le buffer)
DELETE 
FROM SRL
WHERE GID IN
(
SELECT gid
FROM SRL 
WHERE st_area(st_buffer(geom,-5)) = 0
);


-- buffer de -8m BIM ça calme les parcelles inexploitables. 
-- PETIT TRICKS: l'option 'join=mitre' préserve les angles intactes mais augmentent parfois la taille du polygone (BUG), j'applique donc un st_intersection entre l'ancien et le nouveau
-- polygone afin d'éviter l'apparition de nouvelles surfaces. 

DROP TABLE IF EXISTS temp;
CREATE TABLE temp AS
with t1 as
(
SELECT st_buffer(ST_buffer(geom,-8,'join=mitre'),8,'join=mitre') as geom, gid
FROM SRL
)
SELECT st_intersection(t1.geom,a.geom) as geom, t1.gid
FROM t1, SRL a
WHERE t1.gid = a.gid;

DROP TABLE SRL;
ALTER TABLE TEMP 
RENAME TO SRL;


ALTER TABLE SRL
ADD COLUMN AREA double precision;
UPDATE SRL SET AREA = st_area(GEOM);

DELETE FROM SRL 
WHERE ST_AREA(GEOM) < 300;


/* ETAPE 8: On supprime les bouts de SR15 qui sont recouverte par des SRL, typiquement un champ jouxtant une maison et faisant partie de la même parcelle*/

DROP TABLE IF EXISTS temp;

CREATE TABLE temp AS

with temp as 
(
  select   b.gid, st_union(a.geom) as geom
  from     SR15 b join SRL a on st_intersects(a.geom, b.geom)
  group by b.gid
) 

select (st_dump(st_difference(b.geom,coalesce(t.geom, 'GEOMETRYCOLLECTION EMPTY'::geometry)))).geom as geom
from SR15 b left join temp t on b.gid = t.gid;

UPDATE temp SET GEOM = (st_dump(st_buffer(st_buffer(geom,-3),3))).geom
WHERE abs(st_area(st_buffer(st_buffer(geom,-3),3))-st_area(geom)) > 35;

DELETE FROM temp 
WHERE st_area(geom) < 300;

ALTER TABLE temp 
ADD COLUMN gid SERIAL,
ADD COLUMN FOSNR integer,
ADD COLUMN AREA double precision;

UPDATE temp SET FOSNR = t.fosnr
FROM
(
SELECT b.fosnr, a.gid as gid
FROM temp a,commune b
WHERE st_contains(b.geom,st_centroid(a.geom))
) as t
WHERE temp.gid = t.gid;

UPDATE temp SET AREA = st_area(geom);

DROP TABLE SR15;

ALTER TABLE temp
RENAME TO SR15;

/* ETAPE 9: DUMP de la SRL + ELIMINATION DES POLYGONES TROP COMPLEXE. */
DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'DUMP de la SRL + ELIMINATION DES POLYGONES TROP COMPLEXE'; END $$;

DROP TABLE IF EXISTS TEMP;

CREATE TABLE TEMP AS
SELECT (st_dump(geom)).geom AS GEOM 
FROM SRL;

ALTER TABLE TEMP 
ADD COLUMN FOSNR integer,
ADD COLUMN AREA double precision,
ADD COLUMN LENG double precision,
ADD COLUMN RATIO double precision,
ADD COLUMN GID SERIAL;

UPDATE TEMP SET FOSNR = t.fosnr
FROM
(
SELECT b.fosnr, a.gid as gid
FROM TEMP a,commune b
WHERE st_contains(b.geom,st_centroid(a.geom))
) as t
WHERE TEMP.gid = t.gid;

UPDATE TEMP SET AREA = ST_AREA(GEOM);
UPDATE TEMP SET LENG = ST_PERIMETER(GEOM);
UPDATE TEMP SET RATIO = sqrt(AREA)/LENG;

DROP TABLE SRL; 

ALTER TABLE TEMP
RENAME TO SRL;

-- ON AJOUTE LA SRL A LA COMMUNE + CALCULE DU RATIO SRL/SR15.

UPDATE COMMUNE SET SRL = t1.area
FROM
(
	SELECT sum(st_area(geom)) as area, fosnr
	FROM SRL
	group by fosnr
	order by fosnr
) as t1
WHERE t1.FOSNR = commune.FOSNR;

ALTER TABLE COMMUNE
DROP COLUMN IF EXISTS RATIO;
ALTER TABLE COMMUNE
ADD RATIO double precision;

UPDATE COMMUNE SET RATIO = SRL/SR15;

-- ON AJOUTE A LA COMMUNE L'AIRE TOTALE DE LA SR15 PAR COMMUNE

		
UPDATE COMMUNE SET sr15 = t.sr15
FROM
(
SELECT sum(st_area(geom)) as sr15, FOSNR
FROM sr15
GROUP BY FOSNR
) t
WHERE t.FOSNR = commune.FOSNR


-- ON AJOUTE UN ATTRIBUT POUR DIFFERENCIER LES PARCELLES ENTIERES ET LES DEMI-PARCELLES

ALTER TABLE SRL
ADD COLUMN COMPOSITION integer;

UPDATE SRL
SET COMPOSITION = 0;

UPDATE SRL
SET COMPOSITION = 1
WHERE GID IN
(
SELECT a.gid FROM SRL a, demiparcelle b
WHERE st_overlaps(a.geom,b.geom)
);

-- SUPPRESSION DES POLYGONS COMPLEXES

DELETE FROM SRL
WHERE RATIO < 0.12 AND AREA < 5000;

DELETE FROM SRL
WHERE RATIO < 0.1;

-- On supprime une dernière fois les polygones SRL de moins de 300 m^2

DELETE FROM SRL
WHERE AREA < 300;


/* ETAPE 10: Au besoin on coupe les polygones SRL et SR15 avec les zones d'affectations pour connaître quelle parcelle appartient à quelle type.

DROP VIEW IF EXISTS V1;
DROP VIEW IF EXISTS V2;
DROP TABLE IF EXISTS SR15_intersected;
DROP TABLE IF EXISTS SRL_intersected;

-----------------------------------------------------------------
CREATE TABLE SR15_intersected AS
SELECT n.fosnr,p.TYPSTD
 , CASE 
   WHEN ST_CoveredBy(p.geom, n.geom) 
   THEN p.geom 
   ELSE 
    ST_Multi(
      ST_Intersection(p.geom,n.geom)
      ) END AS geom 
 FROM affectation_com AS p 
   INNER JOIN SR15 AS n 
    ON ST_Intersects(p.geom, n.geom);

UPDATE  SR15_intersected   
SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(geom), 3));

-----------------------------------------------------------------
CREATE TABLE SRL_intersected AS
SELECT n.fosnr,p.TYPSTD
 , CASE 
   WHEN ST_CoveredBy(p.geom, n.geom) 
   THEN p.geom 
   ELSE 
    ST_Multi(
      ST_Intersection(p.geom,n.geom)
      ) END AS geom 
 FROM affectation_com AS p 
   INNER JOIN SRL AS n 
    ON ST_Intersects(p.geom, n.geom);

UPDATE  SRL_intersected   
SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(geom), 3));

-----------------------------------------------------------------
CREATE VIEW V1 AS
WITH
t1 AS 
(
SELECT sum(st_area(b.geom)) as sum
FROM SR15_intersected b, commune c
WHERE b.typstd = 'ZM'
AND st_intersects(b.geom,c.geom)
AND c.complet__d < '2001-01-01'
)

SELECT t1.sum/sum(st_area(a.geom)) as sum
FROM t1,SR15_intersected a, commune c
WHERE st_intersects(a.geom,c.geom)
AND c.complet__d < '2001-01-01'
group by t1.sum;

-----------------------------------------------------------------
CREATE VIEW V2 AS
WITH
t1 AS 
(
SELECT sum(st_area(b.geom)) as sum
FROM SRL_intersected b, commune c
WHERE b.typstd = 'ZM'
AND st_intersects(b.geom,c.geom)
AND c.complet__d < '2001-01-01'
)

SELECT t1.sum/sum(st_area(a.geom)) as sum
FROM t1,SRL_intersected a, commune c
WHERE st_intersects(a.geom,c.geom)
AND c.complet__d < '2001-01-01'
group by t1.sum;

-----------------------------------------------------------------
-- SELECT a.sum*100 as sum_sr15, b.sum*100 as sum_srl FROM V1 a,V2 b
*/