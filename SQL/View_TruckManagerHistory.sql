-- SELECT * from pbi.v_TruckManagerHistory
-- SELECT * from pbi.vb_TruckManagerHistory

IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'v_TruckManagerHistory' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.v_TruckManagerHistory
GO

Create view pbi.v_TruckManagerHistory AS

SELECT 
	IIF(h._Period >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, h._Period), h._Period) AS PeriodStart,
	CONVERT(VARCHAR(MAX), _Fld34597RRef, 2) AS TruckRef,
	CONVERT(VARCHAR(MAX), _Fld34598RRef, 2) AS ManagerRef
FROM _InfoRg34596 h
GO


IF EXISTS(SELECT v.name FROM sys.views v
				INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
			WHERE v.name = 'vb_TruckManagerHistory' AND v.type = 'V' AND s.name = 'pbi')
    DROP VIEW pbi.vb_TruckManagerHistory
GO

Create view pbi.vb_TruckManagerHistory AS

SELECT 
	IIF(h._Period >= DATEFROMPARTS(4001,1,1), DATEADD(YEAR, -2000, h._Period), h._Period) AS PeriodStart,
	_Fld34597RRef AS TruckRef,
	_Fld34598RRef AS ManagerRef
FROM _InfoRg34596 h
GO