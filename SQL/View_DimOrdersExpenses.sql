-- SELECT * FROM pbi.v_DimOrdersExpenses
-- SELECT * FROM pbi.vb_DimOrdersExpenses where OrderRef in(select OrderRef from pbi.vb_DimOrders where [Order] = 'ÌÂ000002085' and YEAR(OrderDate) = 2026)

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'v_DimOrdersExpenses' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_DimOrdersExpenses;
GO

CREATE VIEW pbi.v_DimOrdersExpenses AS
SELECT
    CONVERT(VARCHAR(MAX), vt._Document650_IDRRef, 2)   AS OrderRef,
    vt._LineNo17872                                    AS LineNumber,
    CONVERT(VARCHAR(MAX), vt._Fld17876RRef, 2)         AS NomenclatureRef,
    vt._Fld17878                                       AS Quantity,
    vt._Fld17879                                       AS Price,
    vt._Fld17880                                       AS [Sum],
    CONVERT(VARCHAR(MAX), vt._Fld17881RRef, 2)         AS VATRateRef,
    vt._Fld17882                                       AS VATSum,
    CONVERT(VARCHAR(MAX), c._Fld1922RRef, 2)           AS CurrencyRef,
    (vt._Fld17880 - ISNULL(vt._Fld17882, 0)) / NULLIF(er.r / NULLIF(cr.r, 0), 0) AS SumNoVatEur
FROM work.dbo._Document650_VT17871 vt
    INNER JOIN pbi.v_DimOrders o ON o.OrderRef = CONVERT(VARCHAR(MAX), vt._Document650_IDRRef, 2)
    LEFT JOIN work.dbo._Reference85 c ON c._IDRRef = CONVERT(binary(16), o.CarrierContractRef, 2)
    OUTER APPLY (
        SELECT TOP 1 d._Fld20832 / d._Fld20833 AS r
        FROM work.dbo._InfoRg20830 d
        WHERE d._Fld20831RRef = c._Fld1922RRef
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
    WHERE v.name = 'vb_DimOrdersExpenses' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_DimOrdersExpenses;
GO

CREATE VIEW pbi.vb_DimOrdersExpenses AS
SELECT
    vt._Document650_IDRRef                             AS OrderRef,
    vt._LineNo17872                                    AS LineNumber,
    vt._Fld17876RRef                                   AS NomenclatureRef,
    vt._Fld17878                                       AS Quantity,
    vt._Fld17879                                       AS Price,
    vt._Fld17880                                       AS [Sum],
    vt._Fld17881RRef                                   AS VATRateRef,
    vt._Fld17882                                       AS VATSum,
    c._Fld1922RRef                                     AS CurrencyRef,
    (vt._Fld17880 - ISNULL(vt._Fld17882, 0)) / NULLIF(er.r / NULLIF(cr.r, 0), 0) AS SumNoVatEur
FROM work.dbo._Document650_VT17871 vt
    INNER JOIN pbi.vb_DimOrders o ON o.OrderRef = vt._Document650_IDRRef
    LEFT JOIN work.dbo._Reference85 c ON c._IDRRef = o.CarrierContractRef
    OUTER APPLY (
        SELECT TOP 1 d._Fld20832 / d._Fld20833 AS r
        FROM work.dbo._InfoRg20830 d
        WHERE d._Fld20831RRef = c._Fld1922RRef
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
