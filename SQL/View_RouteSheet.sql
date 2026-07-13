-- SELECT * from pbi.v_RouteSheet
-- SELECT * from pbi.vb_RouteSheet

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_RouteSheet' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_RouteSheet
GO

Create view pbi.v_RouteSheet AS

SELECT
    CONVERT(VARCHAR(MAX), _Document668._IDRRef, 2) AS 'RouteSheetRef'
    ,IIF(_Document668._Date_Time > DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _Document668._Date_Time), _Document668._Date_Time) AS 'RouteSheetDate'
    ,_Document668._Number AS 'RouteSheetNumber'
    ,CAST(_Document668._Fld18466 as bit) AS 'Ñalculated'
    ,CONVERT(VARCHAR(MAX), _Document668._Fld18467RRef, 2) AS 'RouteSheetTypeRef'
    ,CONVERT(VARCHAR(MAX), _Document668._Fld18468RRef, 2) AS 'TruckRef'
    ,IIF(_Document668._Fld18478 > DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _Document668._Fld18478), _Document668._Fld18478) AS 'DateRouteStart'
    ,IIF(_Document668._Fld18479 > DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _Document668._Fld18479), _Document668._Fld18479) AS 'DateRouteEnd'
    ,_Document668._Fld18480 AS 'SpeedometerAtStart'
    ,_Document668._Fld18481 AS 'SpeedometerAtEnd'
    ,CONVERT(VARCHAR(MAX), _Document668._Fld18494RRef, 2) AS 'CompanyRef'
    ,CONVERT(VARCHAR(MAX), _Document668._Fld18498RRef, 2) AS 'DispetcherRef'
    ,CONVERT(VARCHAR(MAX), _Document668._Fld18470RRef, 2) AS 'DriverRef' -- ç äîâ³äíèêà 254 people
    ,CAST(_Document668._Fld18522 as bit) AS 'IsClosed'
    ,CONVERT(VARCHAR(MAX), _Document668._Fld27347RRef, 2) AS 'BaseDoc'
    ,_Document668._Fld28760 AS 'TruckRepresent'
    ,_Document668._Fld28761 AS 'FuelStockAtStart'
    ,_Document668._Fld28762 AS 'FuelStockAtEnd'
    ,_Document668._Fld28763 AS'FuelUsagePlan'
    ,_Document668._Fld28764 AS 'FuelUsageFact'
    --,FUEL.FuelHeatingPlan
    --,FUEL.FuelDemurragePlan
    ,CAST(_Document668._Fld32894 as bit) AS 'AdvanceReportMissing'
    ,IIF(_Document668._Fld32895 > DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _Document668._Fld32895), null) AS 'RSheetDeliveryDate'
	,CAST(_Document668._Fld34314 as bit) AS RouteIsInProgress
    FROM [work].dbo._Document668
  --  LEFT JOIN (Select _RecorderRRef,
		--SUM(_InfoRg27144._Fld27155) AS 'FuelHeatingPlan',
		--SUM(_InfoRg27144._Fld27160) AS 'FuelDemurragePlan'
		--from _InfoRg27144
		--GROUP BY _RecorderRRef
		--) AS FUEL ON  FUEL._RecorderRRef = _Document668._IDRRef
    WHERE
    CAST(_Document668._Posted as int) = 1
    AND CAST(_Document668._Marked as int) = 0
	AND CAST(_Document668._Fld27346 as bit) = 1
GO



IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'vb_RouteSheet' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_RouteSheet
GO

Create view pbi.vb_RouteSheet AS

SELECT
    _Document668._IDRRef AS 'RouteSheetRef'
    ,IIF(_Document668._Date_Time > DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _Document668._Date_Time), _Document668._Date_Time) AS 'RouteSheetDate'
    ,_Document668._Number AS 'RouteSheetNumber'
    ,CAST(_Document668._Fld18466 as bit) AS 'Ñalculated'
    ,_Document668._Fld18467RRef AS 'RouteSheetTypeRef'
    ,_Document668._Fld18468RRef AS 'TruckRef'
    ,IIF(_Document668._Fld18478 > DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _Document668._Fld18478), _Document668._Fld18478) AS 'DateRouteStart'
    ,IIF(_Document668._Fld18479 > DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _Document668._Fld18479), _Document668._Fld18479) AS 'DateRouteEnd'
    ,_Document668._Fld18480 AS 'SpeedometerAtStart'
    ,_Document668._Fld18481 AS 'SpeedometerAtEnd'
    ,_Document668._Fld18494RRef AS 'CompanyRef'
    ,_Document668._Fld18498RRef AS 'DispetcherRef'
    ,_Document668._Fld18470RRef AS 'DriverRef' -- ç äîâ³äíèêà 254 people
    ,CAST(_Document668._Fld18522 as bit) AS 'IsClosed'
    ,_Document668._Fld27347RRef AS 'BaseDoc'
    ,_Document668._Fld28760 AS 'TruckRepresent'
    ,_Document668._Fld28761 AS 'FuelStockAtStart'
    ,_Document668._Fld28762 AS 'FuelStockAtEnd'
    ,_Document668._Fld28763 AS'FuelUsagePlan'
    ,_Document668._Fld28764 AS 'FuelUsageFact'
    ,CAST(_Document668._Fld32894 as bit) AS 'AdvanceReportMissing'
    ,IIF(_Document668._Fld32895 > DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _Document668._Fld32895), null) AS 'RSheetDeliveryDate'
	,CAST(_Document668._Fld34314 as bit) AS RouteIsInProgress
    FROM [work].dbo._Document668
 
    WHERE
		_Document668._Posted = 0x01
		AND _Document668._Marked = 0x00
		AND _Document668._Fld27346 = 0x01