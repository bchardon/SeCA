﻿	DROP TABLE IF EXISTS oca1032s_affectation_2015;
	
	SELECT * 
	INTO oca1032s_affectation_2015
	FROM oca1032s_affectation_com;
	
	ALTER TABLE oca1032s_affectation_2015 
	DROP COLUMN ZPAD, 
	DROP COLUMN ZPED, 
	DROP COLUMN NUREGPAD, 
	DROP COLUMN ETAT_PAD, 
	DROP COLUMN SENSIBLESP, 
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
	WHERE TYPSTD = 'ZC'

	UPDATE oca1032s_affectation_2015
	SET TYPSTD_2015 = 'ZA'
	WHERE TYPSTD = 'PADIV' 
	

	/*UNE FOIS LE PROCESSUS TERMINE DE COPIE/TRANSFORMATION/EXTRACTION/SUPPRESSION du TYPSTD
	  ON SUPPRIME L'ANCIEN TYPSTD ET ON LE REMPLACE PAR LE NOUVEAU
	  
	ALTER TABLE oca1032s_affectation_2015 
	DROP COLUMN TYPSTD; 
	
	ALTER TABLE oca1032s_affectation_2015
	RENAME COLUMN TYPSTD_2015 TO TYPSTD;
	
	*/

	
	

	

	