/*
CETTE QUERY SE CHARGE DE CREER LES FRONTIERES COMMUNALES DE FACON A CE QUE CES FRONTIERES SOIENT COMPATIBLES AVEC LES ZONES DE ZONE_COMM

INPUT:
	- commune_ancienne 		% La couche contenant les anciennes communes
	- oca8000_suivipal_commune	% La couche des communes actuelles
	- affectation_com_old		% La couche des données d'affectation (plus simple de prendre la "old" car regroupe tout)

OUTPUT:
	- commune_seca
		* GID			% L'identifiant unique
		* SHAPE_Length		% La longueur du périmètre 
		* SHAPE_Area		% La surface
		* FOSNR			% Le numéro de commune compatible ZONE_COMM, issue des anciennes communes
		* FOSNR_SUIVIPAL	% Le numéro de commune actuelle de suivipal
		* GEOM			% La géométrie
	
*/

SELECT UpdateGeometrySRID('public','commune_ancienne','geom',21781);
SELECT UpdateGeometrySRID('public','affectation_com_old','geom',21781);
SELECT UpdateGeometrySRID('public','oca8000s_suivipal_commune','geom',21781);

DROP TABLE IF EXISTS testtable;


CREATE TABLE testtable AS
  (WITH temptable AS
     (SELECT fosnr,
             st_union(geom) AS geom
      FROM
        (SELECT b.secteur,
                count(a.fosnr),
                a.fosnr,
                b.geom
         FROM affectation_com_old a,
              commune_ancienne b
         WHERE st_intersects(st_centroid(a.geom),b.geom)
         GROUP BY b.secteur,
                  a.fosnr,
                  b.geom
         HAVING count(a.fosnr) > 3
         ORDER BY secteur) AS res
      GROUP BY fosnr) SELECT fosnr,
                             st_union(geom) AS geom
   FROM
     (SELECT b.fosnr,
             a.geom
      FROM commune_ancienne a,
           oca8000s_suivipal_commune b
      WHERE st_intersects(st_centroid(a.geom),b.geom)
        AND a.num IN
          (SELECT num AS FOSNR
           FROM commune_ancienne
           WHERE num NOT IN
               (SELECT c.num AS FOSNR
                FROM commune_ancienne c,
                     temptable t
                WHERE st_intersects(st_centroid(c.geom),t.geom) ) )
        AND fosnr IN
          (SELECT num
           FROM commune_ancienne)
      UNION SELECT *
      FROM temptable) AS t1
   GROUP BY fosnr);


DROP TABLE IF EXISTS commune_seca;


CREATE TABLE commune_seca AS
  (WITH tripletemp AS
     (WITH doubletemp AS
        (WITH temptable AS
           (-- Liste les communes adjacentes aux communes de commune_ancienne qui ne sont pas encore ajouté à la table commune_seca
 SELECT a.geom,
        a.num,
        b.fosnr,
        b.geom AS geom_adj
            FROM commune_ancienne a,
                 testtable b
            WHERE st_intersects(a.geom,b.geom)
              AND a.NUM NOT IN
                (-- Liste les fosnr de commune_ancienne qui sont déjà ajouté à la table commune_seca (testtable)
 SELECT a.num
                 FROM commune_ancienne a,
                      testtable b
                 WHERE st_intersects(st_centroid(a.geom),b.geom) ) ) SELECT t.*,
                                                                            b.fosnr AS fosnr_vide
         FROM temptable t,
              oca8000s_suivipal_commune b
         WHERE st_intersects(st_centroid(t.geom),b.geom) ) SELECT dt.*,
                                                                  b.fosnr AS fosnr_plein
      FROM doubletemp dt,
           oca8000s_suivipal_commune b
      WHERE st_intersects(st_centroid(dt.geom_adj),b.geom) ) SELECT st_union(geom) AS geom,
                                                                    fosnr
   FROM
     (SELECT geom,
             fosnr
      FROM tripletemp
      WHERE fosnr_vide = fosnr_plein
      UNION SELECT geom,
                   fosnr
      FROM testtable) AS t
   GROUP BY FOSNR);


DROP TABLE IF EXISTS testtable;


DROP TABLE IF EXISTS TODELETE;


DROP TABLE IF EXISTS TODELETE2;


CREATE TABLE TODELETE AS
SELECT a.FOSNR,
       b.FOSNR AS FOSNR_ancien,
       st_intersection(a.geom,
                       b.geom) AS geom
FROM oca8000s_suivipal_commune a,
     commune_seca b
WHERE st_intersects(a.geom,
                    b.geom);


DROP TABLE IF EXISTS TEMP;


CREATE TABLE TEMP AS
SELECT FOSNR,
       FOSNR_ancien, (st_dump(geom)).geom AS geom
FROM TODELETE;


DROP TABLE TODELETE;


ALTER TABLE TEMP RENAME TO TODELETE;


UPDATE TODELETE
SET FOSNR_ANCIEN = FOSNR
WHERE st_area(geom) < 200000
  AND FOSNR IN
    (SELECT DISTINCT FOSNR
     FROM commune_seca);


UPDATE todelete
SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(ST_CollectionExtract(geom,3)), 3));


DELETE
FROM todelete
WHERE st_area(geom) < 0.1;


CREATE TABLE TODELETE2 AS
SELECT FOSNR_ANCIEN AS FOSNR,
       st_union(geom) AS geom
FROM TODELETE
GROUP BY FOSNR_ANCIEN;


ALTER TABLE TODELETE2 ADD COLUMN gid serial;


DROP TABLE IF EXISTS todelete3;


DROP TABLE IF EXISTS TEMP1;


DROP TABLE IF EXISTS TEMP2;


DROP TABLE IF EXISTS TEMP3;


CREATE TABLE todelete3 AS
  (SELECT row_number() over (
                             ORDER BY geom,fosnr,area) AS gid,
          fosnr,
          geom,
          area
   FROM
     (SELECT fosnr, (st_dump(geom)).geom,
                                    st_area((st_dump(geom)).geom) AS area
      FROM todelete2) AS res);

-- LE RESTE DE LA QUERY CONSISTE A COLLER A LA BONNE COMMUNE LES RESIDUS DE TERRITOIRE DONT LE FOSNR EST FAUX !

CREATE TABLE TEMP1 AS
  (SELECT *
   FROM
     (SELECT DISTINCT ON(GID) GID,
                      FOSNR,
                      ST_AREA
      FROM
        (SELECT a.FOSNR,
                ST_AREA(st_intersection(a.geom,b.geom)),
                b.GID
         FROM oca8000s_suivipal_commune a,
              todelete3 b
         WHERE st_intersects(a.geom,b.geom) ) AS t
      ORDER BY GID,
               ST_AREA DESC) AS res
   ORDER BY gid);


CREATE TABLE TEMP2 AS
SELECT a.gid AS pgid,
       b.gid AS ggid
FROM
  (SELECT *
   FROM todelete3
   WHERE area < 200000) AS a,

  (SELECT *
   FROM todelete3
   WHERE area > 200000) AS b
WHERE st_intersects(a.geom,
                    b.geom);


CREATE TABLE TEMP3 AS
SELECT PGID AS GID,
       FOSNR
FROM
  (SELECT *
   FROM
     (SELECT res.*,
             TEMP1.FOSNR AS GFOSNR
      FROM
        (SELECT TEMP2.*,
                TEMP1.FOSNR AS PFOSNR
         FROM TEMP2
         INNER JOIN TEMP1 ON (TEMP2.pgid = temp1.gid)) AS res
      INNER JOIN TEMP1 ON (res.ggid = temp1.gid)) AS res2
   INNER JOIN TODELETE3 ON (res2.ggid = TODELETE3.gid)) AS res3
WHERE pfosnr = gfosnr
ORDER BY gid;


UPDATE todelete3
SET FOSNR = TEMP3.FOSNR
FROM TEMP3
WHERE TEMP3.gid = todelete3.gid;


DROP TABLE IF EXISTS commune_seca;


CREATE TABLE commune_seca AS
SELECT FOSNR AS FOSNR,
       st_union(geom) AS geom
FROM TODELETE3
GROUP BY FOSNR;


SELECT UpdateGeometrySRID('public','commune_seca','geom',21781);


UPDATE commune_seca
SET GEOM = ST_Buffer(ST_Buffer(geom,0.1,'join=mitre'),-0.1,'join=mitre');


DROP TABLE IF EXISTS TODELETE;


DROP TABLE IF EXISTS TODELETE2;


DROP TABLE IF EXISTS TODELETE3;


DROP TABLE IF EXISTS TEMP1;


DROP TABLE IF EXISTS TEMP2;


DROP TABLE IF EXISTS TEMP3;

-- DERNIERE PARTIE ON CORRIGE LES LIMITES COMMUNALES EXTERIEURES (donc les limites qui ne sont pas en contact avec d'autres communes)

DROP TABLE IF EXISTS TEMP;


CREATE TABLE TEMP AS
SELECT (st_dump(st_difference(b.geom,st_buffer(st_buffer(st_union(a.geom),0.5,'join=mitre'),-0.5,'join=mitre')))).geom AS geom,
                                                                                                                  b.gid
FROM oca8000s_suivipal_commune b,
     commune_seca a
WHERE ST_INTERSECTS(a.geom,
                    b.geom)
  AND b.NAME NOT like('Staat%')
GROUP BY b.geom,
         b.gid;


ALTER TABLE TEMP ADD COLUMN FOSNR integer;


UPDATE TEMP
SET FOSNR = 1;


UPDATE TEMP
SET GEOM = ST_Multi(ST_CollectionExtract(ST_MakeValid(st_collectionextract(geom,3)), 3));


CREATE TABLE TEMP1 AS
SELECT DISTINCT ON (gid) gid,
                   count(fosnr), fosnr
FROM
  (SELECT a.gid,
          b.fosnr
   FROM TEMP a,
             commune_seca b
   WHERE st_intersects(a.geom,b.geom) ) AS res
GROUP BY fosnr,
         gid
ORDER BY gid,
         COUNT DESC;


ALTER TABLE TEMP ADD COLUMN FOSNR_LINK INTEGER;


UPDATE TEMP
SET FOSNR_LINK = TEMP1.FOSNR
FROM TEMP1
WHERE TEMP.gid = TEMP1.gid;


DROP TABLE TEMP1;


DELETE
FROM TEMP
WHERE st_area(geom) < 0.01;


CREATE TABLE TEMP1 AS
SELECT fosnr,
       st_union(geom)
FROM
  (SELECT fosnr_link AS fosnr,
          geom
   FROM TEMP
   UNION SELECT fosnr,
                geom
   FROM commune_seca) AS res
GROUP BY fosnr;


DROP TABLE TEMP1;


CREATE TABLE TEMP1 AS
SELECT fosnr::smallint,
       st_buffer(st_buffer(st_union(geom),0.8,'join=mitre'),
                 -0.8,
                 'join=mitre') AS geom
FROM
  (SELECT fosnr_link AS fosnr,
          geom
   FROM TEMP
   UNION SELECT fosnr,
                geom
   FROM commune_seca) AS res
GROUP BY fosnr;


DROP TABLE commune_seca;


ALTER TABLE TEMP1 RENAME TO commune_seca;


ALTER TABLE commune_seca ADD COLUMN GID SERIAL;


DROP TABLE IF EXISTS TEMP;


CREATE TABLE TEMP AS
SELECT commune_seca.*,
       res.fosnr::smallint AS FOSNR_SUIVIPAL
FROM commune_seca
INNER JOIN
  (SELECT *
   FROM
     (SELECT DISTINCT ON(GID) GID,
                      FOSNR,
                      ST_AREA
      FROM
        (SELECT a.FOSNR,
                ST_AREA(st_intersection(a.geom,b.geom)),
                b.GID
         FROM oca8000s_suivipal_commune a,
              commune_seca b
         WHERE st_intersects(a.geom,b.geom) ) AS t
      ORDER BY GID,
               ST_AREA DESC) AS res) AS res ON res.GID = commune_seca.gid;


DROP TABLE IF EXISTS commune_seca;


ALTER TABLE TEMP RENAME TO commune_seca;


SELECT UpdateGeometrySRID('public','commune_seca','geom',21781);


ALTER TABLE commune_seca ADD COLUMN SHAPE_Length float, ADD COLUMN SHAPE_Area float, ADD COLUMN name character varying(50);


UPDATE commune_seca
SET SHAPE_Length = st_perimeter(geom);


UPDATE commune_seca
SET SHAPE_Area = st_area(geom);


UPDATE commune_seca
SET name = a.name
FROM
  (SELECT secteur_mi AS name,
          num AS fosnr
   FROM commune_ancienne
   UNION SELECT name AS name,
                fosnr AS fosnr
   FROM oca8000s_suivipal_commune
   WHERE fosnr NOT IN
       (SELECT num
        FROM commune_ancienne)
   ORDER BY fosnr) a
WHERE commune_seca.fosnr = a.fosnr;


DROP TABLE IF EXISTS TODELETE;


DROP TABLE IF EXISTS TODELETE2;


DROP TABLE IF EXISTS TODELETE3;


DROP TABLE IF EXISTS TEMP;


DROP TABLE IF EXISTS TEMP1;


DROP TABLE IF EXISTS TEMP2;


DROP TABLE IF EXISTS TEMP3;

-- REATTRIBUTION DE QUELQUES RESIDUS RECALCITRANT.

DROP TABLE IF EXISTS TEMP;


CREATE TABLE TEMP AS
  (WITH residu AS
     (SELECT geom,
             fosnr,
             fosnr_suivipal,
             gid,
             name
      FROM
        (SELECT (st_dump(geom)).geom,
                                fosnr,
                                fosnr_suivipal,
                                gid,
                                commune_seca.name
         FROM commune_seca) AS res
      GROUP BY geom,
               fosnr,
               fosnr_suivipal,
               gid,
               name
      HAVING st_area(geom) < 100000) SELECT DISTINCT ON(st_area) t.geom,
                                                     t.newname AS name,
                                                     t.fosnr,
                                                     t.fosnr_suivipal,
                                                     t.gid
   FROM
     (SELECT st_perimeter(st_multi(ST_Intersection(st_buffer(a.geom,1), b.geom))),
             a.name,
             b.name AS newname,
             b.fosnr,
             b.fosnr_suivipal,
             b.gid,
             st_area(a.geom),
             a.geom AS geom
      FROM residu a,
           commune_seca b
      WHERE a.gid != b.gid
        AND st_perimeter(st_multi(ST_Intersection(st_buffer(a.geom,1), b.geom))) > 0
      ORDER BY st_area(a.geom),
               st_perimeter DESC) t
   UNION
     (SELECT geom,
             name,
             fosnr,
             fosnr_suivipal,
             gid
      FROM
        (SELECT (st_dump(geom)).geom,
                                fosnr,
                                fosnr_suivipal,
                                gid,
                                name
         FROM commune_seca) AS res
      GROUP BY geom,
               fosnr,
               fosnr_suivipal,
               gid,
               name
      HAVING st_area(geom) > 100000
      ORDER BY gid)
   UNION
     (WITH residu AS
        (SELECT geom,
                fosnr,
                fosnr_suivipal,
                gid,
                name
         FROM
           (SELECT (st_dump(geom)).geom,
                                   fosnr,
                                   fosnr_suivipal,
                                   gid,
                                   commune_seca.name
            FROM commune_seca) AS res
         GROUP BY geom,
                  fosnr,
                  fosnr_suivipal,
                  gid,
                  name
         HAVING st_area(geom) < 100000) SELECT DISTINCT ON(st_area) t.geom,
                                                        t.newname AS name,
                                                        t.fosnr,
                                                        t.fosnr_suivipal,
                                                        t.gid
      FROM
        (SELECT st_perimeter(st_multi(ST_Intersection(st_buffer(a.geom,1), b.geom))),
                a.name AS newname,
                b.name,
                a.fosnr,
                a.fosnr_suivipal,
                a.gid,
                st_area(a.geom),
                a.geom AS geom
         FROM residu a,
              commune_seca b
         WHERE a.gid != b.gid
           AND st_perimeter(st_multi(ST_Intersection(st_buffer(a.geom,1), b.geom))) = 0
         ORDER BY st_area(a.geom),
                  st_perimeter DESC) t));


DROP TABLE IF EXISTS COMMUNE_SECA;


CREATE TABLE COMMUNE_SECA AS 
   WITH t1 AS
  (SELECT st_union(geom) AS geom,
          name,
          fosnr,
          fosnr_suivipal,
          gid
   FROM TEMP
   GROUP BY name,
            fosnr,
            fosnr_suivipal,
            gid)
            
SELECT t1.*,
       st_perimeter(t1.geom) AS SHAPE_Length,
       st_area(t1.geom) AS SHAPE_Area
FROM t1;

DROP TABLE IF EXISTS TEMP;

CREATE TABLE TEMP AS
SELECT st_multi(st_union(geom)) as geom, fosnr, fosnr_suivipal, gid, name, st_perimeter(st_multi(st_union(geom))) as SHAPE_Length, st_area(st_multi(st_union(geom))) as SHAPE_Area
FROM
(
SELECT *, st_area(geom) FROM
(
        SELECT (st_dump(geom)).geom,
                                fosnr,
                                fosnr_suivipal,
                                gid,
                                name
        FROM commune_seca
) as T1
WHERE st_area(geom) > 10000
order by gid
) as T2
group by fosnr, fosnr_suivipal, gid, name;

DROP TABLE commune_seca;

ALTER TABLE TEMP RENAME TO COMMUNE_PAL;