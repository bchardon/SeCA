/*
SELECT nufeco,zone,count(*) as freq
FROM oca1032t_zone_comm 
GROUP BY nufeco,zone
order by freq desc
*/

DELETE
FROM oca1032t_zone_comm 
WHERE zone IS NULL