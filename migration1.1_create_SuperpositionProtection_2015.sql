/*CREATION DU NOUVEAU LAYER SuperpositionProtection
LES ZONE dont les TYPPROT sont 'NAT' ou 'PAY' peuvent être en grande partie être transféré en perimètre superposé. Mais certaines zones devront peut être rester
dans le plan d'affectation. C'est pourquoi une colonne ZONEouSUPERPOS est ajouté afin de pouvoir choisir les zones de protection qui devront rester en zone de protection.
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


	/*ON CREE UN SECTEUR DE PROTECTION PADIV (Périmètre d'agriculture diversifiée) à l'endroit ou se situait les anciennes 
	zone PADIV*/

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
	WHERE typstd LIKE 'PADIV'

	-- ICI on ne supprime pas la ZONE, elle est simplement transformé en ZA
	
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
	