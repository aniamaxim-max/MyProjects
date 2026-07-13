-- SELECT * from pbi.v_RouteSheetTask
-- SELECT * from pbi.vb_RouteSheetTask

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_RouteSheetTask' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_RouteSheetTask
GO

Create view pbi.v_RouteSheetTask AS

SELECT
    CONVERT(VARCHAR(MAX), _Document668_VT18528._Document668_IDRRef, 2) AS 'RouteSheetRef'
    --,IIF(_Document668._Date_Time >=  DATEFROMPARTS(4001,1,1),CAST(DATEADD(YEAR, -2000, _Document668._Date_Time) as date), null) AS 'RouteSheetDate'
    ,CONVERT(VARCHAR(MAX), _Fld18535RRef, 2) AS 'RouteRef'
    ,CAST(_Document668_VT18528._Fld18530 as bit) AS 'IsDone'
    ,CONVERT(VARCHAR(MAX), _Fld18557_RRRef, 2) AS 'OrderRef'
    ,CONVERT(VARCHAR(MAX), _Fld18558RRef, 2) AS 'PivotRouteRef'
    ,_Fld18564 AS 'DistancePlan'
	,_Fld18559 AS 'DistanceFact'
    ,CAST(_Fld18560 as bit) AS 'EmptyDistance'
	,_Fld18565 AS'DistanceCorrection'
    ,_Fld18566 AS 'DistanceDeviation'
    ,_Fld26807 AS 'DistanceComment'
    ,IIF(_Document668_VT18528._Fld18538 >= DATEFROMPARTS(4001,1,1),DATEADD(YEAR, -2000, _Document668_VT18528._Fld18538), null) AS 'StartFact_RShT'
    ,IIF(_Document668_VT18528._Fld18539 >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, - 2000, _Document668_VT18528._Fld18539), null) AS 'EndFact_RShT'
    ,_Document668_VT18528._Fld18561 AS 'CargoCode'
    --,CONVERT(VARCHAR(MAX), _Document668_VT18616._Fld18629RRef, 2) AS 'PointUpLoaded'
    --,CONVERT(VARCHAR(MAX), _Document668_VT18616._Fld18630RRef, 2) AS 'PointUnLoaded'
    --,CONVERT(VARCHAR(MAX), _Document668_VT18616._Fld18618RRef, 2) AS 'CargoRef'
    --,SUM(_Document668_VT18616._Fld18619) AS 'CargoWeight'
    --,MIN(IIF(_Document668_VT18616._Fld18631 >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _Document668_VT18616._Fld18631), NULL)) AS 'DateUpLoaded'
    --,MAX(IIF(_Document668_VT18616._Fld18632 >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _Document668_VT18616._Fld18632), NULL)) AS 'DateUnLoaded'
    ,_Document668_VT18528._LineNo18529 AS 'Line¹'
    FROM work.dbo._Document668_VT18528
    --INNER JOIN work.dbo._Document668 ON _Document668_VT18528._Document668_IDRRef = _Document668._IDRRef
    -- Äîêóìåíò.óàòÏóòåâîéËèñò.Ãðóçû:
    --LEFT JOIN [work].dbo._Document668_VT18616 
	--ON _Document668_VT18528._Document668_IDRRef = _Document668_VT18616._Document668_IDRRef AND 
	--_Document668_VT18528._Fld18561 = _Document668_VT18616._Fld18627
    --WHERE
    --CAST(_Document668._Posted as int) = 1
    --AND CAST(_Document668._Marked as int) = 0
    --AND CAST(_Document668._Fld27346 as int) = 1
    GROUP BY
    --_Document668._Fld27346
    _Fld18535RRef
    ,_Fld18557_RRRef
    ,_Fld18558RRef
    ,_Document668_VT18528._Document668_IDRRef
    --,_Document668._Number
    ,_Fld18559
    ,_Fld18560
    ,_Fld18564
    ,_Fld18565
    ,_Fld18566
    ,_Fld26807
   -- ,_Document668._Fld18498RRef
    ,_Document668_VT18528._Fld18561
    ,_Document668_VT18528._Fld18539
    ,_Document668_VT18528._Fld18538
    --,_Document668._Fld18522
    --,_Document668._Fld18466
    --,_Document668._Fld18468RRef
    --,_Document668_VT18616._Fld18618RRef
    ,_Document668_VT18528._Fld18530
    ,_Document668_VT18528._LineNo18529
    --,_Document668._Date_Time
    --,_Document668_VT18616._Fld18629RRef
    --,_Document668_VT18616._Fld18630RRef

go


IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'vb_RouteSheetTask' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_RouteSheetTask
GO

Create view pbi.vb_RouteSheetTask AS

SELECT
    _Document668_VT18528._Document668_IDRRef AS 'RouteSheetRef'
    ,_Fld18535RRef AS 'RouteRef'
    ,CAST(_Document668_VT18528._Fld18530 as bit) AS 'IsDone'
    ,_Fld18557_RRRef AS 'OrderRef'
    ,_Fld18558RRef AS 'PivotRouteRef'
    ,_Fld18564 AS 'DistancePlan'
	,_Fld18559 AS 'DistanceFact'
    ,CAST(_Fld18560 as bit) AS 'EmptyDistance'
	,_Fld18565 AS'DistanceCorrection'
    ,_Fld18566 AS 'DistanceDeviation'
    ,_Fld26807 AS 'DistanceComment'
    ,IIF(_Document668_VT18528._Fld18538 >= DATEFROMPARTS(4001,1,1),DATEADD(YEAR, -2000, _Document668_VT18528._Fld18538), null) AS 'StartFact_RShT'
    ,IIF(_Document668_VT18528._Fld18539 >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, - 2000, _Document668_VT18528._Fld18539), null) AS 'EndFact_RShT'
    ,_Document668_VT18528._Fld18561 AS 'CargoCode'
    ,_Document668_VT18528._LineNo18529 AS 'Line¹'
    FROM work.dbo._Document668_VT18528
    GROUP BY
    _Fld18535RRef
    ,_Fld18557_RRRef
    ,_Fld18558RRef
    ,_Document668_VT18528._Document668_IDRRef
    ,_Fld18559
    ,_Fld18560
    ,_Fld18564
    ,_Fld18565
    ,_Fld18566
    ,_Fld26807
    ,_Document668_VT18528._Fld18561
    ,_Document668_VT18528._Fld18539
    ,_Document668_VT18528._Fld18538
    ,_Document668_VT18528._Fld18530
    ,_Document668_VT18528._LineNo18529

go
