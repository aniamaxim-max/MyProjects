SELECT 
    ti._LineNo33004 AS Nom, 
    f._Description AS Driver,
    unpvt.DayNumber,
    unpvt.FieldValue
FROM _Document32999_VT33003 ti 
INNER JOIN _Document32999 t 
    ON ti._Document32999_IDRRef = t._IDRRef 
INNER JOIN _Reference254 f 
    ON f._IDRRef = ti._Fld33005RRef
CROSS APPLY (
    VALUES 
        (1, ti._Fld33006), (2, ti._Fld33007), (3, ti._Fld33008), (4, ti._Fld33009),
        (5, ti._Fld33010), (6, ti._Fld33011), (7, ti._Fld33012), (8, ti._Fld33013),
        (9, ti._Fld33014), (10, ti._Fld33015), (11, ti._Fld33016), (12, ti._Fld33017),
        (13, ti._Fld33018), (14, ti._Fld33019), (15, ti._Fld33020), (16, ti._Fld33021),
        (17, ti._Fld33022), (18, ti._Fld33023), (19, ti._Fld33024), (20, ti._Fld33025),
        (21, ti._Fld33026), (22, ti._Fld33027), (23, ti._Fld33028), (24, ti._Fld33029),
        (25, ti._Fld33030), (26, ti._Fld33031), (27, ti._Fld33032), (28, ti._Fld33033),
        (29, ti._Fld33034), (30, ti._Fld33035), (31, ti._Fld33036)
) AS unpvt(DayNumber, FieldValue)
WHERE t._Fld33000RRef = 0x90A102B31CC3E40111EDC23F750EDDA1 
  AND t._Date_Time = '40260630 12:00:00';