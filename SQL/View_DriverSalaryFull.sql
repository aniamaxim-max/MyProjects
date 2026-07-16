-- SELECT * from pbi.v_DriverSalaryFull SELECT * from pbi.vb_DriverSalaryFull


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

cte_DriversHistoric AS (
    -- 2. Для кожного 1-го числа місяця шукаємо клас водія, який діяв НА ТУ ДАТУ
    SELECT 
        m.SnapshotDate,
        CL._Fld33135RRef AS Driver,
        CL._Fld33136RRef AS Class,
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
            WHEN R._Fld33138RRef IN (0x924F02B31CC3E40111EFA648B0A9D130, 0x80B902B31CC3E40111F16BD937C916E1, 
                                     0x80B902B31CC3E40111F16BD4E462D93E, 0x80B902B31CC3E40111F16BD937C916E0)
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
    (dt.TaxSum / 30.0) / NULLIF(dr.EURRate, 0) AS DriverTaxEUR,
    (rh.DriverSalaryPerDay + (dt.TaxSum / 30.0)) / NULLIF(dr.EURRate, 0) AS DriverSalaryPerDayEUR,
    dr.EURRate,
    dt.TaxSum
FROM cte_DriversHistoric dh
INNER JOIN cte_RatesHistoric rh ON rh.SnapshotDate = dh.SnapshotDate AND rh.Class = dh.Class AND rh.rn_rate = 1
INNER JOIN _Reference33129 ClassDesc ON ClassDesc._IDRRef = dh.Class
INNER JOIN pbi.vb_DimRatesBI dr ON dr.Dates = dh.SnapshotDate AND dr.CurrencyRef = rh.CurrencyRef
INNER JOIN pbi.vb_DriverTax dt ON 
    (dh.Class IN (0x924F02B31CC3E40111EFA648B0A9D130, 0x80B902B31CC3E40111F16BD937C916E1, 0x80B902B31CC3E40111F16BD4E462D93E, 0x80B902B31CC3E40111F16BD937C916E0) AND dt.Num = 2) OR 
    (dh.Class NOT IN (0x924F02B31CC3E40111EFA648B0A9D130, 0x80B902B31CC3E40111F16BD937C916E1, 0x80B902B31CC3E40111F16BD4E462D93E, 0x80B902B31CC3E40111F16BD937C916E0) AND dt.Num = 1)
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

cte_DriversHistoric AS (
    -- 2. Для кожного 1-го числа місяця шукаємо клас водія, який діяв НА ТУ ДАТУ
    SELECT 
        m.SnapshotDate,
        CL._Fld33135RRef AS Driver,
        CL._Fld33136RRef AS Class,
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
            WHEN R._Fld33138RRef IN (0x924F02B31CC3E40111EFA648B0A9D130, 0x80B902B31CC3E40111F16BD937C916E1, 
                                     0x80B902B31CC3E40111F16BD4E462D93E, 0x80B902B31CC3E40111F16BD937C916E0)
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
    (dt.TaxSum / 30.0) / NULLIF(dr.EURRate, 0) AS DriverTaxEUR,
    (rh.DriverSalaryPerDay + (dt.TaxSum / 30.0)) / NULLIF(dr.EURRate, 0) AS DriverSalaryPerDayEUR,
    dr.EURRate,
    dt.TaxSum
FROM cte_DriversHistoric dh
INNER JOIN cte_RatesHistoric rh ON rh.SnapshotDate = dh.SnapshotDate AND rh.Class = dh.Class AND rh.rn_rate = 1
INNER JOIN _Reference33129 ClassDesc ON ClassDesc._IDRRef = dh.Class
INNER JOIN pbi.vb_DimRatesBI dr ON dr.Dates = dh.SnapshotDate AND dr.CurrencyRef = rh.CurrencyRef
INNER JOIN pbi.vb_DriverTax dt ON 
    (dh.Class IN (0x924F02B31CC3E40111EFA648B0A9D130, 0x80B902B31CC3E40111F16BD937C916E1, 0x80B902B31CC3E40111F16BD4E462D93E, 0x80B902B31CC3E40111F16BD937C916E0) AND dt.Num = 2) OR 
    (dh.Class NOT IN (0x924F02B31CC3E40111EFA648B0A9D130, 0x80B902B31CC3E40111F16BD937C916E1, 0x80B902B31CC3E40111F16BD4E462D93E, 0x80B902B31CC3E40111F16BD937C916E0) AND dt.Num = 1)
WHERE 
    dh.rn_driver = 1 -- Беремо тільки 1 актуальний клас для водія на цей місяць

GO


