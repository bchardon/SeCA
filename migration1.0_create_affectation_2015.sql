	DROP TABLE IF EXISTS oca1032s_affectation_2015;
	
	SELECT * 
	INTO oca1032s_affectation_2015
	FROM oca1032s_affectation_com;
	
	ALTER TABLE oca1032s_affectation_2015 
	DROP COLUMN ZPAD, 
	DROP COLUMN ZPED, 
	DROP COLUMN NUREGPAD, 
	DROP COLUMN ETAT_PAD, 
	DROP COLUMN SENSIBLESP, 
	DROP COLUMN SURF_SECT, -- A double avec shape_area.
	-- DROP COLUMN TYPPROT, TYPPROT DEVRA ETRE A TERME SUPPRIMER 
	ADD COLUMN TYPSTD_2015 character varying(6);
	
	ALTER TABLE oca1032s_affectation_2015
	RENAME COLUMN PLANAFF TO StatutJuridique;
	
	ALTER TABLE oca1032s_affectation_2015
	RENAME COLUMN DATSAI TO PublieeDepuis;
	
	UPDATE oca1032s_affectation_2015
	SET TYPSTD_2015 = TYPSTD
	WHERE TYPSTD IN ('ZA','ZACT','ZG','ZIG','ZL','ZM','ZRFD','ZRMD','ZRHD','ZRS','ZV','ZVI');


-- 	LE CAS du TYPSTD = F (Aire FORESTIERE) est traité à part dans le mesure ou ces aires forestières devront
--	être complété (à l'aide du SFF par exemple)

	UPDATE oca1032s_affectation_2015
	SET TYPSTD_2015 = 'F'
	WHERE TYPSTD = 'F';

	UPDATE oca1032s_affectation_2015
	SET TYPSTD_2015 = 'ZTL'
	WHERE TYPSTD = 'ZC';

-- PADIV devient ZA + Un perimètre de protection PADIV

	UPDATE oca1032s_affectation_2015
	SET TYPSTD_2015 = 'ZA'
	WHERE TYPSTD = 'PADIV';


-- LA QUERY SUIVANTE POURRAIT AUSSI ETRE PLACE DANS le fichier SQL 1.1
-- et ne pas renommer les zones mais les sortir en superposition.

	UPDATE oca1032s_affectation_2015
	SET TYPSTD_2015 = 'ZPCE'
	WHERE TYPSTD = 'ZPCE' 
	OR (TYPSTD = 'ZP' AND TYPPROT = 'EAU');

-- ZPBC devient ZCP (A discuter) mais je pense qu'ici ça doit rester une affectation
-- primaire

	UPDATE oca1032s_affectation_2015
	SET TYPSTD_2015 = 'ZPBC'
	WHERE TYPSTD = 'ZCP';	
	

	/*UNE FOIS LE PROCESSUS TERMINE DE COPIE/TRANSFORMATION/EXTRACTION/SUPPRESSION du TYPSTD
	  ON SUPPRIME L'ANCIEN TYPSTD ET ON LE REMPLACE PAR LE NOUVEAU
	  
	ALTER TABLE oca1032s_affectation_2015 
	DROP COLUMN TYPSTD; 
	
	ALTER TABLE oca1032s_affectation_2015
	RENAME COLUMN TYPSTD_2015 TO TYPSTD;
	
	*/

	
	

	

	