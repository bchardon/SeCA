/* LE SCRIPT SUIVANT PERMET D'EFFECTUER LA MIGRATION DES DONNEES d'AFFECTATION AFIN DE RENDRE COMPATIBLE CES DONNEES AVEC LE MGDM FEDERAL */
-- ENVIRON 3 minutes pour tourner.

-- Creation des fonctions de nettoyage des données.
 -- Sliver Killer et Sliver Murder 
 -- ETAPE 1: On dézingue les slivers enclavée dans un polygone

CREATE OR REPLACE FUNCTION sliver_killer(geometry,float) RETURNS geometry AS $$
SELECT ST_BuildArea(ST_Collect(a.geom)) AS final_geom
FROM ST_DumpRings((st_dump($1)).geom) AS a
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
	RENAME COLUMN NUFECO TO FOSNR;
*/ -- CREATION D'AFFECTATION_COM_NEW

DROP TABLE IF EXISTS affectation_com_new;


SELECT * INTO affectation_com_new
FROM affectation_com_old;


ALTER TABLE affectation_com_new
DROP COLUMN ZPAD,
DROP COLUMN ZPED,
DROP COLUMN NUREGPAD,
DROP COLUMN ETAT_PAD,
DROP COLUMN SENSIBLESP,
DROP COLUMN SURF_SECT,
--DROP COLUMN OBJECTID,

DROP COLUMN LIEU,
DROP COLUMN NOSECT,
DROP COLUMN PLANAFF,
DROP COLUMN DATPLAN,
DROP COLUMN DEROGATION,
            -- A double avec shape_area.
 -- DROP COLUMN TYPPROT, TYPPROT DEVRA ETRE A TERME SUPPRIMER
 ADD COLUMN TYPSTD_2015 character varying(6),
                                  ADD COLUMN STATUTJURIDIQUE character varying(50);

 -- PLANAFF est déjà présent dans SUIVIPAL, de plus modification signifie
 -- que la zone est en cours de modificiation mais pas qu'elle a été modifié
 -- La préservation de cette attribut porte plus à confusion qu'elle ne rend service.
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
                 'ZVI');

 -- 	LE CAS du TYPSTD = F (Aire FORESTIERE) est traité à part dans le mesure ou ces aires forestières devront
--	être complété (à l'aide du SFF par exemple)
 
UPDATE affectation_com_new 
SET TYPSTD_2015 = 'F' 
WHERE TYPSTD = 'F';


UPDATE affectation_com_new
SET TYPSTD_2015 = 'ZTL'
WHERE TYPSTD = 'ZC';

 -- PADIV devient ZA + Un perimètre de protection PADIV

UPDATE affectation_com_new
SET TYPSTD_2015 = 'ZA'
WHERE TYPSTD = 'PADIV';

 -- LA QUERY SUIVANTE POURRAIT AUSSI ETRE PLACE DANS le fichier SQL 1.1
-- et ne pas renommer les zones mais les sortir en superposition.

UPDATE affectation_com_new
SET TYPSTD_2015 = 'ZPCE'
WHERE TYPSTD = 'ZPCE'
  OR (TYPSTD = 'ZP'
      AND TYPPROT = 'EAU');

 -- ZPBC devient ZCP (A discuter) mais je pense qu'ici ça doit rester une affectation
-- primaire
 
UPDATE affectation_com_new 
SET TYPSTD_2015 = 'ZCP' 
WHERE TYPSTD = 'ZPBC' 
  OR (TYPSTD = 'ZP'
      AND TYPPROT = 'ZPBC');

 -- Les périmètres d'habitats ruraux et périmètre d'habitats à maintenir sont transférer en zone agricole + périmètre de protection PHM.
-- (A DISCUTER, eventuellement creer une zone de protection à la place)

UPDATE affectation_com_new
SET TYPSTD_2015 = 'ZA'
WHERE TYPSTD IN ('PHR');

UPDATE affectation_com_new
SET TYPSTD_2015 = 'ZA'
WHERE TYPSTD IN ('PHM'); 

-- LE MGDM recquiere l'attribut statutjuridique, les zones déjà présentes (donc pas FORET/ROUTE/ZA) sont toutes contraignantes:
UPDATE affectation_com_new
SET statutjuridique = 'contraignant';

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


CREATE TABLE superposition_affectation ( geom geometry(MultiPolygon), FOSNR smallint, publieedepuis date, DATESAISIE date, statutjuridique character varying(50), forceobligatoire character varying(50), shape_leng numeric, shape_area numeric, remarques character varying(200), operateur character varying(50), typsupaff character varying(10), fosnr_aff character varying(20));


INSERT INTO superposition_affectation (geom,FOSNR, publieedepuis, DATESAISIE, remarques,operateur,typsupaff,fosnr_aff)
SELECT geom,
       FOSNR::smallint,
       datplan,
       datsai,
       remarq,
       operat,
       'PED',
       concat_ws('_',fosnr,'PED')
FROM affectation_com_old
WHERE zped = 'oui';


UPDATE superposition_affectation
SET shape_area = st_area(geom),
                 shape_leng = st_perimeter(geom),
                              statutjuridique = 'en vigueur',
                              typsupaff = 'PED';


INSERT INTO superposition_affectation (geom,FOSNR, publieedepuis,DATESAISIE, remarques,operateur,typsupaff,fosnr_aff)
SELECT geom,
       FOSNR::smallint,
       datplan,
       datsai,
       remarq,
       operat,
       'PSpe',
       concat_ws('_',fosnr,'PSpe')
FROM affectation_com_old
WHERE (zpad = 'non'
       OR zpad IS NULL)
  AND (zped = 'non'
       OR zped IS NULL)
  AND (lower(REMARQ) LIKE '%spez%'
       OR lower(REMARQ) LIKE '%presc%'
       OR lower(REMARQ) LIKE '%partic%'
       OR lower(REMARQ) LIKE '%bestim%')
  AND TYPPROT IS NULL
  AND typstd NOT LIKE 'ZP%'
  AND (lower(REMARQ) NOT LIKE '%archä%')
ORDER BY REMARQ;

-- on ajoute un ID.
ALTER TABLE superposition_affectation  
ADD COLUMN GID serial;

 -- Unification des géomètries découpées.

DROP TABLE IF EXISTS merged;


CREATE TABLE merged AS
SELECT (ST_DUMP(ST_Union(ST_SnapToGrid(geom,0.0001)))).geom as geom,
       FOSNR_AFF,
       FOSNR::smallint,
       typsupaff
FROM superposition_affectation -- A changé pour affectation_2015 une fois chaque typstd_2015 attribué.

GROUP BY FOSNR_AFF,
         FOSNR,
         typsupaff;

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

 DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Fin de création superposition_affectation_com'; END $$;




























 /*CREATION DU NOUVEAU LAYER superposition_protection
LES ZONE dont les TYPPROT sont 'NAT' ou 'PAY' peuvent être en grande partie être transféré en perimètre superposé. Mais certaines zones devront peut être rester
dans le plan d'affectation. C'est pourquoi une colonne ZONEouSUPERPOS est ajouté afin de pouvoir choisir les zones de protection qui devront rester en zone de protection.
*/ -- migration1.0_creation_affectation_2015 doit être lancer avant cette query.

DROP TABLE IF EXISTS superposition_protection CASCADE;


CREATE TABLE superposition_protection ( geom geometry(MultiPolygon), FOSNR smallint, nosect smallint, datesaisie date, statutjuridique character varying(50), shape_leng numeric, shape_area numeric, remarques character varying(500), operateur character varying(50), typsupprot character varying(10));

 -- DELETE les ROW ou TYPSTD = ZP* et TYPPROT = 'PAY' ET LES PLACE DANS SECTEUR SUPERPOSE.

INSERT INTO superposition_protection (geom,FOSNR,datesaisie,statutjuridique,shape_leng,shape_area,remarques,operateur,typsupprot)
SELECT aff.geom,
       aff.FOSNR::smallint,
       aff.datesaisie,
       aff.statutjuridique,
       aff.shape_len,
       aff.shape_area,
       aff.remarques,
       aff.operateur,
       'PPP'
FROM affectation_com_new aff
WHERE (typstd LIKE 'ZP%'
       AND TYPPROT = 'PAY')
  OR typstd LIKE 'ZPP';


DELETE
FROM affectation_com_new
WHERE (typstd LIKE 'ZP%'
       AND TYPPROT = 'PAY')
  OR typstd LIKE 'ZPP';

 -- DELETE les ROW ou TYPSTD = PHM  ET LES PLACE DANS UN SECTEUR SUPERPOSE PHM.
 -- IDEM POUR TYPSTD = PHR
 -- (JE MET POUR L'INSTANT DANS superposition_protection A DISCUTER !!!)
INSERT INTO superposition_protection (geom,FOSNR,datesaisie,statutjuridique,shape_leng,shape_area,remarques,operateur,typsupprot)
SELECT aff.geom,
       aff.FOSNR::smallint,
       aff.datesaisie,
       aff.statutjuridique,
       aff.shape_len,
       aff.shape_area,
       aff.remarques,
       aff.operateur,
       'PHM'
FROM affectation_com_new aff
WHERE typstd LIKE 'PHM';


DELETE
FROM affectation_com_new
WHERE typstd LIKE 'PHM';
---------------------------------
INSERT INTO superposition_protection (geom,FOSNR,datesaisie,statutjuridique,shape_leng,shape_area,remarques,operateur,typsupprot)
SELECT aff.geom,
       aff.FOSNR::smallint,
       aff.datesaisie,
       aff.statutjuridique,
       aff.shape_len,
       aff.shape_area,
       aff.remarques,
       aff.operateur,
       'PHM' -- On crée un périmètre d'habitat à maintenir et pas un PHR (à discuter)
FROM affectation_com_new aff
WHERE typstd LIKE 'PHR';


DELETE
FROM affectation_com_new
WHERE typstd LIKE 'PHR';
  
 -- DELETE les ROW ou TYPSTD = ZP* et TYPPROT = 'NAT' ET LES PLACE DANS SECTEUR SUPERPOSE.

INSERT INTO superposition_protection (geom,FOSNR,datesaisie,statutjuridique,shape_leng,shape_area,remarques,operateur,typsupprot)
SELECT aff.geom,
       aff.FOSNR,
       aff.datesaisie,
       aff.statutjuridique,
       aff.shape_len,
       aff.shape_area,
       aff.remarques,
       aff.operateur,
       'PPN'
FROM affectation_com_new aff
WHERE typstd LIKE 'ZP%'
  AND TYPPROT = 'NAT';


DELETE
FROM affectation_com_new
WHERE typstd LIKE 'ZP%'
  AND TYPPROT LIKE 'NAT';

 -- DELETE les ROW ou TYPSTD = SPL et les places dans un SECTEUR SUPERPOSE de tourisme et loisir (STL).

INSERT INTO superposition_protection (geom,FOSNR,datesaisie,statutjuridique,shape_leng,shape_area,remarques,operateur,typsupprot)
SELECT aff.geom,
       aff.FOSNR,
       aff.datesaisie,
       aff.statutjuridique,
       aff.shape_len,
       aff.shape_area,
       aff.remarques,
       aff.operateur,
       'PTL'
FROM affectation_com_new aff
WHERE typstd LIKE 'STL';


DELETE
FROM affectation_com_new
WHERE typstd LIKE 'STL';

 /*ON CREE UN SECTEUR DE PROTECTION PADIV (Périmètre d'agriculture diversifiée) à l'endroit ou se situait les anciennes
	zone PADIV*/
INSERT INTO superposition_protection (geom,FOSNR,datesaisie,statutjuridique,shape_leng,shape_area,remarques,operateur,typsupprot)
SELECT aff.geom,
       aff.FOSNR,
       aff.datesaisie,
       aff.statutjuridique,
       aff.shape_len,
       aff.shape_area,
       aff.remarques,
       aff.operateur,
       'PADIV'
FROM affectation_com_new aff
WHERE typstd LIKE 'PADIV';

 -- ICI on ne supprime pas la ZONE, elle est simplement transformé en ZA
 -- (le changement est effectué dans la query 1.0)
 /*ON CREE UN PERIMETRE DE PROTECTION ARCHEOLOGIQUE si la mention périmètre archéologique
	figure dans le champ remarques*/
INSERT INTO superposition_protection (geom,FOSNR,datesaisie,statutjuridique,shape_leng,shape_area,remarques,operateur,typsupprot)
SELECT aff.geom,
       aff.FOSNR,
       aff.datesaisie,
       aff.statutjuridique,
       aff.shape_len,
       aff.shape_area,
       aff.remarques,
       aff.operateur,
       'PA'
FROM affectation_com_new aff
WHERE lower(remarques) LIKE '%archäo%'
  OR lower(remarques) LIKE '%archéo%'
  OR (typstd = 'ZP'
      AND typprot = 'ARCH');


DELETE
FROM affectation_com_new
WHERE (typstd = 'ZP'
       AND typprot = 'ARCH');

 /*ON CREE UN SECTEUR DE PROTECTION DU SITE CONSTRUIT si la mention périmètre de protection du site construit
	figure dans le champ remarquesue*/
INSERT INTO superposition_protection (geom,FOSNR,datesaisie,statutjuridique,shape_leng,shape_area,remarques,operateur,typsupprot)
SELECT aff.geom,
       aff.FOSNR,
       aff.datesaisie,
       aff.statutjuridique,
       aff.shape_len,
       aff.shape_area,
       aff.remarques,
       aff.operateur,
       'PPC'
FROM affectation_com_new aff
WHERE lower(remarques) LIKE '%protection%'
  AND lower(remarques) LIKE '%site%'; -- Attention ici vu que la selection est relativement souple il se peut (même si peu probable) que des périmètres de protection du site construit soit créer à tord.

 /* CETTE PARTIE FUSIONNE LES POLYGONES ADJACENT PARTAGEANT LE MÊME TYPE DE PROTECTION + MEME FOSNR + MEME REMARQUES (car un même type de protection peut faire référence à différents articles RCU)*/ -- La fonction "remplie" les trous dans les polygons, si le trou est inférieur à $2 m^2.

DROP VIEW IF EXISTS v1;


CREATE VIEW v1 AS
SELECT sliver_killer((ST_DUMP(ST_Union(geom))).geom,50::float) AS geom,
       typsupprot, fosnr, remarques
FROM superposition_protection
GROUP BY typsupprot, fosnr, remarques;

 -- On va rechoper l'information (

DROP TABLE IF EXISTS superposition_protection_temp;


CREATE TABLE superposition_protection_temp AS
SELECT v.FOSNR AS FOSNR,
       min(statutjuridique) AS statutjuridique,
       min(a.typsupprot) AS typsupprot,
       v.typsupprot AS gtyp,
       v.remarques AS remarques,
       v.geom AS geom
FROM v1 v,
     superposition_protection a
WHERE st_intersects(v.geom,a.geom)
  AND a.typsupprot = v.typsupprot
GROUP BY v.geom,
         v.typsupprot,
         v.fosnr,
         v.remarques;


ALTER TABLE superposition_protection_temp 
ADD COLUMN datesaisie date, 
ADD COLUMN operateur character varying(50),
ADD COLUMN gid serial, 
ADD COLUMN FOSNR_PROT character varying(30);

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
SET FOSNR_PROT = FOSNR || '_' || typsupprot::text;

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
                                      ADD COLUMN Code_Zone integer, ADD COLUMN typstd_2015 character varying(6); -- Devra être renommé en typstd (et donc typstd supprimé) une fois que chaque typstd_2015 sera attribué


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
        HAVING count(DISTINCT affn.typstd_2015) = 1)
     AND lower(affn.FOSNR_zone) = lower(z.FOSNR_zon)
     AND affn.typstd_2015 IS NOT NULL) AS s2
WHERE s2.zcom = zone_comm_new.zone
  AND s2.znuf = FOSNR;

 -- On crée l'attribut code_zone

UPDATE zone_comm_new
SET code_zone = cast(concat(typstd.code,typfed.code)AS integer)
FROM typfed,
     typstd
WHERE typfed.code = typstd.code_typfe
  AND typstd_2015 = typstd.abrev;

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


ALTER TABLE zone_comm_new ADD IOSGEN float, ADD IOSHI float, ADD IOSHC float, ADD IOSHG float, ADD IOSAUTR float, ADD IBUSGEN float, ADD IBUSHI float, ADD IBUSHG float, ADD IBUSHC float, ADD IBUSAUTR float, ADD IBUS_done boolean, ADD IOS_done boolean;

 -- Tous les txgen... non latec_2008 = taux d'occupation
-- Donc IOS = Taux d'occupation / 100

UPDATE zone_comm_new
SET (IOSGEN,
     IOSHI,
     IOSHG,
     IOSHC,
     IOSAUTR,
     IOS_done) =
  (SELECT TXGEN/100,
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
  (SELECT INDGEN*4.0/3.0,
          INDHI*4.0/3.0,
          INDHG*4.0/3.0,
          INDHC*4.0/3.0,
          INDAUTR*4.0/3.0,
          TRUE)
WHERE latec_2008 = 0;

-- Sauf lorsque IUS < 0.4 IBUS = 0.5

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
  (SELECT TXGEN,
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
  (SELECT TXGEN/100,
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
  (SELECT INDGEN,
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
  (SELECT INDGEN,
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
  (SELECT INDGEN,
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
  (SELECT 0,
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

 -- On crée le typfed:

UPDATE zone_comm_new
SET (TYPFED) =
  (SELECT typfed.code)
FROM typfed,
     typstd
WHERE zone_comm_new.typstd = typstd.abrev
  AND typfed.code = typstd.code_typfe;

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

 -- On cast les données pour les rendre compatibles avec le modèle.

ALTER TABLE zone_comm_new ALTER COLUMN fosnr 	  TYPE smallint using fosnr::smallint;
ALTER TABLE zone_comm_new ALTER COLUMN niveaugen  TYPE double precision using niveaugen::double precision;
ALTER TABLE zone_comm_new ALTER COLUMN niveauhi   TYPE double precision using niveauhi::double precision;
ALTER TABLE zone_comm_new ALTER COLUMN niveauhg   TYPE double precision using niveauhg::double precision;
ALTER TABLE zone_comm_new ALTER COLUMN niveauhc   TYPE double precision using niveauhc::double precision;
ALTER TABLE zone_comm_new ALTER COLUMN niveauautr TYPE double precision using niveauautr::double precision;

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
*/ -- ENVIRON 2 minutes pour runner.
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

 -- Création de la geometrie

DROP TABLE IF EXISTS superpositionbruit;


CREATE TABLE superpositionbruit AS
SELECT sensiblesp::smallint,
       (ST_DUMP(ST_Union(ST_SnapToGrid(ST_MakeValid(geom),0.0)))).geom
FROM affectation_com_old --WHERE sensiblesp > 0
GROUP BY sensiblesp;


DELETE
FROM superpositionbruit
WHERE GeometryType(geom) = 'LINESTRING';


ALTER TABLE superpositionbruit ADD COLUMN GID SERIAL, ADD COLUMN ForceObligatoire character varying(50),
                                                                                            ADD COLUMN DATESAISIE date, ADD COLUMN OPERATEUR character varying(50),
                                                                                                                                                       ADD COLUMN REMARQUES character varying(500);


UPDATE superpositionbruit
SET geom = sliver_murder(sliver_killer(geom,50::float),1::float);


UPDATE superpositionbruit
SET ForceObligatoire = 'Contraignant';

 /* UPDATE OPERATEUR, longue query car il faut récuperer les différents opérateurs potentielles */ -- CORRECTION DES GEOMETRIES

UPDATE superpositionbruit
SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(new.geom), 3))
FROM
  (SELECT geom,
          gid
   FROM superpositionbruit
   WHERE ST_ISVALID(superpositionbruit.geom) = FALSE) AS NEW
WHERE superpositionbruit.gid = NEW.gid;

 -- CORRECTION DES GEOMETRIES

UPDATE affectation_com_old
SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(NEW.geom), 3))
FROM
  (SELECT geom,
          gid
   FROM affectation_com_old
   WHERE ST_ISVALID(affectation_com_old.geom) = FALSE) AS NEW
WHERE affectation_com_old.gid = NEW.gid;


UPDATE superpositionbruit
SET OPERATEUR = t1.ope
FROM
  (SELECT s.GID gid,
          string_agg(DISTINCT lower(a.operat), ', ') ope
   FROM superpositionbruit s,
        affectation_com_old a
   WHERE st_overlaps(s.geom,a.geom)
   GROUP BY s.gid) AS t1
WHERE t1.gid = superpositionbruit.gid;

 -- FIN UPDATE OPERATEUR
 -- Ajout de FOSNR et FOSNR_DEGRE (necessaire pour la relation avec les dispositions)

ALTER TABLE superpositionbruit ADD COLUMN FOSNR smallint, ADD COLUMN FOSNR_DEGRE character varying(20);


UPDATE superpositionbruit
SET FOSNR = t1.FOSNR
FROM
  (SELECT c.FOSNR AS FOSNR,
          b.gid AS GID
   FROM oca8000s_suivipal_commune c,
        superpositionbruit b
   WHERE st_intersects(c.geom,st_centroid(b.geom))
   ORDER BY b.gid) AS t1
WHERE superpositionbruit.gid = t1.gid;


UPDATE superpositionbruit
SET FOSNR_DEGRE = FOSNR || '_' || sensiblesp::text;

 -- Ajout de déclassement

ALTER TABLE superpositionbruit ADD COLUMN declassement integer;


UPDATE superpositionbruit
SET declassement = 0;

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

 /* Creation de disposition ZONE */
DROP TABLE IF EXISTS disposition_zone CASCADE;


CREATE TABLE disposition_zone (FOSNR_zone character varying(20), Article smallint, Alinea smallint);


INSERT INTO disposition_zone (Article,FOSNR_zone)
SELECT res[3]::smallint,
       FOSNR_zone
FROM
  (SELECT regexp_matches(lower(remarques),'(art.)(\s*)(\d+)') res,
          FOSNR_zone
   FROM affectation_com_new) t1 ;

 DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Fin de création disposition zone'; END $$;

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
       typstd_2015
FROM affectation_com_new -- A changé pour affectation_2015 une fois chaque typstd_2015 attribué.

GROUP BY FOSNR_zone,
         FOSNR,
         ZONE, -- Meme si le typestd est identique si la zone communale est différente on ne peut pas effectuer le merge.
         typstd_2015;

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
select st_difference(b.geom,coalesce(t.geom, 'GEOMETRYCOLLECTION EMPTY'::geometry)) as geom, b.fosnr, b.fosnr_zone, b.zone, b.datesaisie, b.typstd_2015, b.gid, b.operateur
from merged b left join temp t on b.gid = t.gid
WHERE t.gid = b.gid;

DROP TABLE TEMPS;

DROP TABLE IF EXISTS TEST2;
CREATE TABLE TEST2 AS
SELECT * FROM TEST
UNION
SELECT a.geom, a.fosnr, a.fosnr_zone, a.zone, a.datesaisie, a.typstd_2015, a.gid, a.operateur FROM merged a
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
UPDATE merged
SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(ST_SnapToGrid(geom,0.0001)), 3));
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


 
 -- Merge devient affectation_com_new

ALTER TABLE affectation_com_new RENAME TO affectation_com_new_backup;

ALTER TABLE merged RENAME TO affectation_com_new;

DROP TABLE affectation_com_new_backup;
-- On supprime la ZA issue de l'ancienne table affectation_com 

DELETE FROM affectation_com_new WHERE typstd_2015 = 'ZA';

-- On renomme TYPSTD_2015 à TYPSTD

ALTER TABLE affectation_com_new
RENAME typstd_2015 to typstd;

DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Fin de création affectation_com avec merge'; END $$;
DO LANGUAGE plpgsql $$ BEGIN RAISE NOTICE 'Fin de la migration'; END $$;