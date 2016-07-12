/*Création de la couche superpositionaffectation, qui comprend la géométrie et les différents attributs liés aux PAD*/
/*Egalement, on ajoute l'attribut DateInitPlanSpe à oca1023t_no_pad*/

TRUNCATE superpositionaffectation;

INSERT INTO superpositionaffectation (publieedep,designatio,etat_pad,nuregpad,operateur,geom,nufeco)
SELECT sp.crea_date,
	sp.nom_pad,
	sp.etat_proce,
	sp.id_pad,
	sp.crea_user,
	ssp.geom,
	sp.fosnr
	
FROM 	oca8030t_suivipal_pad sp, 
	oca8030s_suivipal_pad ssp
WHERE ssp.pad_id = sp.id_pad
AND sp.id_pad IS NOT NULL;


