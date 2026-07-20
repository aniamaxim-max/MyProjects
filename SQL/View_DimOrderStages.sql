-- SELECT * FROM pbi.v_DimOrderStages
-- SELECT * FROM pbi.vb_DimOrderStages

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'v_DimOrderStages' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_DimOrderStages;
GO

CREATE VIEW pbi.v_DimOrderStages AS
SELECT
    CONVERT(VARCHAR(MAX), _Document650_IDRRef, 2)         AS OrderRef,
    _LineNo17819                                          AS LineNumber,
    CONVERT(VARCHAR(MAX), _Fld17820RRef, 2)               AS CargoRef,
    _Fld17821                                             AS [Weight],
    _Fld17826                                             AS Distance,
    IIF(_Fld17833 >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _Fld17833), NULL) AS StartDate,
    IIF(_Fld17834 >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _Fld17834), NULL) AS EndDate,
    _Fld17837                                             AS LoadingAddress,
    _Fld17838                                             AS UnloadingAddress,
    CAST(_Fld34307 AS BIT)                                AS ExactWeight
FROM work.dbo._Document650_VT17818;
GO

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'vb_DimOrderStages' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_DimOrderStages;
GO

CREATE VIEW pbi.vb_DimOrderStages AS
SELECT
    _Document650_IDRRef                                   AS OrderRef,
    _LineNo17819                                          AS LineNumber,
    _Fld17820RRef                                         AS CargoRef,
    _Fld17821                                             AS [Weight],
    _Fld17826                                             AS Distance,
    IIF(_Fld17833 >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _Fld17833), NULL) AS StartDate,
    IIF(_Fld17834 >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _Fld17834), NULL) AS EndDate,
    _Fld17837                                             AS LoadingAddress,
    _Fld17838                                             AS UnloadingAddress,
    _Fld34307                                             AS ExactWeight
FROM work.dbo._Document650_VT17818;
GO
