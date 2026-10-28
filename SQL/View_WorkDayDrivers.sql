-- SELECT * FROM pbi.v_WorkDayDrivers

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'v_WorkDayDrivers' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_WorkDayDrivers;
GO

CREATE VIEW pbi.v_WorkDayDrivers AS
WITH Unpivoted AS (
    SELECT 
        ti._LineNo33004 AS Nom, 
        f._Description AS Driver,
        r._Description AS Department,
        ti._Fld33005RRef AS DriverRef,
        unpvt.DayNumber,
        unpvt.FieldValue,
        t._Date_Time
    FROM work.dbo._Document32999_VT33003 ti 
    INNER JOIN work.dbo._Document32999 t 
        ON ti._Document32999_IDRRef = t._IDRRef 
    INNER JOIN work.dbo._Reference254 f 
        ON f._IDRRef = ti._Fld33005RRef
    INNER JOIN work.dbo._Reference173 r 
        ON r._IDRRef = t._Fld33000RRef
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
    WHERE t._Fld33000RRef IN (0x90A102B31CC3E40111EDC23F750EDDA1, 0x90A102B31CC3E40111EDC23FA67A951B)
),
Nums AS (
    SELECT i FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),
                           (11),(12),(13),(14),(15),(16),(17),(18),(19),(20)) n(i)
),
Parsed AS (
    SELECT 
        u.FieldValue,
        NULLIF(LTRIM(RTRIM((
            SELECT SUBSTRING(u.FieldValue, n.i, 1) AS [text()]
            FROM Nums n
            WHERE n.i <= LEN(u.FieldValue)
              AND CHARINDEX(SUBSTRING(u.FieldValue, n.i, 1), '0123456789') = 0
              AND SUBSTRING(u.FieldValue, n.i, 1) <> ','
            ORDER BY n.i
            FOR XML PATH(''), TYPE
        ).value('.', 'nvarchar(max)'))), '') AS FieldValueLetters,
        NULLIF(LTRIM(RTRIM((
            SELECT SUBSTRING(u.FieldValue, n.i, 1) AS [text()]
            FROM Nums n
            WHERE n.i <= LEN(u.FieldValue)
              AND (CHARINDEX(SUBSTRING(u.FieldValue, n.i, 1), '0123456789') > 0
                   OR SUBSTRING(u.FieldValue, n.i, 1) IN (',', ' '))
            ORDER BY n.i
            FOR XML PATH(''), TYPE
        ).value('.', 'nvarchar(max)'))), '') AS NumbersRaw
    FROM (SELECT DISTINCT FieldValue FROM Unpivoted) u
)
SELECT 
    u.Nom,
    u.Driver,
    u.Department,
    u.DayNumber,
    u.FieldValue,
    p.FieldValueLetters,
    CASE 
        WHEN p.NumbersRaw IS NOT NULL AND CHARINDEX(' ', p.NumbersRaw) = 0
        THEN TRY_CONVERT(decimal(10,2), REPLACE(p.NumbersRaw, ',', '.'))
    END AS FieldValueNumeric,
    CAST(d.dt AS date) AS [Date],
    wd.WorkDate,
    cd._Description AS DriverClass
FROM Unpivoted u
LEFT JOIN Parsed p ON p.FieldValue = u.FieldValue
CROSS APPLY (
    SELECT IIF(u._Date_Time >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, u._Date_Time), u._Date_Time) AS dt
) d
CROSS APPLY (
    SELECT CASE 
        WHEN u.DayNumber <= DAY(EOMONTH(d.dt))
        THEN DATEFROMPARTS(YEAR(d.dt), MONTH(d.dt), u.DayNumber)
    END AS WorkDate
) wd
OUTER APPLY (
    SELECT TOP 1 cl._Fld33136RRef AS ClassRef
    FROM work.dbo._InfoRg33134 cl
    WHERE cl._Fld33135RRef = u.DriverRef
      AND IIF(cl._Period >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, cl._Period), cl._Period) <= wd.WorkDate
    ORDER BY cl._Period DESC
) cls
LEFT JOIN work.dbo._Reference33129 cd ON cd._IDRRef = cls.ClassRef
GO
