-- SELECT * from pbi.v_PlanExpenses where OrderRef = '80B902B31CC3E40111F1334E6FB065C4'

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_PlanExpenses' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_PlanExpenses
GO

Create view pbi.v_PlanExpenses AS

SELECT
    IIF(_AccumRg26553._Period >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _AccumRg26553._Period), _AccumRg26553._Period) AS 'Dates',
    CONVERT(VARCHAR(MAX), _AccumRg26553._RecorderRRef, 2) AS 'RegRef',
    CONVERT(VARCHAR(MAX), _AccumRg26553._Fld26554_RRRef, 2) AS 'OrderRef',
    CASE
		WHEN CONVERT(VARCHAR(32), _AccumRg26553._Fld26555RRef, 2) = '93E78FEF853B0AA111EB6256B4F85879' THEN '983902B31CC3E40111EC7F3FD376A4F0'
		ELSE CONVERT(VARCHAR(MAX), _AccumRg26553._Fld26555RRef, 2)
    END AS 'ExpensesItemRef',
    CONVERT(VARCHAR(MAX), _AccumRg26553._Fld26556_RRRef, 2) AS 'NomenclatureRef',
    SUM(
		CASE
			WHEN CONVERT(VARCHAR(MAX), _AccumRg26553._Fld26556_RRRef, 2) = '9438B52C1CA5BDB511E67F079576A5AA'
			THEN (_Document684._Fld19466 + _Document684._Fld19467 + _Document684._Fld19468)
			ELSE 0
		END) AS 'FuelAmountPlan',
    -- CONVERT(VARCHAR(MAX), _AccumRg26553._Fld26557RRef, 2) AS 'CompanyRef',
    -- CONVERT(VARCHAR(MAX), _AccumRg26553._Fld26558RRef, 2) AS 'ClientRef',
    -- CONVERT(VARCHAR(MAX), _AccumRg26553._Fld26559_RRRef, 2) AS 'SubdivisionRef',
    -- CAST(_AccumRg26553._Fld26560_RTRef as int) AS 'TruckTableNum',
    CONVERT(VARCHAR(MAX), _AccumRg26553._Fld26560_RRRef, 2) AS 'TruckRef',
    -- CONVERT(VARCHAR(MAX), _AccumRg26553._Fld26561_RRRef, 2) AS 'PivotRouteRef',
    CONVERT(VARCHAR(MAX), _Document684._Fld19480RRef, 2) AS 'DriverRef',
    CAST(_Document684._Fld32554 as bit) AS 'ArriveCost',
    SUM(_AccumRg26553._Fld26562) AS 'Mount',
    SUM(_AccumRg26553._Fld26563) AS 'SumFact',
    SUM(_AccumRg26553._Fld26564) AS 'VAT',
    SUM(_AccumRg26553._Fld26565) - SUM(_AccumRg26553._Fld26566) AS 'SumManagerial', -- без ПДВ
    SUM(_AccumRg26553._Fld26566) AS 'VATManagerial'
FROM dbo._AccumRg26553
    INNER JOIN work.dbo._Document684
    ON _AccumRg26553._RecorderRRef = _Document684._IDRRef -- Документ - регистратор нормативных затрат (Расчет нормативных зтрат)
WHERE
    CAST(_AccumRg26553._Active AS bit) = 1
    AND _AccumRg26553._Fld26565 <> 0
GROUP BY
    _AccumRg26553._RecorderTRef,
    _AccumRg26553._RecorderRRef,
    _AccumRg26553._Period,
    _AccumRg26553._Active,
    _AccumRg26553._Fld26554_RRRef,
    _AccumRg26553._Fld26555RRef,
    _AccumRg26553._Fld26556_RTRef,
    _AccumRg26553._Fld26556_RRRef,
    _AccumRg26553._Fld26557RRef,
    _AccumRg26553._Fld26558RRef,
    _AccumRg26553._Fld26559_RRRef,
    _AccumRg26553._Fld26560_RTRef,
    _AccumRg26553._Fld26560_RRRef,
    _AccumRg26553._Fld26561_RRRef,
    _Document684._Fld32554,
    _Document684._Fld19480RRef