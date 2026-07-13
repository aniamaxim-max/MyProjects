-- SELECT * from pbi.v_DimRoute
-- SELECT * from pbi.vb_DimRoute

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_DimRoute' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_DimRoute
GO

Create view pbi.v_DimRoute AS

SELECT
    CONVERT(VARCHAR(MAX), _Reference283._IDRRef, 2) AS 'RouteRef'
    ,CONVERT(VARCHAR(MAX), _Reference283._ParentIDRRef, 2) AS 'ParentRouteRef'
    ,_Reference283._Code AS 'RouteID'
    ,_Reference283._Description AS 'RouteName'
    ,CONVERT(VARCHAR(MAX), _Reference283._Fld3644RRef, 2) AS 'RouteArrivalPoint'
    ,CONVERT(VARCHAR(MAX), _Reference283._Fld3645RRef, 2) AS 'RouteDeparturePoint'
    ,CONVERT(VARCHAR(MAX), _Reference283._Fld3646RRef, 2) AS 'CountryRef'
    ,_Reference283._Fld3648 AS 'Distance'
    ,SUM(ISNULL(_Reference283_VT32570._Fld32575, 0)) as 'NumOfDays'
    FROM [work].dbo._Reference283
    LEFT JOIN [work].dbo._Reference283_VT32570 ON _Reference283_VT32570._Reference283_IDRRef = _Reference283._IDRRef
	WHERE CAST(_Reference283._Marked as bit) = 0 AND
	CAST(_Reference283._Folder as bit) = 1

    GROUP BY
    _Reference283._IDRRef
    ,_Reference283._ParentIDRRef
    ,_Reference283._Code
    ,_Reference283._Description
    ,_Reference283._Fld3644RRef
    ,_Reference283._Fld3645RRef
    ,_Reference283._Fld3646RRef
    ,_Reference283._Fld3647
    ,_Reference283._Fld3648
    ,_Reference283._Fld3649
    ,_Reference283._Fld26860RRef
GO


IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'vb_DimRoute' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_DimRoute
GO

Create view pbi.vb_DimRoute AS

SELECT
    _Reference283._IDRRef AS 'RouteRef'
    ,_Reference283._ParentIDRRef AS 'ParentRouteRef'
    ,_Reference283._Code AS 'RouteID'
    ,_Reference283._Description AS 'RouteName'
    ,_Reference283._Fld3644RRef AS 'RouteArrivalPoint'
    ,_Reference283._Fld3645RRef AS 'RouteDeparturePoint'
    ,_Reference283._Fld3646RRef AS 'CountryRef'
    ,_Reference283._Fld3648 AS 'Distance'
    ,SUM(ISNULL(_Reference283_VT32570._Fld32575, 0)) as 'NumOfDays'
    FROM [work].dbo._Reference283
    LEFT JOIN [work].dbo._Reference283_VT32570 ON _Reference283_VT32570._Reference283_IDRRef = _Reference283._IDRRef
	WHERE _Reference283._Marked = 0x00 AND _Reference283._Folder = 0x01

    GROUP BY
    _Reference283._IDRRef
    ,_Reference283._ParentIDRRef
    ,_Reference283._Code
    ,_Reference283._Description
    ,_Reference283._Fld3644RRef
    ,_Reference283._Fld3645RRef
    ,_Reference283._Fld3646RRef
    ,_Reference283._Fld3647
    ,_Reference283._Fld3648
    ,_Reference283._Fld3649
    ,_Reference283._Fld26860RRef

