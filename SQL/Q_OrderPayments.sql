IF OBJECT_ID('tempdb..#inv') IS NOT NULL DROP TABLE #inv;
SELECT CustomOrderRef, SUM([Sum]) AS InvoicedSum
INTO #inv
FROM pbi.vb_DimOrderPayment WHERE RecordKind = 0 GROUP BY CustomOrderRef;
CREATE CLUSTERED INDEX IX_inv ON #inv(CustomOrderRef);

IF OBJECT_ID('tempdb..#pay') IS NOT NULL DROP TABLE #pay;
SELECT CustomOrderRef, SUM([Sum]) AS PaidSum, MAX([Period]) AS LastPayment
INTO #pay
FROM pbi.vb_DimOrderPayment WHERE RecordKind = 1 GROUP BY CustomOrderRef;
CREATE CLUSTERED INDEX IX_pay ON #pay(CustomOrderRef);

IF OBJECT_ID('tempdb..#inc') IS NOT NULL DROP TABLE #inc;
SELECT OrderRef, SUM(SumNoVatEur) AS IncomeNoVatEur
INTO #inc
FROM pbi.vb_DimOrdersIncome GROUP BY OrderRef;
CREATE CLUSTERED INDEX IX_inc ON #inc(OrderRef);

IF OBJECT_ID('tempdb..#exp') IS NOT NULL DROP TABLE #exp;
SELECT OrderRef, SUM(SumNoVatEur) AS ExpensesNoVatEur
INTO #exp
FROM pbi.vb_DimOrdersExpenses GROUP BY OrderRef;
CREATE CLUSTERED INDEX IX_exp ON #exp(OrderRef);

IF OBJECT_ID('tempdb..#ord') IS NOT NULL DROP TABLE #ord;
SELECT o.OrderRef, o.[Order], o.OrderDate, o.ClientReff,
       SUM(ISNULL(i.InvoicedSum, 0)) AS InvoicedSum,
       SUM(ISNULL(p.PaidSum, 0))     AS PaidSum,
       MAX(p.LastPayment)            AS LastPaymentDate
INTO #ord
FROM pbi.vb_DimOrders o
INNER JOIN pbi.vb_DimCustomOrders c ON c.BaseDocRef = o.OrderRef
LEFT JOIN #inv i ON i.CustomOrderRef = c.CustomOrderRef
LEFT JOIN #pay p ON p.CustomOrderRef = c.CustomOrderRef
GROUP BY o.OrderRef, o.[Order], o.OrderDate, o.ClientReff;
CREATE CLUSTERED INDEX IX_ord ON #ord(OrderRef);

SELECT
    o.[Order],
    CONVERT(VARCHAR(MAX), o.OrderRef, 2)   AS OrderRef,
    o.OrderDate,
    CONVERT(VARCHAR(MAX), o.ClientReff, 2) AS ClientReff,
    CAST(o.LastPaymentDate AS date)        AS LastPaymentDate,
    o.InvoicedSum,
    o.PaidSum,
    o.InvoicedSum - o.PaidSum AS Remainder,
    ISNULL(inc.IncomeNoVatEur, 0)   AS IncomeNoVatEur,
    ISNULL(exp.ExpensesNoVatEur, 0) AS ExpensesNoVatEur,
    ISNULL(inc.IncomeNoVatEur, 0) - ISNULL(exp.ExpensesNoVatEur, 0) AS MarginNoVatEur,
    CASE WHEN o.InvoicedSum <= o.PaidSum THEN 'Paid' ELSE 'Unpaid' END AS PaymentStatus
FROM #ord o
LEFT JOIN #inc inc ON inc.OrderRef = o.OrderRef
LEFT JOIN #exp exp ON exp.OrderRef = o.OrderRef
WHERE o.InvoicedSum > 0
ORDER BY PaymentStatus, o.OrderDate DESC;
