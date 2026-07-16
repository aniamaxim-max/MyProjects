
select t.*, o._Date_Time from _Document403_VT6775 t
INNER JOIN _Document403 o ON o._IDRRef = t._Document403_IDRRef
WHERE o._Fld6774 LIKE '%Максимова%'
order by o._Date_Time