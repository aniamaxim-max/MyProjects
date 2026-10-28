-- SELECT * FROM pbi.v_OrderPayments
-- SELECT * FROM pbi.vb_OrderPayments

IF EXISTS(SELECT v.name FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.name = 'v_OrderPayments' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_OrderPayments;
GO

CREATE VIEW pbi.v_OrderPayments AS
WITH inv AS (
    SELECT CustomOrderRef, SUM([Sum]) AS InvoicedSum
    FROM pbi.v_DimOrderPayment
    WHERE RecordKind = 0
    GROUP BY CustomOrderRef
),
pay AS (
    SELECT CustomOrderRef, SUM([Sum]) AS PaidSum, MAX([Period]) AS LastPayment
    FROM pbi.v_DimOrderPayment
    WHERE RecordKind = 1
    GROUP BY CustomOrderRef
),
inc AS (
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
           SUM(ISNULL(i.InvoicedSum, 0)) AS InvoicedSum,
           SUM(ISNULL(p.PaidSum, 0))     AS PaidSum,
           MAX(p.LastPayment)            AS LastPaymentDate
    FROM pbi.v_DimOrders o
    INNER JOIN pbi.v_DimCustomOrders c ON c.BaseDocRef = o.OrderRef
    LEFT JOIN inv i ON i.CustomOrderRef = c.CustomOrderRef
    LEFT JOIN pay p ON p.CustomOrderRef = c.CustomOrderRef
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
WITH inv AS (
    SELECT CustomOrderRef, SUM([Sum]) AS InvoicedSum
    FROM pbi.vb_DimOrderPayment
    WHERE RecordKind = 0
    GROUP BY CustomOrderRef
),
pay AS (
    SELECT CustomOrderRef, SUM([Sum]) AS PaidSum, MAX([Period]) AS LastPayment
    FROM pbi.vb_DimOrderPayment
    WHERE RecordKind = 1
    GROUP BY CustomOrderRef
),
inc AS (
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
           SUM(ISNULL(i.InvoicedSum, 0)) AS InvoicedSum,
           SUM(ISNULL(p.PaidSum, 0))     AS PaidSum,
           MAX(p.LastPayment)            AS LastPaymentDate
    FROM pbi.vb_DimOrders o
    INNER JOIN pbi.vb_DimCustomOrders c ON c.BaseDocRef = o.OrderRef
    LEFT JOIN inv i ON i.CustomOrderRef = c.CustomOrderRef
    LEFT JOIN pay p ON p.CustomOrderRef = c.CustomOrderRef
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
    ISNULL(inc.IncomeNoVatEur, 0)     AS IncomeNoVatEur,
    ISNULL(exp.ExpensesNoVatEur, 0)   AS ExpensesNoVatEur,
    ISNULL(inc.IncomeNoVatEur, 0) - ISNULL(exp.ExpensesNoVatEur, 0) AS MarginNoVatEur,
    CASE WHEN o.InvoicedSum <= o.PaidSum THEN 'Paid' ELSE 'Unpaid' END AS PaymentStatus
FROM ord o
LEFT JOIN inc ON inc.OrderRef = o.OrderRef
LEFT JOIN exp ON exp.OrderRef = o.OrderRef
WHERE o.InvoicedSum > 0;
GO
