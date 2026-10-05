-- SELECT * FROM pbi.v_DimOrdersIncome 
-- SELECT * FROM pbi.vb_DimOrdersIncome where OrderRef in(select OrderRef from pbi.vb_DimOrders where [Order] = 'ÌÂ000002085' and YEAR(OrderDate) = 2026)

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'v_DimOrdersIncome' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_DimOrdersIncome;
GO

CREATE VIEW pbi.v_DimOrdersIncome AS
SELECT
    CONVERT(VARCHAR(MAX), vt._Document650_IDRRef, 2)   AS OrderRef,
    vt._LineNo17860                                    AS LineNumber,
    CONVERT(VARCHAR(MAX), vt._Fld17861RRef, 2)         AS ClientRef,
    CONVERT(VARCHAR(MAX), vt._Fld17862RRef, 2)         AS ContractRef,
    CONVERT(VARCHAR(MAX), vt._Fld17863RRef, 2)         AS ContractCurrencyRef,
    CONVERT(VARCHAR(MAX), vt._Fld17864RRef, 2)         AS NomenclatureRef,
    CAST(vt._Fld17865 AS BIT)                          AS CashPayment,
    vt._Fld17866                                       AS Quantity,
    vt._Fld17867                                       AS Price,
    vt._Fld17868                                       AS [Sum],
    CONVERT(VARCHAR(MAX), vt._Fld17869RRef, 2)         AS VATRateRef,
    vt._Fld17870                                       AS VATSum,
    CAST(vt._Fld34337 AS BIT)                          AS Managerial,
    vt._Fld34338                                       AS ManagerialSum,
    CONVERT(VARCHAR(MAX), vt._Fld34339RRef, 2)         AS ManagerialCurrencyRef,
    (vt._Fld17868 - ISNULL(vt._Fld17870, 0)) / NULLIF(er.r / NULLIF(cr.r, 0), 0) AS SumNoVatEur
FROM work.dbo._Document650_VT17859 vt
    INNER JOIN pbi.v_DimOrders o ON o.OrderRef = CONVERT(VARCHAR(MAX), vt._Document650_IDRRef, 2)
    OUTER APPLY (
        SELECT TOP 1 d._Fld20832 / d._Fld20833 AS r
        FROM work.dbo._InfoRg20830 d
        WHERE d._Fld20831RRef = CONVERT(binary(16), o.CurrencyRef, 2)
          AND d._Period <= DATEADD(YEAR, 2000, o.StartFact)
        ORDER BY d._Period DESC
    ) cr
    OUTER APPLY (
        SELECT TOP 1 e._Fld20832 / e._Fld20833 AS r
        FROM work.dbo._InfoRg20830 e
        WHERE e._Fld20831RRef = 0x86F7D6671738F3EC11E653118C548398
          AND e._Period <= DATEADD(YEAR, 2000, o.StartFact)
        ORDER BY e._Period DESC
    ) er;
GO

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'vb_DimOrdersIncome' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_DimOrdersIncome;
GO

CREATE VIEW pbi.vb_DimOrdersIncome AS
SELECT
    vt._Document650_IDRRef                             AS OrderRef,
    vt._LineNo17860                                    AS LineNumber,
    vt._Fld17861RRef                                   AS ClientRef,
    vt._Fld17862RRef                                   AS ContractRef,
    vt._Fld17863RRef                                   AS ContractCurrencyRef,
    vt._Fld17864RRef                                   AS NomenclatureRef,
    vt._Fld17865                                       AS CashPayment,
    vt._Fld17866                                       AS Quantity,
    vt._Fld17867                                       AS Price,
    vt._Fld17868                                       AS [Sum],
    vt._Fld17869RRef                                   AS VATRateRef,
    vt._Fld17870                                       AS VATSum,
    vt._Fld34337                                       AS Managerial,
    vt._Fld34338                                       AS ManagerialSum,
    vt._Fld34339RRef                                   AS ManagerialCurrencyRef,
    (vt._Fld17868 - ISNULL(vt._Fld17870, 0)) / NULLIF(er.r / NULLIF(cr.r, 0), 0) AS SumNoVatEur
FROM work.dbo._Document650_VT17859 vt
    INNER JOIN pbi.vb_DimOrders o ON o.OrderRef = vt._Document650_IDRRef
    OUTER APPLY (
        SELECT TOP 1 d._Fld20832 / d._Fld20833 AS r
        FROM work.dbo._InfoRg20830 d
        WHERE d._Fld20831RRef = o.CurrencyRef
          AND d._Period <= DATEADD(YEAR, 2000, o.StartFact)
        ORDER BY d._Period DESC
    ) cr
    OUTER APPLY (
        SELECT TOP 1 e._Fld20832 / e._Fld20833 AS r
        FROM work.dbo._InfoRg20830 e
        WHERE e._Fld20831RRef = 0x86F7D6671738F3EC11E653118C548398
          AND e._Period <= DATEADD(YEAR, 2000, o.StartFact)
        ORDER BY e._Period DESC
    ) er;
GO
