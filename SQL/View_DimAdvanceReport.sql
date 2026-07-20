-- SELECT * FROM pbi.v_DimAdvanceReport
-- SELECT * FROM pbi.vb_DimAdvanceReport

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'v_DimAdvanceReport' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_DimAdvanceReport;
GO

CREATE VIEW pbi.v_DimAdvanceReport AS
SELECT
    CONVERT(VARCHAR(MAX), _IDRRef, 2)                     AS AdvanceReportRef,
    LTRIM(RTRIM(_Number))                                 AS AdvanceReportNumber,
    IIF(_Date_Time >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _Date_Time), _Date_Time) AS AdvanceReportDate,
    CAST(_Posted AS BIT)                                  AS Posted,
    CAST(_Marked AS BIT)                                  AS DeleteMark
FROM work.dbo._Document338
WHERE _Fld4161 = 0x01;
GO

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'vb_DimAdvanceReport' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_DimAdvanceReport;
GO

CREATE VIEW pbi.vb_DimAdvanceReport AS
SELECT
    _IDRRef                                               AS AdvanceReportRef,
    LTRIM(RTRIM(_Number))                                 AS AdvanceReportNumber,
    IIF(_Date_Time >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _Date_Time), _Date_Time) AS AdvanceReportDate,
    _Posted                                               AS Posted,
    _Marked                                               AS DeleteMark
FROM work.dbo._Document338
WHERE _Fld4161 = 0x01;
GO
