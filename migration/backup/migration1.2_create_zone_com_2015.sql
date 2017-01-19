/* La query suivante lie chaque zone communale d'une commune particulière avec le nouveau typstd_2015 SI et SEULEMENT SI chaque combinaise
de ZONE + NUFECO (de la table zone_com) ne fait référence qu'à un seul typstd_2015. 
En changeant le having count(distinct aff2015) = 1 à > 1 on peut voir les ZONE + NUFECO qui devront être traité manuellement car il y a
un conflit entre plusieur type de zone */

-- A AJOUTER:

-- Verification que chaque ZONE + NUFECO se voit attribuer un nouveau typstd 2015. Pour cela il est nécessaire que chaque zone d'affectation primaire
-- possède un nouveau TYPSTD_2015. Cette opération doit donc être réalisé après la transition affectation_2015.

DROP TABLE IF EXISTS oca1032t_zone_com_2015;

SELECT *
INTO oca1032t_zone_com_2015
FROM oca1032t_zone_comm;

ALTER TABLE oca1032t_zone_com_2015
DROP COLUMN HTTGEN,
DROP COLUMN HTTHI,
DROP COLUMN HTTHG,
DROP COLUMN HTTHC,
DROP COLUMN HTTAUTR,
DROP COLUMN distd,
DROP COLUMN sensible,
-- DROP COLUMN latec_2008,
ADD  COLUMN ForceObligatoire character varying(50),
ADD  COLUMN Code_Zone integer,
ADD  COLUMN typstd_2015 character varying(6); -- Devra être renommé en typstd (et donc typstd supprimé) une fois que chaque typstd_2015 sera attribué



UPDATE oca1032t_zone_com_2015
SET TYPSTD_2015 = s2.aff2015
FROM (
SELECT zcom,znuf,min(aff2015) as aff2015
FROM
(
	SELECT DISTINCT z.zone as zcom, z.nufeco as znuf, affn.typstd_2015 as aff2015  --, count(*) as occur
	FROM 
	oca1032s_affectation_2015 	affn, 
	oca1032t_zone_comm 		z,
	oca1032s_affectation_com 	affo
	WHERE 	z.nufeco = affo.nufeco
	AND 	z.zone 	 = affo.zone
	AND 	affn.gid = affo.gid
	GROUP BY z.zone, affn.typstd_2015, z.nufeco
) as s1
WHERE 	 aff2015 is not null
group by zcom,znuf
having count(distinct aff2015) = 1 -- POUR VOIR LES ZONES + NUFECO qui posent problème " = 1" --> "> 2".
order by zcom
) as s2
WHERE s2.zcom = oca1032t_zone_com_2015.zone
AND   s2.znuf = nufeco;

UPDATE oca1032t_zone_com_2015
SET code_zone = cast(concat(typstd.code,typfed.code)as integer)
FROM typfed, typstd
WHERE typfed.code = typstd.code_typfe
AND typstd_2015 = typstd.abrev;
