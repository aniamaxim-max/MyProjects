-- SELECT * FROM pbi.v_DimAdvanceReportRows
-- SELECT * FROM pbi.vb_DimAdvanceReportRows

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'v_DimAdvanceReportRows' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_DimAdvanceReportRows;
GO

CREATE VIEW pbi.v_DimAdvanceReportRows AS
SELECT
    CONVERT(VARCHAR(MAX), _Document338_IDRRef, 2)         AS AdvanceReportRef,
    _LineNo4235                                           AS LineNumber,
    _Fld4236                                              AS IncomingDocType,
    _Fld4237                                              AS IncomingDocNumber,
    IIF(_Fld4238 >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _Fld4238), _Fld4238) AS IncomingDocDate,
    CONVERT(VARCHAR(MAX), _Fld4239RRef, 2)                AS SupplierRef,
    CONVERT(VARCHAR(MAX), _Fld4240RRef, 2)                AS ItemRef,
    _Fld4241                                              AS Content,
    _Fld4242                                              AS Quantity,
    _Fld4243                                              AS Price,
    _Fld4244                                              AS [Sum],
    CONVERT(VARCHAR(MAX), _Fld4245RRef, 2)                AS VATRateRef,
    _Fld4246                                              AS VATSum,
    _Fld4247                                              AS VATSumProportion,
    CONVERT(VARCHAR(MAX), _Fld4248RRef, 2)                AS CostAccountRef,
    CONVERT(VARCHAR(MAX), _Fld4250RRef, 2)                AS ItemGroupRef,
    CONVERT(VARCHAR(MAX), _Fld4253RRef, 2)                AS CostItemRef,
    CONVERT(VARCHAR(MAX), _Fld4257RRef, 2)                AS ContractRef,
    CONVERT(VARCHAR(MAX), _Fld4258RRef, 2)                AS ProductRef,
    CONVERT(VARCHAR(MAX), _Fld4260RRef, 2)                AS ProductSeriesRef,
    CONVERT(VARCHAR(MAX), _Fld4277RRef, 2)                AS CurrencyRef,
    _Fld4278                                              AS CurrencySum,
    _Fld4279                                              AS ExchangeRate
FROM work.dbo._Document338_VT4234;
GO

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'vb_DimAdvanceReportRows' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_DimAdvanceReportRows;
GO

CREATE VIEW pbi.vb_DimAdvanceReportRows AS
SELECT
    _Document338_IDRRef                                   AS AdvanceReportRef,
    _LineNo4235                                           AS LineNumber,
    _Fld4236                                              AS IncomingDocType,
    _Fld4237                                              AS IncomingDocNumber,
    IIF(_Fld4238 >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _Fld4238), _Fld4238) AS IncomingDocDate,
    _Fld4239RRef                                          AS SupplierRef,
    _Fld4240RRef                                          AS ItemRef,
    _Fld4241                                              AS Content,
    _Fld4242                                              AS Quantity,
    _Fld4243                                              AS Price,
    _Fld4244                                              AS [Sum],
    _Fld4245RRef                                          AS VATRateRef,
    _Fld4246                                              AS VATSum,
    _Fld4247                                              AS VATSumProportion,
    _Fld4248RRef                                          AS CostAccountRef,
    _Fld4250RRef                                          AS ItemGroupRef,
    _Fld4253RRef                                          AS CostItemRef,
    _Fld4257RRef                                          AS ContractRef,
    _Fld4258RRef                                          AS ProductRef,
    _Fld4260RRef                                          AS ProductSeriesRef,
    _Fld4277RRef                                          AS CurrencyRef,
    _Fld4278                                              AS CurrencySum,
    _Fld4279                                              AS ExchangeRate
FROM work.dbo._Document338_VT4234;
GO
