-- SELECT * FROM pbi.v_DimOrderPayment where CustomOrderRef = '80B902B31CC3E40111F1B7E7C4583415'
-- SELECT * FROM pbi.vb_DimOrderPayment

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'v_DimOrderPayment' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_DimOrderPayment;
GO

CREATE VIEW pbi.v_DimOrderPayment AS
SELECT
    IIF(_Period >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _Period), NULL)   AS Period,
    CONVERT(int, _RecorderTRef)                                                   AS RegRefTable,
    CONVERT(VARCHAR(MAX), _RecorderRRef, 2)                                       AS RegRef,
    _LineNo                                                                       AS LineNumber,
    _Active                                                                       AS Active,
    _RecordKind                                                                   AS RecordKind,
    CONVERT(VARCHAR(MAX), _Fld24030RRef, 2)                                       AS ContractRef,
    _Fld24031_TYPE                                                                AS CustomOrderType,
    CONVERT(int, _Fld24031_RTRef)                                                 AS CustomOrderRefTable,
    CONVERT(VARCHAR(MAX), _Fld24031_RRRef, 2)                                     AS CustomOrderRef,
    _Fld24032_TYPE                                                                AS SettlementDocType,
    CONVERT(int, _Fld24032_RTRef)                                                 AS SettlementDocRefTable,
    CONVERT(VARCHAR(MAX), _Fld24032_RRRef, 2)                                     AS SettlementDocRef,
    CONVERT(VARCHAR(MAX), _Fld24033RRef, 2)                                       AS SettlementTypeRef,
    CONVERT(VARCHAR(MAX), _Fld24034RRef, 2)                                       AS OrganizationRef,
    CONVERT(VARCHAR(MAX), _Fld24035RRef, 2)                                       AS ClientRef,
    _Fld24036                                                                     AS [Sum]
FROM work.dbo._AccumRg24029;
GO

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'vb_DimOrderPayment' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_DimOrderPayment;
GO

CREATE VIEW pbi.vb_DimOrderPayment AS
SELECT
    IIF(_Period >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _Period), NULL)   AS Period,
    CONVERT(int, _RecorderTRef)                                                   AS RegRefTable,
    _RecorderRRef                                                                 AS RegRef,
    _LineNo                                                                       AS LineNumber,
    _Active                                                                       AS Active,
    _RecordKind                                                                   AS RecordKind,
    _Fld24030RRef                                                                 AS ContractRef,
    _Fld24031_TYPE                                                                AS CustomOrderType,
    CONVERT(int, _Fld24031_RTRef)                                                 AS CustomOrderRefTable,
    _Fld24031_RRRef                                                               AS CustomOrderRef,
    _Fld24032_TYPE                                                                AS SettlementDocType,
    CONVERT(int, _Fld24032_RTRef)                                                 AS SettlementDocRefTable,
    _Fld24032_RRRef                                                               AS SettlementDocRef,
    _Fld24033RRef                                                                 AS SettlementTypeRef,
    _Fld24034RRef                                                                 AS OrganizationRef,
    _Fld24035RRef                                                                 AS ClientRef,
    _Fld24036                                                                     AS [Sum]
FROM work.dbo._AccumRg24029;
GO
