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
	    'ZPP'
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
	    'ZPN'
	FROM oca1032s_affectation_2015 aff
	WHERE typstd LIKE 'ZP%'
	AND TYPPROT = 'NAT';

	DELETE FROM oca1032s_affectation_2015 
	WHERE typstd LIKE 'ZP%'
	AND TYPPROT LIKE 'NAT';
	
	/* OPTION: AJOUTER UN ATTRIBUT ZONEouSUPERPOS AFIN 
	DE POUVOIR DETERMINER l'APPARTENANCE DE CHAQUE POLYGON A 
	UNE ZONE OU UN CONTENU SUPERPOSE */
	
	ALTER TABLE superpositionprotection 
	ADD COLUMN ZONEouSUPERPOS character varying(6);

	
	