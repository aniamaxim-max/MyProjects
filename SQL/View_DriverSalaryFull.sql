-- SELECT * from pbi.v_DriverSalaryFull SELECT * from pbi.vb_DriverSalaryFull where Driver in (0xBC2702B31CC3E40111EF56638C09EEA7, 0x9CA802B31CC3E40111EC17BE67B59020, 0x86F5B68AC35E4EB511E67B12EA805EDA) order by Driver


IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'vb_DriverSalaryFull' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_DriverSalaryFull
GO

USE [work]
GO

/****** Object:  View [pbi].[vb_DriverSalaryFull]    Script Date: 16.07.2026 16:36:46 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


Create view [pbi].[vb_DriverSalaryFull] AS

WITH cte_Months AS (
    -- 1. Генеруємо або беремо список перших чисел кожного місяця
    SELECT DISTINCT 
        dr.CalDate AS SnapshotDate
    FROM pbi.v_Calendar dr
    WHERE DAY(dr.CalDate) = 1 -- Залишаємо тільки 1-ше число кожного місяця
),
cte_SpecialClasses AS (
    -- Класи, що рахуються за "тримексівською" схемою:
    --   ставка без +150, податок Num = 2, EUR = ставка / EURRate + TaxSum / 30
    SELECT Class FROM (VALUES
        (0x924F02B31CC3E40111EFA648B0A9D130), -- Клас 10
        (0x80B902B31CC3E40111F16BD4E462D93E), -- Клас Trimex 1
        (0x80B902B31CC3E40111F1AC3EA991E3E9), -- Клас Trimex 350
        (0x80B902B31CC3E40111F1AC3D83AF7FBA), -- Клас Trimex 365
        (0x80B902B31CC3E40111F16BD937C916E0), -- Клас Trimex 380
        (0x80B902B31CC3E40111F16BD937C916E1), -- Клас Trimex 390
        (0x80B902B31CC3E40111F19643117DEA57), -- Клас Trimex 400
        (0x80B902B31CC3E40111F1ADCCCE8B2872)  -- Клас Trimex 410
    ) v(Class)
),

cte_DriversHistoric AS (
    -- 2. Для кожного 1-го числа місяця шукаємо клас водія, який діяв НА ТУ ДАТУ
    SELECT 
        m.SnapshotDate,
        CL._Fld33135RRef AS Driver,
        CL._Fld33136RRef AS Class,
        CASE WHEN EXISTS (SELECT 1 FROM cte_SpecialClasses sc WHERE sc.Class = CL._Fld33136RRef) THEN 1 ELSE 0 END AS IsSpecialClass,
        ROW_NUMBER() OVER (
            PARTITION BY m.SnapshotDate, CL._Fld33135RRef
            ORDER BY IIF(CL._Period >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, CL._Period), CL._Period) DESC
        ) AS rn_driver
    FROM cte_Months m
    INNER JOIN _InfoRg33134 CL ON IIF(CL._Period >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, CL._Period), CL._Period) <= m.SnapshotDate
    --where CL._Fld33135RRef =0xAA9002B31CC3E40111EC8F0F56A637D0
),

cte_RatesHistoric AS (
    -- 3. Для кожного 1-го числа місяця шукаємо тариф класу, який діяв НА ТУ ДАТУ
    SELECT 
        m.SnapshotDate,
        R._Fld33138RRef AS Class,
        R._Fld34210RRef AS Currency,
        R._Fld34210RRef AS CurrencyRef,
        CASE
            WHEN EXISTS (SELECT 1 FROM cte_SpecialClasses sc WHERE sc.Class = R._Fld33138RRef) 
            THEN (R._Fld33140) 
            ELSE (R._Fld33140 + 150) END
        AS DriverSalaryPerDay,
        ROW_NUMBER() OVER (
            PARTITION BY m.SnapshotDate, R._Fld33138RRef
            ORDER BY R._Period DESC
        ) AS rn_rate
    FROM cte_Months m
    INNER JOIN _InfoRg33137 R ON R._Period <= DATEADD(year, 2000, m.SnapshotDate)
    WHERE
		R._Fld33139RRef = 0x9F700416C8172D6D434B867B43C82D1F AND
		R._Fld33214RRef = 0x00000000000000000000000000000000
)

SELECT
    dh.SnapshotDate AS [Period], -- Тепер це завжди 1-ше число місяця
    dh.Driver,
    dh.Class,
    ClassDesc._Description,
    rh.DriverSalaryPerDay,
    -- Розрахунки з курсом EUR на 1-ше число конкретного місяця
    rh.DriverSalaryPerDay / NULLIF(dr.EURRate, 0) AS DriverSalaryPerDayNoTaxEUR,
    CASE WHEN dh.IsSpecialClass = 1 THEN (dt.TaxSum / 30.0) ELSE (dt.TaxSum / 30.0) / NULLIF(dr.EURRate, 0) END AS DriverTaxEUR,
    CASE WHEN dh.IsSpecialClass = 1 THEN (rh.DriverSalaryPerDay / NULLIF(dr.EURRate, 0)) + (dt.TaxSum / 30.0) ELSE (rh.DriverSalaryPerDay + (dt.TaxSum / 30.0)) / NULLIF(dr.EURRate, 0) END AS DriverSalaryPerDayEUR,
    dr.EURRate,
    dt.TaxSum
FROM cte_DriversHistoric dh
INNER JOIN cte_RatesHistoric rh ON rh.SnapshotDate = dh.SnapshotDate AND rh.Class = dh.Class AND rh.rn_rate = 1
INNER JOIN _Reference33129 ClassDesc ON ClassDesc._IDRRef = dh.Class
INNER JOIN pbi.vb_DimRatesBI dr ON dr.Dates = dh.SnapshotDate AND dr.CurrencyRef = rh.CurrencyRef
CROSS APPLY (
    SELECT TOP 1 t.TaxSum
    FROM pbi.vb_DriverTax t
    WHERE t.PeriodStart <= dh.SnapshotDate
      AND (
          (dh.IsSpecialClass = 1 AND t.Num = 2) OR 
          (dh.IsSpecialClass = 0 AND t.Num = 1)
      )
    ORDER BY t.PeriodStart DESC
) dt
WHERE 
    dh.rn_driver = 1 -- Беремо тільки 1 актуальний клас для водія на цей місяць


GO

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_DriverSalaryFull' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_DriverSalaryFull
GO


Create view [pbi].[v_DriverSalaryFull] AS

WITH cte_Months AS (
    -- 1. Генеруємо або беремо список перших чисел кожного місяця
    SELECT DISTINCT 
        dr.CalDate AS SnapshotDate
    FROM pbi.v_Calendar dr
    WHERE DAY(dr.CalDate) = 1 -- Залишаємо тільки 1-ше число кожного місяця
),
cte_SpecialClasses AS (
    -- Класи, що рахуються за "тримексівською" схемою:
    --   ставка без +150, податок Num = 2, EUR = ставка / EURRate + TaxSum / 30
    SELECT Class FROM (VALUES
        (0x924F02B31CC3E40111EFA648B0A9D130), -- Клас 10
        (0x80B902B31CC3E40111F16BD4E462D93E), -- Клас Trimex 1
        (0x80B902B31CC3E40111F1AC3EA991E3E9), -- Клас Trimex 350
        (0x80B902B31CC3E40111F1AC3D83AF7FBA), -- Клас Trimex 365
        (0x80B902B31CC3E40111F16BD937C916E0), -- Клас Trimex 380
        (0x80B902B31CC3E40111F16BD937C916E1), -- Клас Trimex 390
        (0x80B902B31CC3E40111F19643117DEA57), -- Клас Trimex 400
        (0x80B902B31CC3E40111F1ADCCCE8B2872)  -- Клас Trimex 410
    ) v(Class)
),

cte_DriversHistoric AS (
    -- 2. Для кожного 1-го числа місяця шукаємо клас водія, який діяв НА ТУ ДАТУ
    SELECT 
        m.SnapshotDate,
        CL._Fld33135RRef AS Driver,
        CL._Fld33136RRef AS Class,
        CASE WHEN EXISTS (SELECT 1 FROM cte_SpecialClasses sc WHERE sc.Class = CL._Fld33136RRef) THEN 1 ELSE 0 END AS IsSpecialClass,
        ROW_NUMBER() OVER (
            PARTITION BY m.SnapshotDate, CL._Fld33135RRef
            ORDER BY IIF(CL._Period >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, CL._Period), CL._Period) DESC
        ) AS rn_driver
    FROM cte_Months m
    INNER JOIN _InfoRg33134 CL ON IIF(CL._Period >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, CL._Period), CL._Period) <= m.SnapshotDate
),

cte_RatesHistoric AS (
    -- 3. Для кожного 1-го числа місяця шукаємо тариф класу, який діяв НА ТУ ДАТУ
    SELECT 
        m.SnapshotDate,
        R._Fld33138RRef AS Class,
        R._Fld34210RRef AS Currency,
        R._Fld34210RRef AS CurrencyRef,
        CASE
            WHEN EXISTS (SELECT 1 FROM cte_SpecialClasses sc WHERE sc.Class = R._Fld33138RRef) 
            THEN (R._Fld33140) 
            ELSE (R._Fld33140 + 150) END
        AS DriverSalaryPerDay,
        ROW_NUMBER() OVER (
            PARTITION BY m.SnapshotDate, R._Fld33138RRef
            ORDER BY R._Period DESC
        ) AS rn_rate
    FROM cte_Months m
    INNER JOIN _InfoRg33137 R ON R._Period <= DATEADD(year, 2000, m.SnapshotDate)
    WHERE
		R._Fld33139RRef = 0x9F700416C8172D6D434B867B43C82D1F AND
		R._Fld33214RRef = 0x00000000000000000000000000000000
)

SELECT
    dh.SnapshotDate AS [Period], -- Тепер це завжди 1-ше число місяця
    CONVERT(VARCHAR(MAX), dh.Driver, 2) AS Driver,
    CONVERT(VARCHAR(MAX), dh.Class, 2) AS Class,
    ClassDesc._Description,
    rh.DriverSalaryPerDay,
    -- Розрахунки з курсом EUR на 1-ше число конкретного місяця
    rh.DriverSalaryPerDay / NULLIF(dr.EURRate, 0) AS DriverSalaryPerDayNoTaxEUR,
    CASE WHEN dh.IsSpecialClass = 1 THEN (dt.TaxSum / 30.0) ELSE (dt.TaxSum / 30.0) / NULLIF(dr.EURRate, 0) END AS DriverTaxEUR,
    CASE WHEN dh.IsSpecialClass = 1 THEN (rh.DriverSalaryPerDay / NULLIF(dr.EURRate, 0)) + (dt.TaxSum / 30.0) ELSE (rh.DriverSalaryPerDay + (dt.TaxSum / 30.0)) / NULLIF(dr.EURRate, 0) END AS DriverSalaryPerDayEUR,
    dr.EURRate,
    dt.TaxSum
FROM cte_DriversHistoric dh
INNER JOIN cte_RatesHistoric rh ON rh.SnapshotDate = dh.SnapshotDate AND rh.Class = dh.Class AND rh.rn_rate = 1
INNER JOIN _Reference33129 ClassDesc ON ClassDesc._IDRRef = dh.Class
INNER JOIN pbi.vb_DimRatesBI dr ON dr.Dates = dh.SnapshotDate AND dr.CurrencyRef = rh.CurrencyRef
CROSS APPLY (
    SELECT TOP 1 t.TaxSum
    FROM pbi.vb_DriverTax t
    WHERE t.PeriodStart <= dh.SnapshotDate
      AND (
          (dh.IsSpecialClass = 1 AND t.Num = 2) OR 
          (dh.IsSpecialClass = 0 AND t.Num = 1)
      )
    ORDER BY t.PeriodStart DESC
) dt
WHERE 
    dh.rn_driver = 1 -- Беремо тільки 1 актуальний клас для водія на цей місяць

GO


