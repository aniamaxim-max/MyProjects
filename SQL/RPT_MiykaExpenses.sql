-- ============================================================
-- RPT_MiykaExpenses.sql
-- Заказы на использование ТС за Апрель-Июнь 2026:
--   Filter 1: без расходов по статье "мийки внутрішні"
--   Filter 2: с 2+ документами расходов по статье "мийки внутрішні"
--             (исключая авансовые отчёты с услугой "заміна продукту")
--
-- Поля _Fld26332 / _Fld26333 в EUR.
-- Сумма без НДС = _Fld26332 - _Fld26333
-- ============================================================

WITH
-- Прицепы (и тягачи) классифицированные как "Тент" или "Сипучка"
cte_ExcludedTrailers AS (
    SELECT TruckReff
    FROM pbi.vb_DimTrucks
    WHERE Description4 IN (N'Тент', N'Сипучка')
),

-- Заказы с продуктами групп TDI/MDI (ADR) или ТЕНТ
-- (використовується тільки у Filter 1)
cte_ExcludedProductGroups AS (
    SELECT DISTINCT vt._Document650_IDRRef AS OrderRef
    FROM dbo._Document650_VT17818 vt
    JOIN dbo._Reference271 r ON vt._Fld17820RRef = r._IDRRef
    WHERE r._ParentIDRRef IN (
        0x924F02B31CC3E40111EFFD8C25CD1220,   -- TDI/MDI (ADR)
        0x931A8B6411C0FD9211E70D85A447F759    -- ТЕНТ
    )
),

-- Все записи регистра _AccumRg26319 по статье "мийки внутрішні"
-- (без фильтра по дате — заказы отфильтрованы периодом ниже)
cte_MiykaDocs AS (
    SELECT
        a._Fld26320_RRRef                  AS OrderRef,
        a._RecorderRRef,
        a._RecorderTRef,
        a._Fld26332                        AS SumTotal,
        a._Fld26333                        AS VAT,
        a._Fld26332 - a._Fld26333          AS SumWithoutVAT,
        IIF(CONVERT(int, a._RecorderTRef) = 338
            AND EXISTS (
                SELECT 1 FROM dbo._Document338_VT4234 vt
                WHERE vt._Document338_IDRRef = a._RecorderRRef
                   AND (vt._Fld4241 LIKE N'%заміна продукту%'
                        OR vt._Fld4241 LIKE N'%пломб%'
                        OR vt._Fld4241 LIKE N'%шланг%')
            ), 1, 0)                       AS IsBadAdvance
    FROM dbo._AccumRg26319 a
    WHERE a._Active = 0x01
      AND a._Fld26321RRef = 0x983902B31CC3E40111EC7F3FD376A4F0
),

-- Все заказы за период, прошедшие базовые отборы
cte_FilteredOrders AS (
    SELECT d._IDRRef, d._Number, d._Fld27200,
           c._Description AS Client,
           m._Description AS Manager
    FROM dbo._Document650 d
    LEFT JOIN dbo._Reference123 c ON d._Fld17681_RRRef = c._IDRRef
    LEFT JOIN dbo._Reference177 m ON d._Fld17686RRef = m._IDRRef
    LEFT JOIN dbo._Enum26798    e ON d._Fld17685RRef = e._IDRRef
    WHERE d._Fld27200 >= DATEFROMPARTS(4026, 4, 1)
      AND d._Fld27200 <  DATEFROMPARTS(4026, 7, 1)
      AND d._Fld32970 = 0x00                        -- не технический
      AND d._Fld17708 = 0x00                        -- не экспедиция
      AND d._Marked  = 0x00                         -- не помечен на удаление
      AND d._Fld17681_RRRef NOT IN (
          0x8CA1D8710025B9B611EB8C7FDCE23E90,       -- Ейр Продактс
          0xACEFD32FEC9A2DE011E680D1BDE456FD,       -- Лінде Газ
          0xACEFD32FEC9A2DE011E680D1BDE45671,       -- доп. клиент
          0xA107CA8955BA52BF11EA9E6A10FEB780        -- доп. клиент
      )
      AND d._Fld17686RRef <> 0x80B802B31CC3E40111F0FB7A4B1CF82F  -- Тимофієв
      AND e._EnumOrder NOT IN (2, 6)                -- отказные статусы
      AND (d._Fld17704_RRRef NOT IN (SELECT TruckReff FROM cte_ExcludedTrailers)
           OR d._Fld17704_RRRef IS NULL)            -- не прицеп тент/сыповоз
)

-- ============================================================
-- Filter 1: заказы БЕЗ расходов на мийку
-- ============================================================
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

-- ============================================================
-- Filter 2: заказы с 2+ документами расходов на мийку
--           (без учёта авансовых отчётов с услугой "заміна продукту")
-- ============================================================
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

ORDER BY ReasonFilter, OrderDate DESC;
GO
