-- SELECT * FROM pbi.v_DimCustomOrders
-- SELECT * FROM pbi.vb_DimCustomOrders

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'v_DimCustomOrders' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_DimCustomOrders;
GO

CREATE VIEW pbi.v_DimCustomOrders AS
SELECT
    CONVERT(VARCHAR(MAX), _IDRRef, 2)                                                    AS CustomOrderRef,
    IIF(_Date_Time >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _Date_Time), NULL)   AS CustomOrderDate,
    _Number                                                                              AS CustomOrderNumber,
    CONVERT(VARCHAR(MAX), _Fld6396_RRRef, 2)                                             AS BaseDocRef,
    CONVERT(VARCHAR(MAX), _Fld6378RRef, 2)                                               AS ClientRef
FROM work.dbo._Document392
WHERE _Posted = 0x01 AND _Marked = 0x00
    AND _Fld6378RRef NOT IN (SELECT ClientRef FROM pbi.vb_DimClient WHERE InnerClient = 1);
GO

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'vb_DimCustomOrders' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_DimCustomOrders;
GO

CREATE VIEW pbi.vb_DimCustomOrders AS
SELECT
    _IDRRef                                                                              AS CustomOrderRef,
    IIF(_Date_Time >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _Date_Time), NULL)   AS CustomOrderDate,
    _Number                                                                              AS CustomOrderNumber,
    _Fld6396_RRRef                                                                       AS BaseDocRef,
    _Fld6378RRef                                                                         AS ClientRef
FROM work.dbo._Document392
WHERE _Posted = 0x01 AND _Marked = 0x00
    AND _Fld6378RRef NOT IN (SELECT ClientRef FROM pbi.vb_DimClient WHERE InnerClient = 1);
GO
