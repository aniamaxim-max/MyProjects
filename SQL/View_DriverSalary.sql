-- SELECT * from pbi.v_DriverSalary 

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_DriverSalary' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_DriverSalary
GO

Create view pbi.v_DriverSalary AS

WITH cte_DriverClasses AS (
    SELECT
        IIF(_Period >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _Period), _Period) AS [Period],
        CONVERT(VARCHAR(MAX), CL._Fld33135RRef, 2) AS Driver,
        CONVERT(VARCHAR(MAX), CL._Fld33136RRef, 2) AS Class,
        ROW_NUMBER() OVER (
            PARTITION BY _Fld33135RRef, _Fld33136RRef
            ORDER BY _Period DESC
        ) AS RN
    FROM _InfoRg33134 CL -- класи водіїв
),
cte_RateClasses AS (
    SELECT 
        CONVERT(VARCHAR(MAX), _InfoRg33137._Fld33138RRef, 2) AS Class, 
        _Fld33140 AS DriverSalaryPerDay,
        CONVERT(VARCHAR(MAX), _InfoRg33137._Fld34210RRef, 2) AS Currency,
        ROW_NUMBER() OVER (
            PARTITION BY 
                _InfoRg33137._Fld33138RRef
            ORDER BY _Period DESC
        ) AS rn
    FROM _InfoRg33137 -- тариф по класу
	WHERE
	CONVERT(VARCHAR(MAX), _InfoRg33137._Fld33139RRef, 2) = '9F700416C8172D6D434B867B43C82D1F' AND
	_InfoRg33137._Fld33214RRef = 0x00000000000000000000000000000000
)

SELECT
    cte_DriverClasses.[Period],
    cte_DriverClasses.Driver,
    cte_DriverClasses.Class,
	ClassDesc._Description,
	cte_RateClasses.DriverSalaryPerDay,
	(cte_RateClasses.DriverSalaryPerDay) / dr.EURRate as DriverSalaryPerDayNoTaxEUR,
	(dt.TaxSum /30) / dr.EURRate as DriverTaxEUR,
	(cte_RateClasses.DriverSalaryPerDay + dt.TaxSum /30) / dr.EURRate as DriverSalaryPerDayEUR,
	dr.EURRate,
	dt.TaxSum
FROM cte_DriverClasses
inner JOIN _Reference33129 ClassDesc ON CONVERT(VARCHAR(MAX), ClassDesc._IDRRef, 2) = cte_DriverClasses.Class
inner JOIN cte_RateClasses ON cte_RateClasses.Class = cte_DriverClasses.Class
inner JOIN pbi.v_DimRatesBI dr ON (dr.Dates =  cte_DriverClasses.[Period])
							and (dr.CurrencyRef = cte_RateClasses.Currency)
INNER JOIN pbi.v_DriverTax dt ON (cte_DriverClasses.Class = '924F02B31CC3E40111EFA648B0A9D130' and dt.Num = 2)  
								 or (cte_DriverClasses.Class <> '924F02B31CC3E40111EFA648B0A9D130' and dt.Num = 1)

WHERE cte_DriverClasses.rn = 1 AND cte_RateClasses.rn = 1

go

