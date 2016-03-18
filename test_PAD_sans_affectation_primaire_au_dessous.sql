-- Permet de lister les id_pad des PAD qui n'ont pas de zone d'affectation primaire
-- au lieu ou il font effet.


select pad_id
from oca8030s_suivipal_pad
WHERE  pad_id not in
(
select distinct pad.PAD_ID
from oca8030s_suivipal_pad pad, oca1032s_affectation_com aff
WHERE ST_INTERSECTs(aff.geom,pad.geom) = TRUE
order by pad.pad_ID
)