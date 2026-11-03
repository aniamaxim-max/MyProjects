-- SELECT * FROM pbi.v_OrderPayments
-- SELECT * FROM pbi.vb_OrderPayments

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'v_OrderPayments' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_OrderPayments;
GO

CREATE VIEW pbi.v_OrderPayments AS
WITH inc AS (
    SELECT OrderRef, SUM(SumNoVatEur) AS IncomeNoVatEur
    FROM pbi.v_DimOrdersIncome
    GROUP BY OrderRef
),
exp AS (
    SELECT OrderRef, SUM(SumNoVatEur) AS ExpensesNoVatEur
    FROM pbi.v_DimOrdersExpenses
    GROUP BY OrderRef
),
ord AS (
    SELECT o.OrderRef, o.[Order], o.OrderDate, o.ClientReff, o.DispetcherReff,
           SUM(CASE WHEN d.RecordKind = 0 THEN d.[Sum] ELSE 0 END) AS InvoicedSum,
           SUM(CASE WHEN d.RecordKind = 1 THEN d.[Sum] ELSE 0 END) AS PaidSum,
           SUM(CASE WHEN d.RecordKind = 0 THEN d.[Sum]
                    WHEN d.RecordKind = 1 THEN -d.[Sum]
                    ELSE 0 END / NULLIF(er.Rate / NULLIF(cr.Rate, 0), 0)) AS RemainderEur,
           MAX(CASE WHEN d.RecordKind = 1 THEN d.[Period] END)     AS LastPaymentDate
    FROM pbi.v_DimOrders o
    INNER JOIN pbi.v_DimCustomOrders c ON c.BaseDocRef = o.OrderRef
    LEFT JOIN pbi.v_DimOrderPayment d ON d.CustomOrderRef = c.CustomOrderRef
    LEFT JOIN work.dbo._Reference85 ct ON ct._IDRRef = CONVERT(binary(16), d.ContractRef, 2)
    OUTER APPLY (
        SELECT TOP 1 r._Fld20832 / r._Fld20833 AS Rate
        FROM work.dbo._InfoRg20830 r
        WHERE r._Fld20831RRef = COALESCE(ct._Fld1922RRef, CONVERT(binary(16), o.CurrencyRef, 2))
          AND r._Period <= DATEADD(YEAR, 2000, COALESCE(o.StartFact, o.OrderDate))
        ORDER BY r._Period DESC
    ) cr
    OUTER APPLY (
        SELECT TOP 1 e._Fld20832 / e._Fld20833 AS Rate
        FROM work.dbo._InfoRg20830 e
        WHERE e._Fld20831RRef = 0x86F7D6671738F3EC11E653118C548398
          AND e._Period <= DATEADD(YEAR, 2000, COALESCE(o.StartFact, o.OrderDate))
        ORDER BY e._Period DESC
    ) er
    GROUP BY o.OrderRef, o.[Order], o.OrderDate, o.ClientReff, o.DispetcherReff
)
SELECT
    o.[Order],
    o.OrderRef,
    o.OrderDate,
    o.ClientReff,
    o.DispetcherReff,
    d._Description                    AS Dispetcher,
    CAST(o.LastPaymentDate AS date)   AS LastPaymentDate,
    o.InvoicedSum,
    o.PaidSum,
    o.InvoicedSum - o.PaidSum         AS Remainder,
    o.RemainderEur,
    ISNULL(inc.IncomeNoVatEur, 0)     AS IncomeNoVatEur,
    ISNULL(exp.ExpensesNoVatEur, 0)   AS ExpensesNoVatEur,
    ISNULL(inc.IncomeNoVatEur, 0) - ISNULL(exp.ExpensesNoVatEur, 0) AS MarginNoVatEur,
    CASE WHEN o.InvoicedSum <= o.PaidSum THEN 'Paid' ELSE 'Unpaid' END AS PaymentStatus
FROM ord o
LEFT JOIN work.dbo._Reference208 d ON CONVERT(VARCHAR(MAX), d._IDRRef, 2) = o.DispetcherReff
LEFT JOIN inc ON inc.OrderRef = o.OrderRef
LEFT JOIN exp ON exp.OrderRef = o.OrderRef
WHERE o.InvoicedSum > 0;
GO

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'vb_OrderPayments' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_OrderPayments;
GO

CREATE VIEW pbi.vb_OrderPayments AS
WITH inc AS (
    SELECT OrderRef, SUM(SumNoVatEur) AS IncomeNoVatEur
    FROM pbi.vb_DimOrdersIncome
    GROUP BY OrderRef
),
exp AS (
    SELECT OrderRef, SUM(SumNoVatEur) AS ExpensesNoVatEur
    FROM pbi.vb_DimOrdersExpenses
    GROUP BY OrderRef
),
ord AS (
    SELECT o.OrderRef, o.[Order], o.OrderDate, o.ClientReff, o.DispetcherReff,
           SUM(CASE WHEN d.RecordKind = 0 THEN d.[Sum] ELSE 0 END) AS InvoicedSum,
           SUM(CASE WHEN d.RecordKind = 1 THEN d.[Sum] ELSE 0 END) AS PaidSum,
           SUM(CASE WHEN d.RecordKind = 0 THEN d.[Sum]
                    WHEN d.RecordKind = 1 THEN -d.[Sum]
                    ELSE 0 END / NULLIF(er.Rate / NULLIF(cr.Rate, 0), 0)) AS RemainderEur,
           MAX(CASE WHEN d.RecordKind = 1 THEN d.[Period] END)     AS LastPaymentDate
    FROM pbi.vb_DimOrders o
    INNER JOIN pbi.vb_DimCustomOrders c ON c.BaseDocRef = o.OrderRef
    LEFT JOIN pbi.vb_DimOrderPayment d ON d.CustomOrderRef = c.CustomOrderRef
    LEFT JOIN work.dbo._Reference85 ct ON ct._IDRRef = d.ContractRef
    OUTER APPLY (
        SELECT TOP 1 r._Fld20832 / r._Fld20833 AS Rate
        FROM work.dbo._InfoRg20830 r
        WHERE r._Fld20831RRef = COALESCE(ct._Fld1922RRef, o.CurrencyRef)
          AND r._Period <= DATEADD(YEAR, 2000, COALESCE(o.StartFact, o.OrderDate))
        ORDER BY r._Period DESC
    ) cr
    OUTER APPLY (
        SELECT TOP 1 e._Fld20832 / e._Fld20833 AS Rate
        FROM work.dbo._InfoRg20830 e
        WHERE e._Fld20831RRef = 0x86F7D6671738F3EC11E653118C548398
          AND e._Period <= DATEADD(YEAR, 2000, COALESCE(o.StartFact, o.OrderDate))
        ORDER BY e._Period DESC
    ) er
    GROUP BY o.OrderRef, o.[Order], o.OrderDate, o.ClientReff, o.DispetcherReff
)
SELECT
    o.[Order],
    o.OrderRef,
    o.OrderDate,
    o.ClientReff,
    o.DispetcherReff,
    CAST(o.LastPaymentDate AS date)   AS LastPaymentDate,
    o.InvoicedSum,
    o.PaidSum,
    o.InvoicedSum - o.PaidSum         AS Remainder,
    o.RemainderEur,
    ISNULL(inc.IncomeNoVatEur, 0)     AS IncomeNoVatEur,
    ISNULL(exp.ExpensesNoVatEur, 0)   AS ExpensesNoVatEur,
    ISNULL(inc.IncomeNoVatEur, 0) - ISNULL(exp.ExpensesNoVatEur, 0) AS MarginNoVatEur,
    CASE WHEN o.InvoicedSum <= o.PaidSum THEN 'Paid' ELSE 'Unpaid' END AS PaymentStatus
FROM ord o
LEFT JOIN inc ON inc.OrderRef = o.OrderRef
LEFT JOIN exp ON exp.OrderRef = o.OrderRef
WHERE o.InvoicedSum > 0;
GO
