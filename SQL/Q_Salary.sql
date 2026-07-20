
select t.*, o._Date_Time, o._Fld6771 from _Document403_VT6775 t
INNER JOIN _Document403 o ON o._IDRRef = t._Document403_IDRRef
WHERE o._Fld6774 LIKE '%Велигорська%'
order by o._Date_Time