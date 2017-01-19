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
	    'PPP'
	FROM oca1032s_affectation_2015 aff
	WHERE (typstd LIKE 'ZP%'
	AND TYPPROT = 'PAY')
	OR typstd LIKE 'ZPP';
	
	DELETE FROM oca1032s_affectation_2015 
	WHERE (typstd LIKE 'ZP%'
	AND TYPPROT = 'PAY')
	OR typstd LIKE 'ZPP';

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
	    'PPN'
	FROM oca1032s_affectation_2015 aff
	WHERE typstd LIKE 'ZP%'
	AND TYPPROT = 'NAT';

	DELETE FROM oca1032s_affectation_2015 
	WHERE typstd LIKE 'ZP%'
	AND TYPPROT LIKE 'NAT';

	-- DELETE les ROW ou TYPSTD = SPL et les places dans un SECTEUR SUPERPOSE de tourisme et loisir (STL).
	
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
	    'STL'
	FROM oca1032s_affectation_2015 aff
	WHERE typstd LIKE 'STL';

	DELETE FROM oca1032s_affectation_2015 
	WHERE typstd LIKE 'STL';


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
	    'PADIV'
	FROM oca1032s_affectation_2015 aff
	WHERE typstd LIKE 'PADIV';

	-- ICI on ne supprime pas la ZONE, elle est simplement transformé en ZA
	-- (le changement est effectué dans la query 1.0)


	/*ON CREE UN SECTEUR DE PROTECTION ARCHEOLOGIQUE si la mention périmètre archéologique 
	figure dans le champ remarque*/

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
	    'PA'
	FROM oca1032s_affectation_com 
	WHERE lower(remarq) like '%archäo%' 
	OR lower(remarq) like '%archéo%';




/*ON CREE UN SECTEUR DE PROTECTION DU SITE CONSTRUIT si la mention périmètre de protection du site construit 
	figure dans le champ remarque*/

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
	    'PPC'
	FROM oca1032s_affectation_com 
	WHERE lower(remarq) like '%protection%'
	AND lower(remarq) like '%site%'; 
	-- Attention ici vu que la 


 

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
	
