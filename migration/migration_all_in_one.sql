/* 

LE SCRIPT SUIVANT PERMET D'EFFECTUER LA MIGRATION DES DONNEES d'AFFECTATION AFIN DE RENDRE COMPATIBLE CES DONNEES AVEC LE MGDM FEDERAL 

* LES TABLES NECESSAIRES SONT LES SUIVANTES:

	- affectation_com_old 		(affectation_com)
	- oca8000s_suivipal_commune
	- zone_comm_old 		(zone_comm)
	
* TEMPS D'EXECUTION:

	- Environ 420 secondes
	
*/



DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Début de l''operation'; END $$;

-- On affecte le bon SRID à toutes les couches qui possèdent une géomètrie:

SELECT UpdateGeometrySRID('public','affectation_com_old','geom',21781);
SELECT UpdateGeometrySRID('public','oca8000s_suivipal_commune','geom',21781);

 -- Creation des fonctions de nettoyage des données.
 -- Sliver Killer et Sliver Murder 
 -- ETAPE 1: On dézingue les slivers enclavée dans un polygone

CREATE OR REPLACE FUNCTION sliver_killer(geometry,float) RETURNS geometry AS $$
SELECT ST_BuildArea(ST_Collect(a.geom)) AS final_geom
FROM ST_DumpRings($1) AS a
WHERE a.path[1] = 0
  OR (a.path[1] > 0
      AND ST_Area(a.geom) > $2) $$ LANGUAGE 'sql' IMMUTABLE;

 -- ETAPE 2: On dézingue les slivers qui touchent le bord du polygone.

CREATE OR REPLACE FUNCTION sliver_murder(geometry,float) RETURNS geometry AS $$
SELECT ST_Buffer(ST_Buffer($1,$2,'join=mitre'),-$2,'join=mitre') AS geom $$ LANGUAGE 'sql' IMMUTABLE;

 -- On renomme NUFECO par FOSNR afin d'uniformiser la nomenclature entre SUIVIPAL et l'affectation
 /* SEULEMENT LA PREMIERE FOIS ! 
 	ALTER TABLE affectation_com_old
	RENAME COLUMN NUFECO TO FOSNR;

	ALTER TABLE affectation_com_old
	RENAME COLUMN NUFECO_ZON TO FOSNR_zon;

	ALTER TABLE zone_comm_old
	RENAME COLUMN NUFECO_ZON TO FOSNR_ZON;

	ALTER TABLE zone_comm_old
	RENAME COLUMN NUFECO TO FOSNR; */
  -- CREATION D'AFFECTATION_COM_NEW

DROP TABLE IF EXISTS affectation_com_new;


SELECT * INTO affectation_com_new
FROM affectation_com_old;


ALTER TABLE affectation_com_new
DROP COLUMN ZPAD,
DROP COLUMN ZPED,
DROP COLUMN NUREGPAD,
DROP COLUMN ETAT_PAD,
-- DROP COLUMN SENSIBLESP, 
DROP COLUMN SURF_SECT,
-- DROP COLUMN OBJECTID,
DROP COLUMN LIEU,
DROP COLUMN NOSECT,
DROP COLUMN PLANAFF,
DROP COLUMN DATPLAN,
DROP COLUMN DEROGATION,
 -- A double avec shape_area.
 -- DROP COLUMN TYPPROT, TYPPROT DEVRA ETRE A TERME SUPPRIMER
ADD COLUMN TYPSTD_2015 character varying(6),
ADD COLUMN CODE_TYPE smallint;


 -- PLANAFF est déjà présent dans SUIVIPAL, de plus modification signifie
 -- que la zone est en cours de modificiation mais pas qu'elle a été modifié
 -- La préservation de cette attribut porte plus à confusion qu'elle ne rend service.
 -- Les requêtes ci-dessous sont donc commentées.
 
/*

	UPDATE affectation_com_new
	SET STATUTJURIDIQUE = 'En vigueur'
	WHERE PLANAFF = 'APP';

	UPDATE affectation_com_new
	SET STATUTJURIDIQUE = 'Modification'
	WHERE PLANAFF = 'MOD';

*/

ALTER TABLE affectation_com_new RENAME COLUMN DATSAI TO DATESAISIE;


ALTER TABLE affectation_com_new RENAME COLUMN operat TO OPERATEUR;


ALTER TABLE affectation_com_new RENAME COLUMN FOSNR_zon TO FOSNR_ZONE;


ALTER TABLE affectation_com_new RENAME COLUMN remarq TO REMARQUES;


UPDATE affectation_com_new
SET TYPSTD_2015 = TYPSTD
WHERE TYPSTD IN ('ZA',
                 'ZACT',
                 'ZG',
                 'ZIG',
                 'ZL',
                 'ZM',
                 'ZRFD',
                 'ZRMD',
                 'ZRHD',
                 'ZRS',
                 'ZV',
                 'ZVI',
                 'ZCP');

UPDATE affectation_com_new
SET CODE_TYPE = 441
WHERE TYPSTD = 'F';
UPDATE affectation_com_new
SET CODE_TYPE = 121
WHERE TYPSTD = 'ZACT';
UPDATE affectation_com_new
SET CODE_TYPE = 491
WHERE TYPSTD = 'ZG';
UPDATE affectation_com_new
SET CODE_TYPE = 151
WHERE TYPSTD = 'ZIG';
UPDATE affectation_com_new
SET CODE_TYPE = 161
WHERE TYPSTD = 'ZL';
UPDATE affectation_com_new
SET CODE_TYPE = 131
WHERE TYPSTD = 'ZM';
UPDATE affectation_com_new
SET CODE_TYPE = 111
WHERE TYPSTD = 'ZRFD';
UPDATE affectation_com_new
SET CODE_TYPE = 112
WHERE TYPSTD = 'ZRMD';
UPDATE affectation_com_new
SET CODE_TYPE = 113
WHERE TYPSTD = 'ZRHD';
UPDATE affectation_com_new
SET CODE_TYPE = 114
WHERE TYPSTD = 'ZRS';
UPDATE affectation_com_new
SET CODE_TYPE = 141
WHERE TYPSTD = 'ZV';
UPDATE affectation_com_new
SET CODE_TYPE = 231
WHERE TYPSTD = 'ZVI';
UPDATE affectation_com_new
SET CODE_TYPE = 142
WHERE TYPSTD = 'ZCP';
-- 	Le cas du TYPSTD = F (Aire FORESTIERE) est traité à part dans le mesure ou ces aires forestières devront
--	être complété (à l'aide du SFF par exemple)
 
UPDATE affectation_com_new 
SET 	TYPSTD_2015 = 'F',
	CODE_TYPE = 441
WHERE TYPSTD = 'F';



UPDATE affectation_com_new
SET 	TYPSTD_2015 = 'ZTL',
	CODE_TYPE = 171
WHERE TYPSTD = 'ZC';

 -- PADIV devient ZA + Un perimètre de protection PADIV

UPDATE affectation_com_new
SET 	TYPSTD_2015 = 'ZA',
	CODE_TYPE = 211
WHERE TYPSTD = 'PADIV';

-- La query suivante pourrait aussi être placée dans le fichier SQL 1.1
-- et ne pas renommer les zones mais les sortir en superposition.

UPDATE affectation_com_new
SET 	TYPSTD_2015 = 'ZPCE',
	CODE_TYPE = 312
WHERE TYPSTD = 'ZPCE'
  OR (TYPSTD = 'ZP'
      AND TYPPROT = 'EAU');

 -- ZPBC devient ZCP (Zone de centre protéger) (A discuter) mais je pense qu'ici ça doit rester une affectation
 -- primaire
 
UPDATE affectation_com_new 
SET 	TYPSTD_2015 = 'ZCP',
	CODE_TYPE = 142
WHERE TYPSTD = 'ZPBC' 
  OR (TYPSTD = 'ZP'
      AND TYPPROT = 'ZPBC');

 -- Les périmètres d'habitats ruraux et périmètre d'habitats à maintenir sont transférer en zone agricole + périmètre de protection PHM.
-- (A DISCUTER, eventuellement creer une zone de protection à la place)

UPDATE affectation_com_new
SET 	TYPSTD_2015 = 'ZA',
	CODE_TYPE = 211
WHERE TYPSTD IN ('PHR');



-- La zone spéciale (ZSP) correspond à l'article 18 al. 1 LAT, la correspondance dans le nouveau modèle équivaut à de l'"Autre zone à l'extérieur des zones à bâtir" (AZE)
-- La zone sans affectation (ZSA) est une ancienne zone qui ne trouve plus et surtout ne recquière pas de trouver une correspondance dans le nouveau modèle. Cette zone est donc supprimer et sera
-- par la suite affecter à de la zone agricole (ZA).

UPDATE affectation_com_new
SET 	TYPSTD_2015 = 'AZE',
	CODE_TYPE = 499
WHERE TYPSTD IN ('ZSP'); 


 /*UNE FOIS LE PROCESSUS TERMINE DE COPIE/TRANSFORMATION/EXTRACTION/SUPPRESSION du TYPSTD
	  ON SUPPRIME L'ANCIEN TYPSTD ET ON LE REMPLACE PAR LE NOUVEAU
	  
	ALTER TABLE affectation_com_new 
	DROP COLUMN TYPSTD; 
	
	ALTER TABLE affectation_com_new
	RENAME COLUMN TYPSTD_2015 TO TYPSTD;
	
	*/ /*ATTENTION: LA PARTIE SUIVANTE EST EN PHASE DE TESTE: Récupération des 
	- route
	- forêt
	- champ
	dans le but d'atteindre une couverture complète du territoire
	les données sont extraites de la couverture du sol. */ /*
	INSERT INTO affectation_com_new (geom,typstd_2015,shape_leng,shape_area)
	SELECT cs.geom,
	cs.type,
	cs.shape_leng,
	cs.shape_area
	FROM couverture_sol_sans_aff cs
	WHERE cs.type = 17 -- FORET
	OR cs.type = 8 -- CHAMP
	OR cs.type = 1; -- ROUTE

	UPDATE affectation_com_new
	SET TYPSTD_2015 = 'F'
	WHERE TYPSTD_2015 = '17';

	UPDATE affectation_com_new
	SET TYPSTD_2015 = 'ZA'
	WHERE TYPSTD_2015 = '8';

	UPDATE affectation_com_new
	SET TYPSTD_2015 = 'ZTE'
	WHERE TYPSTD_2015 = '1';


*/ DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Fin de création affectation_com sans merge'; END $$;














 /*CREATION DU NOUVEAU LAYER superposition_affectation
Seul les PED et les périmètres spéciaux sont extrait, les PAD sont déjà dans SUIVIPAL.
*/
DROP TABLE IF EXISTS superposition_affectation CASCADE;


CREATE TABLE superposition_affectation ( geom geometry(MultiPolygon), FOSNR smallint, DATESAISIE date, forceobligatoire character varying(50), shape_leng numeric, shape_area numeric, remarques character varying(200), operateur character varying(50), typsupaff character varying(10), fosnr_code character varying(20),code_type smallint);


INSERT INTO superposition_affectation (geom,FOSNR, DATESAISIE, remarques,operateur,typsupaff,fosnr_code,code_type)
SELECT geom,
       FOSNR::smallint,
       datsai,
       remarq,
       operat,
       'PED',
       concat_ws('_',fosnr,'631'),
       631
FROM affectation_com_old
WHERE zped = 'oui';


UPDATE superposition_affectation
SET shape_area = st_area(geom),
    shape_leng = st_perimeter(geom);

-- On ajoute les secteur à préscription particulière (la donnée se trouve dans les remarques d'affectation_com)
INSERT INTO superposition_affectation (geom,FOSNR,DATESAISIE, remarques,operateur,typsupaff,fosnr_code,code_type)
SELECT geom,
       FOSNR::smallint,
       datsai,
       remarq,
       operat,
       'SPP',
       concat_ws('_',fosnr,'691'),
       691
FROM affectation_com_old
WHERE (lower(REMARQ) LIKE '%spez%'
       OR lower(REMARQ) LIKE '%presc%'
       OR lower(REMARQ) LIKE '%présc%'
       OR lower(REMARQ) LIKE '%prescr%'
       OR lower(REMARQ) LIKE '%prescri%'
       OR lower(REMARQ) LIKE '%partic%'
       OR lower(REMARQ) LIKE '%bestim%')
AND lower(REMARQ) NOT LIKE '%mesures partic%'

ORDER BY REMARQ;



-- DELETE les ROW ou TYPSTD = PHM  ET LES PLACE DANS UN SECTEUR SUPERPOSE PHM.
 -- IDEM POUR TYPSTD = PHR
 -- (JE MET POUR L'INSTANT DANS superposition_protection A DISCUTER !!!)
INSERT INTO superposition_affectation (geom,FOSNR,DATESAISIE, remarques,operateur,typsupaff,fosnr_code,code_type)
SELECT aff.geom,
       aff.FOSNR::smallint,
       aff.datesaisie,
       aff.REMARQUES,
       aff.OPERATEUR,
       'PHM',
       concat_ws('_',fosnr,'693'),
       693
FROM affectation_com_new aff
WHERE typstd LIKE 'PHM';



---------------------------------
/*
INSERT INTO superposition_affectation (geom,FOSNR,DATESAISIE, remarques,operateur,typsupaff,fosnr_code,type_code)
SELECT aff.geom,
       aff.FOSNR::smallint,
       aff.datesaisie,
       aff.REMARQUES,
       aff.OPERATEUR,
       'PHM',
       concat_ws('_',fosnr,'692')-- On crée un périmètre d'habitat à maintenir et pas un PHR (à discuter)
       692
FROM affectation_com_new aff
WHERE typstd LIKE 'PHR';
*/

-- DELETE les ROW ou TYPSTD = SPL et les places dans un SECTEUR SUPERPOSE de tourisme et loisir (STL).

INSERT INTO superposition_affectation (geom,FOSNR,DATESAISIE, remarques,operateur,typsupaff,fosnr_code,code_type)
SELECT aff.geom,
       aff.FOSNR::smallint,
       aff.datesaisie,
       aff.REMARQUES,
       aff.OPERATEUR,
       'PTL',
       concat_ws('_',fosnr,'694'),
       694
FROM affectation_com_new aff
WHERE typstd LIKE 'STL';




 /*ON CREE UN SECTEUR DE PROTECTION PADIV (Périmètre d'agriculture diversifiée) à l'endroit ou se situait les anciennes
	zone PADIV*/
INSERT INTO superposition_affectation (geom,FOSNR,DATESAISIE, remarques,operateur,typsupaff,fosnr_code,code_type)
SELECT aff.geom,
       aff.FOSNR::smallint,
       aff.datesaisie,
       aff.REMARQUES,
       aff.OPERATEUR,
       'PADIV',
       concat_ws('_',fosnr,'696'),
       696
FROM affectation_com_new aff
WHERE typstd LIKE 'PADIV';

 -- ICI on ne supprime pas la ZONE, elle est simplement transformé en ZA
 -- (le changement est effectué dans la query 1.0)
 /*ON CREE UN PERIMETRE DE PROTECTION ARCHEOLOGIQUE si la mention périmètre archéologique
	figure dans le champ remarques*/
INSERT INTO superposition_affectation (geom,FOSNR,DATESAISIE, remarques,operateur,typsupaff,fosnr_code,code_type)
SELECT aff.geom,
       aff.FOSNR::smallint,
       aff.datesaisie,
       aff.REMARQUES,
       aff.OPERATEUR,
       'PA',
       concat_ws('_',fosnr,'695'),
       695
FROM affectation_com_new aff
WHERE lower(remarques) LIKE '%archäo%'
  OR lower(remarques) LIKE '%achäo%'
  OR lower(remarques) LIKE '%archéo%'
  OR lower(remarques) LIKE '%achéolo%'
  OR (typstd = 'ZP'
      AND typprot = 'ARCH');




-- on ajoute un ID.
ALTER TABLE superposition_affectation  
ADD COLUMN GID serial;

 -- Unification des géomètries découpées.

DROP TABLE IF EXISTS merged;


CREATE TABLE merged AS
SELECT (ST_DUMP(ST_Union(ST_SnapToGrid(geom,0.0001)))).geom as geom,
       fosnr_code,
       FOSNR::smallint,
       typsupaff,
       code_type
FROM superposition_affectation -- A changé pour affectation_2015 une fois chaque typstd_2015 attribué.

GROUP BY fosnr_code,
         FOSNR,
         typsupaff,
	 code_type;

 -- On ajoute un GID les remarques et l'operateur:

ALTER TABLE merged ADD COLUMN GID SERIAL, ADD COLUMN OPERATEUR character varying(50), ADD COLUMN DATESAISIE date, ADD COLUMN REMARQUE character varying(500);



DROP VIEW IF EXISTS v1 CASCADE;
CREATE view v1 AS
SELECT b.gid gid, lower(a.operateur) ope, a.datesaisie datesaisie, a.remarques
FROM superposition_affectation a, merged b
WHERE st_overlaps(b.geom,a.geom)
order by b.gid;


 -- ATTENTION: EN CAS DE FUSION DE 2 polygones OU PLUS la remarque du dernier polygone crée est appliquée à l'ensemble de la surface fusionnée. 
UPDATE merged
SET OPERATEUR = t1.ope, DATESAISIE = t1.datesaisie, REMARQUE = t1.remarques
FROM
(
SELECT DISTINCT tt.*
FROM v1 tt
INNER JOIN
    (SELECT DISTINCT gid, MAX(datesaisie) AS MaxDateTime
    FROM v1
    GROUP BY gid) groupedtt 
ON tt.gid = groupedtt.gid 
AND tt.datesaisie = groupedtt.MaxDateTime
order by tt.gid
) AS t1
WHERE t1.gid = merged.gid;



 -- On ajoute l'aire et le périmètre

ALTER TABLE merged
DROP COLUMN IF EXISTS shape_leng,
DROP COLUMN IF EXISTS shape_area,
                      ADD COLUMN shape_leng numeric, ADD COLUMN shape_area numeric;

UPDATE merged
SET shape_leng = st_Perimeter(geom),
    shape_area = st_area(geom);

 -- NETTOYAGE DES DONNEES

 -- voir: http://gis.stackexchange.com/q/198115
 
 -- Sliver Killer et Sliver Murder : mission erradiquer les slivers.
 -- ETAPE 1: On dézingue les slivers enclavée dans un polygone

UPDATE merged
SET geom = sliver_killer(geom,50::float);

 -- ETAPE 2: On dézingue les slivers qui touchent le bord du polygone.

UPDATE merged
SET geom = sliver_murder(geom,0.5::float);

 -- C'est beau, c'est propre


 
 -- Merge devient superposition_affectation

ALTER TABLE superposition_affectation RENAME TO superposition_affectation_backup;

ALTER TABLE merged RENAME TO superposition_affectation;

DROP TABLE superposition_affectation_backup CASCADE;

 DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Fin de création superposition_affectation'; END $$;




























 /*CREATION DU NOUVEAU LAYER superposition_protection
LES ZONE dont les TYPPROT sont 'NAT' ou 'PAY' peuvent être en grande partie être transféré en perimètre superposé. Mais certaines zones devront peut être rester
dans le plan d'affectation. C'est pourquoi une colonne ZONEouSUPERPOS est ajouté afin de pouvoir choisir les zones de protection qui devront rester en zone de protection.
*/ -- migration1.0_creation_affectation_2015 doit être lancer avant cette query.

DROP TABLE IF EXISTS superposition_protection CASCADE;


CREATE TABLE superposition_protection (geom geometry(MultiPolygon), FOSNR smallint, datesaisie date, statutjuridique character varying(50), shape_leng numeric, shape_area numeric, remarques character varying(500), operateur character varying(50), typsupprot character varying(10),fosnr_code character varying(20),code_type smallint);

 -- DELETE les ROW ou TYPSTD = ZP* et TYPPROT = 'PAY' ET LES PLACE DANS SECTEUR SUPERPOSE.

INSERT INTO superposition_protection (geom,FOSNR,datesaisie,shape_leng,shape_area,remarques,operateur,typsupprot,fosnr_code,code_type)
SELECT aff.geom,
       aff.FOSNR::smallint,
       aff.datesaisie,
       aff.shape_len,
       aff.shape_area,
       aff.remarques,
       aff.operateur,
       'PPP',
       concat_ws('_',fosnr,'521'),
       521
       
FROM affectation_com_new aff
WHERE (typstd LIKE 'ZP%'
       AND TYPPROT = 'PAY')
  OR typstd LIKE 'ZPP';


DELETE
FROM affectation_com_new
WHERE (typstd LIKE 'ZP%'
       AND TYPPROT = 'PAY')
  OR typstd LIKE 'ZPP';

 
  
 -- DELETE les ROW ou TYPSTD = ZP* et TYPPROT = 'NAT' ET LES PLACE DANS SECTEUR SUPERPOSE.

INSERT INTO superposition_protection (geom,FOSNR,datesaisie,shape_leng,shape_area,remarques,operateur,typsupprot,fosnr_code,code_type)
SELECT aff.geom,
       aff.FOSNR,
       aff.datesaisie,
       aff.shape_len,
       aff.shape_area,
       aff.remarques,
       aff.operateur,
       'PPN',
       concat_ws('_',fosnr,'522'),
       522
FROM affectation_com_new aff
WHERE typstd LIKE 'ZP%'
  AND TYPPROT = 'NAT';


DELETE
FROM affectation_com_new
WHERE typstd LIKE 'ZP%'
  AND TYPPROT LIKE 'NAT';

 



 /*ON CREE UN SECTEUR DE PROTECTION DU SITE CONSTRUIT si la mention périmètre de protection du site construit
	figure dans le champ remarquesue*/
INSERT INTO superposition_protection (geom,FOSNR,datesaisie,shape_leng,shape_area,remarques,operateur,typsupprot,fosnr_code,code_type)
SELECT aff.geom,
       aff.FOSNR,
       aff.datesaisie,
       aff.shape_len,
       aff.shape_area,
       aff.remarques,
       aff.operateur,
       'PPC',
       concat_ws('_',fosnr,'511'),
       511
FROM affectation_com_new aff
WHERE (lower(remarques) LIKE '%protection%'
  AND (lower(remarques) LIKE '%site%' OR lower(remarques) LIKE '%siite%'))
  OR (lower(remarques) LIKE '%site%' AND lower(remarques) LIKE '%protég%')
  OR (lower(remarques) LIKE '%bâti%' AND lower(remarques) LIKE '%conserver%')
  OR lower(remarques) LIKE '%ortsbild%'
  OR lower(remarques) LIKE '%orstbild%'
  OR (lower(remarques) like '%périmètre d''implantation%' AND typstd not like 'PHR'); -- Attention ici vu que la selection est relativement souple il se peut (même si peu probable) que des périmètres de protection du site construit soit créer à tord.

 /* CETTE PARTIE FUSIONNE LES POLYGONES ADJACENT PARTAGEANT LE MÊME TYPE DE PROTECTION + MEME FOSNR + MEME REMARQUES (car un même type de protection peut faire référence à différents articles RCU)*/ -- La fonction "remplie" les trous dans les polygons, si le trou est inférieur à $2 m^2.

DROP VIEW IF EXISTS v1;


CREATE VIEW v1 AS
SELECT sliver_killer((ST_DUMP(ST_Union(geom))).geom,50::float) AS geom,
       typsupprot, fosnr, remarques, code_type,fosnr_code
FROM superposition_protection
GROUP BY typsupprot, fosnr, remarques, code_type,fosnr_code;

 -- On va rechoper l'information (

DROP TABLE IF EXISTS superposition_protection_temp;


CREATE TABLE superposition_protection_temp AS
SELECT v.FOSNR AS FOSNR,
       min(a.typsupprot) AS typsupprot,
       v.remarques AS remarques,
       v.geom AS geom,
       v.code_type AS code_type,
       v.fosnr_code AS fosnr_code
FROM v1 v,
     superposition_protection a
WHERE st_intersects(v.geom,a.geom)
  AND a.typsupprot = v.typsupprot
GROUP BY v.geom,
         v.typsupprot,
         v.fosnr,
         v.remarques,
         v.code_type,
         v.fosnr_code;


ALTER TABLE superposition_protection_temp 
ADD COLUMN datesaisie date, 
ADD COLUMN operateur character varying(50),
ADD COLUMN gid serial;
--ADD COLUMN FOSNR_CODE character varying(30);

 -- Pour la date de saisie et l'operateur je ne prend QUE les dernières modifications.

UPDATE superposition_protection_temp
SET datesaisie = t1.datesaisie,
    operateur = t1.operateur
FROM
  ( SELECT max(a.datesaisie) AS datesaisie,
           max(a.operateur) AS operateur,
           b.gid
   FROM superposition_protection_temp b,
        superposition_protection a
   WHERE st_intersects(a.geom,b.geom)
   GROUP BY b.gid
   ORDER BY b.gid ) AS t1
WHERE t1.gid = superposition_protection_temp.gid;


UPDATE superposition_protection_temp
SET FOSNR_CODE = FOSNR || '_' || code_type::text;

 -- On change le nom de la table.

DROP TABLE IF EXISTS superposition_protection CASCADE ;


CREATE TABLE superposition_protection AS
SELECT *
FROM superposition_protection_temp;


DROP TABLE IF EXISTS superposition_protection_temp;

 --DROP FUNCTION IF EXISTS sliver_killer(geometry,float);
 /* OPTION: AJOUTER UN ATTRIBUT ZONEouSUPERPOS AFIN
	DE POUVOIR DETERMINER l'APPARTENANCE DE CHAQUE POLYGON A 
	UNE ZONE OU UN CONTENU SUPERPOSE */ 
	DO $$ BEGIN BEGIN 
ALTER TABLE superposition_protection ADD COLUMN ZONEouSUPERPOS character varying(6); EXCEPTION WHEN duplicate_column THEN RAISE NOTICE 'column ZONEouSUPERPOS already exists in superposition_protection.'; END; END; $$;


ALTER TABLE superposition_protection ADD COLUMN shape_leng numeric;


UPDATE superposition_protection
SET shape_leng = ST_perimeter(geom);


ALTER TABLE superposition_protection ADD COLUMN shape_area numeric;


UPDATE superposition_protection
SET shape_area = ST_area(geom);

 -- Sliver Killer et Sliver Murder : Votre mission erradiquer les slivers.
 -- ETAPE 1: On dézingue les slivers enclavée dans un polygone

UPDATE superposition_protection
SET geom = sliver_killer(geom,50::float);

 -- ETAPE 2: On dézingue les slivers qui touchent le bord du polygone.
-- Cette étape demande quelques dizaines de seconde, mais la qualité ça n'a pas de prix.

UPDATE superposition_protection
SET geom = sliver_murder(geom,1::float);

 DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Fin de création superposition_protection'; END $$;













 /* La query suivante lie chaque zone communale d'une commune particulière avec le nouveau typstd_2015 SI et SEULEMENT SI chaque combinaise
de ZONE + FOSNR (de la table zone_com) ne fait référence qu'à un seul typstd_2015.
En changeant le having count(distinct aff2015) = 1 à > 1 on peut voir les ZONE + FOSNR qui devront être traité manuellement car il y a
un conflit entre plusieur type de zone */ -- A AJOUTER:
 -- Verification que chaque ZONE + FOSNR se voit attribuer un nouveau typstd 2015. Pour cela il est nécessaire que chaque zone d'affectation primaire
-- possède un nouveau TYPSTD_2015. Cette opération doit donc être réalisé après la transition affectation_2015.

DROP TABLE IF EXISTS zone_comm_new;

-- Certain fosnr_zon de zone_comm_new ne sont pas définit, donc on corrige le tir

UPDATE zone_comm_old SET fosnr_zon = concat(fosnr,zone)
WHERE fosnr_zon IS NULL;

-- Copy de zone_comm_old

SELECT * INTO zone_comm_new
FROM zone_comm_old;


ALTER TABLE zone_comm_new
DROP COLUMN HTTGEN,
DROP COLUMN HTTHI,
DROP COLUMN HTTHG,
DROP COLUMN HTTHC,
DROP COLUMN HTTAUTR,
DROP COLUMN distd,
DROP COLUMN sensible,
            -- DROP COLUMN latec_2008,
ADD COLUMN ForceObligatoire character varying(50),
ADD COLUMN Code_Zone integer, 
ADD COLUMN typstd_2015 character varying(6); -- Devra être renommé en typstd (et donc typstd supprimé) une fois que chaque typstd_2015 sera attribué

 -- La query suivante va chercher la correspondance fosnr + zone / typstd et affecte le bon typstd à zone_comm_new.typstd_2015
UPDATE zone_comm_new
SET TYPSTD_2015 = s2.aff2015
FROM
  (SELECT DISTINCT z.zone AS zcom,
                   z.FOSNR AS znuf,
                   affn.typstd_2015 aff2015
   FROM affectation_com_new affn,
        zone_comm_old z
   WHERE (z.zone,
          z.FOSNR) IN
       ( SELECT DISTINCT z.zone AS zcom,
                         z.FOSNR AS znuf --, count(*) as occur

        FROM affectation_com_new affn,
             zone_comm_old z
        WHERE z.FOSNR_zon = affn.FOSNR_zone
        GROUP BY z.zone,
                 z.FOSNR
        HAVING count(DISTINCT affn.typstd_2015) = 1) -- On controle que chache fosnr_zone correspond à un et un seul type d'affectation cantonal.
     AND lower(affn.FOSNR_zone) = lower(z.FOSNR_zon)
     AND affn.typstd_2015 IS NOT NULL) AS s2
WHERE s2.zcom = zone_comm_new.zone
  AND s2.znuf = FOSNR;

 -- On crée l'attribut code_zone

UPDATE zone_comm_new
SET code_zone = cast(concat(type.code,type.code_typfe)AS integer)
FROM type
WHERE typstd_2015 = type.abrev;

 -- On supprime les tuples qui ne sont jamais utilisés dans affectation_com

DELETE
FROM zone_comm_new
WHERE FOSNR_zon NOT IN
    (SELECT DISTINCT FOSNR_zon
     FROM affectation_com_old
     WHERE FOSNR_zon IS NOT NULL
     ORDER BY FOSNR_zon) ;

 /*SELECT INDGEN,TXGEN,TXHI, TXHG,TXHC,TXAUTR
FROM zone_comm_new
WHERE TXGEN > 0
OR TXHI > 0
OR TXHG > 0
OR TXHC > 0
OR TXAUTR > 0*/

ALTER TABLE zone_comm_new
DROP COLUMN IF EXISTS IOSGEN,
DROP COLUMN IF EXISTS IOSHI,
DROP COLUMN IF EXISTS IOSHC,
DROP COLUMN IF EXISTS IOSHG,
DROP COLUMN IF EXISTS IOSAUTR,
DROP COLUMN IF EXISTS IBUSGEN,
DROP COLUMN IF EXISTS IBUSHI,
DROP COLUMN IF EXISTS IBUSHG,
DROP COLUMN IF EXISTS IBUSHC,
DROP COLUMN IF EXISTS IBUSAUTR,
DROP COLUMN IF EXISTS IBUS_done,
DROP COLUMN IF EXISTS IOS_done;

ALTER TABLE zone_comm_new ADD IOSGEN float; 
ALTER TABLE zone_comm_new ADD IOSHI float; 
ALTER TABLE zone_comm_new ADD IOSHC float; 
ALTER TABLE zone_comm_new ADD IOSHG float; 
ALTER TABLE zone_comm_new ADD IOSAUTR float; 
ALTER TABLE zone_comm_new ADD IBUSGEN float; 
ALTER TABLE zone_comm_new ADD IBUSHI float; 
ALTER TABLE zone_comm_new ADD IBUSHG float; 
ALTER TABLE zone_comm_new ADD IBUSHC float; 
ALTER TABLE zone_comm_new ADD IBUSAUTR float; 
ALTER TABLE zone_comm_new ADD IBUS_done boolean; 
ALTER TABLE zone_comm_new ADD IOS_done boolean;

UPDATE zone_comm_new
SET (IOSGEN,
     IOSHI,
     IOSHG,
     IOSHC,
     IOSAUTR,
     IOS_done) =
	 (TXGEN/100,
          TXHI/100,
          TXHG/100,
          TXHC/100,
          TXAUTR/100,
          TRUE)
WHERE latec_2008 = 0;

 -- Tous les indgen... non latec_2008 = IUS
-- Donc IBUS = IUS * (4/3)

UPDATE zone_comm_new
SET (IBUSGEN,
     IBUSHI,
     IBUSHG,
     IBUSHC,
     IBUSAUTR,
     IBUS_done) =
	 (INDGEN*4.0/3.0,
          INDHI*4.0/3.0,
          INDHG*4.0/3.0,
          INDHC*4.0/3.0,
          INDAUTR*4.0/3.0,
          TRUE)
WHERE latec_2008 = 0;

-- Sauf lorsque IUS < 0.4 IBUS = 0.5 (en accord avec la latec 

UPDATE zone_comm_new
SET IBUSGEN = 0.5
WHERE INDGEN < 0.4 AND INDGEN > 0;

UPDATE zone_comm_new
SET IBUSHI = 0.5
WHERE INDHI < 0.4 AND INDHI > 0;

UPDATE zone_comm_new
SET IBUSHG = 0.5
WHERE INDHG < 0.4 AND INDHG > 0;

UPDATE zone_comm_new
SET IBUSHC = 0.5
WHERE INDHC < 0.4 AND INDHC > 0;

UPDATE zone_comm_new
SET IBUSAUTR = 0.5
WHERE INDAUTR < 0.4 AND INDAUTR > 0;

 -- Les txgen entre 0-5 et latec_2008 = 1 sont des IBUS

UPDATE zone_comm_new
SET (IBUSGEN,
     IBUSHI,
     IBUSHG,
     IBUSHC,
     IBUSAUTR,
     IBUS_done) =
	 (TXGEN,
          TXHI,
          TXHG,
          TXHC,
          TXAUTR,
          TRUE)
WHERE latec_2008 = 1
AND (TXGEN BETWEEN 0.001 AND 5
       OR TXHI BETWEEN 0.001 AND 5
       OR TXHG BETWEEN 0.001 AND 5
       OR TXHC BETWEEN 0.001 AND 5
       OR TXAUTR BETWEEN 0.001 AND 5);

 -- Les txgen entre 5-100 et latec_2008 = 1 sont des taux d'occupation -> donc IOS

UPDATE zone_comm_new
SET (IOSGEN,
     IOSHI,
     IOSHG,
     IOSHC,
     IOSAUTR,
     IOS_done) =
	 (TXGEN/100,
          TXHI/100,
          TXHG/100,
          TXHC/100,
          TXAUTR/100,
          TRUE)
WHERE latec_2008 = 1
  AND (TXGEN BETWEEN 5 AND 101
       OR TXHI BETWEEN 5 AND 101
       OR TXHG BETWEEN 5 AND 101
       OR TXHC BETWEEN 5 AND 101
       OR TXAUTR BETWEEN 5 AND 101); -- les indgen latec_2008 donc le txgen associé [0-5] est un IOS.

UPDATE zone_comm_new
SET (IOSGEN,
     IOSHI,
     IOSHG,
     IOSHC,
     IOSAUTR,
     IOS_done) =
	 (INDGEN,
          INDHI,
          INDHG,
          INDHC,
          INDAUTR,
          TRUE)
WHERE latec_2008 = 1
  AND (TXGEN BETWEEN 0.001 AND 5
       OR TXHI BETWEEN 0.001 AND 5
       OR TXHG BETWEEN 0.001 AND 5
       OR TXHC BETWEEN 0.001 AND 5
       OR TXAUTR BETWEEN 0.001 AND 5);

 -- les indgen latec_2008=1 donc le txgen associé ∈[5-100] est un IBUS !
-- Alors là c'est le pompon donc dans indgen il y a non seulement des IOS/IUS mais dans certain cas (tx > 5) il s'agit d'IBUS !
-- CONFUSION LEVEL OVER 9000
-- Dans le lot des indices traités par la query ci-dessous, il y a visiblement quelque erreur, ou les indices ne correspondent à RIEN, le RCU est juste mais 
-- les valeurs des indices dans zone_comm ont été sorties d'on ne sait ou. Donc quelques erreurs possibles !

UPDATE zone_comm_new
SET (IBUSGEN,
     IBUSHI,
     IBUSHG,
     IBUSHC,
     IBUSAUTR,
     IBUS_done) =
	 (INDGEN,
          INDHI,
          INDHG,
          INDHC,
          INDAUTR,
          TRUE)
WHERE latec_2008 = 1
  AND (TXGEN BETWEEN 5 AND 101
       OR TXHI BETWEEN 5 AND 101
       OR TXHG BETWEEN 5 AND 101
       OR TXHC BETWEEN 5 AND 101
       OR TXAUTR BETWEEN 5 AND 101)
  AND FOSNR NOT IN (2016);

 -- Les indgen... latec_2008 dont le txgen... = 0 DEVRAIENT ETRE des IOS, ERREUR POSSIBLE BIEN QUE FAIBLE ! faible chance que indgen => IUS !

UPDATE zone_comm_new
SET (IOSGEN,
     IOSHI,
     IOSHG,
     IOSHC,
     IOSAUTR,
     IBUSGEN,
     IBUSHI,
     IBUSHG,
     IBUSHC,
     IBUSAUTR,
     IBUS_done,
     IOS_done) =
	 (INDGEN,
          INDHI,
          INDHG,
          INDHC,
          INDAUTR,
          0,
          0,
          0,
          0,
          0,
          TRUE,
          TRUE)
WHERE TXGEN = 0
  AND TXHI = 0
  AND TXHG = 0
  AND TXHC = 0
  AND TXAUTR = 0
  AND latec_2008 = 1;


UPDATE zone_comm_new
SET (IBUSGEN,
     IBUSHI,
     IBUSHG,
     IBUSHC,
     IBUSAUTR,
     IOSGEN,
     IOSHI,
     IOSHG,
     IOSHC,
     IOSAUTR,
     IBUS_done,
     IOS_done) =
	 (0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          TRUE,
          TRUE)
WHERE TXGEN = 0
  AND TXHI = 0
  AND TXHG = 0
  AND TXHC = 0
  AND TXAUTR = 0
  AND INDGEN = 0
  AND INDHI = 0
  AND INDHG = 0
  AND INDHC = 0
  AND INDAUTR = 0;

 /*SELECT INDGEN,TXGEN,TXHI, TXHG,TXHC,TXAUTR, latec_2008
FROM zone_comm_new
WHERE TXGEN = 0
AND TXHI = 0
AND TXHG = 0
AND TXHC = 0
AND TXAUTR = 0
AND INDGEN > 0*/
ALTER TABLE zone_comm_new
DROP COLUMN IF EXISTS INDGEN,
DROP COLUMN IF EXISTS INDHI,
DROP COLUMN IF EXISTS INDHG,
DROP COLUMN IF EXISTS INDHC,
DROP COLUMN IF EXISTS INDAUTR,
DROP COLUMN IF EXISTS TXGEN,
DROP COLUMN IF EXISTS TXHI,
DROP COLUMN IF EXISTS TXHG,
DROP COLUMN IF EXISTS TXHC,
DROP COLUMN IF EXISTS TXAUTR;
 -- On cast niveauxxx pour passer de texte à double

UPDATE zone_comm_new SET niveaugen = t1.nbr
FROM
(
SELECT gid,(regexp_matches(lower(niveaugen),'(\d\.*\d*)'))[1]::double precision as nbr FROM zone_comm_new
ORDER BY nbr desc
) AS t1
WHERE zone_comm_new.gid = t1.gid;

UPDATE zone_comm_new SET niveauhi = t1.nbr
FROM
(
SELECT gid,(regexp_matches(lower(niveauhi),'(\d\.*\d*)'))[1]::double precision as nbr FROM zone_comm_new
ORDER BY nbr desc
) AS t1
WHERE zone_comm_new.gid = t1.gid;

UPDATE zone_comm_new SET niveauhg = t1.nbr
FROM
(
SELECT gid,(regexp_matches(lower(niveauhg),'(\d\.*\d*)'))[1]::double precision as nbr FROM zone_comm_new
ORDER BY nbr desc
) AS t1
WHERE zone_comm_new.gid = t1.gid;

UPDATE zone_comm_new SET niveauhc = t1.nbr
FROM
(
SELECT gid,(regexp_matches(lower(niveauhc),'(\d\.*\d*)'))[1]::double precision as nbr FROM zone_comm_new
ORDER BY nbr desc
) AS t1
WHERE zone_comm_new.gid = t1.gid;

UPDATE zone_comm_new SET niveauautr = t1.nbr
FROM
(
SELECT gid,(regexp_matches(lower(niveauautr),'(\d\.*\d*)'))[1]::double precision as nbr FROM zone_comm_new
ORDER BY nbr desc
) AS t1
WHERE zone_comm_new.gid = t1.gid;

 -- On crée le typfed: +

UPDATE zone_comm_new
SET (TYPFED) = (type.code_typfe)
FROM type
WHERE zone_comm_new.typstd_2015 = type.abrev;

 -- On supprime les éventuelles lignes vides.

DELETE
FROM zone_comm_new t
WHERE t.zone IS NULL;

 -- On supprime les lignes dont le typstd ne fait plus partie de zone com.

DELETE
FROM zone_comm_new t
WHERE typstd = 'ZP%'
  OR typstd = 'ZP'
  AND typstd_2015 IS NOT NULL;
  
-- nouvelle version des lignes supprimées.

DELETE
FROM zone_comm_new
WHERE TYPSTD IN ('PHR',
                 'PHM',
                 'ZP',
                 'STL',
                 'ZSA',
		 'ZR');
DELETE
FROM zone_comm_new
WHERE TYPSTD LIKE 'ZP%';

-- force obligatoire = contraignant:

UPDATE zone_comm_new  
SET ForceObligatoire = 'Contraignant';
/*
Si à ce stade il reste des zones de zone_comm_new ne possédant pas de typfed et de typstd2015
c'est que la zone pose problème car est attribué à cette zone différents types d'affectation cantonals
EX: la zone ZV_IV de la commune Fribourg est affectée une fois en ZACT et une fois en ZV, impossible pour mon algo
de déterminer donc si il faut choisir ZACT ou ZV (cas très rare).
*/

 -- On cast les données pour les rendre compatibles avec le modèle.

ALTER TABLE zone_comm_new ALTER COLUMN fosnr 	  TYPE smallint using fosnr::smallint;
ALTER TABLE zone_comm_new ALTER COLUMN niveaugen  TYPE double precision using niveaugen::double precision;
ALTER TABLE zone_comm_new ALTER COLUMN niveauhi   TYPE double precision using niveauhi::double precision;
ALTER TABLE zone_comm_new ALTER COLUMN niveauhg   TYPE double precision using niveauhg::double precision;
ALTER TABLE zone_comm_new ALTER COLUMN niveauhc   TYPE double precision using niveauhc::double precision;
ALTER TABLE zone_comm_new ALTER COLUMN niveauautr TYPE double precision using niveauautr::double precision;

-- On supprime les polygones de la couche affectation_com qui ne sont plus utiles:

DELETE
FROM affectation_com_new
WHERE typstd LIKE 'PHR';

DELETE
FROM affectation_com_new
WHERE typstd LIKE 'STL';

DELETE
FROM affectation_com_new
WHERE typstd LIKE 'PHM';

DELETE
FROM affectation_com_new
WHERE (typstd = 'ZP'
       AND typprot = 'ARCH');


DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Fin de création zone_comm'; END $$;

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
-- ENVIRON 2 minutes pour runner.
 -- Creation superposition bruit 
 
 -- En premier lieu: certaines zones contiennes le DS dans la remarque et pas sur l'attribut sensiblesp: CORRECTION

	UPDATE affectation_com_old
	SET sensiblesp = t1.DS
	FROM
	  (SELECT (regexp_matches(lower(remarq),'ds\s*[\s|=]\s*(\d)'))[1]::integer AS DS,
										      gid,
										      sensiblesp,
										      remarq
	FROM affectation_com_old) t1
	WHERE affectation_com_old.gid = t1.gid;

	 -- Création de superposition bruit, on récupère l'attribut sensible de zone comme si sensiblesp n'est pas définit, sinon on récupère sensiblesp.

	DROP TABLE IF EXISTS superposition_bruit;

        -- Necessite de checker si il y a un declassement ou pas, plus pratique de rajouter un attribut sur affectation_old
        ALTER TABLE affectation_com_old
        DROP COLUMN IF EXISTS declass;
        ALTER TABLE affectation_com_old 
        ADD COLUMN declass integer;

        UPDATE affectation_com_old
        SET declass = 0;
        
        UPDATE affectation_com_old
        SET declass = 1
        WHERE gid in
        (
        select gid from affectation_com_old where remarq like '%declasss%' or remarq like '%déclass%'
        );

	-- on reprend
	
	CREATE TABLE superposition_bruit AS
	SELECT sensible::smallint, declassement, (ST_DUMP(ST_Union(ST_SnapToGrid(ST_MakeValid(geom),0.0)))).geom
	FROM
	(
		SELECT a.sensiblesp::smallint as sensible, a.declass as declassement,
		geom
		FROM affectation_com_old a
		WHERE a.sensiblesp <> 0 -- sensiblesp existe
		UNION
		SELECT b.sensible::smallint as sensible, a.declass as declassement,
		geom
		FROM affectation_com_old a, zone_comm_old b
		WHERE a.fosnr_zon = b.fosnr_zon
		AND a.sensiblesp = 0 -- sensiblesp n'existe pas
	) as T
	group by sensible, declassement;

	DELETE
	FROM superposition_bruit
	WHERE GeometryType(geom) = 'LINESTRING';


	ALTER TABLE superposition_bruit 
	ADD COLUMN GID SERIAL, 
	ADD COLUMN ForceObligatoire character varying(50),
	ADD COLUMN DATESAISIE date, 
	ADD COLUMN OPERATEUR character varying(100),
	ADD COLUMN REMARQUES character varying(500);


	UPDATE superposition_bruit
	SET geom = sliver_murder(sliver_killer(geom,50::float),1::float);


	UPDATE superposition_bruit
	SET ForceObligatoire = 'Contraignant';

	 /* UPDATE OPERATEUR, longue query car il faut récuperer les différents opérateurs potentielles */ -- CORRECTION DES GEOMETRIES

	UPDATE superposition_bruit
	SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(new.geom), 3))
	FROM
	  (SELECT geom,
		  gid
	   FROM superposition_bruit
	   WHERE ST_ISVALID(superposition_bruit.geom) = FALSE) AS NEW
	WHERE superposition_bruit.gid = NEW.gid;

	 -- CORRECTION DES GEOMETRIES d'affectation_old.

	UPDATE affectation_com_old
	SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(NEW.geom), 3))
	FROM
	  (SELECT geom,
		  gid
	   FROM affectation_com_old
	   WHERE ST_ISVALID(affectation_com_old.geom) = FALSE) AS NEW
	WHERE affectation_com_old.gid = NEW.gid;

	 
	UPDATE superposition_bruit
	SET OPERATEUR = t1.ope
	FROM
	  (SELECT s.GID gid,
		  string_agg(DISTINCT lower(a.operat), ', ') ope
	   FROM superposition_bruit s,
		affectation_com_old a
	   WHERE st_overlaps(s.geom,a.geom)
	   GROUP BY s.gid) AS t1
	WHERE t1.gid = superposition_bruit.gid;

	 -- FIN UPDATE OPERATEUR
	 -- Ajout de FOSNR et FOSNR_DEGRE (necessaire pour la relation avec les dispositions)

	ALTER TABLE superposition_bruit ADD COLUMN FOSNR smallint, ADD COLUMN FOSNR_DEGRE character varying(20);

	
	UPDATE superposition_bruit
	SET FOSNR = t1.FOSNR
	FROM
	(SELECT a.fosnr,b.gid from affectation_com_old a, superposition_bruit b
	WHERE st_intersects(a.geom,st_pointonsurface(b.geom))
	AND st_intersects(a.geom,b.geom)
	) t1
	WHERE superposition_bruit.gid = t1.gid;


	UPDATE superposition_bruit
	SET FOSNR_DEGRE = FOSNR || '_' || sensible::text;

	 /*-- Ajout de déclassement

	ALTER TABLE superposition_bruit ADD COLUMN declassement integer;


	UPDATE superposition_bruit
	SET declassement = 0;
	*/
	-- On supprimer les secteurs qui découlent d'opérations foirée sur les données dont la largeur max n'exède pas 1.5m
	
	DELETE FROM superposition_bruit  
	WHERE gid in
	(
	select gid from superposition_bruit 
	group by gid,geom
	having st_area(ST_Buffer(ST_Buffer(geom,-1.5,'join=mitre'),1.5,'join=mitre')) < 1
	);

	-- DELETE les zones ou sensible == 0

	DELETE FROM superposition_bruit 
	where sensible = 0;


 DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Fin de création superposition_bruit'; END $$;


















 

 /* Creation de la table disposition_commune */
DROP TABLE IF EXISTS disposition_commune CASCADE;


CREATE TABLE disposition_commune ( FOSNR smallint, LIEN character varying(200), TYPE character varying(50), DATE date );

 --SELECT to_timestamp(array_to_string(regexp_matches(Lien, '(\d{8})'),','),'YYYYMMDD'),Lien
--FROM suivipal_lien_scan;
 WITH t1 AS
  ( SELECT regexp_matches(Lien, '(\d{4})(.)(\d{8})') res,
           Lien
   FROM suivipal_lien_scan
   WHERE type_docum = '02'),
      -- (TYPE_DOCUM == 02) = RCU
 t2 AS
  ( SELECT y.res[1] FOSNR,
           max(to_timestamp(y.res[3],'YYYYMMDD')) date
   FROM
     ( SELECT regexp_matches(Lien, '(\d{4})(.)(\d{8})') res
      FROM suivipal_lien_scan
      WHERE type_docum LIKE '02'
        AND name NOT LIKE '%art%') AS y
   GROUP BY FOSNR
   ORDER BY FOSNR)
INSERT INTO disposition_commune (FOSNR,DATE,LIEN)
SELECT t1.res[1]::integer FOSNR,
       to_timestamp(t1.res[3],'YYYYMMDD') date, t1.Lien
FROM t1,
     t2
WHERE t1.res[1] = t2.FOSNR
  AND to_timestamp(t1.res[3],'YYYYMMDD') = t2.date;


UPDATE disposition_commune
SET TYPE = 'principal'
WHERE FOSNR IN
    (SELECT FOSNR
     FROM disposition_commune
     GROUP BY FOSNR
     HAVING count(FOSNR) = 1);

 -- ON AJOUTE également les quelques articles de RCU qui sont toujours valides.
 WITH t1 AS
  ( SELECT regexp_matches(Lien, '(\d{4})(.)(\d{8})') res,
           Lien
   FROM suivipal_lien_scan
   WHERE type_docum = '02'),
      -- (TYPE_DOCUM == 02) = RCU
 t2 AS
  ( SELECT y.res[1] FOSNR,
           max(to_timestamp(y.res[3],'YYYYMMDD')) date
   FROM
     ( SELECT regexp_matches(Lien, '(\d{4})(.)(\d{8})') res
      FROM suivipal_lien_scan
      WHERE type_docum LIKE '02') AS y
   GROUP BY FOSNR
   ORDER BY FOSNR)
INSERT INTO disposition_commune (FOSNR,DATE,LIEN)
SELECT t1.res[1]::integer FOSNR,
       to_timestamp(t1.res[3],'YYYYMMDD') date, t1.Lien
FROM t1,
     t2,
     disposition_commune t3
WHERE t1.res[1] = t2.FOSNR
  AND t3.FOSNR = t1.res[1]::integer
  AND to_timestamp(t1.res[3],'YYYYMMDD') > t3.date
  AND to_timestamp(t1.res[3],'YYYYMMDD') = t2.date;

 DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Fin de création disposition_commune'; END $$;

 /* Dans le système actuel il n'y a pas de gestion des périmètres superposés: 
donc lorsqu'un secteur PAD, de danger, de protection... affecte un des polygons de
affectation_com, ce polygon est découpé et une remarque est placé dans le champ remarque
afin de préciser la nature de la superposition.

Puisque le nouveau modèle sépare ces superpositions d'affectation_com, ces découpages de polygons
ne sont plus nécessaires et les polygons adjacents ayant le même type de zone communale (et non typstd) doivent être "mergé".

PAR CONTRE ET C'EST IMPORTANT, il faut récupérer l'information qui découpait les polygons dans des couches "superposition" AVANT de lancer le "merge".
IL FAUT RECUPERER:
- Sensibilité au bruit
- Danger 
- Protection non répertorié par typprot ou typstd (genre protec archéologique)
Le PAD est déjà vectorisé.
*/ -- On s'assure que la géometrie d'affectation_com_new ne contient aucune erreur et on corrige les erreurs le cas échéant. Tout beau tout propre.

DELETE
FROM affectation_com_new 
WHERE GeometryType(geom) = 'LINESTRING';

DELETE FROM affectation_com_new
WHERE TYPSTD IN ('ZSA'); -- On a récupérer toutes l'information superposée donc on peut enfin supprimer la zone sans affectation



UPDATE affectation_com_new
SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(NEW.geom), 3))
FROM
  (SELECT geom,
          gid
   FROM affectation_com_new
   WHERE ST_ISVALID(affectation_com_new.geom) = FALSE) AS NEW
WHERE affectation_com_new.gid = NEW.gid;


 -- Unification (géométrie + FOSNR_zone uniquement) des géomètries découpées.

DROP TABLE IF EXISTS merged;


CREATE TABLE merged AS
SELECT (ST_DUMP(ST_Union(ST_SnapToGrid(geom,0.0001)))).geom,
       FOSNR_zone,
       FOSNR::smallint,
       ZONE,
       max(datesaisie) datesaisie,
       typstd_2015,
       code_type
FROM affectation_com_new -- A changé pour affectation_2015 une fois chaque typstd_2015 attribué.

GROUP BY FOSNR_zone,
         FOSNR,
         ZONE, -- Meme si le typestd est identique si la zone communale est différente on ne peut pas effectuer le merge.
         typstd_2015,
         code_type;

 -- On ajoute un GID et l'operateur:

ALTER TABLE merged ADD COLUMN GID SERIAL, ADD COLUMN OPERATEUR character varying(50);


UPDATE merged
SET OPERATEUR = t1.ope
FROM
  (SELECT t.ope ope,
          t.gid
   FROM
     (SELECT DISTINCT a.*,
                      lower(b.operateur) ope
      FROM merged a,
           affectation_com_new b
      WHERE a.FOSNR_zone = b.FOSNR_zone
        AND a.datesaisie = b.datesaisie
        AND lower(b.operateur) NOT IN('pagbre')
      ORDER BY gid) AS t) AS t1
WHERE t1.gid = merged.gid;

 -- On supprime les erreurs topologiques (chevauchement) de < de 10m^2 || Rallonge passablement l'opération on peut commenter durant la phase de teste.

DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Elimination des erreurs topologiques'; END $$;
DROP TABLE IF EXISTS TEMPS;

CREATE TABLE TEMPS AS
(
SELECT st_intersection(a.geom,b.geom) as geom, a.gid as gid
FROM merged a, merged b
WHERE st_intersects(a.geom,b.geom)
AND a.gid < b.gid
GROUP BY a.geom, b.geom, a.gid
having st_area(st_intersection(a.geom,b.geom)) < 10
);

/* Avant la VERSION de postgresql 9.3 la fonction ST_MakeValid ne supporte pas tous les types de géometries en entré, donc je filtre déjà avant afin de ne pas avoir de bug */

DELETE FROM temps WHERE 
lower(geometrytype(geom)) != 'multipolygon'
AND 
lower(geometrytype(geom)) != 'polygon';

UPDATE temps
SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(ST_SnapToGrid(geom,0.0001)), 3));

DROP TABLE IF EXISTS TEST;
CREATE TABLE TEST AS
with temp as 
(
  select   b.gid, st_union(a.geom) as geom
  from     merged b join temps a on st_intersects(a.geom, b.geom)
  group by b.gid
) 
select st_difference(b.geom,coalesce(t.geom, 'GEOMETRYCOLLECTION EMPTY'::geometry)) as geom, b.fosnr, b.fosnr_zone, b.zone, b.datesaisie, b.typstd_2015, b.gid, b.operateur, b.code_type
from merged b left join temp t on b.gid = t.gid
WHERE t.gid = b.gid;

DROP TABLE TEMPS;

DROP TABLE IF EXISTS TEST2;
CREATE TABLE TEST2 AS
SELECT * FROM TEST
UNION
SELECT a.geom, a.fosnr, a.fosnr_zone, a.zone, a.datesaisie, a.typstd_2015, a.gid, a.operateur, a.code_type FROM merged a
WHERE a.gid not in 
(
SELECT test.gid
FROM test
);

DROP TABLE TEST;

DROP TABLE merged;

ALTER TABLE TEST2
RENAME TO merged;
DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Fin Elimination des erreurs topologiques'; END $$;


 -- On ajoute l'aire et le périmètre

ALTER TABLE merged
DROP COLUMN IF EXISTS shape_leng,
DROP COLUMN IF EXISTS shape_area,
                      ADD COLUMN shape_leng numeric, ADD COLUMN shape_area numeric;


UPDATE merged
SET shape_leng = st_Perimeter(geom),
                 shape_area = st_area(geom);

-- LE MGDM recquiere l'attribut statutjuridique, les zones déjà présentes (donc pas FORET/ROUTE/ZA) sont toutes contraignantes:
ALTER TABLE merged
ADD COLUMN statutjuridique character varying(50);
UPDATE merged
SET statutjuridique = 'Contraignant';

DELETE FROM merged WHERE 
lower(geometrytype(geom)) != 'multipolygon'
AND 
lower(geometrytype(geom)) != 'polygon';
                
UPDATE merged
SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(ST_SnapToGrid(geom,0.0001)), 3));
 -- NETTOYAGE DES DONNEES

 -- voir: http://gis.stackexchange.com/q/198115
 
 -- Sliver Killer et Sliver Murder : mission erradiquer les slivers.
 -- ETAPE 1: On dézingue les slivers enclavée dans un polygone


--UPDATE merged
--SET geom = sliver_killer(geom,50::float);

 -- ETAPE 2: On dézingue les slivers qui touchent le bord du polygone.

UPDATE merged
SET geom = sliver_murder(geom,0.5::float);

 -- C'est beau, c'est propre


 
 -- Merge devient affectation_com_new

ALTER TABLE affectation_com_new RENAME TO affectation_com_new_backup;

ALTER TABLE merged RENAME TO affectation_com_new;

DROP TABLE affectation_com_new_backup;

-- On ajoute le champ REMARQUE à affectation_com_new (la zone d'affectation_com_old la plus grande superposée par une zone d'affectation_com_new donne sa remarque à cette dernière)

ALTER TABLE affectation_com_new ADD COLUMN REMARQUE character varying(500);

UPDATE affectation_com_new SET REMARQUE = T1.remarq
FROM
(
	select DISTINCT ON (a.gid) a.gid, st_area(st_intersection(a.geom,b.geom)), b.remarq from affectation_com_new a, affectation_com_old b
	where st_intersects(a.geom,b.geom)
	order by gid, st_area DESC
) as T1
WHERE T1.gid = affectation_com_new.gid;

-- Mais si une zone affectation_com_new recouvre plus d'une zone affectation_com_old et que les zones recouvertes par une des nouvelles entitées possèdes des remarques différentes on supprime les remarques
-- mieux vaut pas d'information que de l'information erronée sur une partie des zones

UPDATE affectation_com_new SET remarque = null
FROM
(
select a.gid,count(*) as newcount,regexp_replace(a.remarque, E'[\\n\\r]+', ' ', 'g' ), count(distinct coalesce(b.remarq,'0')) as oldcount from affectation_com_new a, affectation_com_old b
where st_intersects(st_buffer(a.geom,-0.2),b.geom)
and st_intersects(a.geom,b.geom)
group by  a.gid, a.remarque
order by newcount
) t2 
where affectation_com_new.gid = t2.gid
and t2.newcount > 1
and t2.oldcount > 1;

-- On supprime la ZA issue de l'ancienne table affectation_com 

DELETE FROM affectation_com_new WHERE typstd_2015 = 'ZA';

-- On renomme TYPSTD_2015 à TYPSTD

ALTER TABLE affectation_com_new
RENAME typstd_2015 to typstd;

-- On ajoute la référence spatial 

ALTER TABLE affectation_com_new
ALTER COLUMN geom TYPE geometry(MULTIPOLYGON,21781) USING ST_Multi(geom),
DROP COLUMN gid,
ADD COLUMN gid SERIAL;
SELECT UpdateGeometrySRID('public','affectation_com_new','geom',21781);
ALTER TABLE affectation_com_new  ADD PRIMARY KEY (gid);

-- On transfert le code_type de affectation_com à zone_comm

ALTER TABLE ZONE_COMM_NEW
ADD COLUMN code_type smallint;

UPDATE zone_comm_new  SET code_type = a.code_type
FROM
(
select distinct code_type,  fosnr, zone from affectation_com_new
) a
WHERE zone_comm_new.fosnr = a.fosnr
AND zone_comm_new.zone = a.zone;

-- On ajoute l'operateur à zone_comm

ALTER TABLE ZONE_COMM_NEW
ADD COLUMN OPERATEUR CHARACTER VARYING(50);

UPDATE ZONE_COMM_NEW SET OPERATEUR = a.OPERATEUR
FROM
(
SELECT distinct on (a.fosnr_zone) a.operateur, a.fosnr_zone, a.datesaisie from affectation_com_new a
order by a.fosnr_zone,a.datesaisie asc
) a
WHERE FOSNR_ZONE = a.FOSNR_ZONE;

-- On supprime les zones dont la largeur maximal n'excède pas 1.5m

	DELETE FROM affectation_com_new  
	WHERE gid in
	(
	select gid from affectation_com_new 
	group by gid,geom
	having st_area(ST_Buffer(ST_Buffer(geom,-1.5,'join=mitre'),1.5,'join=mitre')) < 1
	); 
	
DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Fin de création affectation_com avec merge'; END $$;


-- On  transfert la référence aux articles du RCU de la table zone_comm à la table expressément dévouée à les accueillir.

	DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Extraction des références aux RCU pour zone_comm'; END $$;

	ALTER TABLE zone_comm_new
	ADD COLUMN article smallint,
	ADD COLUMN article_fin smallint,
	ADD COLUMN "union" character varying(5);
	

	UPDATE zone_comm_new set 
	article = (regexp_matches(lower(affect),'art\W{1,2}(\d+)(\s+(und|et|à)\s+(\d+))?'))[1]::smallint;
	UPDATE zone_comm_new set 
	"union" = (regexp_matches(lower(affect),'art\W{1,2}(\d+)(\s+(und|et|à)\s+(\d+))?'))[3],
	article_fin = (regexp_matches(lower(affect),'art\W{1,2}(\d+)(\s+(und|et|à)\s+(\d+))?'))[4]::smallint;

	
	UPDATE zone_comm_new set "union" = 'et'
	WHERE "union" ='und';

	UPDATE zone_comm_new set article_fin = null
	WHERE article_fin is null;

DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Fin de l''extraction des références aux RCU pour zone_comm'; END $$;

-- Extraction des références aux RCU pour les superpositions protection et affectation

DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Extraction des références aux RCU pour les superpositions protection et affectation'; END $$;

DROP TABLE IF EXISTS DISPOSITION_AFFECTATION;
CREATE TABLE DISPOSITION_AFFECTATION AS
(
SELECT DISTINCT 
fosnr_code,
(regexp_matches(lower(affect),'art\W{1,2}(\d+)(\s+(und|et|à)\s+(\d+))?'))[1]::smallint as article, 
(regexp_matches(lower(affect),'art\W{1,2}(\d+)(\s+(und|et|à)\s+(\d+))?'))[3] as union, 
(regexp_matches(lower(affect),'art\W{1,2}(\d+)(\s+(und|et|à)\s+(\d+))?'))[4]::smallint as article_fin
FROM
(
SELECT a.gid as sgid, b.fosnr_zon, c.affect, a.fosnr_code
from 
superposition_affectation a, 
affectation_com_old b, 
zone_comm_old c
where st_intersects(a.geom,st_buffer(b.geom,-0.5)) -- Buffer négatif pour éviter de racoller les articles des zones adjacentes.
and st_intersects(a.geom,b.geom)
and b.fosnr_zon = c.fosnr_zon
order by a.gid
) T1
order by fosnr_code
);

UPDATE DISPOSITION_AFFECTATION SET "union" = 'et' 
WHERE lower("union") LIKE 'und';


DROP TABLE IF EXISTS DISPOSITION_PROTECTION;
CREATE TABLE DISPOSITION_PROTECTION AS
(
SELECT DISTINCT 
fosnr_code,
(regexp_matches(lower(affect),'art\W{1,2}(\d+)(\s+(und|et|à)\s+(\d+))?'))[1]::smallint as article, 
(regexp_matches(lower(affect),'art\W{1,2}(\d+)(\s+(und|et|à)\s+(\d+))?'))[3] as union, 
(regexp_matches(lower(affect),'art\W{1,2}(\d+)(\s+(und|et|à)\s+(\d+))?'))[4]::smallint as article_fin
FROM
(
SELECT a.gid as sgid, b.fosnr_zon, c.affect, a.fosnr_code
from 
superposition_protection a, 
affectation_com_old b, 
zone_comm_old c
where st_intersects(a.geom,st_buffer(b.geom,-0.5)) -- Buffer négatif pour éviter de racoller les articles des zones adjacentes.
and st_intersects(a.geom,b.geom)
and b.fosnr_zon = c.fosnr_zon
order by a.gid
) T1
order by fosnr_code
);
UPDATE DISPOSITION_PROTECTION SET "union" = 'et' 
WHERE lower("union") like 'und';

DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Fin Extraction des références aux RCU pour les superpositions protection et affectation'; END $$;

-- Pour une raison que j'ignore topoforms ne gère pas l'attribut FOSNR_CODE si il est sous la forme 2013_433, je dois donc bazarder l'underscore

UPDATE DISPOSITION_AFFECTATION SET FOSNR_CODE =  replace(fosnr_code, '_', '')::integer;
UPDATE DISPOSITION_PROTECTION SET FOSNR_CODE =  replace(fosnr_code, '_', '')::integer;
UPDATE SUPERPOSITION_AFFECTATION SET FOSNR_CODE =  replace(fosnr_code, '_', '')::integer;
UPDATE SUPERPOSITION_PROTECTION SET FOSNR_CODE =  replace(fosnr_code, '_', '')::integer;

-- SI length(operatuer) > 50 operateur = null
UPDATE superposition_bruit SET operateur = '' 
WHERE GID IN
(
select gid from superposition_bruit
group by operateur, gid
having octet_length(operateur) > 50
);


DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Fin de la migration'; END $$;