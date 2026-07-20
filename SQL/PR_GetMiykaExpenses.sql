-- exec pbi.GetMiykaExpenses

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'GetMiykaExpenses' AND SCHEMA_NAME(schema_id) = 'pbi')
    DROP PROCEDURE pbi.GetMiykaExpenses;
GO

CREATE PROCEDURE pbi.GetMiykaExpenses
AS
BEGIN
    SET NOCOUNT ON;

    WITH
    cte_ExcludedTrailers AS (
        SELECT TruckReff
        FROM pbi.vb_DimTrucks
        WHERE Description4 IN (N'Тент', N'Сипучка')
    ),
    cte_ExcludedProductGroups AS (
        SELECT DISTINCT vt.OrderRef
        FROM pbi.vb_DimOrderStages vt
        JOIN pbi.vb_DimCargoGroup r ON vt.CargoRef = r.CargoGroupRef
        WHERE r.ParentGroupRef IN (
            0x924F02B31CC3E40111EFFD8C25CD1220,
            0x931A8B6411C0FD9211E70D85A447F759
        )
    ),
    cte_MiykaDocs AS (
        SELECT
            e.OrderRef,
            e.RegReff                              AS _RecorderRRef,
            e.RegReffTable                         AS _RecorderTRef,
            e.[Sum]                                AS SumTotal,
            e.NDS                                  AS VAT,
            e.[Sum] - e.NDS                        AS SumWithoutVAT,
            IIF(e.RegReffTable = 338
                AND EXISTS (
                    SELECT 1 FROM pbi.vb_DimAdvanceReportRows vt
                    WHERE vt.AdvanceReportRef = e.RegReff
                       AND (vt.Content LIKE N'%заміна продукту%'
                            OR vt.Content LIKE N'%пломб%'
                            OR vt.Content LIKE N'%шланг%')
                ), 1, 0)                           AS IsBadAdvance
        FROM pbi.vb_Expenses e
        WHERE e.ExpensesRef = 0x983902B31CC3E40111EC7F3FD376A4F0
    ),
    cte_FilteredOrders AS (
        SELECT d._IDRRef, d._Number, d._Fld27200,
               c.ClientName AS Client,
               m.[User] AS Manager
        FROM dbo._Document650 d
        LEFT JOIN pbi.vb_DimClient c ON d._Fld17681_RRRef = c.ClientRef
        LEFT JOIN pbi.vb_DimUsers m ON d._Fld17686RRef = m.UserReff
        LEFT JOIN pbi.vb_DimOrderStatus e ON d._Fld17685RRef = e.StatusRef
        WHERE d._Fld27200 >= DATEFROMPARTS(4026, 4, 1)
          AND d._Fld27200 <  DATEFROMPARTS(4026, 7, 1)
          AND d._Fld32970 = 0x00
          AND d._Fld17708 = 0x00
          AND d._Marked  = 0x00
          AND d._Fld17681_RRRef NOT IN (
              0x8CA1D8710025B9B611EB8C7FDCE23E90,
              0xACEFD32FEC9A2DE011E680D1BDE456FD,
              0xACEFD32FEC9A2DE011E680D1BDE45671,
              0xA107CA8955BA52BF11EA9E6A10FEB780
          )
          AND d._Fld17686RRef <> 0x80B802B31CC3E40111F0FB7A4B1CF82F
           AND e.EnumOrder NOT IN (2, 6)
          AND (d._Fld17704_RRRef NOT IN (SELECT TruckReff FROM cte_ExcludedTrailers)
               OR d._Fld17704_RRRef IS NULL)
    )

    SELECT
        LTRIM(RTRIM(d._Number))                       AS OrderNumber,
        DATEADD(YEAR, -2000, d._Fld27200)             AS OrderDate,
        d.Client,
        d.Manager,
        N'1. Без витрат на мийку'                     AS ReasonFilter,
        CAST(NULL AS INT)                             AS DocCount,
        CAST(NULL AS NUMERIC(38,2))                   AS TotalWithoutVAT_EUR,
        CAST(NULL AS NUMERIC(38,2))                   AS TotalSum_EUR,
        CAST(NULL AS NUMERIC(38,2))                   AS TotalVAT_EUR
    FROM cte_FilteredOrders d
    WHERE NOT EXISTS (SELECT 1 FROM cte_MiykaDocs md WHERE md.OrderRef = d._IDRRef)
      AND d._IDRRef NOT IN (SELECT OrderRef FROM cte_ExcludedProductGroups)

    UNION ALL

    SELECT
        LTRIM(RTRIM(d._Number))                       AS OrderNumber,
        DATEADD(YEAR, -2000, d._Fld27200)             AS OrderDate,
        d.Client,
        d.Manager,
        N'2. 2+ документи мийки'                      AS ReasonFilter,
        COUNT(DISTINCT md._RecorderRRef)              AS DocCount,
        SUM(md.SumWithoutVAT)                         AS TotalWithoutVAT_EUR,
        SUM(md.SumTotal)                              AS TotalSum_EUR,
        SUM(md.VAT)                                   AS TotalVAT_EUR
    FROM cte_FilteredOrders d
    JOIN cte_MiykaDocs md ON md.OrderRef = d._IDRRef AND md.IsBadAdvance = 0
    GROUP BY d._IDRRef, d._Number, d._Fld27200, d.Client, d.Manager
    HAVING COUNT(DISTINCT md._RecorderRRef) >= 2

    ORDER BY ReasonFilter, OrderDate;
END
GO
