/*SELECT 
    m.*, 
    o.[Order]  
FROM pbi.v_Mixing AS m 
INNER JOIN pbi.v_DimOrders AS o ON o.OrderRef = m.OrderReff
ORDER BY m.Date DESC

select * from pbi.vb_Mixing
*/

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_Mixing' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_Mixing
GO

Create view pbi.v_Mixing AS

SELECT
    IIF(_InfoRg32722._Period >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _InfoRg32722._Period), _InfoRg32722._Period) AS [Date]
    ,CONVERT(VARCHAR(MAX), _InfoRg32722._Fld32723RRef, 2) AS [OrderReff]
    ,CONVERT(VARCHAR(MAX), _InfoRg32722._Fld32724, 2) AS [Hitch]
    ,CONVERT(VARCHAR(MAX), _InfoRg32722._Fld32725RRef, 2) AS [FirstTruckReff]
    ,CONVERT(VARCHAR(MAX), _InfoRg32722._Fld32726RRef, 2) AS [LastTruckReff]
	,CONVERT(VARCHAR(MAX), _InfoRg32722._Fld32727RRef, 2) AS [FirstTrailerReff]
	,CONVERT(VARCHAR(MAX), _InfoRg32722._Fld32728RRef, 2) AS [LastTrailerReff]
	,CONVERT(VARCHAR(MAX), _InfoRg32722._Fld32729RRef, 2) AS [FirstDriverReff]
	,CONVERT(VARCHAR(MAX), _InfoRg32722._Fld32730RRef, 2) AS [LastDriverReff]
    ,IIF(_InfoRg32722._Fld32731 >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _InfoRg32722._Fld32731), _InfoRg32722._Fld32731) AS [HitchDate]
FROM work.dbo._InfoRg32722
WHERE _InfoRg32722._Fld32725RRef <> 0x0 
	AND _InfoRg32722._Fld32726RRef <> 0x0 
	AND _InfoRg32722._Fld32725RRef <> _InfoRg32722._Fld32726RRef
GO

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'vb_Mixing' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_Mixing
GO

Create view pbi.vb_Mixing AS

SELECT
    IIF(_InfoRg32722._Period >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _InfoRg32722._Period), _InfoRg32722._Period) AS [Date]
    ,_InfoRg32722._Fld32723RRef AS [OrderReff]
    ,_InfoRg32722._Fld32724 AS [Hitch]
    ,_InfoRg32722._Fld32725RRef AS [FirstTruckReff]
    ,_InfoRg32722._Fld32726RRef AS [LastTruckReff]
	,_InfoRg32722._Fld32727RRef AS [FirstTrailerReff]
	,_InfoRg32722._Fld32728RRef AS [LastTrailerReff]
	,_InfoRg32722._Fld32729RRef AS [FirstDriverReff]
	,_InfoRg32722._Fld32730RRef AS [LastDriverReff]
    ,IIF(_InfoRg32722._Fld32731 >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, _InfoRg32722._Fld32731), _InfoRg32722._Fld32731) AS [HitchDate]
FROM work.dbo._InfoRg32722
WHERE _InfoRg32722._Fld32725RRef <> 0x0 
	AND _InfoRg32722._Fld32726RRef <> 0x0 
	AND _InfoRg32722._Fld32725RRef <> _InfoRg32722._Fld32726RRef
