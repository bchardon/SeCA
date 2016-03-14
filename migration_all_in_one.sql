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
	-- DROP COLUMN TYPPROT, TYPPROT DEVRA ETRE A TERME SUPPRIMER 
	ADD COLUMN TYPSTD_2015 character varying(6);
	
	ALTER TABLE oca1032s_affectation_2015
	RENAME COLUMN PLANAFF TO StatutJuridique;
	
	ALTER TABLE oca1032s_affectation_2015
	RENAME COLUMN DATSAI TO PublieeDepuis;
	
	UPDATE oca1032s_affectation_2015
	SET TYPSTD_2015 = TYPSTD
	WHERE TYPSTD IN ('ZA','ZACT','ZG','ZIG','ZL','ZM','ZRFD','ZRMD','ZRHD','ZRS','ZV','ZVI');
	
	UPDATE oca1032s_affectation_2015
	SET TYPSTD_2015 = 'F'
	WHERE TYPSTD = 'F';
	

	/*CREATION DU NOUVEAU LAYER SuperpositionProtection
	*/


	TRUNCATE superpositionprotection;
	
	-- DELETE les ROW ou TYPSTD = ZP* et TYPPROT = 'PAY' ET LES PLACE DANS SECTEUR SUPERPOSE.

	INSERT INTO superpositionprotection (geom,nufeco,nosect,lieu,publieedep,statutjuri,shape_leng,shape_area,remarques,operateur,typsupprot)
	SELECT aff.geom,
	    aff.nufeco,
	    aff.nosect,
	    aff.lieu,
	    aff.publieedepuis,
	    aff.statutjuridique,
	    aff.shape_leng,
	    aff.shape_area,
	    aff.remarq,
	    aff.operat,
	    'ZSPNP'
	FROM oca1032s_affectation_2015 aff
	WHERE typstd LIKE 'ZP%'
	AND TYPPROT = 'PAY';

	DELETE FROM oca1032s_affectation_2015 
	WHERE typstd LIKE 'ZP%'
	AND TYPPROT LIKE 'PAY';

	-- DELETE les ROW ou TYPSTD = ZP* et TYPPROT = 'NAT' ET LES PLACE DANS SECTEUR SUPERPOSE.
	
	INSERT INTO superpositionprotection (geom,nufeco,nosect,lieu,publieedep,statutjuri,shape_leng,shape_area,remarques,operateur,typsupprot)
	SELECT aff.geom,
	    aff.nufeco,
	    aff.nosect,
	    aff.lieu,
	    aff.publieedepuis,
	    aff.statutjuridique,
	    aff.shape_leng,
	    aff.shape_area,
	    aff.remarq,
	    aff.operat,
	    'ZSPNP'
	FROM oca1032s_affectation_2015 aff
	WHERE typstd LIKE 'ZP%'
	AND TYPPROT = 'NAT';

	DELETE FROM oca1032s_affectation_2015 
	WHERE typstd LIKE 'ZP%'
	AND TYPPROT LIKE 'NAT';
	
	/* OPTION: AJOUTER UN ATTRIBUT ZONEouSUPERPOS AFIN 
	DE POUVOIR DETERMINER l'APPARTENANCE DE CHAQUE POLYGON A 
	UNE ZONE OU UN CONTENU SUPERPOSE */

	

	DO $$ 
	    BEGIN
		BEGIN
		    ALTER TABLE superpositionprotection ADD COLUMN ZONEouSUPERPOS character varying(6);
		EXCEPTION
		    WHEN duplicate_column THEN RAISE NOTICE 'column ZONEouSUPERPOS already exists in superpositionprotection.';
		END;
	    END;
	$$


	/*UNE FOIS LE PROCESSUS TERMINE DE COPIE/TRANSFORMATION/EXTRACTION/SUPPRESSION du TYPSTD
	  ON SUPPRIME L'ANCIEN TYPSTD ET ON LE REMPLACE PAR LE NOUVEAU
	  
	ALTER TABLE oca1032s_affectation_2015 
	DROP COLUMN TYPSTD; 
	
	ALTER TABLE oca1032s_affectation_2015
	RENAME COLUMN TYPSTD_2015 TO TYPSTD;
	
	*/
	