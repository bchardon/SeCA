
SELECT * FROM (SELECT NUFECO, shape_area, shape_leng, COUNT(*) as FREQ
FROM oca1032s_affectation_com 
group by NUFECO, shape_area, shape_leng 
order by FREQ desc) AS DOUBLON
WHERE FREQ > 1