-- SELECT * FROM pbi.v_DimCargoGroup
-- SELECT * FROM pbi.vb_DimCargoGroup

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'v_DimCargoGroup' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_DimCargoGroup;
GO

CREATE VIEW pbi.v_DimCargoGroup AS
SELECT
    CONVERT(VARCHAR(MAX), _IDRRef, 2)                     AS CargoGroupRef,
    CAST(_Marked AS BIT)                                  AS DeleteMark,
    CONVERT(VARCHAR(MAX), _ParentIDRRef, 2)               AS ParentGroupRef,
    CONVERT(VARCHAR(MAX), _PredefinedID, 2)               AS PredefinedID,
    CAST(_Folder AS BIT)                                  AS IsGroup,
    LTRIM(RTRIM(_Code))                                   AS Code,
    _Description                                          AS CargoGroupName,
    _Fld3606                                              AS [Class],
    CAST(_Fld26900 AS BIT)                                AS DangerousCargo,
    CAST(_Fld32743 AS BIT)                                AS HeatingSummer,
    CAST(_Fld32744 AS BIT)                                AS HeatingWinter,
    CAST(_Fld33983 AS BIT)                                AS FoodCargo,
    CAST(_Fld34237 AS BIT)                                AS GMP,
    CONVERT(VARCHAR(MAX), _Fld34254RRef, 2)               AS UKTVEDRef
FROM work.dbo._Reference271;
GO

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'vb_DimCargoGroup' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_DimCargoGroup;
GO

CREATE VIEW pbi.vb_DimCargoGroup AS
SELECT
    _IDRRef                                               AS CargoGroupRef,
    _Marked                                               AS DeleteMark,
    _ParentIDRRef                                         AS ParentGroupRef,
    _PredefinedID,
    _Folder                                               AS IsGroup,
    LTRIM(RTRIM(_Code))                                   AS Code,
    _Description                                          AS CargoGroupName,
    _Fld3606                                              AS [Class],
    _Fld26900                                             AS DangerousCargo,
    _Fld32743                                             AS HeatingSummer,
    _Fld32744                                             AS HeatingWinter,
    _Fld33983                                             AS FoodCargo,
    _Fld34237                                             AS GMP,
    _Fld34254RRef                                         AS UKTVEDRef
FROM work.dbo._Reference271;
GO
